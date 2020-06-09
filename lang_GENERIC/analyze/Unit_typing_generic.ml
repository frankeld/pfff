open Common
open OUnit
module V = Visitor_AST
module A = AST_generic

(*****************************************************************************)
(* Unit tests *)
(*****************************************************************************)

let unittest =
  "typing_tests" >::: [

    "test basic variable definitions java" >:: (fun () ->
      let file = Filename.concat Config_pfff.path "/tests/GENERIC/typing/VarDef.java" in
        try
          let ast = Parse_generic.parse_program file in
            let lang = List.hd (Lang.langs_of_filename file) in 
             Naming_AST.resolve lang ast;

            let v = V.mk_visitor { V.default_visitor with
                V.kexpr = (fun (_k, _) exp ->
                    match exp with
                      | A.Id(_, {A.id_type=id_type; _}) -> (
                            match !id_type with 
                              | Some(A.TyName((("String", _)), _)) -> ()
                              | _ -> assert_failure("Variable referenced did not have expected type String"))
                      | _ -> ()
                );
            } in
            v (A.Pr ast)
        with Parse_info.Parsing_error _ ->
          assert_failure (spf "it should correctly parse %s" file)
    );

    "test multiple variable definitions java" >:: (fun () ->
      let file = Filename.concat Config_pfff.path "/tests/GENERIC/typing/EqVarCmp.java" in
        try
          let ast = Parse_generic.parse_program file in
            let lang = List.hd (Lang.langs_of_filename file) in 
             Naming_AST.resolve lang ast;

            let v = V.mk_visitor { V.default_visitor with
                V.kexpr = (fun (_k, _) exp ->
                  match exp with
                    | A.Call(_, x::y::[]) ->
                      ((match x with
                        | A.Arg(A.Id(_, {A.id_type=id_type; _})) -> (
                              match !id_type with 
                                | Some(A.TyName((("String", _)), _)) -> ()
                                | _ -> assert_failure("Variable 1 referenced did not have expected type String"))
                        | _ -> ());
                      (match y with
                        | A.Arg(A.Id(_, {A.id_type=id_type; _})) -> (
                              match !id_type with 
                                | Some(A.TyBuiltin((("int", _)))) -> ()
                                | _ -> assert_failure("Variable 2 referenced did not have expected type int"))
                        | _ -> ()))
                    | A.Assign(A.Id(_, {A.id_type=id_type; _}), _, _) -> (
                        match !id_type with 
                          | Some(A.TyName((("String", _)), _)) -> ()
                          | _ -> assert_failure("Variable 1 referenced did not have expected type String"))
                    | _ -> ()
                );
            } in
            v (A.Pr ast)
        with Parse_info.Parsing_error _ ->
          assert_failure (spf "it should correctly parse %s" file)
    );

    "test basic params java" >:: (fun () ->
      let file = Filename.concat Config_pfff.path "/tests/GENERIC/typing/BasicParam.java" in
        try
          let ast = Parse_generic.parse_program file in
            let lang = List.hd (Lang.langs_of_filename file) in 
             Naming_AST.resolve lang ast;

            let v = V.mk_visitor { V.default_visitor with
                V.kexpr = (fun (_k, _) exp ->
                  match exp with
                    | A.Call(_, x::y::[]) ->
                      ((match x with
                        | A.Arg(A.Id(_, {A.id_type=id_type; _})) -> (
                              match !id_type with 
                                | Some(A.TyBuiltin((("int", _)))) -> ()
                                | _ -> assert_failure("Variable 1 referenced did not have expected type String"))
                        | _ -> ());
                      (match y with
                        | A.Arg(A.Id(_, {A.id_type=id_type; _})) -> (
                              match !id_type with 
                                | Some(A.TyBuiltin((("boolean", _)))) -> ()
                                | _ -> assert_failure("Variable 2 referenced did not have expected type int"))
                        | _ -> ()))
                    | _ -> ()
                );
            } in
            v (A.Pr ast)
        with Parse_info.Parsing_error _ ->
          assert_failure (spf "it should correctly parse %s" file)
    );

    "test basic variable definitions go" >:: (fun () ->
      let file = Filename.concat Config_pfff.path "/tests/GENERIC/typing/StaticVarDef.go" in
        try
          let ast = Parse_generic.parse_program file in
            let lang = List.hd (Lang.langs_of_filename file) in 
             Naming_AST.resolve lang ast;

            let v = V.mk_visitor { V.default_visitor with
                V.kexpr = (fun (_k, _) exp ->
                    match exp with
                      | A.Id(_, {A.id_type=id_type; _}) -> (
                            match !id_type with 
                              | Some(A.TyName((("int", _)), _)) -> ()
                              | _ -> assert_failure("Variable referenced did not have expected type int"))
                      | _ -> ()
                );
            } in
            v (A.Pr ast)
        with Parse_info.Parsing_error _ ->
          assert_failure (spf "it should correctly parse %s" file)
    );

    "test basic function call go" >:: (fun () ->
      let file = Filename.concat Config_pfff.path "/tests/GENERIC/typing/FuncParam.go" in
        try
          let ast = Parse_generic.parse_program file in
            let lang = List.hd (Lang.langs_of_filename file) in 
             Naming_AST.resolve lang ast;

            let v = V.mk_visitor { V.default_visitor with
                V.kexpr = (fun (_k, _) exp ->
                    match exp with
                      | A.Call(_, x::y::[]) ->
                        ((match x with
                          | A.Arg(A.Id(("a", _), {A.id_type=id_type; _})) -> (
                                match !id_type with 
                                  | Some(A.TyName((("int", _)), _)) -> ()
                                  | _ -> assert_failure("Variable referenced did not have expected type int"))
                          | _ -> assert_failure("Expected function call to be with int a as first argument"));
                        (match y with
                          | A.Arg(A.Id(("c", _), {A.id_type=id_type; _})) -> (
                                match !id_type with 
                                  | Some(A.TyName((("bool", _)), _)) -> ()
                                  | _ -> assert_failure("Variable referenced did not have expected type bool"))
                          | _ -> assert_failure("Epected function call to have bool c as second argument")))
                      | _ -> ()
                );
            } in
            v (A.Pr ast)
        with Parse_info.Parsing_error _ ->
          assert_failure (spf "it should correctly parse %s" file)
    );
  ]