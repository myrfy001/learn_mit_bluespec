import CacheTypes::*;
import Vector::*;
import Fifo::*;
import Types::*;
import RefTypes::*;
import MemTypes::*;

typedef enum{Ready, StartMiss, SendFillReq, WaitFillResp, Resp} CacheStatus
    deriving(Eq, Bits);

typedef struct {
    CacheTag tag;
    MSI msi;
} CacheLineInfo deriving(Bits, FShow);

module mkDCache#(CoreID id)(MessageGet fromMem, MessagePut toMem, RefDMem refDMem, DCache ifc);

    Reg#(CacheStatus) cacheState <- mkReg(Ready);

    Vector#(CacheRows, Reg#(CacheLine)) storage <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(CacheLineInfo)) cli <- replicateM(mkReg(CacheLineInfo{msi: I}));
    Reg#(MemReq) missReq <- mkRegU;

    Fifo#(2, MemResp) respQ <- mkBypassFifo;

    function Addr address( CacheTag tag, CacheIndex index, CacheWordSelect sel );
        return {tag, index, sel, 0};
    endfunction

    rule doStartMiss (cacheState == StartMiss);
        CacheIndex lineIdx = getIndex(missReq.addr);
        CacheWordSelect wordIdx = getWordSelect(missReq.addr);
        
        // recover address to invalid
        Addr oldAddr = address(cli[lineIdx].tag, lineIdx, wordIdx);

        let data = cli[lineIdx].msi == M ? tagged Valid storage[lineIdx] : tagged Invalid;
        toMem.enq_resp(CacheMemResp{child: id, addr: oldAddr, state: I, data: data});
        
        cli[lineIdx] <= CacheLineInfo{msi: I};
        cacheState <= SendFillReq;
    endrule


    rule doSendFillReq (cacheState == SendFillReq);
        toMem.enq_req(CacheMemReq{child: id, addr: missReq.addr, state: missReq.op == St ? M : S});
        cacheState <= WaitFillResp;
    endrule

    rule doWaitFillResp (cacheState == WaitFillResp && fromMem.hasResp);
        CacheIndex lineIdx = getIndex(missReq.addr);
        CacheMemResp resp = fromMem.first.Resp;
        fromMem.deq;

        CacheLine d = isValid(resp.data) ? fromMaybe(?, resp.data) : storage[lineIdx];

        CacheWordSelect wordIdx = getWordSelect(missReq.addr);
        if (missReq.op == Ld) begin
            respQ.enq(d[wordIdx]);
        end else if (missReq.op == St) begin
            d[wordIdx] = missReq.data;
        end
        storage[lineIdx] <= d;
        CacheLineInfo myCurInfo = cli[lineIdx];
        myCurInfo.msi = resp.state;
        myCurInfo.tag = getTag(missReq.addr);
        cli[lineIdx] <= myCurInfo;
        
        cacheState <= Resp;
        
    endrule

    rule doResp (cacheState == Resp);
        // TODO: in my design, it seems that we don't need this stage.
        cacheState <= Ready;
    endrule


    rule doHandleDowngrade (fromMem.hasReq);
        CacheMemReq req = fromMem.first.Req;
        fromMem.deq;

        CacheIndex lineIdx =  getIndex(req.addr);
        CacheLineInfo myCurInfo = cli[lineIdx];

        if (myCurInfo.msi > req.state) begin

            let data = myCurInfo.msi == M ? tagged Valid storage[lineIdx] : tagged Invalid;
            toMem.enq_resp(CacheMemResp{child: id, addr: req.addr, state: req.state, data: data});

            myCurInfo.msi = req.state;
            cli[lineIdx] <= myCurInfo;
        end
    endrule



    method Action req(MemReq r) if (cacheState == Ready);
        CacheIndex lineIdx = getIndex(r.addr);
        CacheWordSelect wordIdx = getWordSelect(r.addr);

        missReq <= r;
        
        if (cli[lineIdx].tag == getTag(r.addr)) begin
            $display("hit========");
            if (r.op == Ld) begin
                $display("op is load ========", fshow(cli[lineIdx]));
                if (cli[lineIdx].msi > I) begin
                    respQ.enq(storage[lineIdx][wordIdx]);
                end else if (cli[lineIdx].msi == I) begin
                    cacheState <= SendFillReq;
                end
            end else if (r.op == St ) begin
                if (cli[lineIdx].msi == M) begin 
                    CacheLine line = storage[lineIdx];
                    line[wordIdx] = r.data;
                    storage[lineIdx] <= line;
                end else begin
                    // now is S or I, need upgrade
                    cacheState <= SendFillReq;
                end
            end
        end else begin
            if (cli[lineIdx].msi == I) begin
                cacheState <= SendFillReq;
            end else begin
                cacheState <= StartMiss;
            end
        end
    endmethod

    method ActionValue#(MemResp) resp;
        respQ.deq;
        return respQ.first;
    endmethod

endmodule