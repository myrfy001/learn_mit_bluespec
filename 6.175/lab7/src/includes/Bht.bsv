import Types::*;
import ProcTypes::*;
import RegFile::*;
import Vector::*; 

typedef Bit#(idxBits) BhtIndex#(numeric type idxBits);

interface DirectionPred#(numeric type idxBits);
    method Addr ppcDP(Addr pc, Addr targetPC);
    method Action update(Addr pc, Bool taken);
endinterface


module mkBht(DirectionPred#(idxBits));

    Vector#(TExp#(idxBits), Reg#(Bit#(2))) bhtArr <- replicateM(mkReg(2'b01));

    function BhtIndex#(idxBits) getBhtIndex(Addr pc);
        return pc[valueOf(idxBits)+1:2];
    endfunction

    function Bit#(2) newDpBits(Bit#(2) curDpBits, Bool taken);
        if (curDpBits == 2'b11 && taken == True) begin
            return 2'b11;
        end else if (curDpBits == 2'b00 && taken == False) begin
            return 2'b00;
        end else if (taken == True) begin
            return curDpBits + 1;
        end else begin
            return curDpBits - 1;
        end
    endfunction

    function Bit#(2) getBhtEntry(BhtIndex#(idxBits) index);
        return bhtArr[index];
    endfunction

    function Addr computeTarget(Addr pc, Addr targetPC, Bool taken);
        return taken ? targetPC : pc + 4;
    endfunction

    function Bool extractDir(Bit#(2) val);
        return val[1] == 1;
    endfunction


    method Addr ppcDP(Addr pc, Addr targetPC);
        let index = getBhtIndex(pc);
        let entry = getBhtEntry(index);
        let taken = extractDir(entry);
        return computeTarget(pc, targetPC, taken);
    endmethod


    method Action update(Addr pc, Bool taken);
        let index = getBhtIndex(pc);
        let entry = getBhtEntry(index);
        let next_entry = newDpBits(entry, taken);
        bhtArr[index] <= next_entry;
    endmethod

endmodule