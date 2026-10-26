# RCEI headlight demonstration

Data and MATLAB code accompanying *Self-referenced optical carrier enables
joint static and dynamic event imaging*.

The example estimates carrier frequency from the event-rate spectrum and
folds the two headlight recordings into carrier cycles. It reproduces the
headlight frequency cross-check in the paper and supplies the data used for
the cycle-level analyses.

## Run

MATLAB R2021b or later is required. No additional toolboxes are needed.
From the repository folder, run:

    run_demo

The program writes three PNG figures, two MAT result files, summary.csv
and validation.csv to results/. It checks the computed values against
expected/expected_values.csv and reports any mismatch. Reference figures
and a numerical summary are in expected/.

| Recording | Full-field frequency | Hand region excluded | Complete cycles |
|---|---:|---:|---:|
| Waving hand | 11.045 Hz | 11.052 Hz | 39 |
| No hand | 10.990 Hz | not used | 58 |

The analysis uses both event polarities, a 1-ms event-rate trace, an 8-14 Hz
frequency search band and 16 phase bins. The phase coordinate is
mod((t - t_first) * f, 1), with the frequency estimated separately for each
recording. This is the fixed-frequency phase folding used in the headlight
analyses; it does not apply the per-cycle reversal anchors described elsewhere
in the paper. The 64-bin plot includes all recorded events, and its dashed
line marks the minimum after circular three-bin smoothing.

## Data and files

Both sequences were acquired with a Prophesee EVK4 camera (1280 × 720 pixels,
16-mm lens) viewing a parked vehicle under headlight glare. A 3-arcmin wedge
prism produced the reciprocal optical carrier.

| Folder | Events | Duration |
|---|---:|---:|
| data/headlight_dynamic | 13,256,812 | 3.5997 s |
| data/headlight_static | 8,736,357 | 5.3320 s |

Keep all four dynamic parts and all three static parts. Each MAT file contains:

| Variable | Meaning |
|---|---|
| x, y | Zero-based pixel coordinates, uint16 |
| p | Polarity: 1 ON, 0 OFF, uint8 |
| t_us | Microseconds from the first retained event, uint32 |
| meta | Recording description, part index and total event count |

data/annotations/palm_center_manual.csv contains 21 palm positions at
0.18-s intervals. The frequency cross-check excludes the union of ellipses
with semiaxes 82 and 86 pixels around these positions, plus a 20-pixel image
border. The annotations are used for this cross-check only.

The events were decoded from EVT 3.0 RAW recordings. For the dynamic
recording, 142 decoded events preceding the retained start time were excluded.
Coordinates, polarity and timestamps of the retained events are preserved;
timestamps are rebased to the first retained event. Packaged data checksums
are listed in data/SHA256SUMS.txt.

Original recording checksums:

    3453c4876ad929fe85648251b1b0d18cd435e5d7770ffdb697b6d956cc0e9b41  output01.raw
    e0dd550d9fb8084869a0ecc1b509ba46e0d30687764464e8befd75df337b64c0  recording_2026-05-20_21-08-57.raw

## Implementation

run_demo.m and src/ contain the loader, analysis, plotting and numerical
checks as MATLAB source. The two estimators in core/ are executable P-files
generated with MATLAB R2021b. Their interfaces are:

    [fHz, info] = rcei_carrier_frequency(t_s, 'Band', [8 14], 'BinWidth', 1e-3)
    [phase, cycleIdx, binIdx, info] = rcei_carrier_phase(t_s, fHz, 'NumBins', 16)

The frequency estimator also accepts 'EventMask', mask to select events.
Cycle indices are one-based; events outside complete cycles have index zero.
Phase is expressed in cycles, in [0, 1).

The supplied example covers frequency estimation and phase folding. Further
research materials will be organized for release, and the repository will be
maintained.

## Citation, license and contact

Please cite the manuscript title and this repository until the paper's
publication details are available.

See LICENSE: data are distributed under CC BY 4.0, source files under the
MIT License, and the P-files under the demo-use terms stated there.

Banglei Guan, National University of Defense Technology  
guanbanglei12@nudt.edu.cn
