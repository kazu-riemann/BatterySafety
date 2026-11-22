# Battery Safety Verification Examples

This repository contains two small Lean 4 examples that demonstrate different ways of checking a battery state-of-charge (SoC) safety requirement:

- **`BattSafeProof`** proves a one-step safety invariant for a battery model defined in Lean.
- **`BattSafeCheck`** checks a single transition reported by an external system against a set of safety requirements at runtime.

The examples use the same simplified SoC range, but they address different verification questions.

## Contents

The Lean source files are organized as follows:

```text
BatterySafety/
└── BatterySafety/
    ├── BattSafeCheck.lean
    ├── BattSafeProof.lean
    └── Common.lean
```

| Source file | Executable | Purpose |
|---|---|---|
| `BattSafeProof.lean` | `battsafeproof` | Proves the one-step safety invariant and provides a command-line example that performs one proof-backed simulation step. Namely, theorem proving. |
| `BattSafeCheck.lean` | `battsafecheck` | Defines requirements for an externally reported transition and provides a command-line runtime checker. Namely, runtime verification. |
| `Common.lean` | - | Defines the shared safety condition used by both examples. |

The Lake configuration defines an executable for each example. Running `lake build` builds both executables.

## Requirements

- Lean 4, using the toolchain specified by `lean-toolchain`
- Lake
- Mathlib (used by `BattSafeProof`)

## Build

From the repository root, run:

```bash
lake exe cache get
lake build
```

This builds the targets declared in `lakefile.toml`, including the `battsafeproof` and `battsafecheck` executables.

## Shared specification

`Common.lean` defines the safety condition shared by `BattSafeProof` and `BattSafeCheck`. Both modules use this common definition rather than defining separate SoC safety conditions.

The safety condition is:

\[
0 < \mathrm{SoC} < 100
\]

It is represented by the predicate `IsSafe`. The use of `Rat` allows the examples to represent decimal SoC values exactly, rather than introducing floating-point rounding.

## 1. BattSafeProof: Theorem proving

`BattSafeProof` defines a simple battery model directly in Lean and uses the shared `IsSafe` predicate from `Common.lean`.

### Model

The battery state is represented by a rational-valued SoC:

```lean
structure BatteryState where
  soc : Rat
```

The controller and one-step state transition are defined as follows:

- If the SoC is at least `95`, the controller turns charging off.
- Otherwise, the controller turns charging on.
- Charging on increases the SoC by `5`.
- Charging off decreases the SoC by `2`.

### Main theorem

The central result is `battery_safety_invariant`:

```lean
theorem battery_safety_invariant (s : BatteryState) (h_safe : IsSafe s) :
    IsSafe (nextState s (controller s))
```

It states that, for the controller and transition model defined in this file, every safe state transitions to another safe state in one step.

The function `stepSimulationSecurely` uses this theorem internally. It requires a proof that the initial state is safe, computes the next state, and constructs a local proof that the next state is safe. Its return type is `BatteryState`; the proof of the next state's safety is not included in the returned value.

### Command-line example

The `battsafeproof` executable accepts an initial SoC value. It checks whether the initial state satisfies `IsSafe` and, if so, performs one step using `stepSimulationSecurely`.

Example:

```bash
lake exe battsafeproof 94.1
```

This command-line entry point is an example of using the proven model. The main verification result is the Lean theorem, not the output of the executable.

## 2. BattSafeCheck: Runtime verification

`BattSafeCheck` does not define an implementation of the controller or a battery state-transition model. Instead, it receives one transition reported by an external system and checks whether that transition satisfies the specified requirements.

It also uses the shared `IsSafe` predicate from `Common.lean`.

### External transition

An `ExternalStep` contains:

- `current`: the reported current battery state;
- `signal`: the reported control signal (`On` or `Off`);
- `next`: the reported next battery state.

The transition is accepted only if all three conditions hold:

1. The current state satisfies `IsSafe`.
2. The control signal satisfies `ControllerSafe`.
3. The next state satisfies `IsSafe`.

The controller-output requirement is:

\[
\mathrm{SoC} < 95 \;\lor\; \mathrm{signal} = \mathrm{Off}
\]

In other words, when the current SoC is at least `95`, the reported control signal must be `Off`.

When the three component conditions hold, the program combines their proofs into a proof of `TransitionSafe`. The function `acceptStep` takes that proof and returns the reported next state. The theorem `accepted_step_is_safe` establishes that the returned state satisfies `IsSafe`.

### Command-line interface

The `battsafecheck` executable expects three arguments in this order:

```text
<current_soc> <On|Off> <next_soc>
```

Examples:

```bash
lake exe battsafecheck 94 On 99
lake exe battsafecheck 99 Off 97
lake exe battsafecheck 96 On 101
```

The first two examples satisfy the specified conditions. The third fails because the control signal is `On` while the current SoC is at least `95`; the reported next SoC is also outside the safe range.

The parser accepts integer and decimal-form SoC arguments, such as `94` and `94.1`. Decimal digits are interpreted as a base-10 fractional part and converted to `Rat`.

## 3. How the two examples differ

| Aspect | `BattSafeProof` | `BattSafeCheck` |
|---|---|---|
| Verification target | A controller and transition model defined in Lean | One transition reported by an external system |
| Controller implementation | Defined in Lean | Not included |
| State-transition implementation | Defined in Lean | Not included |
| Main result | A theorem proving one-step safety preservation | A runtime decision about whether the supplied transition satisfies the requirements |
| Scope | All safe states under the defined model, for one step | The particular transition supplied as input |

These examples should not be interpreted as providing the same kind of guarantee.

`BattSafeProof` proves a mathematical property of the model encoded in the Lean file. The result depends on the correctness and adequacy of that model.

`BattSafeCheck` checks the supplied values against the stated conditions. It does not prove that an external controller or physical battery will always behave safely, and it does not establish that the reported `next` state was physically produced from `current` by `signal`.

## 4. Runtime verification is not model checking

`BattSafeCheck` checks one externally reported transition at a time. It does not enumerate possible states or systematically explore a transition system.

Therefore, the current implementation is a small **runtime verification** example, not a **model checker**.

A future extension could introduce a transition model and systematically explore its reachable states. Such an extension could then be developed into a model-checking example.

## 5. Scope and limitations

These projects are intentionally small demonstrations, not production battery-management systems.

In particular:

- The model uses only SoC; it does not represent voltage, current, temperature, cell imbalance, aging, or measurement uncertainty.
- The numerical thresholds and state changes are illustrative.
- `BattSafeProof` proves preservation for the specific controller and transition functions defined in its source.
- `BattSafeCheck` checks only the values supplied for one transition and relies on the external system to report them correctly.
- Neither example establishes the safety of a real battery, controller, sensor, or physical system.

To adapt the examples to a practical setting, the safety requirements, controller constraints, transition model, and external data interface would need to be replaced or extended to reflect the system under consideration.

## License

This project is licensed under the [MIT License](./LICENSE).
