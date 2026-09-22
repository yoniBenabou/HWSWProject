#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hardware_dir="$(cd "$script_dir/.." && pwd)"
build_dir="$hardware_dir/build"

mkdir -p "$build_dir"

iverilog -g2012 \
  -s pyflate_huffman_accelerator_tb \
  -o "$build_dir/pyflate_huffman_tb.vvp" \
  "$hardware_dir/rtl/bit_buffer.sv" \
  "$hardware_dir/rtl/huffman_decoder.sv" \
  "$hardware_dir/rtl/pyflate_huffman_accelerator.sv" \
  "$hardware_dir/tb/pyflate_huffman_accelerator_tb.sv"

cd "$build_dir"
vvp ./pyflate_huffman_tb.vvp
