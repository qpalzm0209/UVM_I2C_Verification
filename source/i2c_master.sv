`timescale 1ns / 1ps

module i2c_master (
    input  logic       clk,
    input  logic       reset,
    input  logic       cmd_start,
    input  logic       cmd_write,
    input  logic       cmd_read,
    input  logic [7:0] tx_data,
    input  logic       ack_in,
    output logic       mode,
    output logic [7:0] rx_data,
    output logic       done,
    output logic       slave_ack,
    output logic       busy,
    output logic       scl,
    output logic       sda_drive_low,
    input  logic       sda_i
);

    logic       mode_next;
    logic [7:0] addr_byte;

    assign addr_byte = {7'd0, mode};

    always_comb begin
        mode_next = (!busy && cmd_write) ? 1'b0 :
                    (!busy && cmd_read)  ? 1'b1 :
                                           mode;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            mode <= 1'b0;
        end else begin
            mode <= mode_next;
        end
    end

    typedef enum logic [2:0] {
        IDLE     = 3'b000,
        START    = 3'b001,
        ADDR     = 3'b010,
        ADDR_ACK = 3'b011,
        DATA     = 3'b100,
        DATA_ACK = 3'b101,
        STOP     = 3'b110
    } state_t;

    state_t state;

    logic [7:0] sw_data_reg;
    logic [7:0] tx_shift_reg;
    logic [7:0] rx_shift_reg;
    logic [2:0] bit_cnt;
    logic [1:0] step;
    logic       is_read;

    logic [$clog2(250)-1:0] div_cnt;
    logic                   qtr_tick;

    logic sda_r;
    logic scl_r;

    assign sda_drive_low = ~sda_r;
    assign scl           = scl_r;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt  <= '0;
            qtr_tick <= 1'b0;
        end else if (busy) begin
            if (div_cnt == 249) begin
                div_cnt  <= '0;
                qtr_tick <= 1'b1;
            end else begin
                div_cnt  <= div_cnt + 1'b1;
                qtr_tick <= 1'b0;
            end
        end else begin
            div_cnt  <= '0;
            qtr_tick <= 1'b0;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sw_data_reg <= 8'h00;
        end else if (!busy) begin
            sw_data_reg <= tx_data;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state      <= IDLE;
            rx_data    <= 8'h00;
            done       <= 1'b0;
            slave_ack  <= 1'b1;
            busy       <= 1'b0;
            scl_r      <= 1'b1;
            sda_r      <= 1'b1;
            bit_cnt    <= 3'd7;
            step       <= 2'd0;
            tx_shift_reg <= 8'h00;
            rx_shift_reg <= 8'h00;
            is_read    <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    scl_r <= 1'b1;
                    sda_r <= 1'b1;
                    busy  <= 1'b0;
                    step  <= 2'd0;

                    if (cmd_start) begin
                        state <= START;
                        busy  <= 1'b1;
                    end
                end

                START: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b0;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b0;
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                scl_r        <= 1'b0;
                                sda_r        <= 1'b0;
                                is_read      <= mode;
                                tx_shift_reg <= addr_byte;
                                bit_cnt      <= 3'd7;
                                step         <= 2'd0;
                                state        <= ADDR;
                            end
                        endcase
                    end
                end

                ADDR: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= tx_shift_reg[bit_cnt];
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                sda_r <= tx_shift_reg[bit_cnt];
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                sda_r <= tx_shift_reg[bit_cnt];
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                sda_r <= tx_shift_reg[bit_cnt];
                                if (bit_cnt == 3'd0) begin
                                    state   <= ADDR_ACK;
                                    bit_cnt <= 3'd7;
                                    step    <= 2'd0;
                                end else begin
                                    bit_cnt <= bit_cnt - 1'b1;
                                    step    <= 2'd0;
                                end
                            end
                        endcase
                    end
                end

                ADDR_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r     <= 1'b1;
                                slave_ack <= sda_i; // 0=ACK, 1=NACK
                                step      <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                sda_r <= 1'b1;
                                step  <= 2'd0;
                                if (!slave_ack) begin
                                    bit_cnt <= 3'd7;
                                    if (is_read) begin
                                        rx_shift_reg <= 8'h00;
                                    end else begin
                                        tx_shift_reg <= sw_data_reg;
                                    end
                                    state <= DATA;
                                end else begin
                                    state <= STOP;
                                end
                            end
                        endcase
                    end
                end

                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[bit_cnt];
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[bit_cnt];
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[bit_cnt];
                                if (is_read) begin
                                    rx_shift_reg[bit_cnt] <= sda_i;
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[bit_cnt];
                                if (bit_cnt == 3'd0) begin
                                    bit_cnt <= 3'd7;
                                    step    <= 2'd0;
                                    state   <= DATA_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt - 1'b1;
                                    step    <= 2'd0;
                                end
                            end
                        endcase
                    end
                end

                DATA_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? ack_in : 1'b1;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                sda_r <= is_read ? ack_in : 1'b1;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                sda_r <= is_read ? ack_in : 1'b1;
                                if (!is_read) begin
                                    slave_ack <= sda_i; // 0=ACK, 1=NACK
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b0;
                                sda_r <= 1'b0;
                                step  <= 2'd0;
                                if (is_read) begin
                                    rx_data <= rx_shift_reg;
                                end
                                state <= STOP;
                            end
                        endcase
                    end
                end

                STOP: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= 1'b0;
                                step  <= 2'd1;
                            end
                            2'd1: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b0;
                                step  <= 2'd2;
                            end
                            2'd2: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b1;
                                step  <= 2'd3;
                            end
                            2'd3: begin
                                scl_r <= 1'b1;
                                sda_r <= 1'b1;
                                busy  <= 1'b0;
                                done  <= 1'b1;
                                step  <= 2'd0;
                                state <= IDLE;
                            end
                        endcase
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

module btn_debouncer (
    input  logic clk,
    input  logic reset,
    input  logic btn,
    output logic btn_pulse
);
    logic sync_1;
    logic sync_2;
    logic btn_state;
    logic [$clog2(1000)-1:0] cnt;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sync_1    <= 1'b0;
            sync_2    <= 1'b0;
            btn_state <= 1'b0;
            btn_pulse <= 1'b0;
            cnt       <= '0;
        end else begin
            sync_1    <= btn;
            sync_2    <= sync_1;
            btn_pulse <= 1'b0;

            if (sync_2 == btn_state) begin
                cnt <= '0;
            end else if (cnt == 999) begin
                btn_state <= sync_2;
                cnt       <= '0;

                if (sync_2) begin
                    btn_pulse <= 1'b1;
                end
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end
endmodule

module rx_fnd_controller (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] rx_data,
    output logic [6:0] seg,
    output logic       dp,
    output logic [3:0] an
);
    logic [16:0] refresh_cnt;
    logic [1:0]  scan_sel;
    logic [3:0]  active_digit;
    logic        digit_enable;
    logic [6:0]  seg_decoded;

    hex_to_7seg u_hex_to_7seg (
        .hex_digit (active_digit),
        .seg_n     (seg_decoded)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            refresh_cnt <= '0;
        end else begin
            refresh_cnt <= refresh_cnt + 1'b1;
        end
    end

    assign scan_sel = refresh_cnt[16:15];
    assign dp       = 1'b1;

    always_comb begin
        active_digit = 4'h0;
        digit_enable = 1'b0;
        an           = 4'b1111;

        case (scan_sel)
            2'd0: begin
                active_digit = rx_data[3:0];
                digit_enable = 1'b1;
                an           = 4'b1110;
            end
            2'd1: begin
                active_digit = rx_data[7:4];
                digit_enable = 1'b1;
                an           = 4'b1101;
            end
            default: begin
                an = 4'b1111;
            end
        endcase
    end

    assign seg = digit_enable ? seg_decoded : 7'b1111111;
endmodule

module hex_to_7seg (
    input  logic [3:0] hex_digit,
    output logic [6:0] seg_n
);
    always_comb begin
        case (hex_digit)
            4'h0: seg_n = 7'b1000000;
            4'h1: seg_n = 7'b1111001;
            4'h2: seg_n = 7'b0100100;
            4'h3: seg_n = 7'b0110000;
            4'h4: seg_n = 7'b0011001;
            4'h5: seg_n = 7'b0010010;
            4'h6: seg_n = 7'b0000010;
            4'h7: seg_n = 7'b1111000;
            4'h8: seg_n = 7'b0000000;
            4'h9: seg_n = 7'b0010000;
            4'hA: seg_n = 7'b0001000;
            4'hB: seg_n = 7'b0000011;
            4'hC: seg_n = 7'b1000110;
            4'hD: seg_n = 7'b0100001;
            4'hE: seg_n = 7'b0000110;
            4'hF: seg_n = 7'b0001110;
            default: seg_n = 7'b1111111;
        endcase
    end
endmodule
