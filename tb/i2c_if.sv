interface i2c_if(input logic clk);
    logic       reset;
    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic [7:0] tx_data;
    logic       ack_in;

    logic       mode;
    logic [7:0] rx_data;
    logic       done;
    logic       slave_ack;
    logic       busy;
    logic [7:0] slave_data;
    logic       master_ack;
    logic [7:0] led_data;
    logic [7:0] fnd_data;

    wire        scl;
    wire        sda;

    clocking drv_cb @(posedge clk);
        output cmd_start;
        output cmd_write;
        output cmd_read;
        output tx_data;
        output ack_in;

        input reset;
        input mode;
        input rx_data;
        input done;
        input slave_ack;
        input busy;
        input slave_data;
        input master_ack;
        input led_data;
        input fnd_data;
    endclocking

    clocking mon_cb @(posedge clk);
        input reset;
        input cmd_start;
        input cmd_write;
        input cmd_read;
        input tx_data;
        input mode;
        input rx_data;
        input done;
        input slave_ack;
        input busy;
        input slave_data;
        input master_ack;
        input led_data;
        input fnd_data;
        input scl;
        input sda;
    endclocking
endinterface
