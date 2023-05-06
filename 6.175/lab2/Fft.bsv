import Vector::*;
import Complex::*;

import FftCommon::*;
import Fifo::*;
import FIFOF::*;

interface Fft;
    method Action enq(Vector#(FftPoints, ComplexData) in);
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
endinterface


(* synthesize *)
module mkFftCombinational(Fft);
    FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
    FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction

    rule doFft;
            inFifo.deq;
            Vector#(4, Vector#(FftPoints, ComplexData)) stage_data;
            stage_data[0] = inFifo.first;

            for (StageIdx stage = 0; stage < 3; stage = stage + 1) begin
                stage_data[stage + 1] = stage_f(stage, stage_data[stage]);
            end
            outFifo.enq(stage_data[3]);
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

(* synthesize *)
module mkFftInelasticPipeline(Fft);
    FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
    FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    Reg #(Maybe #( Vector#(FftPoints, ComplexData))) sReg1 <- mkRegU;
    Reg #(Maybe #( Vector#(FftPoints, ComplexData))) sReg2 <- mkRegU;


    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        
        Vector#(FftPoints, ComplexData) before_permute;
        for (Integer i=0; i<valueOf(BflysPerStage); i=i+1) begin
            
            Vector#(4, ComplexData) dat;
            Vector#(4, ComplexData) tw;

            for (Integer j=0; j<4 ; j=j+1) begin
                let idx = fromInteger(i*4 + j);
                dat[j] = stage_in[idx];
                tw[j] = getTwiddle(stage, idx);
            end

            let bfly4_ret = bfly[stage][i].bfly4(dat, tw);
            for (Integer k=0; k<4; k=k+1) begin
                let idx =i*4 + k;
                before_permute[idx] = bfly4_ret[k];
            end
            
        end
        return permute(before_permute);
    endfunction

    rule doFft;
        if (inFifo.notEmpty) begin
            let s1_ret = stage_f(0, inFifo.first);
            sReg1 <= tagged Valid s1_ret;
            inFifo.deq;
        end else 
            sReg1 <= tagged Invalid;
        
        case (sReg1) matches
            tagged Invalid : sReg2 <= tagged Invalid;
            tagged Valid .d : begin
                    let s2_ret = stage_f(1, d);
                    sReg2 <= tagged Valid s2_ret;
                end
        endcase

        case (sReg2) matches
            tagged Valid .d: begin
                    let s3_ret = stage_f(2, d);
                    outFifo.enq(s3_ret);
                end 
        endcase
        
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

(* synthesize *)
module mkFftElasticPipeline(Fft);
    Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo <- mkFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) fifo1 <- mkFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) fifo2 <- mkFifo;

    Vector#(3, Vector#(16, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction

    // You should use more than one rule
    rule in_to_fifo1;
        let s0_ret = stage_f(0, inFifo.first);
        fifo1.enq(s0_ret);
        inFifo.deq;
    endrule

    rule fifo1_to_fifo2;
        let s1_ret = stage_f(1, fifo1.first);
        fifo2.enq(s1_ret);
        fifo1.deq;
    endrule

    rule fifo2_to_outFifo;
        let s2_ret = stage_f(2, fifo2.first);
        outFifo.enq(s2_ret);
        fifo2.deq;
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule
