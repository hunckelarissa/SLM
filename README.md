# SLM — tiny neural networks

[Русский](README.md)

Two independent Ruby experiments on what happens when a network is
deliberately tiny and connectivity shape is the main object of study.
Neither aims at production or language models: both look at rhythm, memory,
delay, and behaviour that a graph of a few dozen neurons can already carry.

| | [sm_lab](sm_lab/) | [snail_networks](snail_networks/) |
|---|---|---|
| Idea | Digital organism: excitation, fatigue, rest | “Snail”: topology as the subject of dynamics and learning |
| Learning inside the net | None | Evolution, SGD, BPTT |
| Neuron | Activation, fatigue, threshold, homeostasis | `tanh` / `sigmoid` / `linear`, synapses and biases |
| Forms | 10 architectures | 12 topologies |
| Ruby | 3.4+ | 3.0+ (verified on 3.4) |
| Tests | minitest | RSpec |
| Details | [README](sm_lab/README.md), [tutorial](sm_lab/УЧЕБНИК.md) (RU) | [README](snail_networks/README.md), [tutorial](snail_networks/docs/uchebnik.md) (RU) |

## Shared premise

A usual network is layers plus gradient. Here the bet is different:

- the net is tiny on purpose (about 8–20 neurons, far under 10 000 parameters);
- topology is not hidden behind layers — rings, spirals, cubes, strips, gardens;
- time is discrete: a step reads previous activations, then all units update together;
- the question is not “how big a model to clear a benchmark”, but “what dynamics
  the graph shape already carries”.

The two subprojects answer that from different angles and are **independent**:
they share only this repository and an interest in tiny nets.

## sm_lab — organisms without learning

> “We are not building AI. We grow digital organisms on a floppy disk.”

A neuron is a short organism. It excites, tires, and slowly returns to rest.
Weights may inhibit. Complex behaviour comes from topology, fatigue, and an
external stimulus — with no gradients inside the network.

Already covered: gait, phototaxis, echo memory, a crawling bump, habituation,
and rhythm with an external readout.

```bash
cd sm_lab
bundle install
ruby examples/run_all.rb
ruby experiments/runner.rb --all
```

## snail_networks — connectivity shape and learnability

“Snails” compare how a ring, star, cube, or Möbius strip holds a pulse, learns
a delay, and separates sign tables. All forms share one tick; only edges and
weight-learning methods change.

```bash
cd snail_networks
bundle install
rake test
rake examples
rake run_all
```

## Which to open

- Need a **living cycle without learning** — rhythm, inhibition, fatigue, taxis —
  use `sm_lab`.
- Need to **compare topologies under training** — delay, echo, XOR, pulse routes —
  use `snail_networks`.

`snail_networks` is MIT (`snail_networks/LICENSE`). `sm_lab` has no license file
in its directory yet; clarify before publishing.
