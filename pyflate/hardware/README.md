# Pyflate Huffman Hardware Accelerator

This directory contains the SystemVerilog implementation and tests for the
Pyflate accelerator. The hardware replaces the repeated Huffman symbol lookup
in the BZip2 decoder. The rest of the decompression pipeline remains in
software.

The design is split into three RTL modules:

- `bit_buffer.sv` stores incoming compressed bytes and exposes the next bits to
  the decoder.
- `huffman_decoder.sv` stores up to six Huffman tables and checks one possible
  code length per clock cycle.
- `pyflate_huffman_accelerator.sv` connects the two blocks and provides the
  external configuration and streaming interface.

## Directory structure

| Path | Contents |
| --- | --- |
| `rtl/` | Synthesizable accelerator modules |
| `tb/pyflate_huffman_accelerator_tb.sv` | Directed self-checking testbench |
| `tb/pyflate_real_trace_tb.sv` | Differential testbench using a real Pyflate trace |
| `scripts/run_simulation.sh` | Builds and runs the directed tests with Icarus Verilog |
| `scripts/run_real_trace.sh` | Generates the real trace and runs the differential test |
| `scripts/analyze_workload.py` | Counts symbols and models cycles for the iterative decoder |
| `scripts/profile_hotspot.py` | Runs Pyflate directly for profiling with `cProfile` |
| `verification_results.md` | Full recorded verification and synthesis results |

## Requirements

- Python 3
- Icarus Verilog (`iverilog` and `vvp`) for the directed test
- Icarus Verilog or Verilator for the real-input test

The scripts use paths relative to this directory, so they can be run from any
working directory. The commands below assume that the current directory is
`pyflate/hardware`.

## Running the tests

Run the directed testbench:

```bash
bash ./scripts/run_simulation.sh
```

A successful run ends with:

```text
ALL TESTS PASSED
```

Run the differential test on the benchmark input:

```bash
bash ./scripts/run_real_trace.sh
```

This script extracts the Huffman tables and expected decoded symbols from the
Python implementation, feeds the same input to the RTL, and compares every
symbol and consumed code length. A successful run ends with:

```text
REAL TRACE PASSED: 148271/148271 symbols matched Python
```

To reproduce the workload-based cycle count:

```bash
python3 ./scripts/analyze_workload.py
```

Generated simulation files are written under `build/` and are ignored by Git.

## Design and interface summary

Pyflate constructs new canonical Huffman tables for each BZip2 block. Software
loads these tables into the accelerator and selects the required table while
decoding. Compressed bytes enter through a ready/valid interface, and each
decode request returns a symbol together with the number of bits consumed.

Header parsing can finish in the middle of a byte. The `seed_data` and
`seed_count` inputs preserve these unread bits before the remaining compressed
bytes are streamed into the buffer. The supplied benchmark reaches this
handoff with four unread bits, and the real-trace test covers that case.

The top-level interface has five main parts:

| Interface group | Purpose |
| --- | --- |
| `cfg_*` | Clear, select, and load the six Huffman table banks |
| `seed_*` | Load residual bits left by software header parsing |
| `byte_*` | Stream compressed input bytes into the bit buffer |
| `decode_*` | Select a table and request the next symbol |
| `symbol_*` | Return the decoded symbol and consumed bit count |

All data paths use ready/valid handshakes. The submitted RTL provides this
low-level interface but does not include a processor-specific AXI, DMA, or MMIO
wrapper. In a complete system, input bytes and output symbols should be moved
in batches; one MMIO transaction or interrupt per symbol would add too much
overhead.

## Current verification status

- The directed testbench passes all functional cases.
- The real-input test matches all 148,271 Python reference symbols and code
  lengths.
- Workload analysis gives 646,642 modeled RTL cycles for the supplied input,
  or about 6.47 ms at the proposed 100 MHz clock before communication overhead.
- Generic Yosys synthesis infers seven memories with 20,292 total storage bits.

The cycle count and 100 MHz clock are estimates, not end-to-end hardware
measurements. Physical area, timing, and power require a specific FPGA or ASIC
target and a complete implementation flow.

For the design decisions, performance calculation, hardware/software split,
and limitations, see [`../report_hardware_accelerator.md`](../report_hardware_accelerator.md).
For the full test output and synthesis notes, see
[`verification_results.md`](verification_results.md).
