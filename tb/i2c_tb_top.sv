`timescale 1ns / 1ps

module i2c_tb_top;
    import uvm_pkg::*;
    import i2c_uvm_pkg::*;

    logic clk;
    i2c_if tb_if(clk);

    wire       reset_mon          = tb_if.reset;
    wire       cmd_start_mon      = tb_if.cmd_start;
    wire       cmd_write_mon      = tb_if.cmd_write;
    wire       cmd_read_mon       = tb_if.cmd_read;
    wire       cmd_stop_mon       = tb_if.cmd_stop;
    wire [7:0] tx_data_mon        = tb_if.tx_data;
    wire       mode_mon           = tb_if.mode;
    wire [7:0] rx_data_mon        = tb_if.rx_data;
    wire [7:0] slave_data_mon     = tb_if.slave_data;
    wire [7:0] led_data_mon       = tb_if.led_data;
    wire [7:0] fnd_data_mon       = tb_if.fnd_data;
    wire       done_mon           = tb_if.done;
    wire       busy_mon           = tb_if.busy;
    wire       slave_ack_mon      = tb_if.slave_ack;
    wire       master_ack_mon     = tb_if.master_ack;
    wire       scl_mon            = tb_if.scl;
    wire       sda_mon            = tb_if.sda;

    i2c_dut_wrapper dut(.vif(tb_if));

    wire       scl_bus_mon        = dut.scl_bus;
    wire       sda_bus_mon        = dut.sda_bus;
    wire       master_scl_mon     = dut.master_scl;
    wire       master_drive_mon   = dut.master_scl_drive_low;
    wire       sda_master_low_mon = dut.sda_master_drive_low;
    wire       sda_slave_low_mon  = dut.sda_slave_drive_low;
    wire [2:0] master_state_mon   = dut.u_i2c_master.state;
    wire [2:0] master_bit_cnt_mon = dut.u_i2c_master.bit_cnt;
    wire [1:0] master_step_mon    = dut.u_i2c_master.step;
    wire [2:0] slave_state_mon    = dut.u_i2c_slave.state;
    wire [2:0] slave_bit_cnt_mon  = dut.u_i2c_slave.bit_cnt;

    always #5 clk = ~clk;

    initial begin
        clk             = 1'b0;
        tb_if.reset     = 1'b1;
        tb_if.cmd_start = 1'b0;
        tb_if.cmd_write = 1'b0;
        tb_if.cmd_read  = 1'b0;
        tb_if.cmd_stop  = 1'b0;
        tb_if.tx_data   = 8'h00;
        tb_if.ack_in    = 1'b1;

        repeat (10) @(posedge clk);
        tb_if.reset = 1'b0;
    end

    initial begin
        string wave_file;

        if ($value$plusargs("WAVE_FILE=%s", wave_file)) begin
            $dumpfile(wave_file);
            $dumpvars(0, i2c_tb_top);
        end
    end

    initial begin
        uvm_config_db#(virtual i2c_if)::set(null, "*", "vif", tb_if);
        run_test("i2c_smoke_test");
    end
endmodule
