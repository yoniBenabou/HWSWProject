#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hardware_dir="$(cd "$script_dir/.." && pwd)"
build_dir="$hardware_dir/build"
trace_dir="$build_dir/real_trace"

mkdir -p "$trace_dir"
python3 "$script_dir/generate_real_trace.py" "$trace_dir"

rtl_files=(
  "$hardware_dir/rtl/bit_buffer.sv"
  "$hardware_dir/rtl/huffman_decoder.sv"
  "$hardware_dir/rtl/pyflate_huffman_accelerator.sv"
)
testbench="$hardware_dir/tb/pyflate_real_trace_tb.sv"

if command -v iverilog >/dev/null 2>&1; then
  iverilog -g2012 \
    -s pyflate_real_trace_tb \
    -o "$build_dir/pyflate_real_trace_tb.vvp" \
    "${rtl_files[@]}" "$testbench"
  vvp "$build_dir/pyflate_real_trace_tb.vvp" "+TRACE_DIR=$trace_dir"
elif command -v verilator >/dev/null 2>&1; then
  verilator --binary --timing -Wno-fatal \
    -CFLAGS "-std=c++20 -fcoroutines" \
    --top-module pyflate_real_trace_tb \
    --Mdir "$build_dir/verilator-real-trace" \
    "${rtl_files[@]}" "$testbench"
  "$build_dir/verilator-real-trace/Vpyflate_real_trace_tb" \
    "+TRACE_DIR=$trace_dir"
else
  echo "Install Icarus Verilog or Verilator to run the real-trace test." >&2
  exit 1
fi
