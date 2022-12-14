import Mathlib
import LeanCodePrompts.Translate
import LeanCodePrompts.CodeActions

/-!
# Translation demo

To see translation in action, place the cursor anywhere on one of the comments below and invoke the code action to translate by clicking on the lightbulb or using `ctrl-.`. 
-/


/- There are infinitely many odd numbers -/
example : ∀ (n : ℕ), ∃ m, m > n ∧ m % 2 = 1 := by sorry

/- Every prime number is either `2` or odd -/

