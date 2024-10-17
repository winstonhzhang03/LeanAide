import Lean
open Std Lean

inductive IndentedList where
  | nil
  | cons (head : String) (offsetList : IndentedList) (tail : IndentedList)
  | kv_cons (head body : String) (optional: Bool)
      (offsetList : IndentedList) (tail : IndentedList)
deriving Inhabited, Repr, ToJson, FromJson

def IndentedList.append : IndentedList → IndentedList → IndentedList
  | IndentedList.nil, l => l
  | l, IndentedList.nil => l
  | IndentedList.cons h1 o1 t1, l2 => IndentedList.cons h1 o1 (t1.append l2)
  | IndentedList.kv_cons h1 b1 optional o1 t1, l2 => IndentedList.kv_cons h1 b1 optional o1 (t1.append l2)

instance : Append IndentedList := ⟨IndentedList.append⟩

def IndentedList.kvLine (head body : String) (optional: Bool) : IndentedList :=
  IndentedList.kv_cons head body optional IndentedList.nil IndentedList.nil

def IndentedList.renderAux : IndentedList → String → String
  | IndentedList.nil, _ => ""
  | IndentedList.cons h o t, indent =>
      let subList := o.renderAux (indent ++ "  ")
      indent ++ "* " ++ h ++ "\n" ++ subList ++ "¬" ++ t.renderAux indent
  | IndentedList.kv_cons h b optional o t, indent =>
      let subList := o.renderAux (indent ++ "  ")
      let body := if optional then s!"(OPTIONAL) {b}" else b
      indent ++ s!"* **{h}**: {body}" ++ "\n" ++
          subList ++ "\n" ++ t.renderAux indent

def IndentedList.render (l : IndentedList) : String :=
  l.renderAux ""

/--
Building blocks for structured math documents. Additional data is given as a HashMap from `Name` to `MathPara` for elements in a group.
-/
inductive MathPara where
  | text (name: Name) (description : String)
  | bool (name: Name) (description : String)
  | enum (name: Name) (choices: List String)
      (description : String)
  | list (name: Name) (fieldType: Name) (describeOptions: Bool) (description : String)
  | one_of (name: Name) (choices: List MathPara) (description : String)
  | list_of (name: Name) (type : MathPara)
  | obj (name: Name) (fields: List MathPara) (optFields : List MathPara)
      (description : String)
namespace MathPara

def name : MathPara → Name
  | text n _ => n
  | bool n _ => n
  | enum n _ _ => n
  | list n _ _ _ => n
  | one_of n _ _ => n
  | list_of n _ => n
  | obj n _ _ _ => n

def mathDoc : MathPara :=
  .list `math_document (fieldType := `math_object) (describeOptions := true) "A structured math document in a custom JSON format."

namespace let_statement

def var : MathPara := .text `variable ("The variable being defined (use `<anonymous>` if there is no name such as in `We have a group structure on S`)")

def value : MathPara := .text `value ("The value of the variable being defined")

def kind : MathPara := .text `kind ("The type of the variable, such as `real number`, `function from S to T`, `element of G` etc.")

def properties : MathPara := .text `properties "Specific properties of the variable beyond the type."

end let_statement

open let_statement in
def let_statement : MathPara :=
  .obj `let (fields := [var])
    (optFields := [value, kind, properties])
    (description := "A statement introducing a new variable with given value, type and/or property.")

def assume : MathPara :=
  .text `assume "A mathematical assumption being made. In case this is a variable or structure being introduced, use a **let** statement."

namespace define

def statement : MathPara :=
  .text `statement "The mathematical definition."

def term : MathPara :=
  .text `term "The term being defined."

end define

def define : MathPara :=
  .obj `def (fields := [define.statement, define.term]) (optFields := [])
    (description := "A mathematical definition of a term.")

namespace deduced_using

def deduced_from : MathPara := .text `deduced_from "The assumptions or previously known results from which the deduction is made."

def in_context : MathPara := .bool `in_context "Whether the statement from which deduction is made is in the current context. Answer `true` or `false` (answer `false` if a result from the mathematical literature is being invoked)."


def instantiation : MathPara :=  .text `instantiation "The instantiation of the assumption or previously known result to which the result is applied. For example,  `42` if we apply uniqueness of prime factorisation to `42`."

def instantiations : MathPara :=
  .list_of `instantiations instantiation

end deduced_using

namespace calculation

def inline : MathPara := .text `inline "A simple calculation or computation written as a single line."

def step : MathPara := .text `step "A step, typically an equality or inequality, in a calculation or computation."

def continuation : MathPara := .text `continuation "A continuation of a chain of equalities/inequalities, for example `= x + 3`. Should begin with an operator such as `=` or `≤` and be followed by a term."

end calculation

def calculation_step.justification : MathPara :=
  .text `justification "The justification for the step in a calculation or computation."

open calculation in
def calculation : MathPara :=
  .one_of `calculation [inline, step, continuation]  "A series of calculations or computations."

def calculation_step : MathPara :=
  .obj `calculation (fields := [calculation])
    (optFields := [calculation_step.justification])
    (description := "A step in a calculation or computation.")

namespace assert
open deduced_using in
def deduction : MathPara :=
  .obj `deduction (fields := [deduced_from, in_context])
    (optFields := [instantiations])
    (description := "A deduction of a mathematical result from assumptions or previously known results.")

def deductions : MathPara :=
  .list_of `deductions deduction

def claim : MathPara :=
  .text `claim "The mathematical claim being asserted, NOT INCLUDING proofs, justifications or results used. The claim should be purely a logical statement which is the *consequence* obtained."

def proof_method : MathPara :=
  .text `proof_method "The method used to prove the claim. This could be a direct proof, proof by contradiction, proof by induction, etc. this should be a single phrase or a fairly simple sentence; if a longer justification is needed break the step into smaller steps. If the method is deduction from a result, use the **deduced_using** field"

def calculations : MathPara :=
  .list_of `calculation (type := calculation_step)
end assert

def missing_result : MathPara :=
  .text `missing "A  problem that need to be solved or results that need to be proved to complete the proof. Standard results/criteria may be omitted from the proof: include them in the **deduced_from** field."

def missing : MathPara :=
  .list_of `missing missing_result

def error : MathPara :=
  .text `error "An error in a proof or calculation. Report only actual errors, with missing steps reported in the **missing** field."

def errors : MathPara :=
  .list_of `errors error

open assert in
def assert : MathPara :=
  .obj `assert (fields := [claim])
    (optFields := [proof_method, deductions, calculations, missing, errors])
    (description := "A mathematical statement whose proof is a straightforward consequence of given and known results following some method.")

namespace thm

def hypothesis : MathPara :=
  .list `hypothesis (fieldType := `contextBlock) (describeOptions := false)  "a JSON list of data and assumptions, i.e., **let** and **assume** statements"

def conclusion : MathPara :=
  .text `conclusion "The conclusion of the theorem."

def proved : MathPara :=
  .bool `proved "Whether the theorem has been proved, either here or earlier or by citing the literature."


def ref : MathPara :=
  .text `ref "A reference where the result has been previously proved."

def cite : MathPara :=
  .text `cite "A citation of a result from the mathematical literature which gives the proof."

end thm

def proof : MathPara :=
  .list `proof (fieldType := `math_object) (describeOptions := false) "A proof of a lemma, theorem or claim. A list of steps each of which is an arbitrary `math_object` (as in a `math_document`)."

open thm in
def thm : MathPara :=
  .obj `theorem (fields := [hypothesis, conclusion, proved])
    (optFields := [proof, ref, cite, missing, errors])
    (description := "A mathematical theorem, with a list of hypotheses and a conclusion.")

namespace problem

def statement : MathPara :=
  .text `statement "The statement of the problem."

def solved : MathPara :=
  .bool `solved "Whether the problem has been solved."

def answer : MathPara :=
  .text `answer "The answer to the problem."

end problem

open problem in
def problem : MathPara :=
  .obj `problem (fields := [statement, solved])
    (optFields := [answer, proof, missing, errors])
    (description := "A mathematical problem, with a statement and an answer.")

namespace case

def condition : MathPara :=
  .text `condition "The case condition or pattern; for induction one of 'base' or 'induction-step'"

end case

open case in
def case : MathPara :=
  .obj `case (fields := [condition, proof])
    (optFields := [missing, errors])
    (description := "A case in a proof by cases or proof by induction.")

namespace cases

def on : MathPara :=
  .text `on "The variable or expression on which the cases are being done."

def split_kind : MathPara :=
  .enum `split_kind ["match", "condition", "groups"] "one of 'match' (for pattern matching), 'condition' (if based on a condition being true or false) and 'groups' (for more complex cases)"

def exhaustiveness : MathPara :=
  .list `exhaustiveness (fieldType := `math_object) (describeOptions := false) "Proof that the cases are exhaustive."

end cases

def proof_cases : MathPara :=
  .list_of `proof_cases case

open cases in
def cases : MathPara :=
  .obj `cases (fields := [on, split_kind, proof_cases])
    (optFields := [exhaustiveness, missing, errors])
    (description := "A proof by cases or proof by induction, with a list of cases.")

namespace induction

def on : MathPara :=
  .text `on "The variable or expression on which induction is being done."

end induction

open induction in
def induction : MathPara :=
  .obj `induction (fields := [on, proof_cases])
    (optFields := [missing, errors])
    (description := "A proof by induction, with a base case and an induction step.")

namespace contradiction
def assumption : MathPara :=
  .text `assumption "The assumption being made to be contradicted."

def proof : MathPara :=
  .list `proof (fieldType := `math_object) (describeOptions := false) "The proof of the contradiction given the assumption."

end contradiction

open contradiction in
def contradiction : MathPara :=
  .obj `contradiction (fields := [assumption, contradiction.proof])
    (optFields := [missing, errors])
    (description := "A proof by contradiction, with an assumption and a proof of the contradiction.")

namespace conclude

def claim : MathPara :=
  .text `claim "The conclusion of the proof."

end conclude

open conclude in
def conclude : MathPara :=
  .obj `conclude (fields := [claim])
    (optFields := [missing, errors])
    (description := "Conclude a claim obtained from the steps so far. This is typically the final statement of a proof giving the conclusion of the theorem.")

def remark : MathPara :=
  .text `remark "A remark or comment that is NOT MATHEMATICAL, instead being for motivation, attention, sectioning etc."

def math_objectElems := [let_statement, assume, define, assert, thm, problem, cases, induction, contradiction, conclude, remark]

def contextBlockElems := [let_statement, assume]

def elemMap : Std.HashMap Name <| List MathPara :=
  Std.HashMap.ofList [(`math_object, math_objectElems), (`contextBlock, contextBlockElems)]

open IndentedList in
def toIndendentList (p: MathPara) (optional : Bool := false)
  (elemMap : Std.HashMap Name <| List MathPara := elemMap) (maxDepth: Nat := 3): IndentedList :=
  match p with
  | .text name description => kvLine name.toString description optional
  | .bool name description => kvLine name.toString description optional
  | .enum name _ description =>
      kvLine name.toString description optional
  | .list name fieldType describeOptions description =>
    if describeOptions then
    match maxDepth with
    | 0 => kvLine name.toString description optional
    | k + 1 =>
      let fields := elemMap.getD fieldType []
      let innerList :=
        fields.map (fun elem => toIndendentList elem false elemMap k)
      let inner := innerList.foldl (fun acc elem => acc.append elem) nil
      let body := description ++ s!"Each element of the list is a JSON object of type {fieldType}.The options for elements of {fieldType} are as follows:\n"
      .kv_cons name.toString body optional inner .nil
    else kvLine name.toString description optional
  | .one_of name choices description =>
    match maxDepth with
    | 0 => kvLine name.toString description optional
    | k + 1 =>
      let innerList :=
        choices.map (fun elem => toIndendentList elem false elemMap k)
      let inner := innerList.foldl (fun acc elem => acc.append elem) nil
      .kv_cons name.toString description optional inner .nil
  | .list_of name type =>
      let inner :=
      match maxDepth with
      | 0 => .nil
      | k + 1 => toIndendentList type false elemMap k
      .kv_cons name.toString s!"A list of elements of {type.name}. Each element of type {type.name} is as follows" optional inner .nil
  | .obj name fields optFields description =>
    match maxDepth with
    | k + 1 =>
      let innerList :=
        fields.map (fun elem => toIndendentList elem false elemMap k)
      let optInnerList :=
        optFields.map (fun elem => toIndendentList elem true elemMap k)
      let inner := innerList ++ optInnerList
        |>.foldl (fun acc elem => acc.append elem) nil
      .kv_cons name.toString description optional inner .nil
    | 0 => kvLine name.toString description optional


end MathPara

#eval MathPara.mathDoc.toIndendentList |>.render
