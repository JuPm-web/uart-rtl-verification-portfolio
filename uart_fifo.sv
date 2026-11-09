// the fifo keeps received bytes in order until they can be read
// a read frees space for a write on the same clock, even when full
// an empty fifo does not bypass a new write straight to the reader
// rd_valid tells the reader that rd_data was updated this cycle
// overflow and underflow report rejected requests for one clock
module uart_fifo #(
    parameter integer DEPTH = 8
)(
    input  logic clk,
    input  logic rst_n,
    input  logic wr_en,
    input  logic [7:0] wr_data,
    input  logic rd_en,
    output logic [7:0] rd_data,
    output logic rd_valid,
    output wire full,
    output wire empty,
    output logic [$clog2(DEPTH+1)-1:0] level,
    output logic overflow,
    output logic underflow
);
    // use enough pointer bits to address every slot in the buffer
    localparam integer PTR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;

    // memory holds the bytes that have not been read yet
    logic [7:0] memory [0:DEPTH-1];
    // write_ptr points to the next free slot and read_ptr to the oldest byte
    logic [PTR_W-1:0] write_ptr, read_ptr;

    // accepted operations may differ from the requested enables
    wire read_accepted;
    wire write_accepted;
    // level is the number of bytes currently waiting in the fifo
    assign empty = (level == 0);
    assign full  = (level == DEPTH);
    // a read is accepted only if at least one byte is stored
    assign read_accepted = rd_en && !empty;
    // a simultaneous read can free space even when the fifo is full
    assign write_accepted = wr_en && (!full || read_accepted);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            read_ptr  <= 0;
            level     <= 0;
            rd_data   <= 0;
            rd_valid  <= 0;
            overflow  <= 0;
            underflow <= 0;
        end else begin
            // clear last cycle's flags unless a new event occurs
            rd_valid  <= 0;
            overflow  <= wr_en && !write_accepted;
            underflow <= rd_en && !read_accepted;

            // return the oldest unread byte and move the read pointer forward
            if (read_accepted) begin
                rd_data  <= memory[read_ptr];
                rd_valid <= 1;
                // wrap back to slot zero after reaching the last address
                if (read_ptr == DEPTH-1)
                    read_ptr <= 0;
                else
                    read_ptr <= read_ptr + 1'b1;
            end

            // save new data and move the write pointer forward
            if (write_accepted) begin
                memory[write_ptr] <= wr_data;
                // the same wraparound rule applies to the write pointer
                if (write_ptr == DEPTH-1)
                    write_ptr <= 0;
                else
                    write_ptr <= write_ptr + 1'b1;
            end

            // update occupancy only when one operation succeeds without the other
            case ({write_accepted, read_accepted})
                2'b10: level <= level + 1'b1;
                2'b01: level <= level - 1'b1;
                default: level <= level;
            endcase
        end
    end
endmodule
