#!/usr/bin/env python3
"""Measure the real Pyflate Huffman workload and model RTL decode cycles."""

import collections
import importlib.util
import pathlib
import sys
import time
import types


HARDWARE_DIR = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = HARDWARE_DIR.parent / "source" / "pyflate_baseline.py"
INPUT_FILE = HARDWARE_DIR.parent / "source" / "data" / "interpreter.tar.bz2"


def main():
    # Importing the benchmark only needs perf_counter; the pyperf runner is not
    # used by this analysis script.
    sys.modules["pyperf"] = types.SimpleNamespace(perf_counter=time.perf_counter)
    spec = importlib.util.spec_from_file_location("pyflate_baseline", SOURCE_FILE)
    benchmark = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(benchmark)

    code_lengths = collections.Counter()
    check_counts = collections.Counter()
    selector_groups = []
    original_find = benchmark.HuffmanTable.find_next_symbol
    original_selectors = benchmark.compute_selectors_list

    def measured_find(table, field, reversed=True):
        code = original_find(table, field, reversed)
        entry = next(item for item in table.table if item.code == code)
        code_lengths[entry.bits] += 1
        check_counts[entry.bits - table.min_bits + 1] += 1
        return code

    def measured_selectors(field, group_count):
        selectors = original_selectors(field, group_count)
        selector_groups.append((group_count, len(selectors)))
        return selectors

    benchmark.HuffmanTable.find_next_symbol = measured_find
    benchmark.compute_selectors_list = measured_selectors
    benchmark.bench_pyflake(1, str(INPUT_FILE))

    symbols = sum(code_lengths.values())
    length_checks = sum(count * checks for checks, count in check_counts.items())
    # Current FSM: request acceptance + length checks + output handshake.
    rtl_cycles = symbols + length_checks + symbols

    print(f"decoded symbols: {symbols}")
    print(f"code-length distribution: {dict(sorted(code_lengths.items()))}")
    print(f"check-cycle distribution: {dict(sorted(check_counts.items()))}")
    print(f"average length checks per symbol: {length_checks / symbols:.6f}")
    print(f"length-check cycles: {length_checks}")
    print(f"modeled RTL cycles: {rtl_cycles}")
    print(f"compute time at 100 MHz: {rtl_cycles / 100_000:.6f} ms")
    print(f"compute time at 200 MHz: {rtl_cycles / 200_000:.6f} ms")
    print(f"BZip2 table/selector groups: {selector_groups}")


if __name__ == "__main__":
    main()

