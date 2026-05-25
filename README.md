# UVM I2C Verification

## 프로젝트 개요

I2C Master/Slave loopback DUT를 UVM 기반으로 검증한 프로젝트입니다.
SDA/SCL 신호의 start, data, ACK 흐름을 driver/monitor/scoreboard 구조로 확인합니다.

## 목표 동작

- I2C transaction을 sequence item으로 정의합니다.
- Smoke sequence로 기본 write/read 흐름을 검증합니다.
- Driver가 Master 제어 입력을 구동합니다.
- Monitor가 I2C 결과를 수집합니다.
- Scoreboard에서 송신 데이터와 수신 데이터를 비교합니다.

## 기술 스택

| 구분 | 내용 |
| --- | --- |
| 핵심 개념 | UVM, I2C, SDA/SCL, start/stop condition, ACK, driver, monitor, scoreboard |
| 검증 대상 | I2C Master/Slave loopback |
| 사용 언어 | SystemVerilog |
| 사용 도구 | UVM 1.2 기반 simulator, Verdi/파형 디버깅 환경 |

## 시스템 구조

```text
i2c_tb_top
├─ i2c_dut_wrapper
├─ i2c_if
└─ i2c_env
   ├─ i2c_agent
   │  ├─ i2c_sequencer
   │  ├─ i2c_driver
   │  └─ i2c_monitor
   └─ i2c_scoreboard

i2c_smoke_test
└─ i2c_smoke_sequence
```

- `i2c_seq_item`: I2C 검증 transaction을 정의합니다.
- `i2c_smoke_sequence`: 기본 전송 시나리오를 생성합니다.
- `i2c_driver`: DUT 제어 입력을 구동합니다.
- `i2c_monitor`: DUT 출력과 수신 결과를 관찰합니다.
- `i2c_scoreboard`: expected data와 observed data를 비교합니다.
- `i2c_env`: UVM agent와 scoreboard를 묶은 검증 환경입니다.

## 검증 방식

- 기본 smoke test로 I2C Master/Slave loopback 동작을 확인합니다.
- Monitor와 scoreboard를 통해 transaction level에서 결과를 비교합니다.
