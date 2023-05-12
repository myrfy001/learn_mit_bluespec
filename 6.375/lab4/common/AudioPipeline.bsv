
import ClientServer::*;
import GetPut::*;

import AudioProcessorTypes::*;
import Chunker::*;
import FFT::*;
import FIRFilter::*;
import Splitter::*;
import FilterCoefficients::*;
import FixedPoint::*;
import OverSampler::*;
import Overlayer::*;
import ToMP::*;
import PitchAdjust::*;
import Vector::*;


(* synthesize *)
module mkAudioPipelineFIR(AudioProcessor);
    AudioProcessor fir <- mkFIRFilter(c);
    return fir;
endmodule

(* synthesize *)
module mkAudioPipelineFFT(FFT#(FFT_POINTS, FixedPoint#(16, 16)));
    FFT#(FFT_POINTS, FixedPoint#(16, 16)) fft <- mkFFT();
    return fft;
endmodule


(* synthesize *)
module mkAudioPipelineIFFT(FFT#(FFT_POINTS, FixedPoint#(16, 16)));
    FFT#(FFT_POINTS, FixedPoint#(16, 16)) fft <- mkIFFT();
    return fft;
endmodule


(* synthesize *)
module mkAudioPipelineToMP(ToMP#(FFT_POINTS,16,16,16));
    ToMP#(FFT_POINTS,16,16,16) to_mp <- mkToMP();
    return to_mp;
endmodule

(* synthesize *)
module mkAudioPipelineFromMP(FromMP#(FFT_POINTS,16,16,16));
    FromMP#(FFT_POINTS,16,16,16) from_mp <- mkFromMP();
    return from_mp;
endmodule

(* synthesize *)
module mkAudioPipelinePitchAdjust(SettablePitchAdjust#(FFT_POINTS,16,16,16));
    SettablePitchAdjust#(FFT_POINTS,16,16,16) pitch_adj <- mkPitchAdjust(valueOf(STRIDE));
    return pitch_adj;
endmodule


module mkAudioPipeline(AudioProcessor);

    AudioProcessor fir <- mkAudioPipelineFIR();
    Chunker#(STRIDE, Sample) chunker <- mkChunker();
    OverSampler#(STRIDE, FFT_POINTS, Sample) over_sampler <- mkOverSampler(replicate(0));

    FFT#(FFT_POINTS, FixedPoint#(16, 16)) fft <- mkAudioPipelineFFT();
    ToMP#(FFT_POINTS,16,16,16) to_mp <- mkAudioPipelineToMP();

    SettablePitchAdjust#(FFT_POINTS,16,16,16) pitch_adj <- mkAudioPipelinePitchAdjust();
    FromMP#(FFT_POINTS,16,16,16) from_mp <- mkAudioPipelineFromMP();

    FFT#(FFT_POINTS, FixedPoint#(16, 16)) ifft <- mkAudioPipelineIFFT();

    Overlayer#(FFT_POINTS,STRIDE,Sample) over_layer <- mkOverlayer(replicate(0));
    Splitter#(STRIDE, Sample) splitter <- mkSplitter();

    rule fir_to_chunker (True);
        let x <- fir.getSampleOutput();
        chunker.request.put(x);
    endrule

    rule chunker_to_over_sampler (True);
        let x <- chunker.response.get();
        over_sampler.request.put(x);
    endrule

    rule over_sampler_to_fft (True);
        Vector#(FFT_POINTS, Sample) x <- over_sampler.response.get();
        Vector#(FFT_POINTS, ComplexSample) y;
        for (Integer i=0; i<valueOf(FFT_POINTS); i=i+1) begin
            y[i] = tocmplx(x[i]);
        end
        fft.request.put(y);
    endrule

    rule fft_to_to_mp (True);
        let x <- fft.response.get();
        to_mp.request.put(x);
    endrule

    rule to_mp_to_pitch_adjust (True);
        let x <- to_mp.response.get();
        pitch_adj.adjust.request.put(x);
    endrule

    rule pitch_adjust_to_from_mp (True);
        let x <- pitch_adj.adjust.response.get();
        from_mp.request.put(x);
    endrule


    rule from_mp_to_ifft (True);
        let x <- from_mp.response.get();
        ifft.request.put(x);
    endrule

    rule ifft_to_overlayer (True);
        Vector#(FFT_POINTS, ComplexSample) x <- ifft.response.get();
        Vector#(FFT_POINTS, Sample) y;
        for (Integer i=0; i<valueOf(FFT_POINTS); i=i+1) begin
            y[i] = frcmplx(x[i]);
        end
        over_layer.request.put(y);
    endrule

    rule overlayer_to_splitter (True);
        let x <- over_layer.response.get();
        splitter.request.put(x);
    endrule
    
    method Action putSampleInput(Sample x);
        fir.putSampleInput(x);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        let x <- splitter.response.get();
        return x;
    endmethod

    interface Put setFactor = pitch_adj.setFactor;

endmodule

