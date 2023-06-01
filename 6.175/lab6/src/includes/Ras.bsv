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
        if (p < fromInteger(valueOf(size) - 1)) begin
            p <= p + 1;
            store[p + 1] <= tagged Valid addr;
        end else begin 
            p <= 0;
            store[0] <= tagged Valid addr;
        end
        
    endmethod

    method ActionValue#(Maybe#(Addr)) pop();
        let r = store[p];
        store[p] <= tagged Invalid;
        if (p > 0) begin
            p <= p - 1;
        end else begin 
            p <= fromInteger(valueOf(size) - 1);
        end
        return r;

    endmethod
endmodule