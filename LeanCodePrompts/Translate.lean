import Lean
import Lean.Meta
import Lean.Parser
import LeanAide.TheoremElab
import LeanAide.Lean4Names
import LeanAide.TheoremEquality
import LeanAide.IP
import LeanCodePrompts.SpawnNearestEmbeddings
import Std.Tactic.TryThis
import Std.Util.Pickle
import LeanCodePrompts.ChatClient

open Lean Meta Elab Parser Command
open Std.Tactic

register_option lean_aide.translate.prompt_size : Nat :=
  { defValue := 10
    group := "lean_aide.translate"
    descr := "Number of document strings in a prompt (default 8)" }

register_option lean_aide.translate.choices : Nat :=
  { defValue := 10
    group := "lean_aide.translate"
    descr := "Number of outputs to request in a query (default 5)." }

register_option lean_aide.translate.use_defintions : Bool :=
  { defValue := true
    group := "lean_aide.translate"
    descr := "Whether to use docstrings of definitions (in addition to theorems)." }

register_option lean_aide.translate.definition_penalty : Nat :=
  { defValue := 20
    group := "lean_aide.translate"
    descr := "Penalty for a prompt being from a definition scaled by 10" }

register_option lean_aide.translate.model : String :=
  { defValue := "gpt-3.5-turbo"
    group := "lean_aide.translate"
    descr := "Model to use (gpt-3.5-turbo)." }

register_option lean_aide.translate.azure : Bool :=
  { defValue := false
    group := "lean_aide.translate"
    descr := "Whether to use Azure OpenAI." }

register_option lean_aide.translate.url? : String :=
  { defValue := ""
    group := "lean_aide.translate"
    descr := "Local url to query. Empty string for none" }

def promptSize : CoreM Nat := do
  return  lean_aide.translate.prompt_size.get (← getOptions)

def chatParams : CoreM ChatParams := do
  let opts ← getOptions
  return {
    n := lean_aide.translate.choices.get opts,
    temp := 0.8,
    model := lean_aide.translate.model.get opts
  }

def chatServer : CoreM ChatServer := do
  let opts ← getOptions
  if lean_aide.translate.azure.get opts then
    return ChatServer.azure
  else
    let url := lean_aide.translate.url?.get opts
    if url.isEmpty then
      return ChatServer.openAI
    else
      return ChatServer.generic url

def fileName := "data/mathlib4-prompts.json"

def lean4mode := decide (fileName ∈ ["data/mathlib4-prompts.json",
        "data/mathlib4-thms.json"])

def docField :=
        if lean4mode then "docString" else "doc_string"

def theoremField :=
        if lean4mode then "type" else "theorem"

/-- extract prompt pairs from JSON response to local server -/
def sentenceSimPairs
  (s: String)
  (theoremField : String := theoremField)
   : IO  <| Except String (Array (String × String)) := do
  let json := Lean.Json.parse  s |>.toOption.get!
  return do
    (← json.getArr?).mapM <| fun j => do
      let lean4mode := fileName ∈ ["data/mathlib4-prompts.json",
        "data/mathlib4-thms.json"]
      let docstring ← j.getObjValAs? String docField
      let typeField :=
        if lean4mode then "type"
        else theoremField
      let thm ← j.getObjValAs? String typeField
      pure (docstring, thm)

-- #eval sentenceSimPairs egSen

namespace GPT

def message (role content : String) : Json :=
  Json.mkObj [("role", role), ("content", content)]

def prompt (sys: String) (egs : List <| String × String)
  (query : String)(pfx : String := "") : Json :=
  let head := message "system" sys
  let egArr :=
    egs.bind (fun (ds, thm) => [message "user" (pfx ++ ds), message "assistant" thm])
  Json.arr <| head :: egArr ++ [message "user" (pfx ++ query)] |>.toArray

def syslessPrompt (sys: String)(egs : List <| String × String)
    (query : String)(pfx : String := "") : Json :=
  let egsPadded := match egs with
  | [] => []
  | (ds, thm) :: _ => (s!"{sys}

{pfx}" ++ ds, thm) :: (egs.map (fun (ds, thm) => (pfx ++ ds, thm)))
  let egArr :=
    egsPadded.bind (fun (ds, thm) => [message "user" ds, message "assistant" thm])
  Json.arr <| egArr ++ [message "user" query] |>.toArray

def sysPrompt := "You are a coding assistant who translates from natural language to Lean Theorem Prover code following examples. Follow EXACTLY the examples given."

def mkMessages(query : String)(examples: Array (String × String))(pfx: String := "")(sysLess: Bool := false) : Json:=
  if sysLess then
    syslessPrompt sysPrompt examples.toList query pfx
  else
    prompt sysPrompt examples.toList query pfx

def makeFlipPrompt(query : String)(examples: Array (String × String)) : Json:= prompt sysPrompt (examples.toList.map (fun (x, y) => (y, x))) query

def exprStrsFromJson (json: Json) : CoreM (Array String) := do
  let outArr : Array String ←
    match json.getArr? with
    | Except.ok arr =>
        let parsedArr : Array String ←
          arr.filterMapM <| fun js =>
            match js.getObjVal? "message" with
            | Except.ok jsobj =>
                match jsobj.getObjVal? "content" with
                | Except.ok jsstr =>
                  match jsstr.getStr? with
                  | Except.ok str => pure (some str)
                  | Except.error e =>
                    throwError m!"json string expected but got {js}, error: {e}"
                | Except.error _ =>
                  throwError m!"no content field in {jsobj}"
            | Except.error _ =>
                throwError m!"no message field in {js}"

        pure parsedArr
    | Except.error e => throwError m!"json parsing error: {e}"

end GPT

/-- make prompt from prompt pairs -/
@[deprecated GPT.mkMessages]
def makePrompt(prompt : String)(pairs: Array (String × String)) : String :=
      pairs.foldr (fun  (ds, thm) acc =>
        -- acc ++ "/-- " ++ ds ++" -/\ntheorem" ++ thm ++ "\n" ++ "\n"
s!"/-- {ds} -/
theorem {thm} :=

{acc}"
          ) s!"/-- {prompt} -/
theorem "


/-- make prompt for reverse translation from prompt pairs -/
@[deprecated GPT.makeFlipPrompt]
def makeFlipPrompt(statement : String)(pairs: Array (String × String)) : String :=
      pairs.foldr (fun  (ds, thm) acc =>
s!"theorem {thm} :=
/- {ds} -/

{acc}"
          ) s!"theorem {statement} :=
/- "

/-- make prompt for reverse translation from prompt pairs -/
def makeFlipStatementsPrompt(statement : String)(pairs: Array (String × String)) : String :=
      pairs.foldr (fun  (ds, thm) acc =>
s!"{thm} :=
/- {ds} -/

{acc}"
          ) s!"{statement} :=
/- "


/-!
Caching, polling etc to avoid repeatedly calling servers
-/

initialize webCacheJson : IO.Ref (HashMap String (Json × Json)) ← IO.mkRef (HashMap.empty)

initialize pendingJsonQueries : IO.Ref (HashSet String)
    ← IO.mkRef (HashSet.empty)

def getCachedJson? (s: String) : IO (Option (Json × Json)) := do
  let cache ← webCacheJson.get
  return cache.find? s

def cacheJson (s: String)(js: Json × Json)  : IO Unit := do
  let cache ← webCacheJson.get
  webCacheJson.set (cache.insert s js)
  return ()

partial def pollCacheJson (s : String) : IO <| Json × Json := do
  let cache ← webCacheJson.get
  match cache.find? s with
  | some jsBlob => return jsBlob
  | none => do
    IO.sleep 200
    pollCacheJson s

/-- check if there is a valid elaboration after translation, autocorrection -/
def hasElab (s: String) : TermElabM Bool := do
  let elab? ← elabThm4 s
  return elab?.toOption.isSome

/-- log to file -/
def elabLog (s: String) : IO Unit := do
  let logFile := System.mkFilePath ["results/elab_logs.txt"]
  let h ←  IO.FS.Handle.mk logFile IO.FS.Mode.append
  h.putStrLn s
  h.putStrLn ""

def fixedPrompts:= #[("If $z_1, \\dots, z_n$ are complex, then $|z_1 + z_2 + \\dots + z_n|\\leq |z_1| + |z_2| + \\dots + |z_n|$.", "(n : ℕ) (f : ℕ → ℂ) :\n Complex.abs (∑ i in Finset.range n, f i) ≤ ∑ i in Finset.range n, Complex.abs (f i)"), ("If x and y are in $\\mathbb{R}^n$, then $|x+y|^2 + |x-y|^2 = 2|x|^2 + 2|y|^2$.", "(n : ℕ) (x y : EuclideanSpace ℝ (Fin n)) :\n ‖x + y‖^2 + ‖x - y‖^2 = 2*‖x‖ ^2 + 2*‖y‖^2"), ("If $x$ is an element of infinite order in $G$, prove that the elements $x^n$, $n\\in\\mathbb{Z}$ are all distinct.", "(G : Type*) [Group G] (x : G) (hx : x ≠ 1) (hx_inf : ∀ n : ℕ, x ^ n ≠ 1) : ∀ m n : ℤ, m ≠ n → x ^ m ≠ x ^ n"), ("Let $X$ be a topological space; let $A$ be a subset of $X$. Suppose that for each $x\\in A$ there is an open set $U$ containing $x$ such that $U\\subset A$. Show that $A$ is open in $X$.", "(X : Type*) [TopologicalSpace X]\n (A : Set X) (hA : ∀ x ∈ A, ∃ U : Set X, IsOpen U ∧ x ∈ U ∧ U ⊆ A):\n IsOpen A")]

def fixedPromptTriples:= #[("If $z_1, \\dots, z_n$ are complex, then $|z_1 + z_2 + \\dots + z_n|\\leq |z_1| + |z_2| + \\dots + |z_n|$.", "(n : ℕ) (f : ℕ → ℂ) :\n Complex.abs (∑ i in Finset.range n, f i) ≤ ∑ i in Finset.range n, Complex.abs (f i)", "abs_sum_leq_sum_abs"), ("If x and y are in $\\mathbb{R}^n$, then $|x+y|^2 + |x-y|^2 = 2|x|^2 + 2|y|^2$.", "(n : ℕ) (x y : EuclideanSpace ℝ (Fin n)) :\n ‖x + y‖^2 + ‖x - y‖^2 = 2*‖x‖ ^2 + 2*‖y‖^2", "sum_add_square_sub_square_eq_sum_square"), ("If $x$ is an element of infinite order in $G$, prove that the elements $x^n$, $n\\in\\mathbb{Z}$ are all distinct.", "(G : Type*) [Group G] (x : G) (hx : x ≠ 1) (hx_inf : ∀ n : ℕ, x ^ n ≠ 1) : ∀ m n : ℤ, m ≠ n → x ^ m ≠ x ^ n", "distinct_powers_of_infinite_order_element"), ("Let $X$ be a topological space; let $A$ be a subset of $X$. Suppose that for each $x\\in A$ there is an open set $U$ containing $x$ such that $U\\subset A$. Show that $A$ is open in $X$.", "(X : Type*) [TopologicalSpace X]\n (A : Set X) (hA : ∀ x ∈ A, ∃ U : Set X, IsOpen U ∧ x ∈ U ∧ U ⊆ A):\n IsOpen A", "subset_of_open_subset_is_open")]

def fixedPromptsJson : Array <| String × Json :=
  fixedPromptTriples.map (fun (ds, thm, name) =>
    (ds,
    Json.mkObj [("docString", ds), ("theorem", thm), ("name", name)]))

def getPromptPairsBert(s: String)(numSim : Nat)
   : IO <| Except String (Array (String × String)) := do
      let jsData := Json.mkObj [
        ("filename", fileName),
        ("field", docField),
        (docField, s),
        ("n", numSim),
        ("model_name", "all-mpnet-base-v2")
      ]
      let simJsonOut ←
        IO.Process.output {cmd:= "curl", args:=
          #["-X", "POST", "-H", "Content-type: application/json", "-d", jsData.pretty, s!"{← leanAideIP}/nearest_prompts"]}
      unless simJsonOut.exitCode == 0 do
        return Except.error s!"curl failed with exit code {simJsonOut.exitCode}¬{simJsonOut.stderr}"
      let pairs? ← sentenceSimPairs simJsonOut.stdout theoremField
      -- IO.println s!"obtained sentence similarity; time : {← IO.monoMsNow}"
      let allPairs : Array (String × String) ←
        match pairs? with
        | Except.error e =>
            return Except.error e
        | Except.ok pairs => pure pairs
      -- logInfo m!"all pairs: {allPairs}"
      let allPairs := allPairs.toList.eraseDups.toArray
      return Except.ok allPairs.toList.eraseDups.toArray

def getNearestDocsOpenAI (s: String)(numSim : Nat)(full: Bool:= true) :
  IO <| Except String (Array (String × Json)) := do
    let outJs ←
     if full then
       getNearestEmbeddingsFull s numSim 2.0
      else getNearestEmbeddings s numSim
    match Json.parse outJs with
    | Except.error e => return Except.error e
    | Except.ok js =>
      match js.getArr? with
      | Except.error e => return Except.error e
      | Except.ok jsArr =>
        let mut pairs : Array <| String × Json := #[]
        for js in jsArr do
          match js.getObjValAs? String "docString" with
          | Except.error e => return Except.error e
          | Except.ok doc =>
            pairs := pairs.push (doc, js)
        return Except.ok pairs.reverse

/-- choosing example theorems to build a prompt -/
def getNearestDocs(s: String)(numSim : Nat)
-- (source: String := "openai_full")
   : IO <| Except String (Array (String × Json)) :=
      getNearestDocsOpenAI s numSim true

def simpleExample :String × Json →
  Option (String × String)
  | (docString, data) => data.getObjValAs? String "theorem" |>.toOption.map fun thm => (docString, thm)

/-- prompts generated from the declarations in the current file. -/
def getEnvPrompts (moduleNames : Array Name := .empty) (useMain? : Bool := true) : MetaM <| Array (String × String):= do
  if moduleNames.isEmpty && !useMain? then
    return #[]

  let env ← getEnv
  let moduleNames :=
    if useMain? then
      moduleNames.push env.mainModule
    else moduleNames
  let moduleIdxs := moduleNames.filterMap env.getModuleIdx?

  List.toArray <$> env.constants.toList.filterMapM fun ⟨nm, ci⟩ ↦ do
    let some _ := moduleIdxs.contains <$> env.getModuleIdxFor? nm  | pure none
    let some docstring ← findDocString? env nm | pure none
    let some kind := (
      match ci with
        | .defnInfo _ => some "def"
        | .thmInfo _  => some "theorem"
        |     _       => none
    ) | pure none
    let some type ← try? (Format.pretty <$> PrettyPrinter.ppExpr ci.type) | pure none
    return some ⟨docstring, s!"{kind} : {type} :="⟩

/-- choosing example theorems to build a prompt -/
def getPromptPairsGeneral(s: String)(numSim : Nat)(field: String := docField)
    (theoremField : String := theoremField)
   : TermElabM (Array (String × String) × IO.Process.Output) := do
      let jsData := Json.mkObj [
        ("filename", fileName),
        ("field", field),
        (field, s),
        ("n", numSim),
        ("model_name", "all-mpnet-base-v2")
      ]
      let simJsonOut ←
        IO.Process.output {cmd:= "curl", args:=
          #["-X", "POST", "-H", "Content-type: application/json", "-d", jsData.pretty, s!"{← leanAideIP}/nearest_prompts"]}
      let pairs? ← sentenceSimPairs simJsonOut.stdout theoremField
      -- IO.println s!"obtained sentence similarity; time : {← IO.monoMsNow}"
      let allPairs : Array (String × String) ←
        match pairs? with
        | Except.error e =>
            throwError e

        | Except.ok pairs => pure pairs
      -- logInfo m!"all pairs: {allPairs}"
      return (
          allPairs.toList.eraseDups.toArray, simJsonOut)


/-- given string to translate, build prompt and query OpenAI; returns JSON response
-/
def getLeanCodeJson (s: String)
  (server: ChatServer := ChatServer.openAI)(params: ChatParams := {})(numSim : Nat:= 8)
  (includeFixed: Bool := Bool.false)(pfx: String := "")(sysLess: Bool := false) : CoreM <| Json × Json := do
  logTimed s!"translating string `{s}` with {numSim} examples"
  match ← getCachedJson? s with
  | some js => return js
  | none =>
    let pending ←  pendingJsonQueries.get
    if pending.contains s then pollCacheJson s
    else
      let pending ←  pendingJsonQueries.get
      pendingJsonQueries.set (pending.insert s)
      -- work starts here; before this was caching, polling etc
      let pairs? ←
        if numSim > 0 then
          getNearestDocs s numSim
        else pure <| Except.ok #[]
      match pairs? with
      | Except.error e => throwError e
      | Except.ok pairs => do
      let pairs := if includeFixed then pairs ++ fixedPromptsJson else pairs
      let pairs  := pairs.filter (fun (s, _) => s.length < 100)
      let examples := pairs.filterMap simpleExample
      let messages := GPT.mkMessages s examples pfx sysLess
      trace[Translate.info] m!"prompt: \n{messages.pretty}"
      logTimed "querying server"
      let fullJson ← server.query messages params
      let outJson :=
        (fullJson.getObjVal? "choices").toOption.getD (Json.arr #[])
      logTimed "obtained gpt response"
      let pending ←  pendingJsonQueries.get
      pendingJsonQueries.set (pending.erase s)
      cacheJson s (outJson, messages)
      return (outJson, messages)

/-- Given an array of outputs, tries to elaborate them with translation and autocorrection and returns the best choice, throwing an error if nothing elaborates.  -/
def bestElab (output: Array String) : TermElabM Expr := do
  trace[Translate.info] m!"output:\n{output}"
  let mut elabStrs : Array String := Array.empty
  let mut elaborated : Array Expr := Array.empty
  let mut fullElaborated : Array Expr := Array.empty
  let mut cache : HashMap String (Except String Expr) :=
    HashMap.empty
  for out in output do
    -- IO.println s!"elaboration called: {out}"
    let elab? ←
      match cache.find? out with
      | some elab? => pure elab?
      | none =>
        let res ← elabThm4 out
        cache := cache.insert out res
        pure res
    match elab? with
      | Except.error _ => pure ()
      | Except.ok expr =>
          elaborated := elaborated.push expr
          elabStrs := elabStrs.push out
          if !expr.hasExprMVar then
            fullElaborated := fullElaborated.push expr
  if elaborated.isEmpty then
    let mut errors : Array Json := #[]
    for out in output do
      let stx ← parseThm4 out
      match stx with
      | Except.error err =>
          errors := errors.push <|
            Json.mkObj [("parsed", false),
              ("error", Json.str err), ("output", Json.str out)]
          pure ()
      | Except.ok stx => do
        errors := errors.push <|
            Json.mkObj [("parsed", true),
              ("syntax", stx.reprint.get!), ("output", Json.str out)]
    let errorJson := Json.arr errors
    appendLog "translate_fail_error" errorJson
    mkSyntheticSorry (mkSort levelZero)
  else
    logTimed "elaborated outputs, starting majority voting"
    let priority :=
        if fullElaborated.isEmpty then elaborated else fullElaborated
    let groupSorted ← groupThmExprsSorted priority
    logTimed "finished majority voting"
    return (groupSorted[0]!)[0]!


/-- Given an array of outputs, tries to elaborate them with translation and autocorrection and optionally returns the best choice as well as all elaborated terms (used for batch processing, interactive code uses `arrayToExpr` instead)  -/
def bestElab? (output: Array String) : TermElabM (Except Json (Expr× (Array String) × (Array (Array String)) )) := do
  -- IO.println s!"arrayToExpr? called with {output.size} outputs"
  let mut elabStrs : Array String := Array.empty
  let mut elaborated : Array Expr := Array.empty
  let mut fullElaborated : Array Expr := Array.empty
  let mut cache : HashMap String (Except String Expr) :=
    HashMap.empty
  logTimed "elaborating outputs"
  for out in output do
    -- IO.println s!"elaboration called: {out}"
    let elab? ←
      match cache.find? out with
      | some elab? => pure elab?
      | none =>
        let res ← elabThm4 out
        cache := cache.insert out res
        pure res

    match elab? with
      | Except.error _ => pure ()
      | Except.ok expr =>
          elaborated := elaborated.push expr
          elabStrs := elabStrs.push out
          if !expr.hasExprMVar then
            fullElaborated := fullElaborated.push expr
  if elaborated.isEmpty then
    let mut errors : Array Json := #[]
    for out in output do
      let stx ← parseThm4 out
      match stx with
      | Except.error err =>
          errors := errors.push <|
            Json.mkObj [("parsed", false),
              ("error", Json.str err), ("output", Json.str out)]
          pure ()
      | Except.ok stx => do
        errors := errors.push <|
            Json.mkObj [("parsed", true),
              ("syntax", stx.reprint.get!), ("output", Json.str out)]
    let errorJson := Json.arr errors
    return Except.error errorJson
  else
    logTimed "elaborated outputs, starting majority voting"
    let priority :=
        if fullElaborated.isEmpty then elaborated else fullElaborated
    let groupSorted ← groupThmExprsSorted priority
    let thm := (groupSorted[0]!)[0]!
    let gpView ←  groupSorted.mapM (fun gp => gp.mapM (fun e => e.view))
    logTimed "obtained majority vote"
    return Except.ok (thm, elabStrs, gpView)


def greedyBestExpr? (output: Array String) : TermElabM (Option Expr) := do
    output.findSomeM? <| fun out => do
      let el? ← elabThm4 out
      pure el?.toOption

/-- reverse translation from `Lean` to natural language -/
def leanToPrompt (thm: String)(numSim : Nat:= 5)(temp : JsonNumber := 0)(textField : String := "text")(model: String) : TermElabM String := do
    let pairs? ← getNearestDocs thm numSim
    let pairs := pairs?.toOption.getD #[]
    let examples := pairs.filterMap simpleExample
    let prompt := GPT.makeFlipPrompt thm examples
    let fullJson ← (ChatServer.openAI).query prompt
      {model := model, temp := temp, n := 1}
    let outJson :=
      (fullJson.getObjVal? "choices").toOption.getD (Json.arr #[])
    let out? := (outJson.getArrVal? 0).bind fun js => js.getObjVal? textField
    let outJson :=
        match (out?) with
        | Except.error s => Json.str s!"query for translation failed: {s}"
        | Except.ok js => js
    return outJson.getStr!

def egThm := "theorem eg_thm : ∀ n: Nat, ∃ m : Nat, m > n ∧ m % 2 = 0"

def egPairs := getPromptPairsGeneral egThm 5 "statement" "statement"

def egPrompt := do
  let (pairs, _) ← egPairs
  return makeFlipStatementsPrompt egThm pairs

-- #eval egPrompt

-- #eval statementToDoc egThm 5 0

-- #eval leanToPrompt "∀ {p : ℕ} [inst : Fact (Nat.Prime p)], p = 2 ∨ p % 2 = 1"

-- #eval leanToPrompt "∀ {α : Type u} {x : FreeGroup α}, x ≠ 1 → ¬IsOfFinOrder x"

-- #eval leanToPrompt "{  n :  ℕ } ->  Even   (    (   n +  1  ) * n  )"

/-- array of outputs extracted from OpenAI Json -/
def exprStrsFromJson (json: Json) : TermElabM (Array String) := do
  let outArr : Array String ←
    match json.getArr? with
    | Except.ok arr =>
        let parsedArr : Array String ←
          arr.filterMapM <| fun js =>
            match js.getObjVal? "text" with
              | Except.ok jsstr =>
                match jsstr.getStr? with
                | Except.ok str => pure (some str)
                | Except.error e =>
                  throwError m!"json string expected but got {js}, error: {e}"
              | Except.error _ =>
                throwError m!"no text field"
        pure parsedArr
    | Except.error e => throwError m!"json parsing error: {e}"
  return outArr

/-- array of outputs extracted from Json Array -/
def exprStrsFromJsonStr (jsString: String) : TermElabM (Array String) := do
  try
  let json := Lean.Json.parse  jsString |>.toOption.get!
  let outArr : Array String ←
    match json.getArr? with
    | Except.ok arr =>
        let parsedArr : Array String ←
          arr.filterMapM <| fun js =>
            match js.getStr? with
            | Except.ok str => pure (some str)
            | Except.error e =>
              throwError m!"json string expected but got {js}, error: {e}"
        pure parsedArr
    | Except.error _ => pure #[jsString]
  return outArr
  catch _ =>
    pure #[jsString]

-- #eval jsonStringToExprStrArray "simple"
-- #eval jsonStringToExprStrArray "[\"simple\", \"simple2\"]"


/-- given json returned by open-ai obtain the best translation -/
def jsonToExpr' (json: Json) : TermElabM Expr := do
  let output ← GPT.exprStrsFromJson json
  bestElab output

/-- translation from a comment-like syntax to a theorem statement -/
elab "//-" cb:commentBody  : term => do
  let s := cb.raw.getAtomVal
  let s := (s.dropRight 2).trim
  -- querying codex
  let (js, _) ←
    getLeanCodeJson  s (params := {model := "gpt-3.5-turbo"})
  -- filtering, autocorrection and selection
  let e ← jsonToExpr' js
  trace[Translate.info] m!"{e}"
  return e

def uncurriedView(numArgs: Nat)(e: Expr) : MetaM String :=
  match numArgs with
  | 0 => do return " : " ++ (← e.view)
  | k +1 =>
    match e with
    | Expr.forallE n t _ bi => do
      let core := s!"{n.eraseMacroScopes} : {← t.view}"
      let typeString :=s!"{← t.view}"
      let argString := match bi with
      | BinderInfo.implicit => "{"++ core ++ "}"
      | BinderInfo.strictImplicit => "{{ "++ core ++ "}}"
      | BinderInfo.instImplicit =>
        if (`inst).isPrefixOf n then s!"[{typeString}]"
          else s!"[{core}]"
      | BinderInfo.default => s!"({core})"
      let tail : String ←
        withLocalDecl `func BinderInfo.default e fun func =>
          withLocalDecl n bi t fun arg => do
            let fx := mkAppN func #[arg]
            let newType ← inferType fx
            uncurriedView k newType
      return " " ++ argString ++ tail
    | _ => do return " : " ++ (← e.view)

elab "uncurry2" e:term : term => do
  let e ← Term.elabTerm e none
  let e ← uncurriedView 2 e
  return mkStrLit e

universe u


def translateViewM (s: String)
  (server: ChatServer := ChatServer.openAI)(params : ChatParams := {}) (numSim: Nat := 8) : TermElabM String := do
  logTimed "starting translation"
  let (js, _) ← getLeanCodeJson  s server params
        (numSim := numSim)
  let output ← GPT.exprStrsFromJson js
  trace[Translate.info] m!"{output}"
  let e? ← bestElab? output
  match e? with
  | Except.ok (e, _) => do
    e.view
  | Except.error _ => do
    let stx ← output.findSomeM? <| fun s => do
      let exp ←  parseThm4 s
      let elab? ← elabThm4 s
      match elab? with
      | Except.ok expr => trace[Translate.info] m!"elaborated: {expr}"
      | Except.error e => trace[Translate.warning] m!"elaboration failed: {e} for {s}"
      return exp.toOption |>.map fun stx => stx.reprint.get!
    return stx.getD "False"


/-- view of string in core; to be run with Snapshot.runCore
-/
def translateViewCore (s: String) : CoreM String :=
  (translateViewM s).run'.run'

syntax (name := ltrans) "l!" str : term

open PrettyPrinter

@[term_elab ltrans] def ltransImpl : Term.TermElab :=
  fun stx _ => do
  match stx with
  | `(l! $s:str) =>
  let s := s.getString
  let (js, _) ←
    getLeanCodeJson  s (← chatServer) (← chatParams)
  let e ← jsonToExpr' js
  logTimed "obtained expression"
  let stx' ← delab e
  logTimed "obtained syntax"
  TryThis.addSuggestion stx stx'
  logTimed "added suggestion"
  return e
  | _ => throwUnsupportedSyntax
