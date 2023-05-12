import Ehr::*;
import Vector::*;
import FIFO::*;

import Ehr::*;
import Vector::*;

//////////////////
// Fifo interface 

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface



module mkMyPipelineFifo( Fifo#(1, t) ) provisos (Bits#(t, tSz));
    Ehr#(3, t) da <- mkEhr(?);
    Ehr#(3, Bool) va <- mkEhr(False);

    method Action enq(t x) if(!va[1]);
        da[1] <= x;
        va[1] <= True;
    endmethod

    method Action deq() if(va[0]);
        va[0] <= False;
    endmethod

    method t first if (va[0]);
        return da[0];
    endmethod

    method Action clear;
        va[2] <= False;
    endmethod

endmodule


module mkMyBypassFifo( Fifo#(1, t) ) provisos (Bits#(t, tSz));
    Ehr#(3, t) da <- mkEhr(?);
    Ehr#(3, Bool) va <- mkEhr(False);

    method Action enq(t x) if(!va[0]);
        da[0] <= x;
        va[0] <= True;
    endmethod

    method Action deq() if(va[1]);
        va[1] <= False;
    endmethod

    method t first if (va[1]);
        return da[1];
    endmethod

    method Action clear;
        va[2] <= False;
    endmethod

endmodule


module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    Reg#(t)     data     <- mkRegU();
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);

    Ehr#(2, Bool)         deqReq  <- mkEhr(False);
    Ehr#(2, Maybe#(t))    enqReq  <- mkEhr(tagged Invalid);
    Ehr#(2, Bool)         clearReq  <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    (* no_implicit_conditions *)
    (* fire_when_enabled *)
    rule canonicalize (True);
        deqReq[1] <= False;
        enqReq[1] <= tagged Invalid;
        clearReq[1] <= False;


        case (tuple3(enqReq[1], deqReq[1], clearReq[1])) matches
            {tagged Valid .dat, True, False}: begin
                data <= dat;
            end
            {tagged Valid .dat, False, False}: begin
                data <= dat;
                full <= True;
                empty <= False;
            end
            {tagged Invalid, True, False}: begin
                empty <= True;
                full <= False;
            end
            {.*, .*, True}: begin
                empty <= True;
                full <= False;
            end
            default: begin end
        endcase      

    endrule

    method Bool notFull;
        return !full;
    endmethod

    method Action enq(t x) if (full==False);
        enqReq[0] <= tagged Valid x; 
    endmethod

    method Bool notEmpty;
        return !empty;
    endmethod

    method Action deq if (empty==False);
        deqReq[0] <= True;
    endmethod


    method t first if (empty==False);
        return data;
    endmethod

    method Action clear;
        clearReq[0] <= True;
    endmethod
endmodule





// module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
//     Reg#(t)     data     <- mkRegU();
//     Ehr#(2,Bool)              empty    <- mkEhr(True);
//     Ehr#(2,Bool)              full     <- mkEhr(False);

//     Ehr#(2, Bool)         deqReq  <- mkEhr(False);
//     Ehr#(2, Maybe#(t))    enqReq  <- mkEhr(tagged Invalid);
//     Ehr#(2, Bool)         clearReq  <- mkEhr(False);

//     // useful value
//     Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

//     // TODO: Implement all the methods for this module

//     (* no_implicit_conditions *)
//     (* fire_when_enabled *)
//     rule canonicalize (True);
//         deqReq[1] <= False;
//         enqReq[1] <= tagged Invalid;
//         clearReq[1] <= False;


//         case (tuple3(enqReq[1], deqReq[1], clearReq[1])) matches
//             {tagged Valid .dat, True, False}: begin
//                 data <= dat;
//             end
//             {tagged Valid .dat, False, False}: begin
//                 data <= dat;
//                 full[0] <= True;
//                 empty[0] <= False;
//             end
//             {tagged Invalid, True, False}: begin
//                 empty[1] <= True;
//                 full[1] <= False;
//             end
//             {.*, .*, True}: begin
//                 empty[0] <= True;
//                 full[0] <= False;
//             end
//             default: begin end
//         endcase      

//     endrule

//     method Bool notFull;
//         return !full[1];
//     endmethod

//     method Action enq(t x) if (full[1]==False);
//         enqReq[0] <= tagged Valid x; 
//     endmethod

//     method Bool notEmpty;
//         return !empty[1];
//     endmethod

//     method Action deq if (empty[1]==False);
//         deqReq[0] <= True;
//     endmethod


//     method t first if (empty[1]==False);
//         return data;
//     endmethod

//     method Action clear;
//         clearReq[0] <= True;
//     endmethod
// endmodule




