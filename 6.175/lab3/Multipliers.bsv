import Vector :: * ;

// Reference functions that use Bluespec's '*' operator
function Bit#(TAdd#(n,n)) multiply_unsigned( Bit#(n) a, Bit#(n) b );
    UInt#(n) a_uint = unpack(a);
    UInt#(n) b_uint = unpack(b);
    UInt#(TAdd#(n,n)) product_uint = zeroExtend(a_uint) * zeroExtend(b_uint);
    return pack( product_uint );
endfunction

function Bit#(TAdd#(n,n)) multiply_signed( Bit#(n) a, Bit#(n) b );
    Int#(n) a_int = unpack(a);
    Int#(n) b_int = unpack(b);
    Int#(TAdd#(n,n)) product_int = signExtend(a_int) * signExtend(b_int);
    return pack( product_int );
endfunction

function Bit#(TAdd#(n,1)) add_unsigned( Bit#(n) a, Bit#(n) b );
    UInt#(n) a_uint = unpack(a);
    UInt#(n) b_uint = unpack(b);
    UInt#(TAdd#(n,1)) add_uint = zeroExtend(a_uint) + zeroExtend(b_uint);
    return pack( add_uint );
endfunction

function Bit#(n) shr_signed( Bit#(n) a, Integer x );
    Int#(n) a_int = unpack(a);
    Int#(n) shr_int = a_int >> x;
    return pack( shr_int );
endfunction


// Multiplication by repeated addition
function Bit#(TAdd#(n,n)) multiply_by_adding( Bit#(n) a, Bit#(n) b );
    // TODO: Implement this function in Exercise 2

    Bit#(TAdd#(n,n)) res = 0;
    Bit#(TAdd#(n,1)) t = 0;

    for (Integer i=0; i<valueOf(n); i=i+1) begin
        Bit#(TSub#(n,1)) ttt = t[valueOf(n)-1:1];
        Bit#(n) tt = { t[valueOf(n)] , ttt};
        if (b[i] == 0) begin 
            t = add_unsigned(tt, 0);
        end else begin
            t = add_unsigned(tt, a);
        end
        res[i] = t[0];
    end

    Bit#(n) zz = t[valueOf(n):1];
    res[valueOf(n)*2-1:valueOf(n)] = zz;

    return res;
endfunction



// Multiplier Interface
interface Multiplier#( numeric type n );
    method Bool start_ready();
    method Action start( Bit#(n) a, Bit#(n) b );
    method Bool result_ready();
    method ActionValue#(Bit#(TAdd#(n,n))) result();
endinterface



// Folded multiplier by repeated addition
module mkFoldedMultiplier( Multiplier#(n) );
    // You can use these registers or create your own if you want
    Reg#(Bit#(n)) a <- mkRegU();
    Reg#(Bit#(n)) b <- mkRegU();
    Reg#(Bit#(n)) prod <- mkRegU();
    Reg#(Bit#(n)) tp <- mkRegU();
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    rule mulStep( /* guard goes here */ i < fromInteger(valueOf(n)) );
        // TODO: Implement this in Exercise 4
        let sum = add_unsigned(tp, b[0] == 1 ? a : 0 );
        b <= b >> 1;
        Bit#(TSub#(n,1)) t = prod[?:1];
        prod <= {sum[0], t};
        tp <= sum[?:1];
        i <= i + 1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 4
        return i == fromInteger(valueOf(n)+1);
    endmethod

    method Action start( Bit#(n) aIn, Bit#(n) bIn );
        // TODO: Implement this in Exercise 4
        a <= aIn;
        b <= bIn;
        i <= 0;
        prod <= 0;
        tp <= 0;
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 4
        return i == fromInteger(valueOf(n));
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 4
        i <= i+1;
        return {tp, prod};
    endmethod
endmodule



// Booth Multiplier
module mkBoothMultiplier( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),1))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)+1) );

    rule mul_step( /* guard goes here */ i < fromInteger(valueOf(n)));
        // TODO: Implement this in Exercise 6
        Bit#(TAdd#(TAdd#(n,n),1)) sum = p;
        if (p[1:0] == 2'b01) begin
            sum = p + m_pos;
        end else if (p[1:0] == 2'b10) begin
            sum = p + m_neg;
        end 

        p <= shr_signed(sum, 1);
        i <= i+1;

    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 6
        return i == fromInteger(valueOf(n)+1);
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 6
        m_neg <= {(-m), 0};
        m_pos <= {m, 0};
        p <= {0, r, 1'b0};
        i <= 0;
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 6
        return i == fromInteger(valueOf(n));
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 6
        i <= i+1;
        return p[?:1];
    endmethod
endmodule



// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4( Multiplier#(n) );
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_neg <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) m_pos <- mkRegU;
    Reg#(Bit#(TAdd#(TAdd#(n,n),2))) p <- mkRegU;
    Reg#(Bit#(TAdd#(TLog#(n),1))) i <- mkReg( fromInteger(valueOf(n)/2+1) );

    rule mul_step( /* guard goes here */  i < fromInteger(valueOf(n)/2) );
        // TODO: Implement this in Exercise 8
        Bit#(TAdd#(TAdd#(n,n),2)) sum = p;
        if (p[2:0] == 3'b001) begin
            sum = p + m_pos;
        end else if (p[2:0] == 3'b010) begin
            sum = p + m_pos;
        end else if (p[2:0] == 3'b011) begin
            sum = p + (m_pos << 1);
        end else if (p[2:0] == 3'b100) begin
            sum = p + (m_neg << 1);
        end else if (p[2:0] == 3'b101) begin
            sum = p + m_neg;
        end else if (p[2:0] == 3'b110) begin
            sum = p + m_neg;
        end 

        p <= shr_signed(sum, 2);
        i <= i+1;
    endrule

    method Bool start_ready();
        // TODO: Implement this in Exercise 8
        return i == fromInteger(valueOf(n)/2+1);
    endmethod

    method Action start( Bit#(n) m, Bit#(n) r );
        // TODO: Implement this in Exercise 8
        m_pos <= {m[valueOf(n)-1], m, 0};
        m_neg <= {(-m)[valueOf(n)-1], (-m), 0};
        p <= {0, r, 1'b0};
        i <= 0;
    endmethod

    method Bool result_ready();
        // TODO: Implement this in Exercise 8
        return i == fromInteger(valueOf(n)/2);
    endmethod

    method ActionValue#(Bit#(TAdd#(n,n))) result();
        // TODO: Implement this in Exercise 8
        i <= i+1;
        return p[valueOf(n)*2:1];
    endmethod
endmodule

