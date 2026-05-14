# Belief System Dynamics - Australian Climate Attitudes
### A Monte Carlo Agent-Based Model using the Multidimensional Friedkin-Johnsen Framework

> Simulating how climate-related belief systems evolve across a socially networked Australian population using an Agent-based model, grounded in the Six Americas climate segmentation framework.

---

## Overview

This repository contains the MATLAB implementation of a multi-agent, multi-topic opinion dynamics model applied to Australian attitudes toward climate change. The model extends the classical DeGroot (1974) social influence framework via the multidimensional Friedkin-Johnsen model, incorporating:

- **Topic interdependence** via per-persona logic matrices (C)
- **Stubbornness** — resistance to opinion change, anchoring agents to initial beliefs
- **Small-world network topology** (Watts-Strogatz) governing social influence structure
- **Monte Carlo robustness checking** across 100 independent stochastic iterations

The six agent personas are drawn from the Six Americas Short Survey (SASSY) framework, with population proportions calibrated to a 2020 Australian national quota sample (n = 5,104).

---

## Repository Structure
```
.
├── main_simulation.m           # Main Monte Carlo simulation script (MATLAB)
├── WattsStrogatz.m             # Custom Watts-Strogatz network generator
├── preprocessing/
│   └── belief_systems_six_Australias.ipynb   # Data preprocessing (Python/Colab)
└── README.md
```

## Data Preprocessing

The `preprocessing/` folder contains a Google Colab notebook 
(`belief_systems_six_Australias.ipynb`) used to:

- Load and inspect the SASSY survey dataset (`.sav` format via `pyreadstat`)
- Compute persona proportions from the `SASSYSegment` variable
- Extract the modal survey response per persona per topic
- Generate Likert scale visualisations for each of the four topics 
  (Importance, Worry, Personal, Future) using `plot_likert`
- Export figures to Google Drive for use in the report

**Dependencies:**
- `pandas`
- `pyreadstat`
- `plot_likert`
- `matplotlib`

**Note:** The raw survey data (`data.sav`) is included in this repository. 
The dataset is openly available from the original study:

Neumann, C., Stanley, S. K., Leviston, Z., & Walker, I. (2022). 
The Six Australias: Concern About Climate Change (and Global Warming) is Rising. 
*Environmental Communication*, 16(4), 1–12. 
https://doi.org/10.1080/17524032.2022.2048407

## Model Description

### Agents and Simulation Parameters

| Parameter | Value |
|-----------|-------|
| Agents (n) | 120 |
| Topics (m) | 4 (Importance, Worry, Personal Relevance, Future Outlook) |
| Personas | 6 (Alarmed, Concerned, Cautious, Doubtful, Dismissive, Disengaged) |
| Time steps (T) | 100 |
| Monte Carlo runs | 100 |
| Network degree (k) | 6 |
| Rewiring probability (p) | 0.2 |
| Self-confidence weight (α) | 0.7 |

### Persona Proportions

| Persona | Agents | Population % |
|---------|--------|-------------|
| Concerned | 30 | 25% |
| Alarmed | 25 | 21% |
| Cautious | 20 | 17% |
| Doubtful | 15 | 13% |
| Dismissive | 10 | 8% |
| Disengaged | 20 | 17% |

### Opinion Update Rule

At each time step, agent *i* updates their opinion vector according to the multidimensional Friedkin-Johnsen model:

$$x_i(t+1) = \lambda_i \sum_{j=1}^{n} w_{ij} C_i x_j(t) + (1 - \lambda_i) x_i(0)$$

where:

- $x_i(t)$ — opinion vector of agent $i$ at time $t$
- $W = [w_{ij}]$ — row-stochastic interpersonal influence matrix
- $C_i$ — per-persona logic (constraint) matrix encoding topic interdependencies
- $\lambda_i$ — susceptibility to social influence ($1 - \lambda_i$ = stubbornness)
- $x_i(0)$ — initial opinion vector (anchor)

When $\lambda_i = 1$ for all agents, the model reduces to the multidimensional DeGroot model.

---

## Scenario Flags

The simulation supports three toggleable scenario flags at the top of Block 1. **These are the only parameters you need to change between runs:**

```matlab
use_block_tri     = false;   % enforce affective→cognitive block-triangular C structure
use_stubbornness  = true;    % anchor agents to initial opinions via lambda
use_weak_diagonal = false;   % halve diagonal entries of C to test diagonal dominance
```

The run label is auto-generated from these flags, e.g. `blocktri_on_stub_on_weakdiag_off`, and is used to name the export folder and figure titles automatically.

You must also update the matching scenario string parameters below the flags:

```matlab
C_scenario = 'normal';        % options: 'normal', 'weak_diagonal'
d_scenario = 'normal';        % options: 'normal', 'no_stubbornness'
```

### Sensitivity Analysis Scenarios

| `use_block_tri` | `use_stubbornness` | `use_weak_diagonal` | Purpose |
|---|---|---|---|
| on / off | on | off | Baseline — isolate C structure effect |
| on / off | on | on | Isolate diagonal dominance in C |
| on / off | off | off | Isolate stubbornness effect |
| on / off | off | on | Maximum sensitivity — both simultaneously |

---

## Parameter Summary

| Symbol | Meaning | How set |
|--------|---------|---------|
| $x_j(t)$ | Opinion vector at previous time step | — (state variable) |
| $w_{ij}$ | Interpersonal influence matrix | G |
| $x_i(0)$ | Initial opinion vector of agent $i$ | G |
| $C_i$ | Logic (constraint) matrix for agent $i$ | C |
| $\lambda_i$ | Stubbornness / susceptibility parameter | G |

*C = calibrated from survey data; G = informed guess, sampled from Beta distribution.*

### Initial Opinions X₀ — Beta Parameters

| Persona | Importance α/β | Worry α/β | Personal α/β | Future α/β |
|---------|---------------|-----------|--------------|-----------|
| Concerned | 6.0 / 2.0 | 5.0 / 2.5 | 5.0 / 3.0 | 6.0 / 2.0 |
| Alarmed | 9.0 / 1.5 | 9.0 / 1.5 | 6.0 / 2.0 | 9.0 / 1.5 |
| Cautious | 4.0 / 3.0 | 5.0 / 4.0 | 4.0 / 3.0 | 4.0 / 3.0 |
| Doubtful | 2.5 / 4.0 | 2.0 / 4.0 | 2.0 / 5.0 | 2.5 / 4.0 |
| Dismissive | 1.5 / 9.0 | 1.5 / 9.0 | 1.5 / 9.0 | 1.5 / 9.0 |
| Disengaged | 4.0 / 3.0 | 2.0 / 5.0 | 2.0 / 4.0 | 2.0 / 4.0 |

### Stubbornness λ — Beta Parameters

| Persona | α | β | Mean |
|---------|---|---|------|
| Concerned | 5.0 | 2.0 | 0.71 |
| Alarmed | 8.0 | 2.0 | 0.80 |
| Cautious | 4.0 | 2.5 | 0.62 |
| Doubtful | 2.0 | 4.0 | 0.33 |
| Dismissive | 9.0 | 2.0 | 0.82 |
| Disengaged | 2.0 | 5.0 | 0.29 |

---

## Requirements

- **MATLAB** R2021a or later
  - Uses: `exportgraphics`, `betarnd`, `graph`, `adjacency`
  - No external toolboxes required
- `WattsStrogatz.m` must be on the MATLAB path (included in this repository)

---

## Running the Simulation

1. Clone or download the repository
2. Open MATLAB and navigate to the repository folder
3. Set your desired scenario flags at the top of Block 1 in `main_simulation.m`
4. Run the script:

```matlab
run('main_simulation.m')
```

Figures are automatically exported as `.png` files to a labelled subfolder under `figures/`, created in the same directory as the script.

---

## Outputs

Each run produces three figures exported to the labelled scenario folder:

| Figure | Description |
|--------|-------------|
| `mc_averaged_persona_trajectories` | Opinion trajectories per persona averaged across all Monte Carlo runs, one subplot per topic |
| `topic_N_<topic>_trajectories` | Per-topic plot showing MC-averaged persona means (thick lines) alongside 5 randomly sampled individual agent trajectories (thin lines), on a log time axis |
| `final_opinion_by_persona_and_topic` | Grouped bar chart of mean final opinions at t=100 with ±1 SD error bars |

---

## Logic Matrix (C) Structure

Two C matrix structures are supported:

**Full (symmetric) C** — bidirectional influence between all topic pairs within each persona's belief system.

**Block-triangular C** — enforces a theoretically motivated one-way influence from the affective cluster (Importance, Worry) to the behavioural cluster (Personal Relevance, Future Outlook):

```
         Imp   Wor   Per   Fut
Imp   [   x     x     x     x  ]
Wor   [   x     x     x     x  ]
Per   [   0     0     x     x  ]
Fut   [   0     0     x     x  ]
```

The Dismissive persona additionally holds negative off-diagonal entries, reflecting motivated rejection of cross-topic consistency.

---

## References

- Converse, P. E. (1964). The nature of belief systems in mass publics. In D. Apter (Ed.), *Ideology and discontent*. Free Press.
- DeGroot, M. H. (1974). Reaching a consensus. *Journal of the American Statistical Association*, 69(345), 118–121.
- Friedkin, N. E., & Johnsen, E. C. (1990). Social influence and opinions. *Journal of Mathematical Sociology*, 15(3-4), 193–206.
- Friedkin, N. E., Proskurnikov, A. V., Tempo, R., & Parsegov, S. E. (2016). Network science on belief system dynamics under logic constraints. *Science*, 354(6310), 321–326.
- Watts, D. J., & Strogatz, S. H. (1998). Collective dynamics of small-world networks. *Nature*, 393, 440–442.
- Leiserowitz, A., et al. Six Americas of climate change. Yale Program on Climate Change Communication.

---

## Acknowledgements
Submitted as part of **Data Science Research Project B**, School of Mathematical Sciences, University of Adelaide.

---

## Licence
All rights reserved
