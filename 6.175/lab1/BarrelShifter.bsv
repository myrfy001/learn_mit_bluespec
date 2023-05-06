import Vector::*;

function Bit#(32) shiftRightPow2(Bit#(1) en, Bit#(32) unshifted, Integer power);
    Integer distance = 2**power;
    Bit#(32) shifted = 0;
    if(en == 0) begin
        return unshifted;
    end else begin
        for(Integer i = 0; i < 32; i = i + 1) begin
            if(i + distance < 32) begin
                shifted[i] = unshifted[i + distance];
            end
        end
        return shifted;
    end
endfunction

// Exercise 6
// Complete the function Bit#(32) barrelShiftRight(Bit#(32) in, Bit#(5) shiftBy)
// in the file BarrelShifter.bsv provided with the initial lab code.

function Bit#(32) barrelShifterRight(Bit#(32) in, Bit#(5) shiftBy);
  Bit#(TMul#(32,6)) res = 0;
  res[31:0] = in;
  for (Integer i = 0; i < 5; i = i + 1) begin
    res[(i+2) * 32 - 1 :(i+1) * 32] = shiftBy[i] == 1 ? shiftRightPow2(1, res[(i+1) * 32 - 1 :(i) * 32], i) : res[(i+1) * 32 - 1 :(i) * 32];
  end
  return res[32*6-1:32*5];
endfunction