package i2c_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef virtual i2c_if i2c_vif_t;

    class i2c_seq_item extends uvm_sequence_item;
        rand bit       mode;
        rand bit [7:0] data;

        bit [7:0] rx_data;
        bit [7:0] slave_data;
        bit [7:0] led_data;
        bit [7:0] fnd_data;
        bit       slave_ack;
        bit       master_ack;

        `uvm_object_utils_begin(i2c_seq_item)
            `uvm_field_int(mode,       UVM_DEFAULT)
            `uvm_field_int(data,       UVM_DEFAULT)
            `uvm_field_int(rx_data,    UVM_DEFAULT | UVM_NOPACK)
            `uvm_field_int(slave_data, UVM_DEFAULT | UVM_NOPACK)
            `uvm_field_int(led_data,   UVM_DEFAULT | UVM_NOPACK)
            `uvm_field_int(fnd_data,   UVM_DEFAULT | UVM_NOPACK)
            `uvm_field_int(slave_ack,  UVM_DEFAULT | UVM_NOPACK)
            `uvm_field_int(master_ack, UVM_DEFAULT | UVM_NOPACK)
        `uvm_object_utils_end

        function new(string name = "i2c_seq_item");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf(
                "mode=%s data=0x%02h rx=0x%02h slave=0x%02h led=0x%02h fnd=0x%02h slave_ack=%0b master_ack=%0b",
                mode ? "READ" : "WRITE",
                data,
                rx_data,
                slave_data,
                led_data,
                fnd_data,
                slave_ack,
                master_ack
            );
        endfunction
    endclass

    class i2c_smoke_sequence extends uvm_sequence #(i2c_seq_item);
        `uvm_object_utils(i2c_smoke_sequence)

        function new(string name = "i2c_smoke_sequence");
            super.new(name);
        endfunction

        task body();
            i2c_seq_item req;

            for (int unsigned value = 0; value < 256; value++) begin
                req = i2c_seq_item::type_id::create($sformatf("wr_%0d", value));
                start_item(req);
                req.mode = 1'b0;
                req.data = value[7:0];
                finish_item(req);

                req = i2c_seq_item::type_id::create($sformatf("rd_%0d", value));
                start_item(req);
                req.mode = 1'b1;
                req.data = value[7:0];
                finish_item(req);
            end
        endtask
    endclass

    class i2c_sequencer extends uvm_sequencer #(i2c_seq_item);
        `uvm_component_utils(i2c_sequencer)

        function new(string name = "i2c_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    class i2c_driver extends uvm_driver #(i2c_seq_item);
        `uvm_component_utils(i2c_driver)

        i2c_vif_t vif;

        function new(string name = "i2c_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(i2c_vif_t)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(), "Virtual interface not found")
            end
        endfunction

        task run_phase(uvm_phase phase);
            i2c_seq_item req;

            drive_idle();
            wait_reset_release();

            forever begin
                seq_item_port.get_next_item(req);
                drive_transfer(req);
                seq_item_port.item_done();
            end
        endtask

        protected task drive_idle();
            vif.drv_cb.cmd_start <= 1'b0;
            vif.drv_cb.cmd_write <= 1'b0;
            vif.drv_cb.cmd_read  <= 1'b0;
            vif.drv_cb.cmd_stop  <= 1'b0;
            vif.drv_cb.tx_data   <= 8'h00;
            vif.drv_cb.ack_in    <= 1'b1;
        endtask

        protected task wait_reset_release();
            while (vif.reset) begin
                @(vif.drv_cb);
                drive_idle();
            end
        endtask

        protected task drive_transfer(i2c_seq_item req);
            while (vif.reset) begin
                @(vif.drv_cb);
                drive_idle();
            end

            while (vif.drv_cb.busy) begin
                @(vif.drv_cb);
            end

            vif.drv_cb.tx_data   <= req.data;
            vif.drv_cb.ack_in    <= 1'b1;
            vif.drv_cb.cmd_stop  <= 1'b0;
            vif.drv_cb.cmd_start <= 1'b0;
            vif.drv_cb.cmd_write <= ~req.mode;
            vif.drv_cb.cmd_read  <= req.mode;
            @(vif.drv_cb);

            vif.drv_cb.cmd_write <= 1'b0;
            vif.drv_cb.cmd_read  <= 1'b0;
            vif.drv_cb.cmd_start <= 1'b1;
            @(vif.drv_cb);

            vif.drv_cb.cmd_start <= 1'b0;
            while (!vif.drv_cb.done) begin
                @(vif.drv_cb);
            end

            @(vif.drv_cb);
            drive_idle();
        endtask
    endclass

    class i2c_monitor extends uvm_component;
        `uvm_component_utils(i2c_monitor)

        i2c_vif_t vif;
        uvm_analysis_port #(i2c_seq_item) ap;

        function new(string name = "i2c_monitor", uvm_component parent = null);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(i2c_vif_t)::get(this, "", "vif", vif)) begin
                `uvm_fatal(get_type_name(), "Virtual interface not found")
            end
        endfunction

        task run_phase(uvm_phase phase);
            i2c_seq_item item;

            forever begin
                @(vif.mon_cb);
                if (vif.mon_cb.reset) begin
                    continue;
                end

                if (vif.mon_cb.cmd_start) begin
                    item = i2c_seq_item::type_id::create($sformatf("mon_%0t", $time), this);
                    item.mode = vif.mon_cb.mode;
                    item.data = vif.mon_cb.tx_data;

                    do begin
                        @(vif.mon_cb);
                    end while (!vif.mon_cb.done && !vif.mon_cb.reset);

                    if (vif.mon_cb.reset) begin
                        continue;
                    end

                    item.rx_data    = vif.mon_cb.rx_data;
                    item.slave_data = vif.mon_cb.slave_data;
                    item.led_data   = vif.mon_cb.led_data;
                    item.fnd_data   = vif.mon_cb.fnd_data;
                    item.slave_ack  = vif.mon_cb.slave_ack;
                    item.master_ack = vif.mon_cb.master_ack;
                    ap.write(item);
                end
            end
        endtask
    endclass

    class i2c_agent extends uvm_agent;
        `uvm_component_utils(i2c_agent)

        i2c_sequencer sequencer;
        i2c_driver    driver;
        i2c_monitor   monitor;

        function new(string name = "i2c_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            monitor   = i2c_monitor::type_id::create("monitor", this);
            sequencer = i2c_sequencer::type_id::create("sequencer", this);
            driver    = i2c_driver::type_id::create("driver", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    class i2c_scoreboard extends uvm_subscriber #(i2c_seq_item);
        `uvm_component_utils(i2c_scoreboard)

        bit [7:0] model_reg;
        int unsigned total_cnt;
        int unsigned write_cnt;
        int unsigned read_cnt;
        int unsigned pass_cnt;
        int unsigned fail_cnt;

        function new(string name = "i2c_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        virtual function void write(i2c_seq_item t);
            bit pass;
            bit [7:0] log_data;
            string mode_str;
            string out_label;

            pass = 1'b1;
            total_cnt++;

            if (t.mode == 1'b0) begin
                write_cnt++;
                mode_str = "write";

                if (t.slave_ack !== 1'b0) begin
                    `uvm_error("I2C_SB", $sformatf("WRITE ACK mismatch: %s", t.convert2string()))
                    pass = 1'b0;
                end
                if (t.slave_data !== t.data) begin
                    `uvm_error("I2C_SB", $sformatf("WRITE slave_data mismatch exp=0x%02h act=0x%02h", t.data, t.slave_data))
                    pass = 1'b0;
                end
                if (t.led_data !== t.data) begin
                    `uvm_error("I2C_SB", $sformatf("WRITE led_data mismatch exp=0x%02h act=0x%02h", t.data, t.led_data))
                    pass = 1'b0;
                end

                if (pass) begin
                    model_reg = t.data;
                end

                log_data = t.led_data;
                out_label = "LED out";
            end else begin
                read_cnt++;
                mode_str = "read";

                if (t.master_ack !== 1'b1) begin
                    `uvm_error("I2C_SB", $sformatf("READ ACK mismatch: %s", t.convert2string()))
                    pass = 1'b0;
                end
                if (t.rx_data !== model_reg) begin
                    `uvm_error("I2C_SB", $sformatf("READ rx_data mismatch exp=0x%02h act=0x%02h", model_reg, t.rx_data))
                    pass = 1'b0;
                end
                if (t.fnd_data !== model_reg) begin
                    `uvm_error("I2C_SB", $sformatf("READ fnd_data mismatch exp=0x%02h act=0x%02h", model_reg, t.fnd_data))
                    pass = 1'b0;
                end

                log_data = t.fnd_data;
                out_label = "FND out";
            end

            `uvm_info(
                "I2C_SMOKE_LOG",
                $sformatf(
                    "Data: %02h  /  Mod: %-7s/  %s: %02h",
                    t.data,
                    mode_str,
                    out_label,
                    log_data
                ),
                UVM_NONE
            )

            if (pass) begin
                pass_cnt++;
            end else begin
                fail_cnt++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info(
                "I2C_SB_SUMMARY",
                $sformatf(
                    "smoke summary: total=%0d write=%0d read=%0d pass=%0d fail=%0d",
                    total_cnt,
                    write_cnt,
                    read_cnt,
                    pass_cnt,
                    fail_cnt
                ),
                UVM_NONE
            )
        endfunction
    endclass

    class i2c_env extends uvm_env;
        `uvm_component_utils(i2c_env)

        i2c_agent      agent;
        i2c_scoreboard scoreboard;

        function new(string name = "i2c_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent      = i2c_agent::type_id::create("agent", this);
            scoreboard = i2c_scoreboard::type_id::create("scoreboard", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.monitor.ap.connect(scoreboard.analysis_export);
        endfunction
    endclass

    class i2c_smoke_test extends uvm_test;
        `uvm_component_utils(i2c_smoke_test)

        i2c_env env;

        function new(string name = "i2c_smoke_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = i2c_env::type_id::create("env", this);
            uvm_top.set_timeout(2s, 1);
        endfunction

        task run_phase(uvm_phase phase);
            i2c_smoke_sequence seq;

            phase.raise_objection(this);
            seq = i2c_smoke_sequence::type_id::create("seq");
            seq.start(env.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass
endpackage
