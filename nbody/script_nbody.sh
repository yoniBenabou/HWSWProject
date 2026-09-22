#!/bin/bash
# script_nbody.sh
# Environment setup, benchmark execution, flame graph generation,
# and before/after performance comparison for the Nbody benchmark.

set -e

# --- 1. Environment setup and dependency installation ---
apt install -y python3-dbg python3-pip
pip3 install pyperformance

# FlameGraph tools (used to generate the .svg from perf data)
if [ ! -d /tmp/FlameGraph ]; then
    git clone --depth 1 https://github.com/brendangregg/FlameGraph.git /tmp/FlameGraph
fi

# --- 2. Baseline benchmark execution ---
python3 source/nbody_baseline.py --rigorous -o results/baseline.json

# --- 3. Flame graph generation ---
# Default hardware 'cycles' event does not work inside this VM (KVM does
# not expose PMU counters to the guest), so task-clock is used instead.
export PYPERF_PERF_RECORD_DATA_DIR=/dev/shm
export PYPERF_PERF_RECORD_EXTRA_OPTS="-e task-clock -g"
rm -f /dev/shm/perf.data.*
python3 source/nbody_baseline.py --hook perf_record -o /tmp/nbody_hook_tmp.json

cd /dev/shm
> nbody_combined.script
for f in perf.data.*; do
    perf script -i "$f" >> nbody_combined.script 2>/dev/null
done
/tmp/FlameGraph/stackcollapse-perf.pl nbody_combined.script > nbody_combined.folded
/tmp/FlameGraph/flamegraph.pl nbody_combined.folded > nbody_flamegraph.svg
cd -
cp /dev/shm/nbody_flamegraph.svg profiling/flamegraph.svg

# --- 4. Post-optimization benchmark execution and comparison ---
python3 source/nbody_optimized.py --rigorous -o results/optimized.json
python3 -m pyperf compare_to results/baseline.json results/optimized.json --table
