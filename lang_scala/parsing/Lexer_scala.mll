{
(* Yoann Padioleau
 *
 * Copyright (C) 2021 r2c
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
open Common

open Token_scala
module PI = Parse_info
module Flag = Flag_parsing

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* The Scala lexer.
 *
 * reference:
 *    - https://scala-lang.org/files/archive/spec/2.13/13-syntax-summary.html
 *
 * other sources:
 *    - fastparse/scalaparse/.../Basic.scala
 *
 * TODO:
 *  - MACRO?
 *  - scala3: THEN
 *  - less: XMLSTART
 *)

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* shortcuts *)
let tok = Lexing.lexeme
let tokinfo = Parse_info.tokinfo
let error = Parse_info.lexical_error

(* ---------------------------------------------------------------------- *)
(* Lexer State *)
(* ---------------------------------------------------------------------- *)
(* note: mostly a copy paste of the trick used in the lexer for PHP *)

type state_mode =
  (* Regular Scala mode *)
  | ST_IN_CODE

  (* started with x", finished with " *)
  | ST_IN_INTERPOLATED_DOUBLE
  (* started with x""", finished with """ *)
  | ST_IN_INTERPOLATED_TRIPLE

let default_state = ST_IN_CODE

let _mode_stack =
  ref [default_state]

let reset () =
  _mode_stack := [default_state];
  ()

let rec current_mode () =
  try
    Common2.top !_mode_stack
  with Failure("hd") ->
    pr2("mode_stack is empty, defaulting to INITIAL");
    reset();
    current_mode ()

let push_mode mode = Common.push mode _mode_stack
let pop_mode () = ignore(Common2.pop2 _mode_stack)

}

(*****************************************************************************)
(* Regexp aliases *)
(*****************************************************************************)

let whiteSpace = [' ' '\t'] (* todo: also OA, OD? *)

let upper = ['A'-'Z''$'] (* todo: and unicode category *)
let lower = ['a'-'z''_'] (* todo: and unicode category L1 *)
let letter = upper | lower (* todo: and unicode category Lo, Lt, Nl *)

let digit = ['0'-'9']
let hexDigit = digit | ['a'-'f''A'-'F']

(* no paren, and no delim, no quotes, no $ or _ *)
(* the _noxxx is to avoid ambiguity with /** comments *)
let op_nodivstar =['+''-'    '%' ':''=''!''#''~''?''\\''@' '|''&''^' '<''>' ]
let op_nodiv = op_nodivstar | '*'
let op_nostar = op_nodivstar | '/'
let opchar   = op_nodivstar | '*' | '/'
let op = '/'
       | '/'      op_nostar opchar*
       | op_nodiv opchar*

let idrest = (letter | digit)* ('_' op)?

let varid = lower idrest
let _boundvarid = varid | '`' varid '`'
let plainid = upper idrest | varid | op

(* bugfix: also ...OrAntislash *)
let charNoBackQuoteOrNewline   = [^'\n' '`'  '\\']
let charNoQuoteOrNewline       = [^'\n' '\'' '\\']
let charNoDoubleQuoteOrNewline = [^'\n' '"'  '\\']
let charNoDoubleQuote =          [^'"' '\\']

let newline = ('\n' | "\r\n")

let _charEscapeSeq = '\\' ['b''t''n''f''r''"''\'''\\']
(* semgrep: we can use regexp in semgrep in strings and we want to
 * support any escape characters there, e.g. eval("=~/.*dev\.corp/")
 *)
let semgrepEscapeSeq = '\\' _

let unicodeEscape = '\\' 'u'+ hexDigit hexDigit hexDigit hexDigit
let escapeSeq = unicodeEscape | semgrepEscapeSeq

let stringElement = charNoDoubleQuoteOrNewline | escapeSeq
let _multiLineChars = ('"'? '"'? charNoDoubleQuote)* '"'*

let decimalNumeral = digit digit*
let hexNumeral = '0' ['X''x'] hexDigit hexDigit*
let integerLiteral = (decimalNumeral | hexNumeral) ['L''l']?

let exponentPart = ['E''e'] ['+''-']? digit digit*
let floatType = ['F''f''D''d']
let floatingPointLiteral =
   digit digit* '.' digit digit* exponentPart? floatType?
 |              '.' digit digit* exponentPart? floatType?
 | digit digit*                  exponentPart  floatType?
 | digit digit*                  exponentPart? floatType

(* note: old Scala spec was wrong and was using stringLiteral *)
let id = plainid | '`' (charNoBackQuoteOrNewline | escapeSeq)+ '`'

(* split id in different tokens *)
let id_lower = lower idrest
let id_upper = upper idrest
let id_backquoted1 = '`' varid '`'
let id_backquoted2 = '`' (charNoBackQuoteOrNewline | escapeSeq)+ '`'

(* for interpolated strings *)
let alphaid = upper idrest | varid

(*****************************************************************************)
(* Rule initial *)
(*****************************************************************************)

rule token = parse

  (* ----------------------------------------------------------------------- *)
  (* spacing/comments *)
  (* ----------------------------------------------------------------------- *)
  | "/*" {
      let info = tokinfo lexbuf in
      let buf = Buffer.create 127 in
      Buffer.add_string buf "/*";
      comment buf lexbuf;
      Comment(info |> PI.rewrap_str (Buffer.contents buf))
    }

  (* don't keep the trailing \n; it will be in another token *)
  | "//" [^ '\r' '\n']* { Comment (tokinfo lexbuf) }
  | whiteSpace+ { Space (tokinfo lexbuf) }

  (* ----------------------------------------------------------------------- *)
  (* Newline (treated specially in Scala, like in Python) *)
  (* ----------------------------------------------------------------------- *)
  | newline     { Nl (tokinfo lexbuf) }

  (* ----------------------------------------------------------------------- *)
  (* symbols *)
  (* ----------------------------------------------------------------------- *)

  (* paren *)
  | '(' { LPAREN (tokinfo lexbuf) }   | ')' { RPAREN (tokinfo lexbuf) }
  | '[' { LBRACKET (tokinfo lexbuf) } | ']' { RBRACKET (tokinfo lexbuf) }
  | '{' { push_mode ST_IN_CODE; LBRACE (tokinfo lexbuf) }
  | '}' { pop_mode ();          RBRACE (tokinfo lexbuf) }

  (* delim *)
  | ';'     { SEMI (tokinfo lexbuf) }
  | ','     { COMMA (tokinfo lexbuf) }
  | '.'     { DOT (tokinfo lexbuf) }

  | ':'     { COLON (tokinfo lexbuf) }
  | '='     { EQUALS (tokinfo lexbuf) }

  (* Those characters can be part of an operator. Conflict with op?
   * Only 'paren' and 'delim' above can't be part of an operator.
   * In the original Scala parser, those operators were agglomerated
   * in the IDENTIFIER category, but then there was lots of code like
   * isRawStar, isRawPipe, etc which was annoying, so here I generate
   * different tokens for those, but accept them also as identifier
   * in Token_helpers_scala.isIdent().
  *)
  (* op and used for type variance and used for prefixExpr *)
  | '+'     { PLUS (tokinfo lexbuf) }
  | '-'     { MINUS (tokinfo lexbuf) }
  (* used for sequences *)
  | '*'     { STAR (tokinfo lexbuf) }
  (* type projection *)
  | '#'     { HASH (tokinfo lexbuf) }
  (* Or patterns *)
  | '|'     { PIPE (tokinfo lexbuf) }

  (* prefixExpr *)
  | '!'     { BANG (tokinfo lexbuf) }
  | '~'     { TILDE (tokinfo lexbuf) }
  (* wildcard *)
  | '_'     { USCORE (tokinfo lexbuf) }
  (* generators *)
  | "<-"    { LARROW (tokinfo lexbuf) }
  (* case body and short lambdas *)
  | "=>"    { ARROW (tokinfo lexbuf) }

  | "<%"    { VIEWBOUND (tokinfo lexbuf) }
  | "<:"    { SUBTYPE (tokinfo lexbuf) }
  | ">:"    { SUPERTYPE (tokinfo lexbuf) }

  | "@"    { AT (tokinfo lexbuf) }

  (* Unicode space characters (like in Lexer_js.mll) special handling.
   * Note that OCaml supports now unicode characters as \u{00a0} in strings
   * but this does not seem to work in ocamllex, hence the hardcoding of
   * the actual UTF8 bytes below (use scripts/unicode.ml and hexl-mode in
   * Emacs to get those byte values).
   * The right solution would be to switch to a unicode-aware lexer generator,
   * like ulex or sedlex.
   * related: Parse_info.tokenize_all_and_adjust_pos ~unicode_hack:true
   * but this code below will trigger only if unicode_hack is set to false.
   *)
  (* an arrow *)
  | "\xe2\x87\x92"    { ARROW (tokinfo lexbuf) }
  (* a dot, found in sbt source *)
  | "\xe2\x88\x99"    { OP (tok lexbuf, tokinfo lexbuf) }
  (* a lambda, found in sbt source *)
  | "\xce\xbb" { ID_LOWER (tok lexbuf, tokinfo lexbuf) }

  (* semgrep-ext: *)
  | "..."   { Flag_parsing.sgrep_guard (Ellipsis (tokinfo lexbuf)) }
  (* semgrep-ext: *)
  | "<..."  { Flag_parsing.sgrep_guard (LDots (tokinfo lexbuf)) }
  | "...>"  { Flag_parsing.sgrep_guard (RDots (tokinfo lexbuf)) }

  (* ----------------------------------------------------------------------- *)
  (* Keywords and ident *)
  (* ----------------------------------------------------------------------- *)
  | "'" (plainid as s) { SymbolLiteral(s, tokinfo lexbuf) }

  (* keywords *)
  | id_lower as s
      { let t = tokinfo lexbuf in
        match s with
        | "null" -> Knull t

        | "true" -> BooleanLiteral (true, t)
        | "false" -> BooleanLiteral (false, t)

        | "if"       -> Kif t
        | "else"     -> Kelse t

        | "for"      -> Kfor t
        | "forSome"      -> KforSome t
        | "while"      -> Kwhile t
        | "do"      -> Kdo t

        | "match"      -> Kmatch t
        | "case"      -> Kcase t

        | "try"      -> Ktry t
        | "catch"      -> Kcatch t
        | "finally"      -> Kfinally t
        | "throw"      -> Kthrow t

        | "return"   -> Kreturn t

        | "class"      -> Kclass t
        | "trait"      -> Ktrait t
        | "object"      -> Kobject t
        | "new"      -> Knew t
        | "super" -> Ksuper t
        | "this" -> Kthis t
        | "with" -> Kwith t
        | "extends" -> Kextends t

        | "def"    -> Kdef t
        | "type"    -> Ktype t
        | "var"    -> Kvar t
        | "val"    -> Kval t

        | "package"     -> Kpackage t
        | "import"   -> Kimport t

        | "abstract"       -> Kabstract t
        | "final"       -> Kfinal t
        | "private"       -> Kprivate t
        | "protected"       -> Kprotected t

        | "sealed"       -> Ksealed t
        | "override"       -> Koverride t
        | "implicit"    -> Kimplicit t
        | "lazy"    -> Klazy t
        | "yield"    -> Kyield t

        (* missing? "macro"? *)

        | _          -> ID_LOWER (s, t)
    }

  (* semgrep-ext: but this is also a valid Scala identifier *)
  | '$' ['A'-'Z']['A'-'Z''0'-'9''_']* as s
    { ID_UPPER (s, tokinfo lexbuf) }
  (* sgrep-ext: *)
  | '$' "..." ['A'-'Z''_']['A'-'Z''_''0'-'9']*
     { Flag.sgrep_guard (ID_UPPER (tok lexbuf, tokinfo lexbuf)) }

  | id_backquoted1 as s { ID_BACKQUOTED (s, tokinfo lexbuf) }
  | id_backquoted2 as s { ID_BACKQUOTED (s, tokinfo lexbuf) }
  (* this was all agglomerated as an IDENTIFIER in original code *)
  | id_upper as s       { ID_UPPER (s, tokinfo lexbuf) }
  | op as s             { OP (s, tokinfo lexbuf) }

  (* ----------------------------------------------------------------------- *)
  (* Constant *)
  (* ----------------------------------------------------------------------- *)
  (* literals *)
  | integerLiteral as n
      { IntegerLiteral (int_of_string_opt n, tokinfo lexbuf) }
  | floatingPointLiteral as n
      { FloatingPointLiteral (float_of_string_opt n, tokinfo lexbuf) }

  (* ----------------------------------------------------------------------- *)
  (* Chars/Strings *)
  (* ----------------------------------------------------------------------- *)

  | "'" ((charNoQuoteOrNewline | escapeSeq) as s)  "'"
      { CharacterLiteral (s, tokinfo lexbuf) }
  | '"' (stringElement* as s) '"'
      { StringLiteral (s, tokinfo lexbuf) }
  (* in spec but does not seem to work, see tests/parsing/triple_quote.scala*)
(*
  | "\"\"\"" (multiLineChars as s) "\"\"\""
      { StringLiteral (s, tokinfo lexbuf) }
*)
  | "\"\"\"" {
      let info = tokinfo lexbuf in
      let buf = Buffer.create 127 in
      string buf lexbuf;
      let s = Buffer.contents buf in
      StringLiteral(s, info |> PI.rewrap_str ("\"\"\"" ^ s ^ "\"\"\""))
    }
  (* interpolated strings *)
  | alphaid as s '"'
   { push_mode ST_IN_INTERPOLATED_DOUBLE;
     T_INTERPOLATED_START(s, tokinfo lexbuf) }
  | alphaid as s "\"\"\""
   { push_mode ST_IN_INTERPOLATED_TRIPLE;
     T_INTERPOLATED_START(s, tokinfo lexbuf) }

  (* ----------------------------------------------------------------------- *)
  (* eof *)
  (* ----------------------------------------------------------------------- *)
  | eof { EOF (tokinfo lexbuf) }

  | _ { error (spf "unrecognized symbol: %s" (tok lexbuf)) lexbuf;
        Unknown (tokinfo lexbuf)
      }

(*****************************************************************************)
(* Multi line triple strings *)
(*****************************************************************************)

and string buf = parse
  (* bugfix: you can have 4 or 5 in a row! only last 3 matters *)
  | "\"" "\"\"\"" {
      Parse_info.yyback 3 lexbuf;
      Buffer.add_string buf (tok lexbuf);
      (* bugfix: this is not the end! We need to recurse with string() again *)
      string buf lexbuf
  }
  | "\"\"\""    { () }
  (* noteopti: *)
  | [^'"']+ as s { Buffer.add_string buf s; string buf lexbuf }
  | '"'          { Buffer.add_string buf (tok lexbuf); string buf lexbuf }
  | eof     { error "end of file in string" lexbuf }
  | _  {
      let s = tok lexbuf in
      error ("unrecognised symbol in string:"^s) lexbuf;
      Buffer.add_string buf s;
      string buf lexbuf
    }

(*****************************************************************************)
(* String interpolation *)
(*****************************************************************************)
and in_interpolated_double = parse
  | '"'  { pop_mode(); T_INTERPOLATED_END (tokinfo lexbuf) }

  (* not in original spec *)
  | escapeSeq as s { StringLiteral (s, tokinfo lexbuf) }
  | [^'"''$''\\']+ as s { StringLiteral (s, tokinfo lexbuf) }
  | "${" { push_mode ST_IN_CODE; LBRACE (tokinfo lexbuf) }
  | "$" (id as s) { ID_DOLLAR (s, tokinfo lexbuf) }

  | eof  { error "end of file in interpolated string" lexbuf;
           pop_mode();
           Unknown(tokinfo lexbuf) }
  | _  {
       error ("unrecognised symbol in interpolated string:"^tok lexbuf) lexbuf;
       Unknown(tokinfo lexbuf)
       }

and in_interpolated_triple = parse
  (* bugfix: you can have 4 or 5 in a row! only last 3 matters *)
  | "\"" "\"\"\"" {
      Parse_info.yyback 3 lexbuf;
      StringLiteral (tok lexbuf, tokinfo lexbuf)
  }

  | "\"\"\""  { pop_mode(); T_INTERPOLATED_END (tokinfo lexbuf) }
  | "\"" { StringLiteral (tok lexbuf, tokinfo lexbuf) }
  (* not in original spec *)
  | escapeSeq as s { StringLiteral (s, tokinfo lexbuf) }
  | [^'"''$''\\']+ as s { StringLiteral (s, tokinfo lexbuf) }
  | "${" { push_mode ST_IN_CODE; LBRACE (tokinfo lexbuf) }
  | "$" id as s { ID_DOLLAR (s, tokinfo lexbuf) }

  | eof  { error "end of file in interpolated2 string" lexbuf;
           pop_mode();
           Unknown(tokinfo lexbuf) }
  | _  {
       error("unrecognised symbol in interpolated2 string:"^tok lexbuf) lexbuf;
       Unknown(tokinfo lexbuf)
       }

(*****************************************************************************)
(* Rule comment *)
(*****************************************************************************)

and comment buf = parse
  | "*/"    { Buffer.add_string buf (tok lexbuf) }
  (* noteopti: *)
  | [^'*']+ { Buffer.add_string buf (tok lexbuf); comment buf lexbuf }
  | "*"     { Buffer.add_string buf (tok lexbuf); comment buf lexbuf }
  | eof     { error "end of file in comment" lexbuf }
  | _  {
      let s = tok lexbuf in
      error ("unrecognised symbol in comment:"^s) lexbuf;
      Buffer.add_string buf s;
      comment buf lexbuf
    }
