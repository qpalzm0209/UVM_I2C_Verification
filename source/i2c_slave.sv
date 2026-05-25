`timescale 1ns / 1ps

module i2c_slave (
    input  logic       clk,
    input  logic       reset,
    input  logic       scl,
    input  logic       sda_i,
    output logic       sda_drive_low,
    output logic [7:0] data_out,
    output logic       busy,
    output logic       done,
    output logic       master_ack
);

    localparam logic [6:0] SLAVE_ADDR = 7'd0;

    typedef enum logic [2:0] {
        IDLE       = 3'd0,
        ADDR       = 3'd1,
        ADDR_ACK   = 3'd2,
        WRITE_DATA = 3'd3,
        WRITE_ACK  = 3'd4,
        READ_DATA  = 3'd5,
        READ_ACK   = 3'd6,
        WAIT_STOP  = 3'd7
    } state_t;

    state_t state;

    logic [7:0] shift_reg;
    logic [7:0] tx_shift_reg;
    logic [2:0] bit_cnt;
    logic       rw;
    logic       addr_match;
    logic       ack_phase;
    logic       txn_done_pending;

    logic scl_d;
    logic sda_d;
    logic scl_rise;
    logic scl_fall;
    logic start_det;
    logic stop_det;

    logic sda_r;

    assign sda_drive_low = ~sda_r;
    assign scl_rise      = !scl_d && scl;
    assign scl_fall      = scl_d && !scl;
    assign start_det     = sda_d && !sda_i && scl;
    assign stop_det      = !sda_d && sda_i && scl;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            shift_reg        <= 8'h00;
            tx_shift_reg     <= 8'h00;
            bit_cnt          <= 3'd7;
            rw               <= 1'b0;
            addr_match       <= 1'b0;
            ack_phase        <= 1'b0;
            txn_done_pending <= 1'b0;
            data_out         <= 8'h00;
            busy             <= 1'b0;
            done             <= 1'b0;
            master_ack       <= 1'b1;
            sda_r            <= 1'b1;
            scl_d            <= 1'b1;
            sda_d            <= 1'b1;
        end else begin
            done  <= 1'b0;
            scl_d <= scl;
            sda_d <= sda_i;

            if (start_det) begin
                state            <= ADDR;
                bit_cnt          <= 3'd7;
                rw               <= 1'b0;
                addr_match       <= 1'b0;
                ack_phase        <= 1'b0;
                txn_done_pending <= 1'b0;
                busy             <= 1'b1;
                sda_r            <= 1'b1;
            end else if (stop_det) begin
                state      <= IDLE;
                bit_cnt    <= 3'd7;
                ack_phase  <= 1'b0;
                busy       <= 1'b0;
                sda_r      <= 1'b1;
                if (txn_done_pending) begin
                    done <= 1'b1;
                end
                txn_done_pending <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin
                        busy  <= 1'b0;
                        sda_r <= 1'b1;
                    end

                    ADDR: begin
                        if (scl_rise) begin
                            shift_reg[bit_cnt] <= sda_i;
                            if (bit_cnt == 3'd0) begin
                                rw         <= sda_i;
                                addr_match <= (shift_reg[7:1] == SLAVE_ADDR);
                                bit_cnt    <= 3'd7;
                                ack_phase  <= 1'b0;
                                state      <= ADDR_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    ADDR_ACK: begin
                        if (!ack_phase && scl_fall) begin
                            ack_phase <= 1'b1;
                            if (addr_match) begin
                                sda_r <= 1'b0;
                            end
                        end else if (ack_phase && scl_fall) begin
                            ack_phase <= 1'b0;
                            sda_r     <= 1'b1;

                            if (addr_match) begin
                                bit_cnt <= 3'd7;
                                if (rw) begin
                                    tx_shift_reg <= data_out;
                                    sda_r        <= data_out[7];
                                    state        <= READ_DATA;
                                end else begin
                                    state <= WRITE_DATA;
                                end
                            end else begin
                                state <= WAIT_STOP;
                            end
                        end
                    end

                    WRITE_DATA: begin
                        if (scl_rise) begin
                            shift_reg[bit_cnt] <= sda_i;
                            if (bit_cnt == 3'd0) begin
                                data_out  <= {shift_reg[7:1], sda_i};
                                bit_cnt   <= 3'd7;
                                ack_phase <= 1'b0;
                                state     <= WRITE_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                        end
                    end

                    WRITE_ACK: begin
                        if (!ack_phase && scl_fall) begin
                            ack_phase <= 1'b1;
                            sda_r     <= 1'b0;
                        end else if (ack_phase && scl_fall) begin
                            ack_phase        <= 1'b0;
                            txn_done_pending <= 1'b1;
                            sda_r            <= 1'b1;
                            state            <= WAIT_STOP;
                        end
                    end

                    READ_DATA: begin
                        if (scl_fall) begin
                            if (bit_cnt == 3'd0) begin
                                bit_cnt <= 3'd7;
                                sda_r   <= 1'b1;
                                state   <= READ_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                                sda_r   <= tx_shift_reg[bit_cnt - 1'b1];
                            end
                        end
                    end

                    READ_ACK: begin
                        if (scl_rise) begin
                            master_ack <= sda_i; // 0=ACK, 1=NACK
                        end

                        if (scl_fall) begin
                            txn_done_pending <= 1'b1;
                            sda_r            <= 1'b1;
                            state            <= WAIT_STOP;
                        end
                    end

                    WAIT_STOP: begin
                        sda_r <= 1'b1;
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule
