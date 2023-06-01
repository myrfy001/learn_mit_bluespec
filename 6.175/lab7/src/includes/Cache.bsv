import CacheTypes::*;
import Fifo::*;
import MemTypes::*;
import MemUtil::*;


module mkTranslator(WideMem backend, Cache ifc);

    
    Fifo#(2, MemReq) originReq <- mkCFFifo();

    method Action req(MemReq r);
        originReq.enq(r);
        backend.req(toWideMemReq(r));
    endmethod

    method ActionValue#(MemResp) resp;
        let rsp <- backend.resp;
        let oreq = originReq.first;
        originReq.deq;

        CacheWordSelect wordsel = truncate( oreq.addr >> 2 );
        return rsp[wordsel];
    endmethod
endmodule