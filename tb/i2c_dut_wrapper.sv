`timescale 1ns / 1ps

module i2c_dut_wrapper(i2c_if vif);
    tri1 scl_bus;
    tri1 sda_bus;

    logic master_scl;
    logic master_scl_drive_low;
    logic sda_master_drive_low;
    logic sda_slave_drive_low;

    assign master_scl_drive_low = ~master_scl;
    assign scl_bus              = master_scl_drive_low ? 1'b0 : 1'bz;
    assign sda_bus              = sda_master_drive_low ? 1'b0 : 1'bz;
    assign sda_bus              = sda_slave_drive_low  ? 1'b0 : 1'bz;

    assign vif.scl      = scl_bus;
    assign vif.sda      = sda_bus;
    assign vif.led_data = vif.slave_data;
    assign vif.fnd_data = vif.rx_data;

    i2c_master u_i2c_master (
        .clk           (vif.clk),
        .reset         (vif.reset),
        .cmd_start     (vif.cmd_start),
        .cmd_write     (vif.cmd_write),
        .cmd_read      (vif.cmd_read),
        .tx_data       (vif.tx_data),
        .ack_in        (vif.ack_in),
        .mode          (vif.mode),
        .rx_data       (vif.rx_data),
        .done          (vif.done),
        .slave_ack     (vif.slave_ack),
        .busy          (vif.busy),
        .scl           (master_scl),
        .sda_drive_low (sda_master_drive_low),
        .sda_i         (sda_bus)
    );

    i2c_slave u_i2c_slave (
        .clk           (vif.clk),
        .reset         (vif.reset),
        .scl           (scl_bus),
        .sda_i         (sda_bus),
        .sda_drive_low (sda_slave_drive_low),
        .data_out      (vif.slave_data),
        .busy          (),
        .done          (),
        .master_ack    (vif.master_ack)
    );
endmodule
