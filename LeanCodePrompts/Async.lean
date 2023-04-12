import Lean
import LeanCodePrompts.Utils
import Aesop
open Lean Meta Elab Term Tactic Core

/-!
# Asynchronous tactic execution

We provide methods for executing tactics asynchronously. These are modelled on the `checkpoint` tactic.

* We run tactics and store resulting states in a cache.
* We use a more robust key than that for checkpoints.

## Indexing

We index by

* the current goal
* the current local context converted into lists

## Running tactics

We have a function of type `TacticM Unit` which

* executes the tactic
* stores the resulting states in the cache

## Fetching results

* We fetch final states based on the current goal and local context.
* We then restore these states.
-/

deriving instance BEq for LocalDecl
deriving instance Hashable for LocalDecl
deriving instance Repr for LocalDecl


structure GoalKey where
  goal : Expr
  lctx : List <| Option LocalDecl
deriving BEq, Hashable, Repr

structure ProofState where
  core   : Core.State
  meta   : Meta.State
  term   : Option Term.State
  preScript : String
  script: Syntax
  tailPos? : Option String.Pos

def GoalKey.get : TacticM GoalKey := do
  let lctx ← getLCtx
  let goal ← getMainTarget
  pure { goal := goal, lctx := lctx.decls.toList }

initialize tacticCache : IO.Ref (HashMap GoalKey ProofState) 
        ← IO.mkRef <| HashMap.empty

initialize tacticPosCache : IO.Ref (HashMap CacheKey ProofState) 
        ← IO.mkRef <| HashMap.empty

def putTactic (key : GoalKey) (s : ProofState) : MetaM Unit := do
  tacticCache.modify fun m => m.insert key s

def putPosTactic (key : CacheKey) (s : ProofState) : MetaM Unit := do
  tacticPosCache.modify fun m => m.insert key s


def getStates (key : GoalKey) : TacticM (Option ProofState) := do  
  let m ← tacticCache.get
  return m.find? key

abbrev PolyTacticM :=  MVarId → 
  (MetaM <| (Option Term.State) × Syntax)

/- Abstracted to possibly replace by Aesop search -/
def runTacticCode (tacticCode : Syntax)  : PolyTacticM := fun goal ↦ do
    let (goals, ts) ← runTactic  goal tacticCode 
    unless goals.isEmpty do
        throwError m!"Tactic not finishing, remaining goals:\n{goals}"
    pure (some ts, tacticCode)

def getMsgTactic?  : CoreM <| Option Syntax := do
  let msgLog ← Core.getMessageLog  
  let msgs := msgLog.toList
  let mut tac? : Option Syntax := none
  for msg in msgs do
    let msg := msg.data
    let msg ← msg.toString 
    let msg := msg.replace "Try this:" "" |>.trim
    let parsedMessage := Parser.runParserCategory (←getEnv)  `tactic msg
    match parsedMessage with
    | Except.ok tac => 
      tac? := some tac
    | _ =>
      logInfo m!"failed to parse tactic {msg}"
  return tac?

def runTacticCodeMsg (tacticCode : Syntax)  : PolyTacticM := fun goal ↦ do
    let (goals, ts) ← runTactic  goal tacticCode 
    unless goals.isEmpty do
        throwError m!"Tactic not finishing, remaining goals:\n{goals}"
    let tac? ← getMsgTactic?
    let code := match tac? with
    | none => tacticCode
    | some tac => tac
    pure (some ts, code)

def PolyTacticM.ofTactic (tacticCode : Syntax) : PolyTacticM := runTacticCodeMsg tacticCode


def runAndCacheM (polyTac : PolyTacticM) (goal: MVarId) (target : Expr) (pos? tailPos? : Option String.Pos)(preScript: String) : MetaM Unit := 
  goal.withContext do 
    let lctx ← getLCtx
    let key : GoalKey := { goal := target, lctx := lctx.decls.toList }
    let core₀ ← getThe Core.State
    let meta₀ ← getThe Meta.State
    try
      let (ts, script) ← polyTac goal 
      let s : ProofState := {
      core   := (← getThe Core.State)
      meta   := (← getThe Meta.State)
      term   := ts
      preScript := preScript
      script := script
      tailPos? := tailPos?
      }     
      putTactic key s
      match pos? with
      | none => pure ()
      | some pos => 
        let ckey : CacheKey := { pos := pos, mvarId := goal}
        putPosTactic ckey s
    catch _ =>
    set core₀
    set meta₀

-- #check MetaM.run'

def runAndCacheIO (polyTac : PolyTacticM) (goal: MVarId) (target : Expr) (pos? tailPos?: Option String.Pos)(preScript: String) 
  (mctx : Meta.Context) (ms : Meta.State) 
  (cctx : Core.Context) (cs: Core.State) : IO Unit :=
  let eio := 
  (runAndCacheM polyTac goal target pos? tailPos? preScript).run' mctx ms |>.run' cctx cs
  let res := eio.runToIO'
  res

syntax (name := launchTactic) "launch" tacticSeq : tactic

@[tactic launchTactic] def elabLaunchTactic : Tactic := fun stx => 
  withMainContext do
  focus do
  match stx with
  | `(tactic| launch $tacticCode) => do
    let s ← saveState
    let ts ← getThe Term.State
    let ioSeek := runAndCacheIO 
      (PolyTacticM.ofTactic tacticCode)  (← getMainGoal) (← getMainTarget) 
              stx.getPos? stx.getTailPos? stx.reprint.get!  
              (← readThe Meta.Context) (← getThe Meta.State ) 
              (← readThe Core.Context) (← getThe Core.State)
    let _ ← ioSeek.asTask
    set ts
    s.restore
  | _ => throwUnsupportedSyntax

syntax (name := bgTactic) "bg" tacticSeq : tactic

@[tactic bgTactic] def elabBgTactic : Tactic := fun stx => 
  withMainContext do
  focus do
  match stx with
  | `(tactic| bg $tacticCode) => do
    let s ← saveState
    let ts ← getThe Term.State
    let ioSeek : IO Unit := runAndCacheIO 
      (PolyTacticM.ofTactic tacticCode)  (← getMainGoal) (← getMainTarget) 
              stx.getPos? stx.getTailPos? stx.reprint.get!  
              (← readThe Meta.Context) (← getThe Meta.State ) 
              (← readThe Core.Context) (← getThe Core.State)
    let _ ← ioSeek.asTask
    set ts
    s.restore
    admitGoal <| ← getMainGoal
  | _ => throwUnsupportedSyntax

def fetchProof : TacticM Unit := 
  focus do
  let key ← GoalKey.get
  let goal ← getMainGoal
  match (← getStates key) with
  | none => throwTacticEx `fetch goal  m!"No cached result found for the goal : {← ppExpr <| key.goal }."
  | some s => do
    set s.core
    set s.meta
    match s.term with
    | none => pure ()
    | some ts =>
      set ts 
    setGoals []
    logInfo m!"Try this: {indentD s.script}"

elab "fetch_proof" : tactic => 
  fetchProof

macro "auto" : tactic => do
  `(tactic|aesop?)

-- the first is to trigger the search
syntax (name := autoLaunch) "#by" : term
syntax (name:= autoBy) "#by#" (tacticSeq)? : term

@[term_elab autoLaunch] def elabAutoLaunch : TermElab := fun stx expectedType? => do
  match expectedType? with
  | none => throwError "could not infer expected type"
  | some type => do
    let mvarId ← mkFreshMVarId
    let mvar := mkMVar mvarId
    let check ← Meta.isProp type 
    if check then
      let tacticCode ← `(tactic|auto) 
      let ioSeek : IO Unit := 
      runAndCacheIO (PolyTacticM.ofTactic tacticCode)  mvarId type
              stx.getPos? stx.getTailPos? stx.reprint.get!  
              (← readThe Meta.Context) (← getThe Meta.State ) 
              (← readThe Core.Context) (← getThe Core.State)
      let _ ← ioSeek.asTask
    admitGoal mvarId
    return mvar


-- for use within tactics
syntax "#by" : tactic
syntax "#by#" (tacticSeq)? : tactic

example : 1 = 1 := by checkpoint rfl

#check Meta.isProp
#check Parser.runParserCategory
#check Syntax.updateTrailing