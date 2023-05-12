
import FIFO::*;
import FixedPoint::*;
import Vector::*;
import Multiplier::*;

import AudioProcessorTypes::*;

module mkFIRFilter (Vector#(tnp1, FixedPoint#(16,16)) coeffs, AudioProcessor ifc);

    FIFO#(Sample) infifo <- mkFIFO();
    FIFO#(Sample) outfifo <- mkFIFO();

    Vector#(TSub#(tnp1, 1), Reg#(Sample)) r <- replicateM(mkReg(0));
    Vector#(tnp1, Multiplier) mul <- replicateM(mkMultiplier());

    let tap_integer = valueOf(tnp1);

    rule shift_and_mul (True);
        Sample sample = infifo.first();
        infifo.deq();
        r[0] <= sample;
        for (Integer i=0; i<tap_integer-2; i=i+1) begin
            r[i+1] <= r[i];
        end

       mul[0].putOperands(coeffs[0], sample);
       for (Integer i=0; i<tap_integer-1; i=i+1) begin
          mul[i+1].putOperands(coeffs[i+1], r[i]);
       end

    endrule

    rule do_sum;

        FixedPoint#(16,16) accumulate = 0;
        for (Integer i=0; i<tap_integer; i=i+1) begin
            let t <- mul[i].getResult;
            accumulate = accumulate + t;
        end

        outfifo.enq(fxptGetInt(accumulate));
    endrule

    method Action putSampleInput(Sample in);
        infifo.enq(in);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        outfifo.deq();
        return outfifo.first();
    endmethod

endmodule

