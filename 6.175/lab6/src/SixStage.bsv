// Six stage

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import MemInit::*;
import RFile::*;
import FPGAMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Fifo::*;
import Ehr::*;
import Btb::*;
import Scoreboard::*;


typedef struct {
    Addr pc;
    Addr predPc;
    Bool epoch;
} Fetch2Decode deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool epoch;
} Decode2RegFetch deriving (Bits, Eq);

// Data structure for Fetch to Execute stage
typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool epoch;
} RegFetch2Execute deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    ExecInst eInst;
    Bool epoch;
} Execute2Memory deriving (Bits, Eq);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    ExecInst eInst;
    Bool epoch;
} Memory2WriteBack deriving (Bits, Eq);

// redirect msg from Execute stage
typedef struct {
	Addr pc;
	Addr nextPc;
} ExeRedirect deriving (Bits, Eq);

(* synthesize *)
module mkProc(Proc);
    Ehr#(2, Addr) pcReg <- mkEhr(?);
    RFile            rf <- mkRFile;
	Scoreboard#(2)   sb <- mkCFScoreboard;
	FPGAMemory        iMem <- mkFPGAMemory;
    FPGAMemory        dMem <- mkFPGAMemory;
    CsrFile        csrf <- mkCsrFile;
    Btb#(6)         btb <- mkBtb; // 64-entry BTB

	// global epoch for redirection from Execute stage
	Reg#(Bool) exeEpoch <- mkReg(False);

	// EHR for redirection
	Ehr#(2, Maybe#(ExeRedirect)) exeRedirect <- mkEhr(Invalid);

	// FIFO between two stages
	Fifo#(2, Fetch2Decode) f2dFifo <- mkCFFifo;
    Fifo#(2, Decode2RegFetch) d2rFifo <- mkCFFifo;
    Fifo#(2, RegFetch2Execute) r2eFifo <- mkCFFifo;
    Fifo#(2, Maybe#(Execute2Memory)) e2mFifo <- mkCFFifo;
    Fifo#(2, Maybe#(Memory2WriteBack)) m2wFifo <- mkCFFifo;

    Bool memReady = iMem.init.done && dMem.init.done;

	// fetch, decode, reg read stage
	rule doFetch(csrf.started);
		// fetch
		iMem.req(MemReq{op: Ld, addr: pcReg[0], data: ?});
		Addr predPc = btb.predPc(pcReg[0]);
        pcReg[0] <= predPc;

        Fetch2Decode f2d = Fetch2Decode{
            pc: pcReg[0],
			predPc: predPc,
			epoch: exeEpoch
        };

        f2dFifo.enq(f2d);
        $display("ReqFetch: PC = %x", pcReg[0]);
    endrule
	
    rule doDecode(csrf.started);
		Fetch2Decode f2d = f2dFifo.first;
        f2dFifo.deq;
        
        let inst <- iMem.resp;
		DecodedInst dInst = decode(inst);

        $display("Decode: PC = %x, inst = %x, expanded = ", f2d.pc, inst, showInst(inst));

        Decode2RegFetch d2r = Decode2RegFetch {
            pc: f2d.pc,
            predPc: f2d.predPc,
            dInst: dInst,
			epoch: f2d.epoch
        };

        d2rFifo.enq(d2r);
    endrule  

    rule doRegFetch(csrf.started);

        let d2r = d2rFifo.first;
        
		// reg read
		Data rVal1 = rf.rd1(fromMaybe(?, d2r.dInst.src1));
		Data rVal2 = rf.rd2(fromMaybe(?, d2r.dInst.src2));
		Data csrVal = csrf.rd(fromMaybe(?, d2r.dInst.csr));
		// data to enq to FIFO
		RegFetch2Execute r2e = RegFetch2Execute {
			pc: d2r.pc,
			predPc: d2r.predPc,
			dInst: d2r.dInst,
			rVal1: rVal1,
			rVal2: rVal2,
			csrVal: csrVal,
			epoch: d2r.epoch
		};

        $display("xxxxxxxxxxxxxxxx  %x,  %x", d2r.dInst.src1, d2r.dInst.src2);
        $display("yyyyyyyyyyyyyyyy  %x,  %x", sb.search1(d2r.dInst.src1), sb.search2(d2r.dInst.src2));

        
		// search scoreboard to determine stall
		if(!sb.search1(d2r.dInst.src1) && !sb.search2(d2r.dInst.src2)) begin
            $display("Fetch Reg PC = %x", d2r.pc);
            $display("Fetch Reg PC insert sb = %x", d2r.dInst.dst);
            d2rFifo.deq();
			r2eFifo.enq(r2e);
			sb.insert(d2r.dInst.dst);
		end
		else begin
			$display("Fetch Reg Stalled: PC = %x", d2r.pc);
		end

    endrule



	(* fire_when_enabled *)
	(* no_implicit_conditions *)
	rule cononicalizeRedirect(csrf.started);
		if(exeRedirect[1] matches tagged Valid .r) begin
			// fix mispred
			pcReg[1] <= r.nextPc;
			exeEpoch <= !exeEpoch; // flip epoch
			btb.update(r.pc, r.nextPc); // train BTB
			$display("Fetch: Mispredict, redirected by Execute");
		end
		// reset EHR
		exeRedirect[1] <= Invalid;
	endrule

	// ex, mem, wb stage
	rule doExecute(csrf.started);
		r2eFifo.deq;
		let r2e = r2eFifo.first;

        $display("Execute: PC = %x", r2e.pc);

		if(r2e.epoch != exeEpoch) begin
			e2mFifo.enq(tagged Invalid);
			$display("Execute: Kill instruction");
		end
		else begin
			// execute
			ExecInst eInst = exec(r2e.dInst, r2e.rVal1, r2e.rVal2, r2e.pc, r2e.predPc, r2e.csrVal);
            // check unsupported instruction at commit time. Exiting
            if(eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", r2e.pc);
                $finish;
            end
            Execute2Memory e2m = Execute2Memory {
                pc: r2e.pc,
                predPc: r2e.predPc,
                dInst: r2e.dInst,
                rVal1: r2e.rVal1,
                rVal2: r2e.rVal2,
                csrVal: r2e.csrVal,
                eInst:eInst,
                epoch: r2e.epoch
            };
            e2mFifo.enq(tagged Valid e2m);
        end

    endrule

    rule doMemory(csrf.started);

        let e2m_maybe = e2mFifo.first;
        e2mFifo.deq();

        if (e2m_maybe matches tagged Valid .e2m) begin
            let eInst = e2m.eInst;
            $display("Memory: PC = %x", e2m.pc);

            // memory
            if(eInst.iType == Ld) begin
                dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
            end else if(eInst.iType == St) begin
                dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
            end

            Memory2WriteBack m2w = Memory2WriteBack {
                pc: e2m.pc,
                predPc: e2m.predPc,
                dInst: e2m.dInst,
                rVal1: e2m.rVal1,
                rVal2: e2m.rVal2,
                csrVal: e2m.csrVal,
                eInst: e2m.eInst,
                epoch: e2m.epoch
            };
            m2wFifo.enq(tagged Valid m2w);
        end else begin
            m2wFifo.enq(tagged Invalid);
        end
    endrule    

    rule doWriteBack(csrf.started);
        let m2w_maybe = m2wFifo.first;
        m2wFifo.deq();

        if (m2w_maybe matches tagged Valid .m2w) begin
            let eInst = m2w.eInst;

            if(eInst.iType == Ld) begin
                eInst.data <- dMem.resp;
            end

            // write back to reg file
            if(isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end
            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);

            if(eInst.mispredict) begin //no btb update?
                $display("Execute finds misprediction: PC = %x", m2w.pc);
                exeRedirect[0] <= Valid (ExeRedirect {
                    pc: m2w.pc,
                    nextPc: eInst.addr // Hint for discussion 1: check this line
                });
            end
            else begin
                $display("WriteBack: PC = %x", m2w.pc);
            end
        end

        // remove from scoreboard
        $display("Remove SB");
        sb.remove;
        
    
    endrule  

    method ActionValue#(CpuToHostData) cpuToHost if(csrf.started);
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
	$display("Start cpu");
        csrf.start(0); // only 1 core, id = 0
        pcReg[0] <= startpc;
    endmethod

	interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

