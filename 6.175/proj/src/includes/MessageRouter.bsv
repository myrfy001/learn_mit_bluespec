
import Types::*;
import Vector::*;
import CacheTypes::*;

module mkMessageRouter(
  Vector#(CoreNum, MessageGet) c2r, Vector#(CoreNum, MessagePut) r2c, 
  MessageGet m2r, MessagePut r2m,
  Empty ifc 
);

    Reg#(Bit#(TLog#(CoreNum))) lastHandledCore <- mkReg(0);

    rule doRoute;
        Bool haveC2RResp = False;
        Bool haveC2RReq = False;
        let haveM2RResp = m2r.hasResp;
        let haveM2RReq = m2r.hasReq;
        Bit#(TLog#(CoreNum)) respRdyIdx = 0;
        Bit#(TLog#(CoreNum)) reqRdyIdx = 0;
        
        lastHandledCore <= lastHandledCore + 1;

        for (Integer _i=0; _i < valueOf(CoreNum); _i=_i+1) begin

            Bit#(TLog#(CoreNum)) i = lastHandledCore + 1 + fromInteger(_i);
            
            if (c2r[i].hasResp && haveC2RResp == False) begin
                respRdyIdx = i;
                haveC2RResp = True;
            end
            
            if (c2r[i].hasReq && haveC2RReq == False) begin
                reqRdyIdx = i;
                haveC2RReq = True;
            end
        end

        // $display("%0t  Router haveC2RResp = %d, respRdyIdx = %d, haveC2RReq = %d, reqRdyIdx = %d, haveM2RResp = %d, haveM2RReq = %d", 
        //           $time, haveC2RResp, respRdyIdx, haveC2RReq, reqRdyIdx, haveM2RResp, haveM2RReq);

        if (haveC2RResp) begin
            r2m.enq_resp(c2r[respRdyIdx].first.Resp);
            c2r[respRdyIdx].deq;
            $display("%0t  Router send resp from core %d to mem  ", $time, respRdyIdx, fshow(c2r[respRdyIdx].first.Resp));
        end else if (haveM2RResp) begin 
            let rsp = m2r.first.Resp;
            m2r.deq;
            r2c[rsp.child].enq_resp(rsp);
            $display("%0t  Router send resp from mem to core %d  ", $time, rsp.child, fshow(rsp));
        end else if (haveM2RReq) begin  
            // handle haveM2RReq before haveC2RReq, because haveC2RReq is more busy than haveM2RReq. 
            // Let item leave from PPP first to make room for item to go into PPP
            // This can avoid deadlock when haveC2RReq is Full and new item can't go into PPP
            let req = m2r.first.Req;
            m2r.deq;
            r2c[req.child].enq_req(req);
            $display("%0t  Router send req from mem to core %d  ", $time, req.child, fshow(req));
        end else if (haveC2RReq) begin 
            r2m.enq_req(c2r[reqRdyIdx].first.Req);
            c2r[reqRdyIdx].deq;
            $display("%0t  Router send req from core %d to mem  ", $time, reqRdyIdx, fshow(c2r[reqRdyIdx].first.Req));
        end 

    endrule

endmodule