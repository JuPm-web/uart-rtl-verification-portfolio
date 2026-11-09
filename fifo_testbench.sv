`timescale 1ns/1ps

module fifo_testbench;
    logic clk = 0;
    logic rst_n = 1;
    logic wr_en = 0;
    logic rd_en = 0;
    logic [7:0] wr_data = 0;
    wire [7:0] rd_data;
    wire rd_valid, full, empty, overflow, underflow;
    wire [3:0] level;

    always #5 clk = ~clk;

    uart_fifo #(.DEPTH(8)) dut (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .wr_data(wr_data), .rd_en(rd_en),
        .rd_data(rd_data), .rd_valid(rd_valid),
        .full(full), .empty(empty), .level(level),
        .overflow(overflow), .underflow(underflow)
    );

    // start each group of tests with a known empty queue
    task automatic reset_fifo;
        begin
            @(negedge clk);
            rst_n = 0;
            wr_en = 0;
            rd_en = 0;
            repeat (2) @(negedge clk);
            if (!empty || full || level !== 0)
                $fatal(1, "FAIL: reset did not empty FIFO");
            rst_n = 1;
        end
    endtask

    // request a write for one clock and reject unexpected overflow
    task automatic push_byte(input logic [7:0] value);
        begin
            @(negedge clk);
            wr_data = value;
            wr_en = 1;
            @(negedge clk);
            wr_en = 0;
            if (overflow)
                $fatal(1, "FAIL: unexpected overflow on push %h", value);
        end
    endtask

    // check that the oldest expected byte comes out on a valid read
    task automatic pop_expect(input logic [7:0] value);
        begin
            @(negedge clk);
            rd_en = 1;
            @(negedge clk);
            rd_en = 0;
            if (!rd_valid || rd_data !== value)
                $fatal(1, "FAIL: expected %h, got %h valid=%b", value, rd_data, rd_valid);
        end
    endtask

    initial begin
        $dumpfile("fifo_dump.vcd");
        $dumpvars(0, fifo_testbench);
        reset_fifo();

        // eight writes should fill the queue exactly
        for (int i = 0; i < 8; i++)
            push_byte(8'h20 + i);
        if (!full || empty || level !== 8)
            $fatal(1, "FAIL: FIFO not full after eight pushes");
        $display("PASS: full flag and 8-byte capacity");

        @(negedge clk);
        // this extra byte must not replace any unread data
        wr_data = 8'hEE;
        wr_en = 1;
        @(negedge clk);
        wr_en = 0;
        if (!overflow || !full || level !== 8)
            $fatal(1, "FAIL: overflow not reported correctly");
        $display("PASS: overflow rejected");

        // checking the values in order also checks the pointer logic
        for (int i = 0; i < 8; i++)
            pop_expect(8'h20 + i);
        if (!empty || full || level !== 0)
            $fatal(1, "FAIL: FIFO not empty after eight pops");
        $display("PASS: FIFO ordering and empty flag");

        @(negedge clk);
        // reading an empty fifo should raise underflow without returning data
        rd_en = 1;
        @(negedge clk);
        rd_en = 0;
        if (!underflow || rd_valid || level !== 0)
            $fatal(1, "FAIL: underflow not reported correctly");
        $display("PASS: underflow rejected");

        reset_fifo();
        for (int i = 0; i < 8; i++)
            push_byte(8'h80 + i);
        @(negedge clk);
        // one old byte leaves as one new byte enters
        wr_data = 8'hF0;
        wr_en = 1;
        rd_en = 1;
        @(negedge clk);
        wr_en = 0;
        rd_en = 0;
        if (!rd_valid || rd_data !== 8'h80 || overflow || level !== 8)
            $fatal(1, "FAIL: simultaneous full read/write");
        for (int i = 1; i < 8; i++)
            pop_expect(8'h80 + i);
        pop_expect(8'hF0);
        if (!empty || level !== 0)
            $fatal(1, "FAIL: pointer wraparound or level mismatch");
        $display("PASS: simultaneous read/write and pointer wraparound");
        $display("FIFO TESTS PASSED");
        $finish;
    end

    // stop the test if a hardware condition prevents progress
    initial begin
        #100000;
        $fatal(1, "FAIL: FIFO simulation timeout");
    end
endmodule
