# Hardware Verification Results

This file records the main verification outputs used in the Part 7 report.
The commands for running the tests are listed in the hardware README.

## Directed RTL tests

RTL lint completed without errors. The self-checking testbench passed all
directed cases:

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

## Full Pyflate trace

`scripts/generate_real_trace.py` records the six Huffman tables, the remaining
compressed bytes, and the symbols decoded by the original Python benchmark.
It also records the four unread bits already held by `RBitfield` at the
software-to-hardware handoff.

The generated trace was then replayed through the complete top-level RTL:

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

All 148,271 decoded symbols and their consumed code lengths matched the Python
reference.

## Cycle estimate

`scripts/analyze_workload.py` uses the code lengths from the same input to
count the cycles required by the iterative RTL decoder.

```text
decoded symbols: 148271
average length checks per symbol: 2.361217
length-check cycles: 350100
modeled RTL cycles: 646642
compute time at 100 MHz: 6.466420 ms
compute time at 200 MHz: 3.233210 ms
BZip2 table/selector groups: [(6, 2966)]
```

The model includes request acceptance, length checks, and the output handshake.
The 6.47 ms result is an RTL compute estimate and does not include driver or
data-transfer overhead.

## Logical synthesis

A generic Yosys synthesis run inferred seven memories for the Huffman tables:

```text
7 memories
20292 memory bits
```

The tables therefore require 20,292 logical memory bits. The separate 64-bit
input reservoir is implemented as register state. These are logical synthesis
results, not physical area or timing measurements.
