`timescale 1ns / 1ps

module i2c_top (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] sw,
    input  logic [4:0] btn,
    inout  wire        jb_scl,
    inout  wire        jb_sda,
    inout  wire        jc_scl,
    inout  wire        jc_sda,
    output logic [6:0] seg,
    output logic       dp,
    output logic [3:0] an,
    output logic [7:0] led,
    output logic       led_15
);
    logic btn_l, btn_r, btn_c;

    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic [7:0] tx_data;
    logic       ack_in;

    logic [7:0] rx_data;
    logic       master_done;
    logic       slave_ack;
    logic       master_busy;
    logic       mode;

    logic [7:0] slave_data;
    logic       slave_busy;
    logic       slave_done;
    logic       master_ack;
    logic       sda_master_drive_low;
    logic       sda_slave_drive_low;
    logic       master_scl;
    logic       master_scl_drive_low;

    // Temporary button mapping for bring-up.
    assign cmd_start = btn_c;
    assign cmd_write = btn_r;
    assign cmd_read  = btn_l;
    assign tx_data   = sw;
    assign ack_in    = 1'b1;
    assign led       = slave_data;
    assign led_15    = mode;
    assign master_scl_drive_low = ~master_scl;
    assign jb_scl = master_scl_drive_low ? 1'b0 : 1'bz;
    assign jb_sda = sda_master_drive_low ? 1'b0 : 1'bz;
    assign jc_scl = 1'bz;
    assign jc_sda = sda_slave_drive_low ? 1'b0 : 1'bz;

    i2c_master u_i2c_master (
        .clk       (clk),
        .reset     (reset),
        .cmd_start (cmd_start),
        .cmd_write (cmd_write),
        .cmd_read  (cmd_read),
        .tx_data   (tx_data),
        .ack_in    (ack_in),
        .mode      (mode),
        .rx_data   (rx_data),
        .done      (master_done),
        .slave_ack (slave_ack),
        .busy      (master_busy),
        .scl           (master_scl),
        .sda_drive_low (sda_master_drive_low),
        .sda_i         (jb_sda)
    );

    i2c_slave u_i2c_slave (
        .clk        (clk),
        .reset      (reset),
        .scl        (jc_scl),
        .sda_i      (jc_sda),
        .sda_drive_low (sda_slave_drive_low),
        .data_out      (slave_data),
        .busy          (slave_busy),
        .done          (slave_done),
        .master_ack    (master_ack)
    );

    rx_fnd_controller u_rx_fnd_controller (
        .clk     (clk),
        .reset   (reset),
        .rx_data (rx_data),
        .seg     (seg),
        .dp      (dp),
        .an      (an)
    );

    btn_debouncer l_btn_debouncer (
        .clk       (clk),
        .reset     (reset),
        .btn       (btn[2]),
        .btn_pulse (btn_l)
    );

    btn_debouncer r_btn_debouncer (
        .clk       (clk),
        .reset     (reset),
        .btn       (btn[3]),
        .btn_pulse (btn_r)
    );

    btn_debouncer c_btn_debouncer (
        .clk       (clk),
        .reset     (reset),
        .btn       (btn[4]),
        .btn_pulse (btn_c)
    );

endmodule
