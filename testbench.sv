`timescale 1ns/1ps

module testbench;

    localparam integer CLKS_PER_BIT = 8;

    logic clk = 0;
    logic rst_n = 0;
    logic start = 0;
    logic [7:0] data_in = 0;

    wire tx, busy;
    wire [7:0] rx_data;
    wire rx_valid;

    // by default, the receiver listens to the transmitter
    // override the wire only when testing malformed frames
    logic inject_enable = 0;
    logic injected_rx = 1;
    wire rx_line;
    assign rx_line = inject_enable ? injected_rx : tx;

    logic [7:0] expected_rx = 0;
    logic expecting_rx = 0;
    // mark each byte value once so we can count unique values tested
    logic [255:0] covered_values = '0;
    integer rx_count = 0;
    integer unique_values = 0;

    // a ten-nanosecond clock period drives both sides of the loopback
    always #5 clk = ~clk;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .data_in(data_in), .tx(tx), .busy(busy)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) receiver (
        .clk(clk), .rst_n(rst_n), .rx(rx_line),
        .data_out(rx_data), .valid(rx_valid)
    );

    // compare against the expected byte, not another internal design signal
    always @(negedge clk) begin
        if (rst_n && rx_valid) begin
            if (!expecting_rx)
                $fatal(1, "FAIL: unexpected RX valid (possible bad frame accepted)");
            if (rx_data !== expected_rx)
                $fatal(1, "FAIL: expected %h, received %h", expected_rx, rx_data);

            rx_count = rx_count + 1;
            if (!covered_values[rx_data]) begin
                covered_values[rx_data] = 1'b1;
                unique_values = unique_values + 1;
            end
        end
    end

    // send one byte and require exactly one matching reception
    task automatic send_and_check(input logic [7:0] value);
        integer before_count;
        begin
            @(negedge clk);
            if (busy !== 1'b0)
                $fatal(1, "FAIL: TX not ready");

            before_count = rx_count;
            // set the expected result before starting the transmission
            expected_rx = value;
            expecting_rx = 1;
            data_in = value;
            start = 1;

            @(negedge clk);
            start = 0;

            repeat (CLKS_PER_BIT/2) @(negedge clk);
            if (tx !== 1'b0 || busy !== 1'b1)
                $fatal(1, "FAIL: TX start bit or busy flag");

            // wait for the complete frame before checking the receive count
            wait (busy == 0);
            @(negedge clk);
            #1;
            if (rx_count != before_count + 1)
                $fatal(1, "FAIL: missing/extra received byte: %h", value);

            expecting_rx = 0;
        end
    endtask

    // a short low pulse should not look like a real start bit
    task automatic test_false_start;
        integer before_count;
        begin
            @(negedge clk);
            if (busy !== 1'b0)
                $fatal(1, "FAIL: TX busy before glitch test");

            inject_enable = 1;
            injected_rx = 1;
            repeat (CLKS_PER_BIT) @(negedge clk);

            before_count = rx_count;
            injected_rx = 0;
            @(negedge clk);
            injected_rx = 1;
            repeat (2*CLKS_PER_BIT) @(negedge clk);

            if (rx_count != before_count || rx_valid !== 1'b0)
                $fatal(1, "FAIL: false start produced a received byte");

            inject_enable = 0;
            $display("PASS: short false-start pulse rejected");
        end
    endtask

    // a low stop bit makes the frame invalid
    task automatic test_bad_stop(input logic [7:0] value);
        integer before_count;
        begin
            @(negedge clk);
            if (busy !== 1'b0)
                $fatal(1, "FAIL: TX busy before bad-stop test");

            inject_enable = 1;
            injected_rx = 1;
            repeat (2*CLKS_PER_BIT) @(negedge clk);

            before_count = rx_count;
            injected_rx = 0; // start bit
            repeat (CLKS_PER_BIT) @(negedge clk);

            for (int i = 0; i < 8; i++) begin
                injected_rx = value[i]; // lsb first
                repeat (CLKS_PER_BIT) @(negedge clk);
            end

            injected_rx = 0; // invalid stop bit (must be 1)
            repeat (CLKS_PER_BIT) @(negedge clk);

            injected_rx = 1; // restore idle line
            repeat (2*CLKS_PER_BIT) @(negedge clk);

            if (rx_count != before_count || rx_valid !== 1'b0)
                $fatal(1, "FAIL: bad stop bit produced a received byte");

            inject_enable = 0;
            $display("PASS: invalid stop bit rejected");
        end
    endtask

    // reset should interrupt an active transfer cleanly
    task automatic test_reset;
        begin
            @(negedge clk);
            data_in = 8'hA5;
            start = 1;
            @(negedge clk);
            start = 0;

            repeat (3) @(negedge clk);
            if (busy !== 1'b1)
                $fatal(1, "FAIL: TX not active before reset");

            rst_n = 0;
            #1;
            if (tx !== 1'b1 || busy !== 1'b0 || rx_valid !== 1'b0)
                $fatal(1, "FAIL: reset outputs");

            repeat (2) @(negedge clk);
            rst_n = 1;
            repeat (2) @(negedge clk);
            $display("PASS: reset during transmission");
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        repeat (3) @(negedge clk);
        rst_n = 1;
        repeat (2) @(negedge clk);

        $display("Testing all 256 byte values...");
        // exercise every possible eight-bit value, not just sample patterns
        for (int i = 0; i < 256; i++)
            send_and_check(i[7:0]);
        $display("PASS: all 256 values received correctly");

        test_reset();
        send_and_check(8'h5A);
        $display("PASS: recovered after reset");

        test_false_start();
        test_bad_stop(8'hA5);

        // a rejected frame should not stop later valid traffic
        send_and_check(8'h96);
        $display("PASS: normal frame after error conditions");

        if (unique_values != 256)
            $fatal(1, "FAIL: incomplete byte-value coverage");
        if (rx_count != 258)
            $fatal(1, "FAIL: expected 258 valid receptions, got %0d", rx_count);

        $display("================================");
        $display("UART EDGE-CASE VERIFICATION PASSED");
        $display("Valid receptions: %0d", rx_count);
        $display("Unique byte values: %0d/256", unique_values);
        $display("False-start and bad-stop tests: PASS");
        $display("ALL TESTS PASSED");
        $display("================================");
        $finish;
    end

    // fail instead of hanging forever if the design gets stuck
    initial begin
        #1000000;
        $fatal(1, "FAIL: simulation timed out");
    end

endmodule
