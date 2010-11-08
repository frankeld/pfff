(*s: lib_parsing_php.ml *)
(*s: Facebook copyright *)
(* Yoann Padioleau
 * 
 * Copyright (C) 2009-2010 Facebook
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 * 
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 *)
(*e: Facebook copyright *)

open Common

(*s: basic pfff module open and aliases *)
open Ast_php 

module Ast = Ast_php
module Flag = Flag_parsing_php
(*e: basic pfff module open and aliases *)
module V = Visitor_php 
module V2 = Map_php 

(*****************************************************************************)
(* Wrappers *)
(*****************************************************************************)
let pr2, pr2_once = Common.mk_pr2_wrappers Flag.verbose_parsing


(*****************************************************************************)
(* Filemames *)
(*****************************************************************************)

let is_php_script file = 
  Common.with_open_infile file (fun chan ->
    try 
      let l = input_line chan in
      l =~ "#!/usr/.*/php" ||
      l =~ "#!/bin/env php" ||
      l =~ "#!/usr/bin/env php"

    with End_of_file -> false
  )

let find_php_files_of_dir_or_files xs = 
  Common.files_of_dir_or_files_no_vcs_nofilter xs 
  +> List.filter (fun filename ->
    (filename =~ ".*\\.php$") ||
      (filename =~ ".*\\.phpt$") ||
      is_php_script filename
  ) |> Common.sort

(*****************************************************************************)
(* Extract infos *)
(*****************************************************************************)
(*s: extract infos *)
let extract_info_visitor recursor = 
  let globals = ref [] in
  let hooks = { V.default_visitor with
    V.kinfo = (fun (k, _) i -> Common.push2 i globals)
  } in
  begin
    let vout = V.mk_visitor hooks in
    recursor vout;
    List.rev !globals
  end
(*x: extract infos *)
let ii_of_any any = 
  extract_info_visitor (fun visitor -> visitor any)
(*e: extract infos *)

(*****************************************************************************)
(* Abstract position *)
(*****************************************************************************)
(*s: abstract infos *)
let abstract_position_visitor recursor = 
  let hooks = { V2.default_visitor with
    V2.kinfo = (fun (k, _) i -> 
      { i with pinfo = Parse_info.Ab }
    )
  } in
  begin
    let vout = V2.mk_visitor hooks in
    recursor vout;
  end
(*x: abstract infos *)
let abstract_position_info_program x = 
  abstract_position_visitor (fun visitor -> visitor.V2.vprogram x)
let abstract_position_info_expr x = 
  abstract_position_visitor (fun visitor -> visitor.V2.vexpr x)
let abstract_position_info_lvalue x = 
  abstract_position_visitor (fun visitor -> visitor.V2.vlvalue x)
let abstract_position_info_toplevel x = 
  abstract_position_visitor (fun visitor -> visitor.V2.vtop x)
(*e: abstract infos *)

(*****************************************************************************)
(* Max min, range *)
(*****************************************************************************)
(*s: max min range *)
let min_max_ii_by_pos xs = 
  match xs with
  | [] -> failwith "empty list, max_min_ii_by_pos"
  | [x] -> (x, x)
  | x::xs -> 
      let pos_leq p1 p2 = (Ast_php.compare_pos p1 p2) =|= (-1) in
      xs +> List.fold_left (fun (minii,maxii) e -> 
        let maxii' = if pos_leq maxii e then e else maxii in
        let minii' = if pos_leq e minii then e else minii in
        minii', maxii'
      ) (x,x)
(*x: max min range *)
let info_to_fixpos ii =
  match Ast_php.pinfo_of_info ii with
  | Parse_info.OriginTok pi -> 
      (* Ast_cocci.Real *)
      pi.Parse_info.charpos
  | Parse_info.FakeTokStr _
  | Parse_info.Ab 
  | Parse_info.ExpandedTok _
    -> failwith "unexpected abstract or faketok"
  
let min_max_by_pos xs = 
  let (i1, i2) = min_max_ii_by_pos xs in
  (info_to_fixpos i1, info_to_fixpos i2)

let (range_of_origin_ii: Ast_php.info list -> (int * int) option) = 
 fun ii -> 
  let ii = List.filter Ast_php.is_origintok ii in
  try 
    let (min, max) = min_max_ii_by_pos ii in
    assert(Ast_php.is_origintok max);
    assert(Ast_php.is_origintok min);
    let strmax = Ast_php.str_of_info max in
    Some 
      (Ast_php.pos_of_info min, Ast_php.pos_of_info max + String.length strmax)
  with _ -> 
    None
(*e: max min range *)

(*****************************************************************************)
(* Print helpers *)
(*****************************************************************************)

(* could perhaps create a special file related to display of code ? *)
type match_format =
  (* ex: tests/misc/foo4.php:3
   *  foo(
   *   1,
   *   2);
   *)
  | Normal
  (* ex: tests/misc/foo4.php:3: foo( *)
  | Emacs
  (* ex: tests/misc/foo4.php:3: foo(1,2) *)
  | OneLine


(* When we print in the OneLine format we want to normalize the matched
 * expression or code and so only print the tokens in the AST (and not
 * the extra whitespace, newlines or comments). It's not enough though
 * to just List.map str_of_info because some PHP expressions such as
 * '$x = print FOO' would then be transformed into $x=printFOO, hence
 * this function
 *)
let rec join_with_space_if_needed xs = 
  match xs with
  | [] -> ""
  | [x] -> x
  | x::y::xs ->
      if x =~ ".*[a-zA-Z0-9_]$" && 
         y =~ "^[a-zA-Z0-9_]"
      then x ^ " " ^ (join_with_space_if_needed (y::xs))
      else x ^ (join_with_space_if_needed (y::xs))
let _ = example
  (join_with_space_if_needed ["$x";"=";"print";"FOO"] = "$x=print FOO")



let print_match ?(format = Normal) ii = 
  let (mini, maxi) = min_max_ii_by_pos ii in
  let (file, line) = 
    Ast.file_of_info mini, Ast.line_of_info mini in
  let prefix = spf "%s:%d" file line in
  let arr = Common.cat_array file in
  let lines = Common.enum (Ast.line_of_info mini) (Ast.line_of_info maxi) in
  
  match format with
  | Normal ->
      pr prefix;
      (* todo? some context too ? *)
      lines +> List.map (fun i -> arr.(i)) +> List.iter (fun s -> pr (" " ^ s));
  | Emacs ->
      pr (prefix ^ ": " ^ arr.(List.hd lines))
  | OneLine ->
      pr (prefix ^ ": " ^ (ii +> List.map Ast.str_of_info 
                            +> join_with_space_if_needed))


let print_warning_if_not_correctly_parsed ast file =
  if ast +> List.exists (function 
  | Ast_php.NotParsedCorrectly _ -> true
  | _ -> false)
  then begin
    Common.pr2 (spf "warning: parsing problem in %s" file);
    Common.pr2_once ("Use -parse_php to diagnose");
    (* old: 
     * Common.pr2_once ("Probably because of XHP; -xhp may be helpful"); 
     *)
  end

(*****************************************************************************)
(* Ast getters *)
(*****************************************************************************)
(*s: ast getters *)
let get_all_funcalls f = 
  let h = Hashtbl.create 101 in
  
  let hooks = { V.default_visitor with

    (* TODO if nested function ??? still wants to report ? *)
    V.klvalue = (fun (k,vx) x ->
      match untype x with
      | FunCallSimple (callname, args) ->
          let str = Ast_php.name callname in
          Hashtbl.replace h str true;
          k x
      | _ -> k x
    );
  } 
  in
  let visitor = V.mk_visitor hooks in
  f visitor;
  Common.hashset_to_list h
(*x: ast getters *)
let get_all_funcalls_any any =
  get_all_funcalls (fun visitor ->  visitor any)
(*x: ast getters *)
let get_all_constant_strings_any any = 
  let h = Hashtbl.create 101 in

  let hooks = { V.default_visitor with
    V.kconstant = (fun (k,vx) x ->
      match x with
      | String (str,ii) ->
          Hashtbl.replace h str true;
      | _ -> k x
    );
    V.kencaps = (fun (k,vx) x ->
      match x with
      | EncapsString (str, ii) ->
          Hashtbl.replace h str true;
      | _ -> k x
    );
  }
  in
  (V.mk_visitor hooks) any;
  Common.hashset_to_list h

(*x: ast getters *)


let get_all_funcvars f =
  let h = Hashtbl.create 101 in
  
  let hooks = { V.default_visitor with

    V.klvalue = (fun (k,vx) x ->
      match untype x with
      | FunCallVar (qu_opt, var, args) ->

          (* TODO enough ? what about qopt ? 
           * and what if not directly a Var ?
           * 
           * and what about call_user_func ? should be
           * transformed at parsing time into a FunCallVar ?
           *)
          (match untype var with
          | Var (dname, _scope) ->
              let str = Ast_php.dname dname in
              Hashtbl.replace h str true;
              k x

          | _ -> k x
          )
      | _ ->  k x
    );
  } 
  in
  let visitor = V.mk_visitor hooks in
  f visitor;
  Common.hashset_to_list h

let get_all_funcvars_any any = 
  get_all_funcvars (fun visitor -> visitor any)
(*e: ast getters *)

let get_static_vars =
  V.do_visit_with_ref (fun aref -> { V.default_visitor with
    V.kstmt = (fun (k,vx) x ->
      match x with
      | StaticVars (tok, xs, tok2) ->
          xs |> Ast.uncomma |> List.iter (fun (dname, affect_opt) -> 
            Common.push2 dname aref
          );
      | _ -> 
          k x
    );
  })


(* todo: move where ? 
 * static_scalar does not have a direct mapping with scalar as some
 * elements like StaticArray have mapping only in expr.
*)
let rec static_scalar_to_expr x = 
  let exprbis = 
    match x with
    | StaticConstant cst -> 
        Sc (C cst)
    | StaticClassConstant (qu, name) -> 
        Sc (ClassConstant (qu, name))
    | StaticPlus (tok, sc) -> 
        Unary ((UnPlus, tok), static_scalar_to_expr sc)
    | StaticMinus (tok, sc) -> 
        Unary ((UnMinus, tok), static_scalar_to_expr sc)
    | StaticArray (tok, array_pairs_paren) ->
        ConsArray (tok, 
                  Ast.map_paren 
                    (Ast.map_comma_list static_array_pair_to_array_pair) 
                    array_pairs_paren)
    | XdebugStaticDots ->
        failwith "static_scalar_to_expr: should not get a XdebugStaticDots"
  in
  exprbis, Ast.noType ()

and static_array_pair_to_array_pair x = 
  match x with
  | StaticArraySingle (sc) -> 
      ArrayExpr (static_scalar_to_expr sc)
  | StaticArrayArrow (sc1, tok, sc2) ->
      ArrayArrowExpr (static_scalar_to_expr sc1, 
                     tok,
                     static_scalar_to_expr sc2)

(* do some isomorphisms for declaration vs assignement *)
let get_vars_assignements recursor = 
  (* We want to group later assignement by variables, and 
   * so we want to use function like Common.group_by_xxx 
   * which requires to have identical key. Each dname occurence 
   * below has a different location and so we can use dname as 
   * key, but the name of the variable can be used, hence the use
   * of Ast.dname
   *)
  V.do_visit_with_ref (fun aref -> { V.default_visitor with
      V.kstmt = (fun (k,vx) x ->
        match x with
        | StaticVars (tok, xs, tok2) ->
            xs |> Ast.uncomma |> List.iter (fun (dname, affect_opt) -> 
              let s = Ast.dname dname in
              affect_opt |> Common.do_option (fun (_tok, scalar) ->
                Common.push2 (s, static_scalar_to_expr scalar) aref;
              );
            );
        | _ -> 
            k x
      );

      V.kexpr = (fun (k,vx) x ->
        match Ast.untype x with
        | Assign (lval, _, e) 
        | AssignOp (lval, _, e) ->
            (* the expression itself can contain assignements *)
            k x; 
            
            (* for now we handle only simple direct assignement to simple
             * variables *)
            (match Ast.untype lval with
            | Var (dname, _scope) ->
                let s = Ast.dname dname in
                Common.push2 (s, e) aref;
            | _ ->
                ()
            )
        (* todo? AssignRef AssignNew ? *)
        | _ -> 
            k x
      );
    }
  ) recursor |> Common.group_assoc_bykey_eff
  
(* todo? do last_stmt_is_a_return isomorphism ? *)
let get_returns = 
  V.do_visit_with_ref (fun aref -> { V.default_visitor with
    V.kstmt = (fun (k,vx) x ->
      match x with
      | Return (tok1, Some e, tok2) ->
          Common.push2 e aref
      | _ -> k x
    )})

let get_vars = 
  V.do_visit_with_ref (fun aref -> { V.default_visitor with
    V.klvalue = (fun (k,vx) x ->
      match Ast.untype x with
      | Var (dname, _scope) ->
          Common.push2 dname aref
      | _ -> k x
    )})

let top_statements_of_program ast = 
  ast |> List.map (function
  | StmtList xs -> xs
  | FinalDef _|NotParsedCorrectly _|Halt (_, _, _)
  | InterfaceDef _|ClassDef _| FuncDef _
      -> []
  ) |> List.flatten  

(*e: lib_parsing_php.ml *)
