
open Il
module G = Meta_ast

(* generated by ocamltarzan with: camlp4o -o /tmp/yyy.ml -I pa/ pa_type_conv.cmo pa_vof.cmo  pr_o.cmo /tmp/xxx.ml  *)

let vof_tok v = Meta_parse_info.vof_info_adjustable_precision v
  
let vof_wrap _of_a (v1, v2) =
  let v1 = _of_a v1 and v2 = vof_tok v2 in Ocaml.VTuple [ v1; v2 ]

let vof_bracket of_a (_t1, x, _t2) =
  of_a x

let vof_sid = Ocaml.vof_int

  
let vof_ident v = vof_wrap Ocaml.vof_string v
  
let vof_var (v1, v2) =
  let v1 = vof_ident v1 and v2 = vof_sid v2 in Ocaml.VTuple [ v1; v2 ]
  
let vof_name (v1, v2) =
  let v1 = vof_ident v1 and v2 = vof_sid v2 in Ocaml.VTuple [ v1; v2 ]
  
let rec vof_lval { base = v_base; offset = v_offset } =
  let bnds = [] in
  let arg = vof_offset v_offset in
  let bnd = ("offset", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_base v_base in
  let bnd = ("base", arg) in let bnds = bnd :: bnds in Ocaml.VDict bnds
and vof_base =
  function
  | Var v1 -> let v1 = vof_var v1 in Ocaml.VSum (("Var", [ v1 ]))
  | VarSpecial v1 ->
      let v1 = vof_wrap vof_var_special v1
      in Ocaml.VSum (("VarSpecial", [ v1 ]))
  | Mem v1 -> let v1 = vof_exp v1 in Ocaml.VSum (("Mem", [ v1 ]))

and vof_var_special =
  function
  | This -> Ocaml.VSum (("This", []))
  | Super -> Ocaml.VSum (("Super", []))
  | Self -> Ocaml.VSum (("Self", []))
  | Parent -> Ocaml.VSum (("Parent", []))

and vof_offset =
  function
  | NoOffset -> Ocaml.VSum (("NoOffset", []))
  | Dot v1 -> let v1 = vof_ident v1 in Ocaml.VSum (("Dot", [ v1 ]))
  | Index v1 -> let v1 = vof_exp v1 in Ocaml.VSum (("Index", [ v1 ]))

and vof_exp { e = v_e; eorig = v_eorig } =
  let bnds = [] in
  let arg = G.vof_expr v_eorig in
  let bnd = ("eorig", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_exp_kind v_e in
  let bnd = ("e", arg) in let bnds = bnd :: bnds in 
  if !Meta_parse_info._current_precision.Meta_parse_info.full_info
  then Ocaml.VDict bnds
  else arg

and vof_exp_kind =
  function
  | Literal v1 ->
      let v1 = G.vof_literal v1 in Ocaml.VSum (("Literal", [ v1 ]))
  | Composite ((v1, v2)) ->
      let v1 = vof_composite_kind v1
      and v2 = vof_bracket (Ocaml.vof_list vof_exp) v2
      in Ocaml.VSum (("Composite", [ v1; v2 ]))
  | Record v1 ->
      let v1 =
        Ocaml.vof_list
          (fun (v1, v2) ->
             let v1 = vof_ident v1
             and v2 = vof_exp v2
             in Ocaml.VTuple [ v1; v2 ])
          v1
      in Ocaml.VSum (("Record", [ v1 ]))
  | Lvalue v1 -> let v1 = vof_lval v1 in Ocaml.VSum (("Lvalue", [ v1 ]))
  | Cast ((v1, v2)) ->
      let v1 = G.vof_type_ v1
      and v2 = vof_exp v2
      in Ocaml.VSum (("Cast", [ v1; v2 ]))
  | Operator (v1, v2) ->
      let v1 = vof_wrap G.vof_arithmetic_operator v1 in
      let v2 = Ocaml.vof_list vof_exp v2 in
      Ocaml.VSum (("Operator", [ v1; v2 ]))
and vof_composite_kind =
  function
  | CTuple -> Ocaml.VSum (("CTuple", []))
  | CArray -> Ocaml.VSum (("CArray", []))
  | CList -> Ocaml.VSum (("CList", []))
  | CSet -> Ocaml.VSum (("CSet", []))
  | CDict -> Ocaml.VSum (("CDict", []))
  | Constructor v1 ->
      let v1 = vof_name v1 in Ocaml.VSum (("Constructor", [ v1 ]))
  
let vof_argument v = vof_exp v

let rec vof_instr { i = v_i; iorig = v_iorig } =
  let bnds = [] in
  let arg = G.vof_expr v_iorig in
  let bnd = ("iorig", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_instr_kind v_i in
  let bnd = ("i", arg) in 
  let bnds = bnd :: bnds in 
  if !Meta_parse_info._current_precision.Meta_parse_info.full_info
  then Ocaml.VDict bnds
  else arg

and vof_instr_kind =
  function
  | Assign ((v1, v2)) ->
      let v1 = vof_lval v1
      and v2 = vof_exp v2
      in Ocaml.VSum (("Assign", [ v1; v2 ]))
  | AssignAnon ((v1, v2)) ->
      let v1 = vof_lval v1
      and v2 = vof_anonymous_entity v2
      in Ocaml.VSum (("AssignAnon", [ v1; v2 ]))
  | Call ((v1, v2, v3)) ->
      let v1 = Ocaml.vof_option vof_lval v1
      and v2 = vof_exp v2
      and v3 = Ocaml.vof_list vof_argument v3
      in Ocaml.VSum (("Call", [ v1; v2; v3 ]))
  | CallSpecial ((v1, v2, v3)) ->
      let v1 = Ocaml.vof_option vof_lval v1
      and v2 = vof_wrap vof_special_kind v2
      and v3 = Ocaml.vof_list vof_argument v3
      in Ocaml.VSum (("CallSpecial", [ v1; v2; v3 ]))
and vof_special_kind =
  function
  | ForeachNext -> Ocaml.VSum (("ForeachNext", []))
  | ForeachHasNext -> Ocaml.VSum (("ForeachHasNext", []))
  | Eval -> Ocaml.VSum (("Eval", []))
  | New -> Ocaml.VSum (("New", []))
  | Typeof -> Ocaml.VSum (("Typeof", []))
  | Instanceof -> Ocaml.VSum (("Instanceof", []))
  | Sizeof -> Ocaml.VSum (("Sizeof", []))
  | Concat -> Ocaml.VSum (("Concat", []))
  | Spread -> Ocaml.VSum (("Spread", []))
  | Yield -> Ocaml.VSum (("Yield", []))
  | Await -> Ocaml.VSum (("Await", []))
  | Assert -> Ocaml.VSum (("Assert", []))
(*
  | TupleAccess v1 ->
      let v1 = Ocaml.vof_int v1 in Ocaml.VSum (("TupleAccess", [ v1 ]))
*)
  | Ref -> Ocaml.VSum (("Ref", []))

and vof_anonymous_entity =
  function
  | Lambda v1 ->
      let v1 = G.vof_function_definition v1
      in Ocaml.VSum (("Lambda", [ v1 ]))
  | AnonClass v1 ->
      let v1 = G.vof_class_definition v1
      in Ocaml.VSum (("AnonClass", [ v1 ]))

let rec vof_stmt { s = v_s } =
  let bnds = [] in
  let arg = vof_stmt_kind v_s in
  let bnd = ("s", arg) in 
  let bnds = bnd :: bnds in 
  if !Meta_parse_info._current_precision.Meta_parse_info.full_info
  then Ocaml.VDict bnds
  else arg
and vof_stmt_kind =
  function
  | Instr v1 -> let v1 = vof_instr v1 in Ocaml.VSum (("Instr", [ v1 ]))
  | If ((v1, v2, v3, v4)) ->
      let v1 = vof_tok v1
      and v2 = vof_exp v2
      and v3 = Ocaml.vof_list vof_stmt v3
      and v4 = Ocaml.vof_list vof_stmt v4
      in Ocaml.VSum (("If", [ v1; v2; v3; v4 ]))
  | Loop ((v1, v2, v3)) ->
      let v1 = vof_tok v1
      and v2 = vof_exp v2
      and v3 = Ocaml.vof_list vof_stmt v3
      in Ocaml.VSum (("Loop", [ v1; v2; v3 ]))
  | Return ((v1, v2)) ->
      let v1 = vof_tok v1
      and v2 = vof_exp v2
      in Ocaml.VSum (("Return", [ v1; v2 ]))
  | Throw ((v1, v2)) ->
      let v1 = vof_tok v1
      and v2 = vof_exp v2
      in Ocaml.VSum (("Throw", [ v1; v2 ]))
  | Goto ((v1, v2)) ->
      let v1 = vof_tok v1
      and v2 = vof_label v2
      in Ocaml.VSum (("Goto", [ v1; v2 ]))
  | Label ((v1)) ->
      let v1 = vof_label v1
      in Ocaml.VSum (("Label", [ v1 ]))
  | Try ((v1, v2, v3)) ->
      let v1 = Ocaml.vof_list vof_stmt v1
      and v2 =
        Ocaml.vof_list
          (fun (v1, v2) ->
             let v1 = vof_var v1
             and v2 = Ocaml.vof_list vof_stmt v2
             in Ocaml.VTuple [ v1; v2 ])
          v2
      and v3 = Ocaml.vof_list vof_stmt v3
      in Ocaml.VSum (("Try", [ v1; v2; v3 ]))
  | OtherStmt ((v1)) ->
      let v1 = vof_other_stmt v1
      in Ocaml.VSum (("OtherStmt", [ v1 ]))

and vof_other_stmt = function
  | DefStmt v1 ->
      let v1 = G.vof_definition v1 in Ocaml.VSum (("DefStmt", [ v1 ]))
  | DirectiveStmt v1 ->
      let v1 = G.vof_directive v1 in Ocaml.VSum (("DirectiveStmt", [ v1 ]))

and vof_label (v1, v2) =
  let v1 = vof_ident v1 and v2 = vof_sid v2 in Ocaml.VTuple [ v1; v2 ]
  
let vof_any =
  function
  | L v1 -> let v1 = vof_lval v1 in Ocaml.VSum (("L", [ v1 ]))
  | E v1 -> let v1 = vof_exp v1 in Ocaml.VSum (("E", [ v1 ]))
  | I v1 -> let v1 = vof_instr v1 in Ocaml.VSum (("I", [ v1 ]))
  | S v1 -> let v1 = vof_stmt v1 in Ocaml.VSum (("S", [ v1 ]))
  | Ss v1 ->
      let v1 = Ocaml.vof_list vof_stmt v1 in Ocaml.VSum (("Ss", [ v1 ]))

let string_of_lval x =
  (match x.base with
  | Var n -> str_of_name n
  | VarSpecial _ -> "<varspecial>"
  | Mem  _ -> "<Mem>"
  ) ^
  (match x.offset with
  | NoOffset -> ""
  | Dot (s, _) -> "." ^ s
  | Index _ -> "[...]"
  )

let string_of_exp e =
  match e.e with
  | Lvalue l -> string_of_lval l
  | _ -> "<EXP>"

let short_string_of_node_kind nkind =
  match nkind with
  | Enter -> "<enter>"
  | Exit -> "<exit>"
  | TrueNode -> "<TRUE path>"
  | FalseNode -> "<FALSE path>"
  | Join -> "<join>"

  | NCond _ -> "cond(...)"
  | NReturn _ -> "return ...;"
  | NThrow _ -> "throw ...;"

  | NOther _ -> "<other>"
  | NInstr x ->
      (match x.i with
      | Assign (lval, _) -> string_of_lval lval ^ " = ..."
      | AssignAnon _ -> " ... = <lambda|class>"
      | Call (_lopt, exp, _) ->
            string_of_exp exp ^ "(...)"
      | CallSpecial _ -> "<special>"
      )


(* using internally graphviz dot and ghostview on X11 *)
let (display_cfg: cfg -> unit) = fun flow ->
  flow |> Ograph_extended.print_ograph_mutable_generic  
    ~s_of_node:(fun (_nodei, node) -> 
      short_string_of_node_kind node.n, None, None
    )
