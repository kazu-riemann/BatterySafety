module
import BatterySafety.Common
/-!
# Battery Safety: Runtime Verification Example

This module performs a runtime check of a single transition reported by an
external system. The external system supplies the current state, control
signal, and next state; this module checks those values against the specified
conditions. It does not implement the controller or the battery dynamics, and
it does not explore a state space as a model checker would.
-/

open Common

/--
A requirement on the controller output, rather than an implementation of the
controller: when the SoC is at least 95%, the signal must be `Off`.
-/
def ControllerSafe (s : BatteryState) (sig : ChargeSignal) : Prop :=
  s.soc < 95 ∨ sig = ChargeSignal.Off

/-- Provide a decidability procedure for the controller-output requirement. -/
instance (s : BatteryState) (sig : ChargeSignal) :
    Decidable (ControllerSafe s sig) := by
  unfold ControllerSafe
  infer_instance

/--
A single transition reported by an external system. The definitions of the
controller and the state-transition function are intentionally not included
in this module.
-/
structure ExternalStep where
  current : BatteryState
  signal : ChargeSignal
  next : BatteryState
deriving Repr

/--
The requirements that an externally reported transition must satisfy:
the current state is safe, the control signal conforms to its requirement,
and the reported next state is safe.
-/
def TransitionSafe (step : ExternalStep) : Prop :=
  IsSafe step.current ∧
  ControllerSafe step.current step.signal ∧
  IsSafe step.next

/--
Accept the reported next state when a proof of `TransitionSafe` is provided.
The proof establishes that the returned state satisfies `IsSafe`.
-/
def acceptStep
    (step : ExternalStep)
    (_proof : TransitionSafe step) : BatteryState :=
  step.next

/-- The next state returned by `acceptStep` satisfies the safety condition. -/
theorem accepted_step_is_safe
    (step : ExternalStep)
    (h : TransitionSafe step) :
    IsSafe (acceptStep step h) := by
  exact h.2.2

/-!
## Command-line interface

The program expects three arguments in the following order:

* `current_soc`: the SoC before the reported transition;
* `signal`: either `On` or `Off`;
* `next_soc`: the SoC after the reported transition.

For example:

* `94 On 99`
* `99 Off 97`
* `96 On 101`
-/

/-- Parse a command-line token as one of the supported charge signals. -/
def stringToChargeSignal? (s : String) : Option ChargeSignal :=
  match s with
  | "On"  => some ChargeSignal.On
  | "Off" => some ChargeSignal.Off
  | _     => none

/--
Command-line entry point for checking one externally reported transition.
The input values are parsed and converted into an `ExternalStep`. The
conditions in `TransitionSafe` are checked in sequence, and the first failing
condition is reported.
-/
public def main (args : List String) : IO Unit := do
  match args with
  | currentSocStr :: signalStr :: nextSocStr :: _ =>
      match
        stringToRat? currentSocStr,
        stringToChargeSignal? signalStr,
        stringToRat? nextSocStr
      with
      | some currentSoc, some signal, some nextSoc =>
          let current := BatteryState.mk currentSoc
          let next := BatteryState.mk nextSoc
          let step : ExternalStep :=
            {
              current := current
              signal := signal
              next := next
            }

          -- Check the current state, control-output requirement, and next state.
          if h_current : IsSafe current then
            IO.println s!"[Current state] Safe: {repr current}"
            if h_controller : ControllerSafe current signal then
              IO.println s!"[Control output] Satisfies the requirement: {repr signal}"
              if h_next : IsSafe next then
                IO.println s!"[Next state] Safe: {repr next}"

                -- Combine the three component proofs into a proof of the full transition requirement.
                let proof : TransitionSafe step :=
                  ⟨h_current, h_controller, h_next⟩

                -- Accept the reported next state using the combined proof.
                let accepted := acceptStep step proof
                IO.println
                  s!"[Verification passed] Accepted next state: {repr accepted}"
              else
                IO.println
                  s!"[Verification failed] The next state is outside the safe range: {repr next}"
            else
              IO.println
                s!"[Verification failed] The control signal violates the controller requirement: {repr signal}"
          else
            IO.println
              s!"[Verification failed] The current state is outside the safe range: {repr current}"
      | _, _, _ =>
          IO.println "Error: Invalid input format."
  | _ =>
      IO.println
        "Usage: <current_soc> <On|Off> <next_soc>"
