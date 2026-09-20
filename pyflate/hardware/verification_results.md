# Verification Results

## Functional RTL verification

Verilator 5.49 lint completed without warnings or errors. The self-checking
simulation passed all cases:

```text
PASS symbol: value=65 len=1
PASS symbol: value=66 len=2
PASS symbol: value=67 len=3
PASS symbol: value=68 len=3
PASS table-bank selection
PASS byte-boundary bit count
PASS underflow stall
PASS refill decode
PASS symbol: value=89 len=1
PASS invalid-code handling
PASS invalid-table handling
ALL TESTS PASSED
```

## Full real-input differential test

`scripts/generate_real_trace.py` captures the six Huffman tables, the exact
software-to-hardware handoff state, remaining compressed bytes, and expected
symbol/length pairs from the unchanged Python benchmark. The handoff occurs
with four unread bits (`1110`) already present in `RBitfield`; these are loaded
through the RTL seed interface before subsequent bytes are streamed.

`pyflate_real_trace_tb.sv` then drives the generated data through the complete
top-level accelerator. Verilator reported:

```text
Starting real trace: 148271 symbols, 66456 bytes, 4 seed bits
Checked 25000/148271 symbols
Checked 50000/148271 symbols
Checked 75000/148271 symbols
Checked 100000/148271 symbols
Checked 125000/148271 symbols
REAL TRACE PASSED: 148271/148271 symbols matched Python
Observed 0 decoder cycles waiting for input
```

This is a differential functional result: every decoded symbol and consumed
code length matched the Python reference. It is stronger than the cycle model,
but it still does not represent physical hardware timing or DMA/driver cost.

## Workload-derived cycle model

`scripts/analyze_workload.py` instruments the unchanged Python decoder on the
repository's `interpreter.tar.bz2` input. It does not time individual Python
calls; it records the actual decoded code lengths and computes the exact number
of length checks performed by the current iterative RTL architecture.

```text
decoded symbols: 148271
average length checks per symbol: 2.361217
length-check cycles: 350100
modeled RTL cycles: 646642
compute time at 100 MHz: 6.466420 ms
compute time at 200 MHz: 3.233210 ms
BZip2 table/selector groups: [(6, 2966)]
```

The model includes one request-acceptance cycle and one output-handshake cycle
per symbol. It excludes DMA, driver, FIFO, table-configuration, and arbitration
overheads, so 6.47 ms is a datapath/control estimate rather than an end-to-end
measurement.

## Profiling reproducibility check

Running three decompressions with `scripts/profile_hotspot.py` produced
444,813 calls to `find_next_symbol`. On the current local runtime, its
cumulative time was 1.383 s out of 3.223 s in `bench_pyflake`, or 42.9%. An
earlier local run measured 40.6%; the lower figure is retained for conservative
Amdahl-law estimates. The final report must use or confirm these values in the
course QEMU environment, since profiler overhead and runtime environment affect
the ratio.

## Generic synthesis check

Yosys 0.69 successfully elaborated and processed the top-level RTL. After the
configuration arrays were separated into a synchronous, non-reset write
process, Yosys inferred seven logical memories:

```text
7 memories
20292 memory bits
```

This confirms 20,292 bits (about 20.3 kbit) of table storage and that the tables
are memory-inferable. The separate 64-bit input reservoir is implemented as
register state. This is not a physical area, maximum-frequency, or power result.
Those require a selected FPGA/ASIC technology, technology mapping, placement
and routing, static timing analysis, and an activity-based power flow.
