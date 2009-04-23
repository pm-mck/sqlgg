/* 
  $Id$

  Simple SQL parser
  TODO: simplify, it captures many unnecessary details
*/


%{
  open Printf
  open Sql
  open ListMore
  open Stmt.Raw
  open Operators
%}

%token <int> INTEGER
%token <string> IDENT
%token <Stmt.Raw.param_id> PARAM
%token LPAREN RPAREN COMMA EOF DOT
%token IGNORE REPLACE ABORT FAIL ROLLBACK
%token SELECT INSERT OR INTO CREATE_TABLE UPDATE TABLE VALUES WHERE FROM ASTERISK DISTINCT ALL 
       LIMIT ORDER_BY DESC ASC EQUAL DELETE_FROM DEFAULT OFFSET SET JOIN LIKE_OP
       EXCL TILDE NOT FUNCTION TEST_NULL BETWEEN AND ESCAPE USING COMPOUND_OP
%token NOT_NULL UNIQUE PRIMARY_KEY AUTOINCREMENT ON CONFLICT
%token PLUS MINUS DIVIDE PERCENT
%token T_INTEGER T_BLOB T_TEXT

%type <Stmt.Raw.params> expr

%start <RA.Scheme.t * Stmt.Raw.params> input

%%

input: statement EOF { $1 } ;

statement: CREATE_TABLE IDENT LPAREN column_defs RPAREN
              { let () = Tables.add ($2,$4) in ([],[]) }
         | select_stmt
              { $1 }
         /*| insert_cmd IDENT LPAREN columns RPAREN VALUES
              { Raw.Insert (Raw.Cols (List.rev $4)), $2, [] }
         | insert_cmd IDENT VALUES
              { Raw.Insert Raw.All, $2, [] }
         | UPDATE IDENT SET set_columns maybe_where
              { Raw.Update $4, $2, List.filter_valid [$5] }
         | DELETE_FROM IDENT maybe_where
              { Raw.Delete, $2, List.filter_valid [$3] }*/ ;

select_stmt: select_core list(preceded(COMPOUND_OP,select_core)) order? maybe_limit 
              { let (s1,p1) = $1 
                and (s2,p2) = List.split $2 in
                List.fold_left RA.Scheme.compound s1 s2,(p1@(List.flatten p2)) } 

select_core: SELECT select_type? r=results FROM t=table_list w=loption(where)
              {
                let (cols) = r in
                let (tbls,p2) = t in
                (Syntax.resolve cols tbls, p2 @ w) 
              }

table_list: source join_source* { let (s,p) = List.split $2 in ($1::s, List.flatten p) }
join_source: join_op s=source p=loption(join_args) { (s,p) }
source: IDENT { Tables.get $1 }
(*       | LPAREN select_core RPAREN { } *)
join_op: COMMA | JOIN { } ;
join_args: ON e=expr { e }
         | USING LPAREN separated_nonempty_list(COMMA,IDENT) RPAREN { [] }

insert_cmd: INSERT OR conflict_algo INTO {}
          | INSERT INTO {}
          | REPLACE INTO {} ;

update_cmd: UPDATE {}
          | UPDATE OR conflict_algo {} ;

select_type: DISTINCT | ALL { }

maybe_limit: LIMIT PARAM { [Some ("limit",Type.Int)] }
           | LIMIT INTEGER { [None] }
           | LIMIT PARAM COMMA PARAM { [Some ("offset",Type.Int); Some ("limit",Type.Int)] }
           | LIMIT INTEGER COMMA PARAM { [Some ("limit",Type.Int)] }
           | LIMIT PARAM COMMA INTEGER { [Some ("offset",Type.Int)] }
           | LIMIT INTEGER COMMA INTEGER { [None] }
           | LIMIT PARAM OFFSET PARAM { [Some ("limit",Type.Int); Some ("offset",Type.Int)] }
           | LIMIT INTEGER OFFSET PARAM { [Some ("offset",Type.Int)] }
           | LIMIT PARAM OFFSET INTEGER { [Some ("limit",Type.Int)] }
           | LIMIT INTEGER OFFSET INTEGER { [None] }
           | /* */ { [None] } ;

order: ORDER_BY IDENT order_type? { }

order_type: DESC { }
          | ASC { }

where: WHERE e=expr { e }

results: separated_nonempty_list(COMMA,column1) { $1 } ;

column1: IDENT { One $1 }
       | IDENT DOT IDENT { OneOf ($3,$1) }
       | IDENT DOT ASTERISK { AllOf $1 }
       | ASTERISK { All } ;
/*        | IDENT LPAREN IDENT RPAREN { $1 } ; */

column_defs: separated_nonempty_list(COMMA,column_def1) { $1 }
column_def1: IDENT sql_type column_def_extra* { RA.Scheme.attr $1 $2 } ;
column_def_extra: PRIMARY_KEY { Some Constraint.PrimaryKey }
                | NOT_NULL { Some Constraint.NotNull }
                | UNIQUE { Some Constraint.Unique }
                | AUTOINCREMENT { Some Constraint.Autoincrement }
                | ON CONFLICT conflict_algo { Some (Constraint.OnConflict $3) } ;
                | DEFAULT INTEGER { None }

/*
set_columns: set_columns1 { Raw.Cols (List.filter_valid (List.rev $1)) } ;

set_columns1: set_column { [$1] }
           | set_columns1 COMMA set_column { $3::$1 } ;

set_column: IDENT EQUAL expr { match $3 with | 1 -> Some $1 | x -> assert (0=x); None } ;
*/

expr:
      expr binary_op expr { $1 @ $3 }
    | expr LIKE_OP expr loption(escape) { $1 @ $3 @ $4 }
    | unary_op expr { $2 }
    | LPAREN expr RPAREN { $2 }
    | IDENT { [] }
    | IDENT DOT IDENT { [] }
    | IDENT DOT IDENT DOT IDENT { [] }
    | INTEGER { [] }
    | PARAM { [($1,None)] }
    | FUNCTION LPAREN func_params RPAREN { $3 }
    | expr TEST_NULL { $1 }
    | expr BETWEEN expr AND expr { $1 @ $3 @ $5 }
;
expr_list: separated_nonempty_list(COMMA,expr) { List.flatten $1 }
func_params: expr_list { $1 }
           | ASTERISK { [] } ;
escape: ESCAPE expr { $2 }
binary_op: PLUS | MINUS | ASTERISK | DIVIDE | EQUAL { } 

unary_op: EXCL { }
        | PLUS { }
        | MINUS { }
        | TILDE { }
        | NOT { } ;

conflict_algo: IGNORE { Constraint.Ignore } 
             | REPLACE { Constraint.Replace }
             | ABORT { Constraint.Abort }
             | FAIL { Constraint.Fail } 
             | ROLLBACK { Constraint.Rollback } ;

sql_type: T_INTEGER  { Type.Int }
        | T_BLOB { Type.Blob }
        | T_TEXT { Type.Text } ;

