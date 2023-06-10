import CacheTypes::*;
import Vector::*;
import Fifo::*;
import Types::*;
import MemTypes::*;
import MemUtil::*;


typedef struct {
    CacheTag tag;
    MSI msi;
    Bool waitingDowngrade;
} CacheLineInfo deriving(Bits, FShow);

typedef enum {
    SendingDowngradeToOthers,
    WaitingAllChildToBeCompatible,
    WaitingReadFromBackendMemory
} UpgradeReqHandleStep deriving(Bits, Eq, FShow);

module mkPPP(MessageGet c2m, MessagePut m2c, WideMem mem, Empty ifc);

    Vector#(CoreNum, Vector#(CacheRows, Reg#(CacheLineInfo))) cli <- replicateM(
        replicateM(mkReg(CacheLineInfo{msi: I, waitingDowngrade:False})));

    Reg#(Bit#(32)) cycle <- mkReg(0);
    Reg#(UpgradeReqHandleStep) upReqStep <- mkReg(SendingDowngradeToOthers);

    rule doIncCycle;
        $display("cycle %d  time %0t =============================================", cycle, $time);
        cycle <= cycle + 1;
    endrule

    function Addr address( CacheTag tag, CacheIndex index, CacheWordSelect sel );
        return {tag, index, sel, 0};
    endfunction

    function Bool isCompatible(MSI cur, MSI next);
        return !((cur==M && next==M) || (cur==M && next==S) || (cur==S && next==M));
    endfunction

    function Bool isInDirectory(CoreID coreID, Addr addr);
        CacheTag tag = getTag(addr);
        CacheIndex lineIdx = getIndex(addr);
        return cli[coreID][lineIdx].tag == tag;
    endfunction
    
    function Maybe#(CacheMemReq) findChildToDowngrade(CacheMemReq req);

        Maybe#(CacheMemReq) downReq = tagged Invalid;
        CacheIndex lineId = getIndex(req.addr);

        for (Integer coreId=0; coreId<valueOf(CoreNum); coreId=coreId+1) begin
            // Only send downgrade requests to other cores.
            if (fromInteger(coreId) != req.child) begin
                
                Bool inDirectory = isInDirectory(fromInteger(coreId), req.addr);

                CacheLineInfo curInfo = cli[coreId][lineId];

                // prevent from sending duplicate request, and select first child as result
                if (curInfo.waitingDowngrade==False && !isValid(downReq)) begin
                    if (inDirectory && isCompatible(curInfo.msi, req.state) == False) begin
                        downReq = tagged Valid CacheMemReq {
                            child: fromInteger(coreId),
                            addr: req.addr,
                            state: req.state == M ? I : S
                        };
                    end else if (inDirectory == False && curInfo.msi != I) begin
                        // In this case, must be Invalid.
                        downReq = tagged Valid CacheMemReq {
                            child: fromInteger(coreId),
                            addr: req.addr,
                            state: I
                        };
                    end
                end
            end
        end
        return downReq;
    endfunction



    function Bool checkAllChildCompatibleWithUpgradeReq(CacheMemReq req);

        Bool ok = True;
        CacheIndex lineId = getIndex(req.addr);

        for (Integer coreId=0; coreId<valueOf(CoreNum); coreId=coreId+1) begin
            // Only check other cores.
            if (fromInteger(coreId) != req.child) begin
                
                Bool inDirectory = isInDirectory(fromInteger(coreId), req.addr);
                CacheLineInfo curInfo = cli[coreId][lineId];

                if ((inDirectory == False && curInfo.msi != I) || ( inDirectory && (isCompatible(curInfo.msi, req.state) == False))) begin
                    ok = False;
                end
                
            end
        end
        return ok;
    endfunction


    rule doDowngradeReqForAnyConflictChild(c2m.hasReq &&& c2m.first matches tagged Req .req &&& upReqStep == SendingDowngradeToOthers);
        CacheIndex lineIdx = getIndex(req.addr);
        CacheTag tag = getTag(req.addr);
        CacheLineInfo info = cli[req.child][lineIdx];

        $display("%0t  doDowngradeReqForAnyConflictChild req = ", $time, fshow(req));
        let childToDowngrade = findChildToDowngrade(req);

        $display("%0t  childToDowngrade req = ", $time, fshow(childToDowngrade));

        if (childToDowngrade matches tagged Valid .reqToSend) begin
            m2c.enq_req(reqToSend);
            $display("%0t  ppp enqueue req = ", $time, fshow(reqToSend));

            CacheLineInfo childInfo = cli[reqToSend.child][lineIdx];
            childInfo.waitingDowngrade = True;
            cli[reqToSend.child][lineIdx] <= childInfo;
        end else begin
            upReqStep <= WaitingAllChildToBeCompatible;
        end
    endrule

    (* descending_urgency = "doHandleDowngradeResp, doCheckAllChildCompatibleWithUpgradeReq" *)
    rule doCheckAllChildCompatibleWithUpgradeReq(c2m.hasReq &&& c2m.first matches tagged Req .req &&& upReqStep == WaitingAllChildToBeCompatible);
        CacheIndex lineIdx = getIndex(req.addr);
        CacheTag tag = getTag(req.addr);
        CacheLineInfo info = cli[req.child][lineIdx];

        Bool isAllCompatible = checkAllChildCompatibleWithUpgradeReq(req);

        $display("%0t  isAllCompatible = ", $time, isAllCompatible);

        if (isAllCompatible) begin

            // if we don't need to read from backend memory, we can save time.
            if (req.state == I || (req.state == M && info.msi == S)) begin
                c2m.deq;
                let t = CacheMemResp{
                    child: req.child,
                    addr: req.addr,
                    state: req.state,
                    data: tagged Invalid
                };
                m2c.enq_resp(t);

                $display("%0t  ppp enqueue resp = ", $time, fshow(t));

                info.tag = tag;
                info.msi = req.state;
                info.waitingDowngrade = False;
                cli[req.child][lineIdx] <= info;
                upReqStep <= SendingDowngradeToOthers;
            end else begin
                mem.req(WideMemReq{write_en: 0, addr: address(tag, lineIdx, 0), data: ?});
                $display("%0t  doDowngradeReqForAnyConflictChild read mem addr = ", $time, address(tag, lineIdx, 0));
                upReqStep <= WaitingReadFromBackendMemory;
            end
            
        end

    endrule

    (* descending_urgency = "doHandleDowngradeResp, doWaitBackendMemoryResponse" *)
    rule doWaitBackendMemoryResponse(mem.respValid && upReqStep == WaitingReadFromBackendMemory);
        c2m.deq;
        CacheMemReq req = c2m.first.Req;
        CacheIndex lineIdx = getIndex(req.addr);

        CacheLineInfo info = cli[req.child][lineIdx];

        CacheLine data <- mem.resp;

        m2c.enq_resp(CacheMemResp{
            child: req.child,
            addr: req.addr,
            state: req.state,
            data: tagged Valid data
        });
        $display("%0t  doWaitBackendMemoryResponse origin req =", $time, fshow(req), "read memory data =", fshow(data));
        info.tag = getTag(req.addr);
        info.msi = req.state;
        info.waitingDowngrade = False;
        cli[req.child][lineIdx] <= info;
        upReqStep <= SendingDowngradeToOthers;


    endrule


    rule doHandleDowngradeResp(c2m.hasResp &&& c2m.first matches tagged Resp .resp);
        c2m.deq;

        $display("%0t  doHandleDowngradeResp origin resp =", $time, fshow(resp));

        CacheTag tag = getTag(resp.addr);
        CacheIndex lineIdx = getIndex(resp.addr);
        CacheLineInfo info = cli[resp.child][lineIdx];

        info.waitingDowngrade = False;
        info.msi = resp.state;
        info.tag = tag;
        if (resp.data matches tagged Valid .d) begin
            mem.req(WideMemReq{write_en: 16'b1111_1111_1111_1111, addr: address(tag, lineIdx, 0), data: d});
            $display("%0t  doHandleDowngradeResp write addr = ", $time, address(tag, lineIdx, 0), " data =", fshow(d));
        end

        cli[resp.child][lineIdx] <= info;

    endrule
endmodule