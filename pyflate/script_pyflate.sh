#!/bin/bash
# script_pyflate.sh
# Environment setup, benchmark execution, flame graph generation,
# and before/after performance comparison for the Pyflate benchmark.

set -e

# --- 1. Environment setup and dependency installation ---
apt install -y python3-dbg python3-pip
pip3 install pyperformance

# FlameGraph tools (used to generate the .svg from perf data)
if [ ! -d /tmp/FlameGraph ]; then
    git clone --depth 1 https://github.com/brendangregg/FlameGraph.git /tmp/FlameGraph
fi

# --- 2. Baseline benchmark execution ---
cd source
python3 pyflate_baseline.py --rigorous -o ../results/baseline.json

# --- 3. Flame graph generation ---
# Default hardware 'cycles' event does not work inside this VM (KVM does
# not expose PMU counters to the guest), so task-clock is used instead.
export PYPERF_PERF_RECORD_DATA_DIR=/dev/shm
export PYPERF_PERF_RECORD_EXTRA_OPTS="-e task-clock -g"
rm -f /dev/shm/perf.data.*
python3 pyflate_baseline.py --hook perf_record -o /tmp/pyflate_hook_tmp.json

cd /dev/shm
> pyflate_combined.script
for f in perf.data.*; do
    perf script -i "$f" >> pyflate_combined.script 2>/dev/null
done
/tmp/FlameGraph/stackcollapse-perf.pl pyflate_combined.script > pyflate_combined.folded
/tmp/FlameGraph/flamegraph.pl pyflate_combined.folded > pyflate_flamegraph.svg
cd -
cp /dev/shm/pyflate_flamegraph.svg ../profiling/flamegraph.svg

# --- 4. Post-optimization benchmark execution and comparison ---
python3 pyflate_optimized.py --rigorous -o ../results/optimized.json
python3 -m pyperf compare_to ../results/baseline.json ../results/optimized.json --table
