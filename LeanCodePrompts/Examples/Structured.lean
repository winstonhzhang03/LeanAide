import LeanCodePrompts.ChatClient
import LeanAide.StructToLean
import LeanAide.TranslateM
open Lean Json LeanAide.Meta
namespace Structured

def server := ChatServer.openAI

def eg1 := server.structuredProofFromStatement "There are infinitely many odd numbers."

def eg2 := server.structuredProofFromStatement "Every subgroup of a cyclic group is cyclic."

def eg3 : TranslateM (Array (String × Array Json) × Format) := do
  let jsArr ← server.structuredProofFromStatement "Every subgroup of an abelian group is abelian."
  let js := jsArr.get! 0 |>.2.get! 0
  let doc ←  mathDocumentCode (doc := js) (pb := LeanAide.Meta.PromptExampleBuilder.embedBuilder 8 6 6)
  return (jsArr, doc)

end Structured


/-
#[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"contradiction":
      {"proof":
       [{"let":
         {"variable": "O",
          "value": "{o_1, o_2, \\ldots, o_n}",
          "kind": "set of all odd numbers"}},
        {"assert":
         {"deductions":
          [{"deduction":
            {"in_context": true, "deduced_from": "definition of odd numbers"}}],
          "claim":
          "Every odd number is of the form 2k + 1 for some integer k."}},
        {"let":
         {"variable": "m",
          "value": "2 \\cdot \\max(o_1, o_2, \\ldots, o_n) + 3",
          "properties": "greater than any element in O"}},
        {"assert":
         {"proof_method": "can be expressed in the form 2k + 1",
          "deductions":
          [{"deduction":
            {"instantiations":
             [{"instantiation": "k = \\max(o_1, o_2, \\ldots, o_n) + 1"}],
             "in_context": true,
             "deduced_from": "definition of odd numbers"}}],
          "claim": "m is an odd number."}},
        {"assert": {"claim": "m is not in the set O."}},
        {"assert":
         {"claim":
          "There is a contradiction in the assumption that O contains all odd numbers."}}],
       "assumption": "There are only finitely many odd numbers."}},
     {"conclude": {"claim": "There are infinitely many odd numbers."}}],
    "hypothesis": [],
    "conclusion": "There are infinitely many odd numbers."}}]}]

-/
-- #eval eg1

-- Before tweak for instantiation
/-
#[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"cases":
      {"split_kind": "condition",
       "proof_cases":
       [{"case":
         {"proof":
          [{"assert": {"proof_method": "direct", "claim": "H is cyclic"}}],
          "condition": "H is trivial"}},
        {"case":
         {"proof":
          [{"assert":
            {"deductions":
             [{"deduction":
               {"in_context": true, "deduced_from": "H ⊆ G and G = <g>"}}],
             "claim":
             "each h in H can be expressed as h = g^k for some integer k"}},
           {"let":
            {"variable": "n",
             "value": "smallest positive integer such that g^n ∈ H"}},
           {"assert":
            {"proof_method": "direct",
             "deductions":
             [{"deduction":
               {"instantiations": [{"instantiation": "(g^n)^m = g^{nm} ∈ H"}],
                "in_context": true,
                "deduced_from":
                "H is a subgroup and closed under group operation"}}],
             "claim": "H = <g^n>",
             "calculations":
             [{"calculation_step": {"equation": {"inline": "<g^n> ⊆ H"}}}]}},
           {"assert":
            {"proof_method": "division algorithm",
             "missing":
             [{"missing":
               "Show that g^r being in H and n being minimal implies r=0"}],
             "claim": "H ⊆ <g^n>",
             "calculations":
             [{"calculation_step":
               {"justification": "division algorithm",
                "equation": {"inline": "k = qn + r where 0 ≤ r < n"}}},
              {"calculation_step":
               {"equation": {"inline": "g^k = g^{qn}g^r = (g^n)^q g^r"}}}]}},
           {"conclude": {"claim": "H = <g^n>"}}],
          "condition": "H is non-trivial"}}],
       "on": "H being trivial"}}],
    "hypothesis":
    [{"let": {"variable": "G", "value": "<g>", "kind": "cyclic group"}},
     {"assume": "H is a subgroup of G"}],
    "conclusion": "H is cyclic"}}]}]

-/


/-
#[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"cases":
      {"split_kind": "condition",
       "proof_cases":
       [{"case":
         {"proof":
          [{"assert":
            {"proof_method": "trivial",
             "claim": "H is cyclic, generated by e"}}],
          "condition": "H = {e}"}},
        {"case":
         {"proof":
          [{"let":
            {"variable": "m",
             "properties": "least integer such that g^m ∈ H",
             "kind": "positive integer"}},
           {"assert":
            {"proof_method": "direct proof",
             "missing": [{"missing": "By the minimality of m, r = 0"}],
             "deductions":
             [{"deduction":
               {"instantiations":
                [{"instantiation":
                  "g^m ∈ H and (g^m)^k = g^{mk} ∈ H for all k ∈ ℤ"}],
                "in_context": true,
                "deduced_from": "m is the smallest integer such that g^m ∈ H"}},
              {"deduction":
               {"instantiations":
                [{"instantiation": "k = mq + r with 0 ≤ r < m"}],
                "in_context": false,
                "deduced_from": "Division Algorithm"}}],
             "claim": "H = ⟨g^m⟩",
             "calculations":
             [{"calculation_step": {"equation": {"step": "g^k = (g^m)^q g^r"}}},
              {"calculation_step":
               {"equation": {"inline": "g^r = g^k (g^m)^{-q} ∈ H"}}}]}},
           {"conclude": {"claim": "H = ⟨g^m⟩"}}],
          "condition": "H ≠ {e}"}}],
       "on": "H",
       "missing": [{"missing": "Ensure that all cases of H are considered"}]}}],
    "hypothesis":
    [{"let":
      {"variable": "G",
       "properties": "generated by element g",
       "kind": "cyclic group"}},
     {"let": {"variable": "H", "kind": "subgroup of G"}}],
    "conclusion": "H is cyclic."}}]}]

-/

-- Removed instantiation
/-
#[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"assume":
      "Every element h in H can be written as h = g^k for some integer k."},
     {"let":
      {"variable": "K",
       "value": "\\{ k \\in \\mathbb{Z} \\mid g^k \\in H \\}",
       "kind": "set"}},
     {"assert":
      {"deductions":
       [{"deduction":
         {"proved_earlier": false,
          "deduced_from": "H is a subgroup, identity e = g^0 is in H."}}],
       "claim": "0 \\in K"}},
     {"assert":
      {"proof_method": "K is closed under subtraction and contains negatives.",
       "claim": "K is a subgroup of \\mathbb{Z}",
       "calculations":
       [{"calculation_step":
         {"equation": {"step": "a, b \\in K \\Rightarrow g^a, g^b \\in H"}}},
        {"calculation_step":
         {"equation":
          {"continuation":
           "g^{a-b} = g^a g^{-b} \\in H \\Rightarrow a-b \\in K"}}},
        {"calculation_step":
         {"equation":
          {"step":
           "a \\in K \\Rightarrow g^a \\in H \\Rightarrow g^{-a} = (g^a)^{-1} \\in H, -a \\in K"}}}]}},
     {"assert":
      {"deductions":
       [{"deduction":
         {"proved_earlier": false,
          "deduced_from": "K is a subgroup of \\mathbb{Z}"}}],
       "claim": "K is cyclic"}},
     {"let":
      {"variable": "d", "properties": "smallest positive generator of K"}},
     {"assert":
      {"proof_method":
       "Every element h = g^k in H can be expressed as h = (g^d)^m for some integer m.",
       "claim": "H = <g^d>",
       "calculations":
       [{"calculation_step":
         {"equation":
          {"inline":
           "k \\in K \\Rightarrow k = md \\text{ for some integer } m"}}},
        {"calculation_step":
         {"equation": {"inline": "h = g^k = g^{md} = (g^d)^m"}}}]}},
     {"conclude": {"claim": "H is cyclic."}}],
    "hypothesis":
    [{"let": {"variable": "G", "value": "<g>", "kind": "cyclic group"}},
     {"let": {"variable": "H", "properties": "H ≤ G, subgroup of G"}}],
    "conclusion": "H is cyclic"}}]}]

-/


/-
#[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"remark":
      "Let G = <g> be a cyclic group generated by an element g. Suppose H is a subgroup of G. Our aim is to show that H is cyclic."},
     {"let":
      {"variable": "S",
       "value": "{ k ∈ ℤ | g^k ∈ H }",
       "properties": "of all such exponents k corresponding to elements in H",
       "kind": "set"}},
     {"assert":
      {"deductions":
       [{"deduction":
         {"proved_earlier": false,
          "deduced_from": "identity element e = g^0 belongs to H"}}],
       "claim": "0 ∈ S"}},
     {"let":
      {"variable": "d",
       "properties": "smallest positive element in S",
       "kind": "integer"}},
     {"assert":
      {"proof_method": "by division algorithm",
       "claim": "for any k ∈ S, k = qd + r where q ∈ ℤ and 0 ≤ r < d"}},
     {"assert":
      {"deductions":
       [{"deduction":
         {"proved_earlier": false,
          "deduced_from": "(g^d)^q ∈ H since g^d ∈ H and H is a subgroup"}}],
       "claim": "g^k = (g^d)^q g^r and g^r ∈ H"}},
     {"assume": "r ≠ 0 implies contradiction to the minimality of d"},
     {"assert":
      {"proof_method": "by contradiction", "claim": "r = 0, hence k = qd"}},
     {"assert":
      {"deductions":
       [{"deduction":
         {"proved_earlier": true,
          "deduced_from": "every g^k ∈ H can be expressed as g^(qd)"}}],
       "claim": "H = <g^d>"}},
     {"conclude": {"claim": "Every subgroup H of a cyclic group G is cyclic"}}],
    "hypothesis":
    [{"let":
      {"variable": "G",
       "properties": "generated by an element g",
       "kind": "cyclic group"}},
     {"let": {"variable": "H", "kind": "subgroup of G"}}],
    "conclusion": "H is cyclic"}}]}]

-/

-- This is after `deduction` instructions included splitting and separating justifications as `assert`.
/-
#[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"def": {"term": "S", "statement": "S = { k ∈ ℤ | g^k ∈ H }"}},
     {"assert":
      {"proof_method": "H contains the identity element, implying 0 ∈ S",
       "claim": "S is nonempty"}},
     {"assert":
      {"proof_method": "By the well-ordering principle",
       "claim": "S contains a smallest positive integer d"}},
     {"let":
      {"variable": "<anonymous>", "value": "g^d", "kind": "element of H"}},
     {"assert": {"proof_method": "since g^d ∈ H", "claim": "⟨g^d⟩ ⊆ H"}},
     {"assume": "Suppose g^k ∈ H"},
     {"assert":
      {"proof_method": "Using the division algorithm",
       "claim": "g^k = (g^d)^q ⋅ g^r for some q ∈ ℤ and 0 ≤ r < d"}},
     {"assert":
      {"proof_method": "since g^k and (g^d)^q are both in H",
       "claim": "g^r ∈ H"}},
     {"assert":
      {"proof_method": "By minimality of d, since 0 ≤ r < d",
       "claim": "r = 0"}},
     {"assert": {"proof_method": "Since r = 0", "claim": "g^k = (g^d)^q"}},
     {"assert":
      {"proof_method": "because every g^k ∈ H is a power of g^d",
       "claim": "H ⊆ ⟨g^d⟩"}},
     {"conclude": {"claim": "H = ⟨g^d⟩"}}],
    "hypothesis":
    [{"let":
      {"variable": "G",
       "properties": "generated by an element g",
       "kind": "cyclic group"}},
     {"let":
      {"variable": "H",
       "properties": "H is a subgroup of G",
       "kind": "subgroup"}}],
    "conclusion": "H is cyclic"}}]}]

-/
-- #eval eg2

/-
Full statement: Let G be a abelian group  . Let H be a subgroup of G  . Then, H is an abelian group.
Type: (some {G : Type u_1} → [inst : CommGroup G] → (H : Subgroup G) → CommGroup ↥H)
Processing {"remark": "We need to show that for any a, b \\in H, ab = ba."}
Head tactics
Processing {"assert":
 {"proof_method": "Since H is a subgroup of G.",
  "claim": "For any a, b \\in H, we have a, b \\in G."}}
Full statement: Let G be a abelian group  . Let H be a subgroup of G  . Then, For any a, b \in H, we have a, b \in G.
Type: none
Head tactics
Processing {"assert":
 {"deduced_from_results":
  [{"deduced_from":
    {"result_used": "G is abelian, so for any a, b \\in G, ab = ba.",
     "proved_earlier": true}}],
  "claim": "For any a, b \\in H, ab = ba."}}
Full statement: Let G be a abelian group  . Let H be a subgroup of G  . Then, For any a, b \in H, ab = ba.
Type: (some (∀ {G : Type u_1} [inst : CommGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a * b = b * a))
Head tactics
have : ∀ {G : Type u_1} [inst : CommGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a * b = b * a := by auto?[]
Processing {"conclude": {"claim": "H is abelian."}}
Head tactics
have : H is abelian. := by auto?
Proof term: by
  have : ∀ {G : Type u_1} [inst : CommGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a * b = b * a := by auto?[]
  have : H is abelian. := by auto?
  auto?
parsed JSON: {"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"remark": "We need to show that for any a, b \\in H, ab = ba."},
     {"assert":
      {"proof_method": "Since H is a subgroup of G.",
       "claim": "For any a, b \\in H, we have a, b \\in G."}},
     {"assert":
      {"deduced_from_results":
       [{"deduced_from":
         {"result_used": "G is abelian, so for any a, b \\in G, ab = ba.",
          "proved_earlier": true}}],
       "claim": "For any a, b \\in H, ab = ba."}},
     {"conclude": {"claim": "H is abelian."}}],
    "hypothesis":
    [{"let": {"variable": "G", "kind": "abelian group"}},
     {"let": {"variable": "H", "kind": "subgroup of G"}}],
    "conclusion": "H is an abelian group."}}]}

Found theorem

error: Elaboration errors : unknown identifier 'AbelianGroup' ; identifiers [G, u_1, inst, AbelianGroup, G, H, Subgroup, G, a, b, G, a, H, b, H, a, G, b, G] (during elaboration) for ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G for ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G; front-end errors: [invalid binder annotation, type is not a class instance
   ?m.12
 use the command `set_option checkBinderAnnotations false` to disable the check,
 function expected at
   AbelianGroup
 term has type
   ?m.6,
 unused universe parameter 'u_1']

error: Elaboration errors : unknown identifier 'AbelianGroup' ; identifiers [G, u_1, inst, AbelianGroup, G, H, Subgroup, G, a, b, G, a, H, b, H, a, G, b, G] (during elaboration) for ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G for ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G; front-end errors: [invalid binder annotation, type is not a class instance
   ?m.12
 use the command `set_option checkBinderAnnotations false` to disable the check,
 function expected at
   AbelianGroup
 term has type
   ?m.6,
 unused universe parameter 'u_1']

error: Elaboration errors : unknown identifier 'AbelianGroup' ; identifiers [G, u_1, inst, AbelianGroup, G, H, Subgroup, G, a, b, G, a, H, b, H, a, G, b, G] (during elaboration) for ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G for ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G; front-end errors: [invalid binder annotation, type is not a class instance
   ?m.12
 use the command `set_option checkBinderAnnotations false` to disable the check,
 function expected at
   AbelianGroup
 term has type
   ?m.6,
 unused universe parameter 'u_1']

error: Elaboration errors : unknown identifier 'AbelianGroup' ; identifiers [G, u_1, inst, AbelianGroup, G, H, Subgroup, G, a, b, G, a, H, b, H, a, G, b, G] (during elaboration) for ∀ {G : Type u_1} [inst : AbelianGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G for ∀ {G : Type u_1} [inst : AbelianGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G; front-end errors: [invalid binder annotation, type is not a class instance
   ?m.12
 use the command `set_option checkBinderAnnotations false` to disable the check,
 function expected at
   AbelianGroup
 term has type
   ?m.6,
 unused universe parameter 'u_1']

error: Elaboration errors : unknown identifier 'AbelianGroup' ; identifiers [G, u_1, inst, AbelianGroup, G, H, Subgroup, G, a, b, G, a, H, b, H, a, G, b, G] (during elaboration) for ∀ {G : Type u_1} [inst : AbelianGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G for ∀ {G : Type u_1} [inst : AbelianGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G; front-end errors: [invalid binder annotation, type is not a class instance
   ?m.12
 use the command `set_option checkBinderAnnotations false` to disable the check,
 function expected at
   AbelianGroup
 term has type
   ?m.6,
 unused universe parameter 'u_1']

no elaboration found for Let G be a abelian group  . Let H be a subgroup of G  . Then, For any a, b \in H, we have a, b \in G.

outputs: [∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G,
 ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G,
 ∀ {G : Type u_1} [inst : AbelianGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G,
 ∀ {G : Type u_1} [inst : AbelianGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G,
 ∀ {G : Type u_1} [inst : AbelianGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a ∈ G ∧ b ∈ G]

(#[("Let \\( G \\) be an abelian group, and let \\( H \\) be a subgroup of \\( G \\). We need to show that \\( H \\) is abelian, i.e., for any \\( a, b \\in H \\), \\( ab = ba \\).\n\nSince \\( H \\) is a subgroup of \\( G \\), it follows that for any \\( a, b \\in H \\), we also have \\( a, b \\in G \\). Given that \\( G \\) is an abelian group, the operation in \\( G \\) is commutative, meaning for any \\( a, b \\in G \\), \\( ab = ba \\).\n\nThus, for any \\( a, b \\in H \\), since \\( a, b \\in G \\) and \\( G \\) is abelian, we have:\n\n\\[\nab = ba\n\\]\n\nTherefore, \\( H \\) is abelian.",
    #[{"math_document":
       [{"theorem":
         {"proved": true,
          "proof":
          [{"remark": "We need to show that for any a, b \\in H, ab = ba."},
           {"assert":
            {"proof_method": "Since H is a subgroup of G.",
             "claim": "For any a, b \\in H, we have a, b \\in G."}},
           {"assert":
            {"deduced_from_results":
             [{"deduced_from":
               {"result_used": "G is abelian, so for any a, b \\in G, ab = ba.",
                "proved_earlier": true}}],
             "claim": "For any a, b \\in H, ab = ba."}},
           {"conclude": {"claim": "H is abelian."}}],
          "hypothesis":
          [{"let": {"variable": "G", "kind": "abelian group"}},
           {"let": {"variable": "H", "kind": "subgroup of G"}}],
          "conclusion": "H is an abelian group."}}]}])],
 #["theorem aux.6439339685659580310 {G : Type u_1} [inst : CommGroup G] (H : Subgroup G) : CommGroup ↥H :=\n  by\n  have : ∀ {G : Type u_1} [inst : CommGroup G] {H : Subgroup G} {a b : G}, a ∈ H → b ∈ H → a * b = b * a := by auto?[]\n  have : H is abelian. := by auto?\n  auto?"])

-/


/-
(#[(Let \( G \) be an abelian group, and let \( H \) be a subgroup of \( G \). We need to show that \( H \) is also abelian, which means we must show that for any elements \( a, b \in H \), the equation \( ab = ba \) holds.

Since \( G \) is abelian, we have that for any elements \( x, y \in G \), it holds that \( xy = yx \). In particular, since \( a, b \) are elements of \( H \) and \( H \subseteq G \), they are also elements of \( G \).

Therefore, for \( a, b \in H \), we have \( ab = ba \), since \( ab = ba \) holds for all elements in the group \( G \).

Thus, \( H \) is abelian., #[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"assume": "a, b \\in H"},
     {"assert":
      {"deduced_from_results":
       [{"deduced_from":
         {"result_used": "G is abelian, so ab = ba for all a, b \\in G",
          "proved_earlier": false}}],
       "claim": "ab = ba"}},
     {"conclude": {"claim": "H is abelian"}}],
    "hypothesis":
    [{"let": {"variable": "G", "kind": "abelian group"}},
     {"let": {"variable": "H", "kind": "subgroup of G"}}],
    "conclusion": "H is abelian"}}]}])],
theorem aux.1430888143716163738 {G : Type u_1} [inst : CommGroup G] {H : Subgroup G} : CommGroup ↥H :=
  by
  have : ∀ {G : Type u_1} [inst : CommGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a * b = b * a := by auto?[]
  have : H is abelian := by auto?
  auto?)

-/

/-
(#[(Let \( G \) be an abelian group, and let \( H \) be a subgroup of \( G \). We must show that \( H \) is abelian.

Take any \( a, b \in H \). Since \( H \subseteq G \) and \( G \) is an abelian group, the operation in \( G \) satisfies \( a \cdot b = b \cdot a \) for any \( a, b \in G \).

Thus, specifically for \( a, b \in H \), we have \( a \cdot b = b \cdot a \). Therefore, \( H \) is abelian., #[{"math_document":
 [{"theorem":
   {"proved": true,
    "proof":
    [{"assume": "Take any a, b in H"},
     {"assert":
      {"deduced_from_results":
       [{"deduced_from":
         {"result_used": "G is abelian", "proved_earlier": true}}],
       "claim": "a * b = b * a"}},
     {"conclude": {"claim": "H is abelian"}}],
    "hypothesis":
    [{"let": {"variable": "G", "kind": "abelian group"}},
     {"let": {"variable": "H", "kind": "subgroup of G"}}],
    "conclusion": "H is abelian"}}]}])],
theorem aux.6439339685659580310 {G : Type u_1} [inst : CommGroup G] (H : Subgroup G) : CommGroup ↥H :=
  by
  have : ∀ {G : Type u_1} [inst : CommGroup G] (H : Subgroup G) {a b : G}, a ∈ H → b ∈ H → a * b = b * a := by auto?[]
  have : H is abelian := by auto?
  auto?)

-/
-- #eval Structured.eg3

def parseEg : TranslateM <| Array Format := do
  let source ← IO.FS.readFile "resources/mathdoc.json"
  match Json.parse source with
  | Except.error e => throwError s!"Failed to parse JSON: {e}"
  | Except.ok js => do
    let doc ←
      mathDocumentCommands (doc := js)
        (pb := LeanAide.Meta.PromptExampleBuilder.embedBuilder 5 5 5)
    let doc' ←  doc.mapM fun c => PrettyPrinter.ppCommand c
    return doc'

-- #eval parseEg

def egJson : TranslateM <| Array String := do
  let source ← IO.FS.readFile "resources/mathdoc.json"
  match Json.parse source with
  | Except.error e => throwError s!"Failed to parse JSON: {e}"
  | Except.ok js =>
    match js.getKV? with
    | some ("math_document", .arr jsArr) =>
      let js := jsArr.get! 0
      match js.getKV? with
      | some ("theorem", js) =>
        match js.getObjValAs? (Array Json) "hypothesis" with
        | Except.ok hyps =>
          hyps.filterMapM fun hyp => contextStatementOfJson hyp
        | _ => throwError "Expected JSON object with key 'hypothesis'"
      | _ => throwError "Expected JSON object with key 'theorem'"
    | _ => throwError "Expected JSON object with key 'math_document'"

#eval egJson
