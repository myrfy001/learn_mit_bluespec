import Vector::*;
import ProcTypes::*;
import Types::*;

interface RAS#(numeric type size);
    method Action push(Addr addr);
    method ActionValue#(Maybe#(Addr)) pop();
endinterface

module mkRas(RAS#(size));
    Vector#(size, Reg#(Maybe#(Addr))) store <- replicateM(mkReg(tagged Invalid));
    Reg#(Bit#(TLog#(size))) p <- mkReg(0);

    method Action push(Addr addr);
        store[p] <= tagged Valid addr;
        if (p < fromInteger(valueOf(size) - 1)) begin
            p <= p + 1;
        end else begin 
            p <= 0;
        end
    endmethod

    method ActionValue#(Maybe#(Addr)) pop();
        if (p > 0) begin
            p <= p - 1;
        end else begin 
            p <= fromInteger(valueOf(size) - 1);
        end
        return store[p];
    endmethod
endmodule