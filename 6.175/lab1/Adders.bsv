import Multiplexer::*;

// Full adder functions

function Bit#(1) fa_sum( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
    return xor1( xor1( a, b ), c_in );
endfunction

function Bit#(1) fa_carry( Bit#(1) a, Bit#(1) b, Bit#(1) c_in );
    return or1( and1( a, b ), and1( xor1( a, b ), c_in ) );
endfunction

// 4 Bit full adder

function Bit#(5) add4( Bit#(4) a, Bit#(4) b, Bit#(1) c_in );
    Bit#(5) ret = 0;
    Bit#(5) c = {?, c_in};
    for (Integer i = 0; i < 4; i = i + 1) begin
        ret[i] = fa_sum(a[i], b[i], c[i]);
        c[i+1] = fa_carry(a[i], b[i], c[i]);
    end
    ret[4] = c[4];
    return ret;
endfunction

// Adder interface

interface Adder8;
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
endinterface

// Adder modules

// RC = Ripple Carry
module mkRCAdder( Adder8 );
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
        Bit#(5) lower_result = add4( a[3:0], b[3:0], c_in );
        Bit#(5) upper_result = add4( a[7:4], b[7:4], lower_result[4] );
        return { upper_result , lower_result[3:0] };
    endmethod
endmodule

// CS = Carry Select
module mkCSAdder( Adder8 );
    method ActionValue#( Bit#(9) ) sum( Bit#(8) a, Bit#(8) b, Bit#(1) c_in );
       Bit#(9) s = 0;
       Bit#(1) c_l = 0;
       let low_res = add4(a[3:0], b[3:0], c_in);
       let high_res_c0 = add4(a[7:4], b[7:4], 0);
       let high_res_c1 = add4(a[7:4], b[7:4], 1);
       let low_cr = low_res[4];
       let high_res = multiplexer_n(low_cr, high_res_c0[3:0], high_res_c1[3:0]);
       let high_cr =  multiplexer_n(low_cr, high_res_c0[4], high_res_c1[4]);
       s[3:0] = low_res[3:0];
       s[7:4] = high_res[3:0];
       s[8] = high_cr;
       return s;
    endmethod
endmodule
