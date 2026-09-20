#!/usr/bin/env python3
"""Run Pyflate directly so cProfile measures the benchmark body, not pyperf."""

import importlib.util
import pathlib
import sys
import time
import types


HARDWARE_DIR = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = HARDWARE_DIR.parent / "source" / "pyflate_baseline.py"
INPUT_FILE = HARDWARE_DIR.parent / "source" / "data" / "interpreter.tar.bz2"


def main():
    loops = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    try:
        import pyperf  # noqa: F401
    except ImportError:
        sys.modules["pyperf"] = types.SimpleNamespace(perf_counter=time.perf_counter)

    spec = importlib.util.spec_from_file_location("pyflate_baseline", SOURCE_FILE)
    benchmark = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(benchmark)
    benchmark.bench_pyflake(loops, str(INPUT_FILE))


if __name__ == "__main__":
    main()
