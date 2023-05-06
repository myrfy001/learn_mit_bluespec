function Bit#(1) and1(Bit#(1) a, Bit#(1) b);
    return a & b;
endfunction

function Bit#(1) or1(Bit#(1) a, Bit#(1) b);
    return a | b;
endfunction

function Bit#(1) xor1( Bit#(1) a, Bit#(1) b );
    return a ^ b;
endfunction

function Bit#(1) not1(Bit#(1) a);
    return ~ a;
endfunction

function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    let o1 = and1(a, not1(sel));
    let o2 = and1(b, sel);
    return or1(o1, o2);
endfunction


function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
    return multiplexer_n(sel, a, b);
endfunction

function Bit#(n) multiplexer_n(Bit#(1) sel, Bit#(n) a, Bit#(n) b);
    Bit#(n) ret  = 0;
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        ret[i] = multiplexer1(sel, a[i], b[i]);
    end
    return ret;
endfunction