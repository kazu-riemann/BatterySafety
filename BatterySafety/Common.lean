module
@[expose] public section
namespace Common

/-- The battery state, represented by its state of charge (SoC). -/
structure BatteryState where
  soc : Rat -- Rational numbers represent decimal values exactly.
deriving Repr

/-- The two possible commands issued by the charging controller. -/
inductive ChargeSignal
  | On
  | Off
deriving DecidableEq, Repr

/-- The SoC safety condition: the value must be strictly between 0% and 100%. -/
def IsSafe (s : BatteryState) : Prop :=
  0 < s.soc ∧ s.soc < 100

/-- Provide a decidability procedure for the battery safety proposition. -/
instance (s : BatteryState) : Decidable (IsSafe s) := by
  dsimp [IsSafe]
  infer_instance

/--
Parse an integer or decimal string into a rational number. The fractional part
is interpreted as a base-10 fraction using the number of digits supplied.
-/
def stringToRat? (s : String) : Option Rat :=
  match s.splitOn "." with
  | [intPart] =>
      intPart.toInt?.map (fun n => (n : Rat))
  | [intPart, fracPart] =>
      match intPart.toInt?, fracPart.toNat? with
      | some n, some f =>
          let denominator : Rat := 10 ^ fracPart.length
          some ((n : Rat) + (f : Rat) / denominator)
      | _, _ => none
  | _ => none

end Common