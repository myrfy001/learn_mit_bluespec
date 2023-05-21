// FourCycle.bsv
//
// This is a four cycle implementation of the RISC-V processor.

// TwoCycle.bsv
//
// This is a two cycle implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import DelayedMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;

typedef enum {
	Fetch,
    Decode,
	Execute,
    WriteBack
} Stage deriving(Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    DelayedMemory  mem <- mkDelayedMemory;
    CsrFile  csrf <- mkCsrFile;

    Reg#(Stage) curStage <- mkReg(Fetch);

    Bool memReady = mem.init.done();
    Reg#(DecodedInst) dInst <- mkRegU();
    Reg#(ExecInst) eInst <- mkRegU();

    rule test (!memReady);
        let e = tagged InitDone;
        mem.init.request.put(e);
    endrule

    rule doFetch(csrf.started && curStage == Fetch && memReady);
        mem.req(MemReq{op: Ld, addr: pc, data: ?});
        curStage <= Decode;
    endrule
    
    rule doDecode (csrf.started && curStage == Decode && memReady);
        // decode

        Data inst <- mem.resp;
        dInst <= decode(inst);
        curStage <= Execute;

        // trace - print the instruction
        $display("pc: %h inst: (%h) expanded: ", pc, inst, showInst(inst));
	    $fflush(stdout);
    endrule

    rule doExecute(csrf.started && curStage == Execute && memReady);

        // read general purpose register values    
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

        // read CSR values (for CSRR inst)
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        // execute
        ExecInst eInstTmp = exec(dInst, rVal1, rVal2, pc, ?, csrVal);  
		// memory
        // The fifth argument above is the predicted pc, to detect if it was mispredicted. 
		// Since there is no branch prediction, this field is sent with a random value
        if(eInstTmp.iType == Ld) begin
            mem.req(MemReq{op: Ld, addr: eInstTmp.addr, data: ?});
        end else if(eInstTmp.iType == St) begin
            mem.req(MemReq{op: St, addr: eInstTmp.addr, data: eInstTmp.data});
        end

        eInst <= eInstTmp;

        curStage <= WriteBack;
    endrule

    rule doWriteBack(csrf.started && curStage == WriteBack && memReady);
		// commit
        
        // check unsupported instruction at commit time. Exiting
        if(eInst.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
            $finish;
        end

        let eInstTmp = eInst;
        if(eInstTmp.iType == Ld) begin
            eInstTmp.data <- mem.resp;
        end


        // write back to reg file
        if(isValid(eInstTmp.dst)) begin
            rf.wr(fromMaybe(?, eInstTmp.dst), eInstTmp.data);
        end

        // update the pc depending on whether the branch is taken or not
        pc <= eInstTmp.brTaken ? eInstTmp.addr : pc + 4;

        // CSR write for sending data to host & stats
        csrf.wr(eInstTmp.iType == Csrw ? eInstTmp.csr : Invalid, eInstTmp.data);

        curStage <= Fetch;
    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
	$display("Start at pc 200\n");
	$fflush(stdout);
        pc <= startpc;
        curStage <= Fetch;
    endmethod

    interface iMemInit = mem.init;
    interface dMemInit = mem.init;
endmodule


(* synthesize *)
module mkTb();
    Proc fifo <-mkProc();
endmodule