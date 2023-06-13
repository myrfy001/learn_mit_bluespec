import CacheTypes::*;
import Vector::*;
import Fifo::*;
import Types::*;
import RefTypes::*;
import MemTypes::*;
import ProcTypes::*;

typedef enum{Ready, StartMiss, SendFillReq, WaitFillResp, Resp} CacheStatus
    deriving(Eq, Bits, FShow);

typedef struct {
    CacheTag tag;
    MSI msi;
} CacheLineInfo deriving(Bits, FShow);

module mkDCache#(CoreID id)(MessageGet fromMem, MessagePut toMem, RefDMem refDMem, DCache ifc);

    Reg#(CacheStatus) cacheState <- mkReg(Ready);
    Reg#(Maybe#(CacheLineAddr)) linkAddr <- mkReg(Invalid);

    Vector#(CacheRows, Reg#(CacheLine)) storage <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(CacheLineInfo)) cli <- replicateM(mkReg(CacheLineInfo{msi: I}));
    Reg#(MemReq) missReq <- mkRegU;

    Fifo#(2, MemResp) respQ <- mkBypassFifo;
    Fifo#(2, MemReq) reqQ <- mkCFFifo;

    function Addr address( CacheTag tag, CacheIndex index, CacheWordSelect sel );
        return {tag, index, sel, 0};
    endfunction

    rule doDebug;
        $display("%0t  DCache@core %d cacheState = ", $time, id, fshow(cacheState), " fromMem.hasResp=", fromMem.hasResp , " fromMem.hasReq=", fromMem.hasReq );
    endrule

    rule doStartMiss (cacheState == StartMiss);
        $display("%0t  DCache@core %d doStartMiss:", $time, id);

        CacheIndex lineIdx = getIndex(missReq.addr);
        CacheWordSelect wordIdx = getWordSelect(missReq.addr);
        
        // recover address to invalid
        Addr oldAddr = address(cli[lineIdx].tag, lineIdx, wordIdx);

        let data = cli[lineIdx].msi == M ? tagged Valid storage[lineIdx] : tagged Invalid;
        toMem.enq_resp(CacheMemResp{child: id, addr: oldAddr, state: I, data: data});
        
        cli[lineIdx] <= CacheLineInfo{msi: I};

        if (isValid(linkAddr) && fromMaybe(?, linkAddr)==getLineAddr(missReq.addr)) begin
            linkAddr <= tagged Invalid;
            $display("%0t  DCache@core %d invalid linkAddr because of local access conflict", $time, id);
        end

        cacheState <= SendFillReq;
    endrule


    rule doSendFillReq (cacheState == SendFillReq);
        $display("%0t  DCache@core %d doSendFillReq:", $time, id);
        toMem.enq_req(CacheMemReq{child: id, addr: missReq.addr, state: (missReq.op == St || missReq.op == Sc) ? M : S});
        cacheState <= WaitFillResp;
    endrule

    rule doWaitFillResp (cacheState == WaitFillResp && fromMem.hasResp);
        CacheIndex lineIdx = getIndex(missReq.addr);
        CacheMemResp resp = fromMem.first.Resp;
        $display("%0t  DCache@core %d doWaitFillResp:", $time, id, fshow(resp));
        fromMem.deq;

        CacheLine d = isValid(resp.data) ? fromMaybe(?, resp.data) : storage[lineIdx];

        CacheWordSelect wordIdx = getWordSelect(missReq.addr);
        if (missReq.op == Ld || missReq.op == Lr) begin
            respQ.enq(d[wordIdx]);
            refDMem.commit(missReq, tagged Valid d, tagged Valid d[wordIdx]);
            if (missReq.op == Lr) begin
                linkAddr <= tagged Valid getLineAddr(missReq.addr);
            end
        end else if (missReq.op == St) begin
            refDMem.commit(missReq, tagged Valid d, tagged Invalid);
            d[wordIdx] = missReq.data;
        end else if (missReq.op == Sc) begin
            if (isValid(linkAddr) && fromMaybe(?, linkAddr) == getLineAddr(missReq.addr)) begin
                refDMem.commit(missReq, tagged Valid d, tagged Valid scSucc);
                respQ.enq(scSucc);
                d[wordIdx] = missReq.data;
                $display("%0t  DCache@core %d sc success", $time, id);
            end else begin
                refDMem.commit(missReq, tagged Valid d, tagged Valid scFail);
                respQ.enq(scFail);
                $display("%0t  DCache@core %d sc fail", $time, id);
            end
            linkAddr <= tagged Invalid;
            $display("%0t  DCache@core %d invalid linkAddr because Sc finished, origin = %x", $time, id, fromMaybe(?,linkAddr));
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

    rule doReady (cacheState == Ready);

        let r = reqQ.first;
        reqQ.deq;

        refDMem.issue(r);
        CacheIndex lineIdx = getIndex(r.addr);
        CacheWordSelect wordIdx = getWordSelect(r.addr);

        missReq <= r;
        Bool respScFail = (r.op == Sc && (!isValid(linkAddr) || getLineAddr(r.addr) != fromMaybe(?, linkAddr)));
        
        if (cli[lineIdx].tag == getTag(r.addr)) begin
            $display("%0t  DCache@core %d hit========", $time, id, fshow(cli[lineIdx]));
            if (r.op == Ld || r.op == Lr) begin
                if (cli[lineIdx].msi > I) begin
                    refDMem.commit(r, tagged Valid storage[lineIdx], tagged Valid storage[lineIdx][wordIdx]);
                    respQ.enq(storage[lineIdx][wordIdx]);
                end else if (cli[lineIdx].msi == I) begin
                    cacheState <= SendFillReq;
                end
                if (r.op == Lr) begin
                    linkAddr <= tagged Valid getLineAddr(r.addr);
                end
            end else if (r.op == St || r.op == Sc) begin
                
                if (respScFail) begin
                    respQ.enq(scFail);
                    refDMem.commit(r, tagged Valid storage[lineIdx], tagged Valid scFail);
                    $display("%0t  DCache@core %d sc Fail", $time, id);
                    linkAddr <= tagged Invalid;
                end else begin
                    if (cli[lineIdx].msi == M) begin 
                        CacheLine line = storage[lineIdx];
                        line[wordIdx] = r.data;
                        storage[lineIdx] <= line; 
                        if (r.op == Sc) begin
                            respQ.enq(scSucc);
                            refDMem.commit(r, tagged Valid storage[lineIdx], tagged Valid scSucc);
                            linkAddr <= tagged Invalid;
                            $display("%0t  DCache@core %d sc success", $time, id);
                        end else begin
                            refDMem.commit(r, tagged Valid storage[lineIdx], tagged Invalid);
                        end
                    end else begin
                        // now is S or I, need upgrade
                        cacheState <= SendFillReq;
                    end
                end
            end
        end else begin
            
            if (r.op == Sc && respScFail) begin
                respQ.enq(scFail);
                refDMem.commit(r, tagged Valid storage[lineIdx], tagged Valid scFail);
                $display("%0t  DCache@core %d sc Fail", $time, id);
                linkAddr <= tagged Invalid;
            end else begin
                if (cli[lineIdx].msi == I) begin
                    cacheState <= SendFillReq;
                end else begin
                    cacheState <= StartMiss;
                end
            end
        end
    endrule

    rule doHandleDowngrade (fromMem.hasReq &&& fromMem.first matches tagged Req .req);
        $display("%0t  DCache@core %d receive downgrade req:", $time, id, fshow(req));
        fromMem.deq;

        CacheIndex lineIdx =  getIndex(req.addr);
        CacheLineInfo myCurInfo = cli[lineIdx];

        if (myCurInfo.msi > req.state) begin

            let data = myCurInfo.msi == M ? tagged Valid storage[lineIdx] : tagged Invalid;
            toMem.enq_resp(CacheMemResp{child: id, addr: address(myCurInfo.tag, lineIdx, 0), state: req.state, data: data});
            myCurInfo.msi = req.state;
            cli[lineIdx] <= myCurInfo;


            if (isValid(linkAddr) && fromMaybe(?, linkAddr)==getLineAddr(req.addr)) begin
                linkAddr <= tagged Invalid;
                $display("%0t  DCache@core %d invalid linkAddr because of downgrade req", $time, id);
            end
        end
    endrule



    method Action req(MemReq r);
        $display("%0t  DCache@core %d receive req from cpu:", $time, id, fshow(r));
        reqQ.enq(r);
    endmethod

    method ActionValue#(MemResp) resp;
        $display("%0t  DCache@core %d send resp to cpu:", $time, id, fshow(respQ.first));
        respQ.deq;
        return respQ.first;
    endmethod

endmodule