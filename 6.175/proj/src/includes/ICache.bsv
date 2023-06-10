import CacheTypes::*;
import Fifo::*;
import MemTypes::*;
import MemUtil::*;
import Vector::*;
import Types::*;
import Ehr::*;

typedef struct {
    Bool valid;
    Bool dirty;
    CacheTag tag;
    CacheLine data;
} CacheEntry deriving(Bits);

typedef struct {
    CacheTag tag;
    CacheIndex idx;
    CacheWordSelect wordIdx;
    Bit#(2) _padding;
} CacheAddr deriving(Bits, FShow);


typedef enum {
    Idle,
    SendWriteReq,
    WaitWriteResp,
    SendReadReq,
    WaitReadResp
} CacheState deriving (Bits, Eq);


// =========================================


module mkCache(WideMem backend, Cache ifc);
    Fifo#(1, MemResp) respQ <- mkBypassFifo();

    Reg#(CacheState) state <- mkReg(Idle);
    Reg#(MemReq) curReq <- mkRegU;

    Vector#(CacheRows, Reg#(CacheEntry)) storage <- replicateM(mkReg(CacheEntry{
        valid: False,
        dirty: False,
        tag: ?,
        data: ?
    }));


    function Bool isCacheHit(Addr addr, CacheEntry entry);
            CacheAddr caddr = unpack(pack(addr));

            let ret = False;
            if (entry.valid) begin
                ret = (caddr.tag == entry.tag) ? True : False;
            end
            return ret;
    endfunction

    function Addr getCacheLineAlignedAddress(Addr addr);
        CacheAddr caddr = unpack(pack(addr));
        caddr._padding = 0;
        caddr.wordIdx = 0;
        return unpack(pack(caddr));
    endfunction

    rule doWriteBack (state == SendWriteReq);
        
        // $display("[Cache] doWriteBack");

        CacheAddr caddr = unpack(pack(curReq.addr));

        let entry = storage[caddr.idx];

        CacheAddr waddr = CacheAddr {
            tag: entry.tag,
            idx: caddr.idx,
            wordIdx: 0,
            _padding: 0
        };

        let req = WideMemReq {
            write_en: 16'b1111_1111_1111_1111,
            addr: getCacheLineAlignedAddress(pack(waddr)),
            data: entry.data
        };
        backend.req(req);
        state <= WaitWriteResp;
    endrule

    rule doWaitWriteResp (state == WaitWriteResp);
        // $display("[Cache] doWaitWriteResp");
        state <= SendReadReq;
    endrule

    rule doSendReadReq (state == SendReadReq);
        // $display("[Cache] doSendReadReq");
        let req = WideMemReq {
            write_en: 0,
            addr: getCacheLineAlignedAddress(curReq.addr),
            data: ?
        };
        backend.req(req);
        state <= WaitReadResp;
    endrule


    
    rule doWaitReadResp (state == WaitReadResp);

        CacheAddr caddr = unpack(pack(curReq.addr));

        // $display("[Cache] doWaitReadResp caddr=");
  
        let resp <- backend.resp;

        let entry = CacheEntry {
            valid: True,
            dirty: False,
            tag: caddr.tag,
            data: resp
        };

        if (curReq.op == Ld) begin
            // $display("[Cache] doWaitReadResp -- Ld");
            respQ.enq(selectWord(pack(resp), caddr.wordIdx));
        end else begin
            // $display("[Cache] doWaitReadResp -- St");
            entry.data[caddr.wordIdx] = curReq.data;
            entry.dirty = True;
        end

        storage[caddr.idx] <= entry;
        state <= Idle;
    endrule 


    method Action req(MemReq r) if (state == Idle);

        CacheAddr caddr = unpack(pack(r.addr));
        CacheEntry entry = storage[caddr.idx];

        // $display("[Cache] Get addr = ", fshow(caddr));

        if (isCacheHit(r.addr, entry)) begin
            // Cache hit
            if (r.op == Ld) begin
                // $display("[Cache] -- Ld Hit");
                respQ.enq(selectWord(pack(entry.data), caddr.wordIdx));
            end else begin
                // $display("[Cache] -- St Hit");
                entry.data[caddr.wordIdx] = r.data;
                entry.dirty = True;
                storage[caddr.idx] <= entry;
            end
        end else begin
            // Cache miss
            curReq <= r;
            if (entry.dirty == False) begin
                // $display("[Cache] Will SendReadReq on next cycle");
                state <= SendReadReq;
            end else begin
                // $display("[Cache] Will SendWriteReq on next cycle");
                state <= SendWriteReq;
            end
        end
    endmethod

    method ActionValue#(MemResp) resp; 
        // $display("[Cache] deq...");       
        respQ.deq;
        return respQ.first;
    endmethod
endmodule





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