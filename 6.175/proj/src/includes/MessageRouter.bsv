
import Types::*;
import Vector::*;
import CacheTypes::*;

module mkMessageRouter(
  Vector#(CoreNum, MessageGet) c2r, Vector#(CoreNum, MessagePut) r2c, 
  MessageGet m2r, MessagePut r2m,
  Empty ifc 
);

    rule doRoute;
        Bool haveC2RResp = False;
        Bool haveC2RReq = False;
        let haveM2RResp = m2r.hasResp;
        let haveM2RReq = m2r.hasReq;
        Bit#(TLog#(CoreNum)) respRdyIdx = 0;
        Bit#(TLog#(CoreNum)) reqRdyIdx = 0;

        for (Integer i=0; i < valueOf(CoreNum); i=i+1) begin
            haveC2RResp = haveC2RResp || c2r[i].hasResp;
            if (c2r[i].hasResp) begin
                respRdyIdx = fromInteger(i);
            end
            haveC2RReq = haveC2RReq || c2r[i].hasReq;
            if (c2r[i].hasReq) begin
                reqRdyIdx = fromInteger(i);
            end
        end

        if (haveC2RResp) begin 
            r2m.enq_resp(c2r[respRdyIdx].first.Resp);
            c2r[respRdyIdx].deq;
        end else if (haveM2RResp) begin 
            let rsp = m2r.first.Resp;
            m2r.deq;
            r2c[rsp.child].enq_resp(rsp);
        end else if (haveC2RReq) begin 
            r2m.enq_req(c2r[reqRdyIdx].first.Req);
            c2r[reqRdyIdx].deq;
        end else if (haveM2RReq) begin
            let req = m2r.first.Req;
            m2r.deq;
            r2c[req.child].enq_req(req);
        end

    endrule

endmodule