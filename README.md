# UART RTL Design & Verification

A SystemVerilog implementation of an 8N1 UART transmitter and receiver, with an 8-byte receive FIFO and self-checking testbenches. This project explores digital communication, finite-state machines, buffering, and practical RTL verification.

## System overview

```text
8-bit data --> UART TX --> serial line --> UART RX --> received byte
                                                        |
                                                        v
                                                8-byte receive FIFO
                                                        |
                                                        v
                                                   read interface
```

The **UART TX/RX loopback** and **FIFO** have each been verified with separate testbenches. End-to-end UART-to-FIFO integration is a next milestone, not yet reported as complete.

## Completed work and test results

The following results were reported from simulations in **EDA Playground with Icarus Verilog**:

| Feature or test | Status |
| --- | --- |
| SystemVerilog UART transmitter and receiver using finite-state machines | Completed |
| 8N1 serial framing and LSB-first data transfer | Tested |
| Self-checking UART TX/RX loopback testbench | Passed |
| All **256 possible 8-bit input values** | Passed: 256/256 distinct values |
| UART reset during transmission and successful recovery | Passed |
| False-start noise pulse rejection | Passed |
| Invalid stop-bit rejection and subsequent valid reception | Passed |
| UART tests at `CLKS_PER_BIT = 8` and `16` | Passed |
| 8-byte synchronous FIFO with full/empty and occupancy tracking | Implemented |
| FIFO byte ordering and pointer wraparound | Passed |
| FIFO overflow and underflow detection | Passed |
| FIFO simultaneous read/write at full occupancy | Passed |

**Coverage note:** 256/256 means every possible value of the eight-bit data field was exercised. It does **not** mean 100% RTL code coverage or complete functional or timing verification.

## Repository files

- `design.sv` — UART TX and RX modules
- `testbench.sv` — 256-value loopback, reset, and malformed-frame checks
- `uart_fifo.sv` — parameterized synchronous FIFO
- `fifo_testbench.sv` — FIFO data order, capacity, status and concurrent-operation tests
- `Makefile` — run the published simulations with Icarus Verilog
- `VERIFICATION.md` — test scope, evidence and known limitations

## Reproduce the simulations

In [EDA Playground](https://www.edaplayground.com/), select **SystemVerilog/Verilog** and **Icarus Verilog**.

| Test | Left testbench editor | Right design editor |
| --- | --- | --- |
| UART loopback | `testbench.sv` | `design.sv` |
| FIFO verification | `fifo_testbench.sv` | `uart_fifo.sv` |

To try a second UART timing configuration, change `CLKS_PER_BIT` near the top of `testbench.sv` from 8 to 16, then rerun.

With Icarus Verilog installed locally:

```bash
make test
make test-fifo
```

The published source is a snapshot from a private development repository. The original user-run tests passed; this public snapshot has **not been independently rerun after its latest comment and signal-name cleanup**.

## Current scope and next milestone

This is an RTL simulation project, not an FPGA implementation. It has not undergone UVM, formal verification, synthesis timing closure, or hardware timing tests. The FIFO and UART are currently verified as separate blocks. The next steps are end-to-end UART-to-FIFO integration verification and additional buffering experiments.

More importantly than adding features, the goal is to be able to explain the control logic, timing assumptions, failure cases, and verification decisions behind the design.
