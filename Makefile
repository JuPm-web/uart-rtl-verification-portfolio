.PHONY: all test test-fifo clean

all: test test-fifo

test:
	iverilog -Wall -g2012 -s testbench -o uart_sim.vvp design.sv testbench.sv
	vvp uart_sim.vvp

test-fifo:
	iverilog -Wall -g2012 -s fifo_testbench -o fifo_sim.vvp uart_fifo.sv fifo_testbench.sv
	vvp fifo_sim.vvp

clean:
	rm -f *.vvp *.vcd *.fst
