run:
	iverilog -y . testbench.v
	vvp -n a.out -lxt2
	gtkwave wave.vcd
.PHONY: run