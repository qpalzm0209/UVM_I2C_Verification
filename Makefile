ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
OUT_DIR  := $(ROOT_DIR)/out
SIMV     := $(OUT_DIR)/simv
WAVE     := $(OUT_DIR)/waves/i2c_smoke_test.vcd
LOG      := $(OUT_DIR)/logs/i2c_smoke_test.log

VCS   ?= vcs
VERDI ?= verdi
SEED  ?= 1

VCS_FLAGS := -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps
VCS_FLAGS += -debug_access+all -kdb +v2k
VCS_FLAGS += -top i2c_tb_top
VCS_FLAGS += -f tb/filelist.f

.PHONY: all compile smoke verdi clean

all: smoke

compile: $(SIMV)

$(SIMV): tb/filelist.f tb/i2c_if.sv tb/i2c_uvm_pkg.sv tb/i2c_dut_wrapper.sv tb/i2c_tb_top.sv source/i2c_master.sv source/i2c_slave.sv source/i2c_top.sv
	mkdir -p $(OUT_DIR)/logs $(OUT_DIR)/waves
	cd $(ROOT_DIR) && $(VCS) $(VCS_FLAGS) -o $(SIMV) -l $(OUT_DIR)/logs/compile.log

smoke: compile
	mkdir -p $(OUT_DIR)/logs $(OUT_DIR)/waves
	rm -f $(WAVE) $(WAVE).fsdb $(WAVE).fsdb.*
	cd $(ROOT_DIR) && $(SIMV) \
		+UVM_NO_RELNOTES \
		+ntb_random_seed=$(SEED) \
		+WAVE_FILE=$(WAVE) \
		-l $(LOG)

verdi: smoke
	rm -rf $(ROOT_DIR)/verdiLog $(ROOT_DIR)/novas.rc $(ROOT_DIR)/novas.conf
	rm -f $(WAVE).fsdb $(WAVE).fsdb.*
	cd $(ROOT_DIR) && $(VERDI) -full64 -dbdir $(OUT_DIR)/simv.daidir -ssf $(WAVE) &

clean:
	rm -rf $(OUT_DIR) csrc simv.daidir ucli.key DVEfiles novas.rc novas.conf verdiLog .vcs_lib_lock
