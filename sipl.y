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

%token Int START STOP
%token <s> VAR
%type <s> intvars ints

%%
siplp: ints START STOP              { printf("START\nSTOP"); }
     ;
ints: Int intvars ';'               { }
    ;
intvars: VAR ',' intvars            { printf("PUSHI 0\n"); }
       | VAR                        { printf("PUSHI 0\n"); }
       ;
%%

#include "lex.yy.c"

int yyerror (char *s) {
  fprintf(stderr, "Syntatic Error: %s (%d)\n", s, yylineno);
  return 0;
}

int main() {
  yyparse();
  return 0;
}
