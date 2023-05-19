// TwoStage.bsv
//
// This is a two stage pipelined implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;

(* synthesize *)
module mkProc(Proc);
    
    RFile      rf <- mkRFile;
    IMemory  iMem <- mkIMemory;
    DMemory  dMem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;

    Reg#(Addr) fetch_pc <- mkRegU;
    Reg#(Addr) exe_pc <- mkRegU;
    Reg#(Maybe#(DecodedInst)) dInstMaybe <- mkReg(tagged Invalid);
    Reg#(Bool) isFirstInst <- mkRegU();
    
    


    Bool memReady = iMem.init.done() && dMem.init.done();
    rule test (!memReady);
        let e = tagged InitDone;
        iMem.init.request.put(e);
        dMem.init.request.put(e);
    endrule

    rule run (csrf.started);
        ExecInst eInst = ?;
        isFirstInst <= False;
        
        Data inst = iMem.req(fetch_pc);

        // decode
        DecodedInst tmp_dInst = decode(inst);

        // trace - print the instruction
        $display("fetch_pc: %h inst: (%h) expanded: ", fetch_pc, inst, showInst(inst));

        $fflush(stdout);
        
        


        if (dInstMaybe matches tagged Valid .dInst) begin 

            $display("execute");

            // read general purpose register values 
            Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
            Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

            // read CSR values (for CSRR inst)
            Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

            // execute
            eInst = exec(dInst, rVal1, rVal2, exe_pc, fetch_pc, csrVal);  
            

            // memory
            if(eInst.iType == Ld) begin
                eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
            end else if(eInst.iType == St) begin
                let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
            end

            $display("eInst.addr=%x, fetch_pc=%x, eInst.mispredict=%d", eInst.addr, fetch_pc, eInst.mispredict);


            // check unsupported instruction at commit time. Exiting
            if(eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", exe_pc);
                $finish;
            end

            // write back to reg file
            if(isValid(eInst.dst)) begin
                rf.wr(fromMaybe(?, eInst.dst), eInst.data);
            end


            // CSR write for sending data to host & stats
            csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);
        end else begin 
            eInst.mispredict = False;
            $display("execute stall due to predict wrong");
        end


        // the code order is important.
        // TODO: why?
        if ((eInst.mispredict == True) && !isFirstInst) begin
            $display("predict wrong");
            fetch_pc <= eInst.addr;
            dInstMaybe <= tagged Invalid;
        end else begin
            $display("predict right");
            fetch_pc <= fetch_pc + 4;
            dInstMaybe <= tagged Valid tmp_dInst;
            exe_pc <= fetch_pc;
        end


    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
	$display("Start at pc 200\n");
	$fflush(stdout);
        fetch_pc <= startpc;
        dInstMaybe <= tagged Invalid;
        isFirstInst <= True;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

