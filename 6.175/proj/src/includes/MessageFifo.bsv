import CacheTypes::*;
import Fifo::*;

module mkMessageFifo(MessageFifo#(n));

    Fifo#(n, CacheMemReq) reqFifo <- mkCFFifo;
    Fifo#(n, CacheMemResp) respFifo <- mkCFFifo;



    method Action enq_resp(CacheMemResp d);
        respFifo.enq(d);
    endmethod

    method Action enq_req(CacheMemReq d);
        reqFifo.enq(d);
    endmethod

    method Bool hasResp;
        return respFifo.notEmpty;
    endmethod

    method Bool hasReq;
        return reqFifo.notEmpty;
    endmethod

    method Bool notEmpty;
        return respFifo.notEmpty || reqFifo.notEmpty;
    endmethod

    method CacheMemMessage first;
        if (respFifo.notEmpty) begin
            return tagged Resp respFifo.first;
        end else begin
            return tagged Req reqFifo.first;
        end
    endmethod

    method Action deq;
        if (respFifo.notEmpty) begin
            respFifo.deq;
        end else begin
            reqFifo.deq;
        end
    endmethod

endmodule