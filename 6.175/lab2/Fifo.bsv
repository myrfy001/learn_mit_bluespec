import Ehr::*;
import Vector::*;
import FIFO::*;

interface Fifo#(numeric type n, type t);
    method Action enq(t x);
    method Action deq;
    method t first;
    method Bool notEmpty;
    method Bool notFull;
endinterface

// Exercise 1
// Completes the code in Fifo.bsv to implements a 3-elements fifo with properly
// guarded methods. Feel free to take inspiration from the class slides.
// The interface defined in Fifo.bsv tells you the type of the methods
// (enq, deq, first) that your module should define.
module mkFifo(Fifo#(3,t)) provisos (Bits#(t,tSz));
   // define your own 3-elements fifo here.
    Vector#(3, Reg#(t)) d;
    d[0] <- mkRegU();
    d[1] <- mkRegU();
    d[2] <- mkRegU();
    Reg#(Bit#(3)) v <- mkReg(0);

    rule canonicalize;

        

    endrule

    // Enq if there's at least one spot open... so, dc is invalid.
    method Action enq(t x) if (v[2] == 0);
        $display("enq=%d", v);
        if (v[0] == 0) begin 
            d[0] <= x;
            v[0] <= 1;
        end else if (v[1] == 0) begin
            d[1] <= x;
            v[1] <= 1;
        end else begin 
            d[2] <= x;
            v[2] <= 1;
        end
    endmethod

    // Deq if there's a valid d[0]ta at d[0]
    method Action deq() if (v[0] == 1);
        $display("deq=%d", v);
        if (v[2]==1) begin
            d[0] <= d[1];
            d[1] <= d[2];
            v[2] <= 0;
        end else if (v[1] == 1) begin
             d[0] <= d[1];
             v[1] <= 0;
        end else begin
            v[0] <= 0;
            // v[1] <= 0;
            // v[2] <= 0;
        end
    endmethod

    // First if there's a valid data at d[0]
    method t first() if (v[0] == 1);
        return d[0];
    endmethod

    // Check if fifo's empty
    method Bool notEmpty();
        return v[0] == 1;
    endmethod

    method Bool notFull();
       return v[2] == 0;
    endmethod

endmodule


// Two elements conflict-free fifo given as black box
module mkCFFifo( Fifo#(2, t) ) provisos (Bits#(t, tSz));
    Ehr#(2, t) da <- mkEhr(?);
    Ehr#(2, Bool) va <- mkEhr(False);
    Ehr#(2, t) db <- mkEhr(?);
    Ehr#(2, Bool) vb <- mkEhr(False);

    rule canonicalize;
        if( vb[1] && !va[1] ) begin
            da[1] <= db[1];
            va[1] <= True;
            vb[1] <= False;
        end
    endrule

    method Action enq(t x) if(!vb[0]);
        db[0] <= x;
        vb[0] <= True;
    endmethod

    method Action deq() if(va[0]);
        va[0] <= False;
    endmethod

    method t first if (va[0]);
        return da[0];
    endmethod

    method Bool notEmpty();
        return va[0];
    endmethod

    method Bool notFull();
        return !vb[0];
    endmethod

endmodule

module mkCF3Fifo(Fifo#(3,t)) provisos (Bits#(t, tSz));
    FIFO#(t) bsfif <-  mkSizedFIFO(3);
    method Action enq( t x);
        bsfif.enq(x);
    endmethod

    method Action deq();
        bsfif.deq();
    endmethod

    method t first();
        return bsfif.first();
    endmethod

    method Bool notEmpty();
        return True;
    endmethod

    method Bool notFull();
        return True;
    endmethod

endmodule
