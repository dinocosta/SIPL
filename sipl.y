%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
  int yylex();
  int yyerror(char *);
%}

%union{
  char * s;
  int n;
}

%token Int Ints START STOP RD WR IF ELSE ELSEIF WHILE AND OR
%token <n> NUM
%token <s> VAR STRING
%type <s> intvars ints insts data

%%
siplp: ints arrays START insts STOP               { printf("start\n%sstop", $4); }
     ;
ints: Int intvars ';'                             { }
    ;
intvars: VAR ',' intvars                          { printf("pushi 0\n"); }
       | VAR                                      { printf("pushi 0\n"); }
       ;
arrays: Ints arrayvars ';'                        { }
      ;
data: VAR
    | VAR '[' NUM ']'
    | VAR '[' NUM ']' '[' NUM ']'
arrayvars: VAR '[' NUM ']' ',' arrayvars          { }
         | VAR '[' NUM ']' '[' NUM ']' arrayvars  { }
         | VAR '[' NUM ']' '[' NUM ']'            { }
         | VAR '[' NUM ']'                        { }
insts: RD '(' data ')' ';' insts                  { printf("READ(%s);\n", $3); }
     | WR '(' data ')' ';' insts                  { printf("WRITE(%s);\n", $3); }
     | WR '(''"' STRING '"' ')' ';' insts         { printf("WRITE(%s);\n)", $4); }
     | data "=" expr ';' insts                    { printf("Atribuuição\n"); }
     | while insts                                { }
     | if insts                                   { }
     |                                            { $$ = ""; }
     ;
expr: parcel
    | expr '+' parcel
    | expr '-' parcel
    ;
parcel: parcel '*' factor
      | parcel '/' factor
      | factor
      ;
factor: NUM
      | VAR
      | '(' expr ')'
      ;
while: WHILE '(' cond ')' '{' insts '}'
     ;
if: IF '(' cond ')' '{' insts '}' else
  | IF '(' cond ')' '{' insts '}' elseif
  | IF '(' cond ')' '{' insts '}'
  ;
else: ELSE '{' insts '}'
    ;
elseif: ELSEIF '(' cond ')' '{' insts '}' elseif
      | ELSEIF '(' cond ')' '{' insts '}' else
      | ELSEIF '(' cond ')' '{' insts '}'
      ;
cond: cond AND cond
    | cond OR cond
    | expr ">=" expr
    | expr ">" expr
    | expr "<=" expr
    | expr "<" expr
    | expr "==" expr
    | expr "!=" expr
    ;
%%

#include "lex.yy.c"

int yyerror (char *s) {
  fprintf(stderr, "%s (%d)\n", s, yylineno);
  return 0;
}

int main() {
  yyparse();
  return 0;
}
