#!/usr/bin/env python3
"""Generate RTL vectors from the real Pyflate BZip2 decode."""

import argparse
import importlib.util
import pathlib
import sys
import time
import types


HARDWARE_DIR = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = HARDWARE_DIR.parent / "source" / "pyflate_baseline.py"
INPUT_FILE = HARDWARE_DIR.parent / "source" / "data" / "interpreter.tar.bz2"
MAX_BITS = 20
MAX_SYMBOLS = 258
NUM_TABLES = 6


def write_hex(path, values, width):
    digits = (width + 3) // 4
    path.write_text("".join(f"{value:0{digits}x}\n" for value in values))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output_dir", type=pathlib.Path)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    sys.modules["pyperf"] = types.SimpleNamespace(perf_counter=time.perf_counter)
    spec = importlib.util.spec_from_file_location("pyflate_baseline", SOURCE_FILE)
    benchmark = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(benchmark)

    handoff = {}
    expected = []
    original_compute_tables = benchmark.compute_tables
    original_find = benchmark.HuffmanTable.find_next_symbol

    def capture_tables(field, group_count, symbols_in_use):
        if handoff:
            raise RuntimeError("trace format currently expects one BZip2 block")
        tables = original_compute_tables(field, group_count, symbols_in_use)
        handoff.update(
            residual_count=field.bits,
            residual_bits=field.bitfield,
            file_position=field.f.tell(),
            tables=tables,
            symbols_in_use=symbols_in_use,
        )
        return tables

    def capture_symbol(table, field, reversed=True):
        code = original_find(table, field, reversed)
        entry = next(item for item in table.table if item.code == code)
        table_id = next(
            index for index, candidate in enumerate(handoff["tables"])
            if candidate is table
        )
        expected.append((table_id, code, entry.bits))
        return code

    benchmark.compute_tables = capture_tables
    benchmark.HuffmanTable.find_next_symbol = capture_symbol
    benchmark.bench_pyflake(1, str(INPUT_FILE))

    tables = handoff["tables"]
    if len(tables) != NUM_TABLES:
        raise RuntimeError(f"expected {NUM_TABLES} tables, found {len(tables)}")
    residual_count = handoff["residual_count"]
    residual_mask = (1 << residual_count) - 1 if residual_count else 0
    seed_data = (handoff["residual_bits"] & residual_mask) << (64 - residual_count)
    compressed = INPUT_FILE.read_bytes()[handoff["file_position"]:]

    bounds = []
    length_records = []
    symbol_records = []
    for table in tables:
        bounds.append((table.min_bits << 5) | table.max_bits)
        by_length = {length: [] for length in range(MAX_BITS + 1)}
        for entry in table.table:
            by_length[entry.bits].append(entry)
        for length in range(MAX_BITS + 1):
            entries = by_length[length]
            if not entries:
                length_records.append(0)
                continue
            first_index = table.table.index(entries[0])
            record = (
                (1 << 49)
                | (entries[0].symbol << 29)
                | (entries[-1].symbol << 9)
                | first_index
            )
            length_records.append(record)
        symbol_records.extend(entry.code for entry in table.table)
        symbol_records.extend([0] * (MAX_SYMBOLS - len(table.table)))

    expected_records = [
        (table_id << 14) | (symbol << 5) | length
        for table_id, symbol, length in expected
    ]
    metadata = [
        residual_count,
        seed_data,
        len(compressed),
        len(expected_records),
        handoff["symbols_in_use"],
        handoff["file_position"],
    ]

    write_hex(args.output_dir / "metadata.hex", metadata, 64)
    write_hex(args.output_dir / "bounds.hex", bounds, 10)
    write_hex(args.output_dir / "lengths.hex", length_records, 50)
    write_hex(args.output_dir / "symbols.hex", symbol_records, 9)
    write_hex(args.output_dir / "expected.hex", expected_records, 17)
    write_hex(args.output_dir / "stream_bytes.hex", compressed, 8)

    print(f"generated {len(expected_records)} expected symbols")
    print(f"generated {len(compressed)} remaining input bytes")
    print(f"seeded {residual_count} residual bits: 0x{seed_data:016x}")
    print(f"symbols per table: {handoff['symbols_in_use']}")


if __name__ == "__main__":
    main()
