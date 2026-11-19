module
import Mathlib.Tactic.Linarith
import BatterySafety.Common
/-!
# Battery Safety: Theorem-Proving Example

This module defines a simple battery model and proves that one application of
its controller preserves the stated state-of-charge (SoC) safety condition.
It also includes a command-line entry point that checks an initial SoC value
and performs one proof-backed simulation step.
-/

open Common

/--
The controller turns charging off when the SoC is at least 95%; otherwise,
it turns charging on.
-/
def controller (s : BatteryState) : ChargeSignal :=
  if s.soc ≥ 95 then ChargeSignal.Off else ChargeSignal.On

/--
The one-step battery model. Charging increases the SoC by 5, while turning
off charging decreases it by 2.
-/
def nextState (s : BatteryState) (sig : ChargeSignal) : BatteryState :=
  match sig with
    | ChargeSignal.On  => { soc := s.soc + 5 }
    | ChargeSignal.Off => { soc := s.soc - 2 }

/--
One-step safety invariant: if the current state is safe, then applying the
controller and the battery transition model produces another safe state.
-/
theorem battery_safety_invariant (s : BatteryState) (h_safe : IsSafe s) :
    IsSafe (nextState s (controller s)) := by
  rcases h_safe with ⟨h_low, h_high⟩
  unfold controller nextState IsSafe
  split_ifs with h_control
  · constructor <;> linarith
  · constructor <;> linarith

/--
Perform one simulation step using a proof that the initial state is safe.
The invariant theorem is applied internally to construct a proof that the
computed next state is safe. The proof is local; this function returns only
the next `BatteryState`, not a state bundled with its safety proof.
-/
def stepSimulationSecurely (s : BatteryState) (proof : IsSafe s) : BatteryState :=
  let next := nextState s (controller s)
  let _next_proof : IsSafe next := battery_safety_invariant s proof
  next

/-!
## Input parsing and command-line execution

The command-line example accepts an SoC value, checks the initial state, and
then performs one step using the controller and transition model defined in
this module.
-/

/--
Parse an integer string as a rational number. This helper is separate from
`stringToRat?`, which is used by the command-line entry point and also handles
decimal input.
-/
def parseRat? (str : String) : Option Rat :=
  match str.toInt? with
  | some i => some (Rat.ofInt i)
  | none => none

/-- Command-line entry point for the one-step battery simulation example. -/
public def main (args : List String) : IO Unit := do
  match args.head?.bind stringToRat? with
  | none =>
    IO.println "Error: Please provide a valid decimal value (e.g., 94.1)."
  | some inputSoc =>

    let current_battery := BatteryState.mk inputSoc

    -- Check whether the supplied initial state satisfies the safety condition.
    if h_safe : IsSafe current_battery then
      IO.println s!"[Validation passed] Initial state is safe: {repr current_battery}"

      -- The initial-state proof is passed to the proof-backed simulation step.
      let next_battery := stepSimulationSecurely current_battery h_safe
      IO.println s!"[Control step] State after one step: {repr next_battery}"

    else
      IO.println s!"[Validation failed] The supplied battery state does not satisfy the safety condition."
