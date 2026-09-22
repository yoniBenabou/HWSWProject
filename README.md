# HW/SW Co-design Project — Nbody & Pyflate

This is our project for course 00460882, benchmark optimization + hardware
accelerator proposal.

## What we picked

We went with **Nbody** (gravity simulation, 5 bodies) and **Pyflate** (a
BZip2 decompressor written entirely in Python).

## What's in here

- nbody/
  - source/
    - nbody_baseline.py       (original benchmark)
    - nbody_optimized.py      (our optimized version)
  - results/                  (pyperf json outputs, baseline vs optimized)
  - profiling/                (flame graph svg + cprofile output)
  - report_nbody.txt          (overview, analysis, optimization, results)
  - script_nbody.sh           (runs everything: setup, profiling, comparison)

- pyflate/
  - source/
    - pyflate_baseline.py
    - pyflate_optimized.py
    - data/interpreter.tar.bz2   (the file the benchmark decompresses)
  - results/
  - profiling/
  - report_pyflate.txt
  - script_pyflate.sh
  - hardware/                 (the hardware accelerator, verilog)
  - report_hardware_accelerator.pdf

- prompt.txt                  (AI prompts used during the project)

## Results

| Benchmark | Before | After | Gain |
|---|---|---|---|
| Nbody | 229 ms | 210 ms | +9% |
| Pyflate | 1.12 sec | 1.05 sec | +7% |

Both are above the 7% target from the assignment.

## How to run it

Each benchmark has one script that does the whole thing (setup, baseline,
flame graph, optimized run, comparison):

```bash
cd nbody
bash script_nbody.sh
```

```bash
cd pyflate
bash script_pyflate.sh
```

We ran everything on the course's Ubuntu VM image (jammy-server-cloudimg) / Python 3.10, inside QEMU. One thing
worth knowing: the default perf event (cycles) just doesn't work inside this
VM, KVM doesn't expose the hardware counters to the guest. So, the scripts use
task-clock instead.
