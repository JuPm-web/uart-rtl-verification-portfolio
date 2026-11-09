// the transmitter sends one start bit, eight data bits and one stop bit
// a small clocks-per-bit value keeps simulation runs short
module uart_tx #(
    parameter integer CLKS_PER_BIT = 8
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [7:0] data_in,
    output logic       tx,
    output logic       busy
);
    // these four states describe which part of a uart frame is being sent
    typedef enum logic [1:0] {IDLE, START_BIT, DATA_BITS, STOP_BIT} state_t;
    state_t state;
    integer clock_count;
    logic [2:0] bit_index;
    logic [7:0] data_reg;

    // state and outputs update on a clock edge or an active-low reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx <= 1'b1;
            busy <= 1'b0;
            clock_count <= 0;
            bit_index <= 0;
            data_reg <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    busy <= 1'b0;
                    clock_count <= 0;
                    if (start) begin
                        // save the whole byte before transmitting any bits
                        data_reg <= data_in;
                        tx <= 1'b0;        // start bit
                        busy <= 1'b1;
                        state <= START_BIT;
                    end
                end
                // hold the start bit low for one complete bit period
                START_BIT: begin
                    if (clock_count == CLKS_PER_BIT-1) begin
                        clock_count <= 0;
                        bit_index <= 0;
                        tx <= data_reg[0]; // least-significant bit first
                        state <= DATA_BITS;
                    end else clock_count <= clock_count + 1;
                end
                // shift through the saved byte starting with bit zero
                DATA_BITS: begin
                    if (clock_count == CLKS_PER_BIT-1) begin
                        clock_count <= 0;
                        if (bit_index == 7) begin
                            tx <= 1'b1;    // stop bit
                            state <= STOP_BIT;
                        end else begin
                            bit_index <= bit_index + 1;
                            tx <= data_reg[bit_index + 1];
                        end
                    end else clock_count <= clock_count + 1;
                end
                // return the line high for the stop bit before going idle
                STOP_BIT: begin
                    if (clock_count == CLKS_PER_BIT-1) begin
                        clock_count <= 0;
                        state <= IDLE;
                        busy <= 1'b0;
                    end else clock_count <= clock_count + 1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule


// the receiver rebuilds a byte from the serial line, least-significant bit first
// the tx and rx are separate modules so either can be tested on its own
module uart_rx #(
    parameter integer CLKS_PER_BIT = 8
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,
    output logic [7:0] data_out,
    output logic       valid
);
    typedef enum logic [1:0] {
        IDLE, START_BIT, DATA_BITS, STOP_BIT
    } state_t;

    state_t state;
    integer clock_count;
    logic [2:0] bit_index;
    // keep sampled bits here until the full frame has been received
    logic [7:0] received_data;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            clock_count   <= 0;
            bit_index     <= 0;
            received_data <= 0;
            data_out      <= 0;
            valid         <= 0;
        end else begin
            valid <= 0;  // valid stays high for one clock after a good stop bit
            case (state)
                IDLE: begin
                    if (rx == 1'b0) begin
                        clock_count <= 0;
                        bit_index <= 0;  // each new frame starts with bit zero
                        state <= START_BIT;
                    end
                end

                START_BIT: begin
                    // check halfway through the start bit to reject short glitches
                    if (clock_count == CLKS_PER_BIT/2 - 1) begin
                        clock_count <= 0;
                        if (rx == 1'b0)
                            state <= DATA_BITS;
                        else
                            state <= IDLE;  // ignore a short pulse that was not a real start bit
                    end else begin
                        clock_count <= clock_count + 1;
                    end
                end

                DATA_BITS: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 0;
                        // sample the serial wire into the current bit position
                        received_data[bit_index] <= rx;
                        if (bit_index == 7)
                            state <= STOP_BIT;
                        else
                            bit_index <= bit_index + 1;
                    end else begin
                        clock_count <= clock_count + 1;
                    end
                end

                STOP_BIT: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 0;
                        // a high stop bit means the completed byte can be accepted
                        if (rx == 1'b1) begin
                            data_out <= received_data;
                            valid <= 1'b1;
                        end
                        state <= IDLE;
                    end else begin
                        clock_count <= clock_count + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
