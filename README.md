# RCEI: headlight data and MATLAB demo

Data and MATLAB code accompanying *Self-referenced optical carrier enables
joint static and dynamic event imaging*.

This repository contains two headlight event recordings and a MATLAB example
for carrier-frequency estimation and phase folding. The example reproduces
the frequency cross-check in the paper and provides the recordings used for
the headlight cycle analyses.

## Quick start

MATLAB R2021b or later is required. No additional toolboxes are needed.

Download the repository using **Code > Download ZIP** and extract it, or clone
it with Git. Keep the folder structure intact. In MATLAB, open the repository
folder and run:

```matlab
run_demo
```

The program creates `results/` and writes three PNG figures, two MAT result
files, `summary.csv` and `validation.csv`. It checks the results against
`expected/expected_values.csv`; a successful run reports `13/13 numerical
checks passed`. Reference figures and a numerical summary are in `expected/`.

| Recording | Full-field frequency | Hand corridor excluded | Complete cycles |
|---|---:|---:|---:|
| Waving hand | 11.045 Hz | 11.052 Hz | 39 |
| No hand | 10.990 Hz | not used | 58 |

The analysis uses both event polarities, 1-ms event-rate bins, an 8–14 Hz
frequency search band and 16 phase bins. The phase coordinate is
`mod((t - t_first) * f, 1)`, with frequency estimated separately for each
recording. The 64-bin plot includes all recorded events; its dashed line
marks the minimum after circular three-bin smoothing.

## Example output

![Carrier-frequency estimation and phase folding for the waving-hand recording](expected/reference_figures/headlight_dynamic_carrier_phase.png)

## Data and files

Both sequences were acquired with a Prophesee EVK4 camera (1280 × 720 pixels,
16-mm lens) viewing a parked vehicle under headlight glare. A 3-arcmin wedge
prism produced the reciprocal optical carrier.

| Folder | Contents | Events | Duration |
|---|---|---:|---:|
| `data/headlight_dynamic/` | Waving-hand recording, four MAT parts | 13,256,812 | 3.5997 s |
| `data/headlight_static/` | No-hand recording, three MAT parts | 8,736,357 | 5.3320 s |
| `data/annotations/` | Manual palm-centre annotations | — | — |
| `src/` | Loading, analysis, plotting and numerical checks | — | — |
| `core/` | Executable frequency and phase functions | — | — |
| `expected/` | Expected values and reference figures | — | — |

Keep all four dynamic parts and all three static parts. Each MAT file contains:

| Variable | Meaning |
|---|---|
| `x`, `y` | Zero-based pixel coordinates, `uint16` |
| `p` | Polarity: 1 ON, 0 OFF, `uint8` |
| `t_us` | Microseconds from the first retained event, `uint32` |
| `meta` | Recording description, part index and total event count |

`data/annotations/palm_center_manual.csv` contains 21 palm positions at
0.18-s intervals. The frequency cross-check excludes the union of ellipses
with semiaxes 82 and 86 pixels around these positions, plus a 20-pixel image
border. The annotations are used for this cross-check only.

The events were decoded from EVT 3.0 RAW recordings. For the dynamic
recording, 142 decoded events preceding the retained start time were excluded.
Coordinates, polarity and timestamps of the retained events are preserved;
timestamps are rebased to the first retained event. Checksums for the seven
data parts and the annotation file are listed in `data/SHA256SUMS.txt`.

Original recording checksums:

```text
3453c4876ad929fe85648251b1b0d18cd435e5d7770ffdb697b6d956cc0e9b41  output01.raw
e0dd550d9fb8084869a0ecc1b509ba46e0d30687764464e8befd75df337b64c0  recording_2026-05-20_21-08-57.raw
```

## Implementation

`run_demo.m` and `src/` provide the loader, analysis, plotting and numerical
checks as MATLAB source. The two estimators in `core/` are executable P-files
generated with MATLAB R2021b. Their interfaces are:

```matlab
[fHz, info] = rcei_carrier_frequency(t_s, 'Band', [8 14], 'BinWidth', 1e-3)
[phase, cycleIdx, binIdx, info] = rcei_carrier_phase(t_s, fHz, 'NumBins', 16)
```

The frequency estimator also accepts `'EventMask', mask` to select events.
Cycle indices are one-based; events outside complete cycles have index zero.
Phase is expressed in cycles, in `[0, 1)`. The example implements the
fixed-frequency phase folding used for the headlight cycle analyses.

## Updates and maintenance

We will continue to organize supporting research materials for public release
and maintain this repository. Further updates will be made available here as
the materials are prepared.

## Citation and license

Please cite the manuscript title and this repository until the paper's
publication details are available.

See [LICENSE](LICENSE): data are distributed under CC BY 4.0, source files
under the MIT License, and the P-files under the demo-use terms stated there.
