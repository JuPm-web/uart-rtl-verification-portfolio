# Verification scope

## Confirmed by project-author simulation

**UART**

- 256/256 distinct input-byte values exercised in TX/RX loopback
- matching TX/RX timing settings of 8 and 16 clocks per bit
- reset asserted during transmission and recovery checked
- short false-start pulse rejected
- invalid stop bit rejected
- valid frames received after error scenarios

**FIFO**

- eight-byte capacity, full and empty states
- data returned in FIFO order
- overflow and underflow requests rejected
- simultaneous read/write when full
- read/write pointer wraparound

These are directed simulation outcomes, as reported from EDA Playground. They are not independent formal proofs or externally audited results. The public source snapshot has not been rerun after the latest comment and internal signal-name cleanup.

## Not yet verified

- UART-to-FIFO end-to-end integration
- buffer-depth study across different consumer service rates
- randomized test campaigns, full statement/branch/toggle coverage, or UVM
- FPGA synthesis, timing closure, hardware deployment or clock-domain crossing

The 256/256 figure represents **input byte-value coverage** only. It should not be described as comprehensive functional coverage.
