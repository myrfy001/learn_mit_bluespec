import ClientServer::*;
import GetPut::*;

import FixedPoint::*;

import Complex::*;
import ComplexMP::*;

import Vector::*;
import FIFO::*;

import Cordic::*;

typedef Server#(
    Vector#(bsize, Complex#(FixedPoint#(isize, fsize))),
    Vector#(bsize, ComplexMP#(isize, fsize, psize))
) ToMP#(numeric type bsize, numeric type isize, numeric type fsize, numeric type psize);

typedef Server#(
    Vector#(bsize, ComplexMP#(isize, fsize, psize)),
    Vector#(bsize, Complex#(FixedPoint#(isize, fsize)))
) FromMP#(numeric type bsize, numeric type isize, numeric type fsize, numeric type psize);

module mkToMP(
    ToMP#(bsize, isize, fsize, psize) ifc
);

    Reg#(Bit#(TLog#(bsize))) cnt_req <- mkReg(0);
    Reg#(Bit#(TLog#(bsize))) cnt_rsp <- mkReg(0);

    // // How to remove this flag?
    // Reg#(Bool) is_first_round <- mkReg(True);


    FIFO#(Vector#(bsize, Complex#(FixedPoint#(isize, fsize))))inq <- mkFIFO();
    FIFO#(Vector#(bsize, ComplexMP#(isize, fsize, psize))) outq <- mkFIFO();

    Reg#(Vector#(bsize, ComplexMP#(isize, fsize, psize))) out_buf <- mkReg(replicate(cmplxmp(0, tophase(0))));

    ToMagnitudePhase#(isize, fsize, psize) convertor <- mkCordicToMagnitudePhase();

    rule do_convert_req;
        convertor.request.put(inq.first[cnt_req]);  //implicity condition'
        if (cnt_req == fromInteger(valueOf(bsize) - 1)) begin
            inq.deq;
            cnt_req <= 0;
        end else begin 
            cnt_req <= cnt_req + 1;
        end
    endrule

    rule get_convert_resp;
        let got <- convertor.response.get(); //implicity condition
        out_buf[cnt_rsp] <= got;
        
        if (cnt_rsp == fromInteger(valueOf(bsize) - 1)) begin
            cnt_rsp <= 0;
            let t = out_buf;
            t[cnt_rsp] = got;
            outq.enq(t);
        end else begin 
            cnt_rsp <= cnt_rsp + 1;
        end
    endrule

    interface Put request = toPut(inq);
    interface Get response = toGet(outq);
endmodule



module mkFromMP(
    FromMP#(bsize, isize, fsize, psize) ifc
);

    Reg#(Bit#(TLog#(bsize))) cnt_req <- mkReg(0);
    Reg#(Bit#(TLog#(bsize))) cnt_rsp <- mkReg(0);

    // How to remove this flag?
    Reg#(Bool) is_first_round <- mkReg(True);


    FIFO#(Vector#(bsize, Complex#(FixedPoint#(isize, fsize))))outq <- mkFIFO();
    FIFO#(Vector#(bsize, ComplexMP#(isize, fsize, psize)))inq <- mkFIFO();

    Reg#(Vector#(bsize, Complex#(FixedPoint#(isize, fsize)))) out_buf <- mkRegU();

    FromMagnitudePhase#(isize, fsize, psize) convertor <- mkCordicFromMagnitudePhase();

    rule do_convert_req;
        // $display("xxxxx", fshow(inq.first[cnt_req]));
        convertor.request.put(inq.first[cnt_req]);  //implicity condition'
        if (cnt_req == fromInteger(valueOf(bsize) - 1)) begin
            inq.deq;
            cnt_req <= 0;
        end else begin 
            cnt_req <= cnt_req + 1;
        end
    endrule

    rule get_convert_resp;

        let got <- convertor.response.get(); //implicity condition
        out_buf[cnt_rsp] <= got;
        
        if (cnt_rsp == fromInteger(valueOf(bsize) - 1)) begin
            cnt_rsp <= 0;
            let t = out_buf;
            t[cnt_rsp] = got;
            outq.enq(t);
        end else begin 
            cnt_rsp <= cnt_rsp + 1;
        end
    endrule

    interface Put request = toPut(inq);
    interface Get response = toGet(outq);

endmodule



// Unit tests for Cordic
(* synthesize *)
module mkToFromMPTest (Empty);
    ToMP#(2,8,8,16) to_mp <- mkToMP();
    FromMP#(2,8,8,16) from_mp <- mkFromMP();

    Vector#(2, Complex#(FixedPoint#(8,8))) c1 = cons(cmplx(1,1) ,cons(cmplx(0,1),nil));
    Vector#(2, Complex#(FixedPoint#(8,8))) c2 = cons(cmplx(1,-1) ,cons(cmplx(1,0),nil));
    Vector#(2, Complex#(FixedPoint#(8,8))) c3 = cons(cmplx(-1,1) ,cons(cmplx(0,0),nil));
    Vector#(2, Complex#(FixedPoint#(8,8))) c4 = cons(cmplx(-1,1) ,cons(cmplx(1,1),nil));
    Vector#(2, Complex#(FixedPoint#(8,8))) c5 = cons(cmplx(-1,1) ,cons(cmplx(0,0),nil));
   

    Reg#(int) cnt <- mkReg(0);
    Reg#(int) cycle <- mkReg(0);

    rule print_cycle;
        cycle <= cycle + 1;
        // $display("cycle = %d", cycle);
        if (cycle > 128) $finish();
    endrule

    rule put_data_1 (cnt <= 4);
        if (cnt == 0) begin
            to_mp.request.put(c1);
            $display("put", fshow(c1));
        end else if (cnt == 1) begin
            to_mp.request.put(c2);
            $display("put", fshow(c2));
        end else if (cnt == 2) begin
            to_mp.request.put(c3);
            $display("put", fshow(c3));
        end else if (cnt == 3) begin
            to_mp.request.put(c4);
            $display("put", fshow(c4));
        end else if (cnt == 4) begin
            to_mp.request.put(c5);
            $display("put", fshow(c5));
        end else begin
            to_mp.request.put(c3);
        end
        cnt <= cnt + 1;
    endrule

    rule put_data_2;
        let t <- to_mp.response.get();
        from_mp.request.put(t);
    endrule

    rule get_result;
        let t <- from_mp.response.get();
        $display("got", fshow(t));
    endrule




endmodule
