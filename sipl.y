%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
  int yylex();
  int yyerror(char *);
%}

%union{
  char * s;
}

%token Int START STOP RD WR
%token <s> VAR
%type <s> intvars ints insts

%%
siplp: ints START insts STOP        { printf("START\n%sSTOP", $3); }
     ;
ints: Int intvars ';'               { }
    ;
intvars: VAR ',' intvars            { printf("PUSHI 0\n"); }
       | VAR                        { printf("PUSHI 0\n"); }
       ;
insts: RD '(' VAR ')' ';' insts     { printf("READ(%s);\n", $3); }
     | WR '(' VAR ')' ';' insts     { printf("WRITE(%s);\n", $3); }
     |                              { $$ = ""; }
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
