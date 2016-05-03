%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
%}

%union{
  char *s;
}

%token <s> TAG ATT TXT VATT
%type <s> elemento corpo atts abreele fechaele

%%
xml: elemento                           {printf("\\begin{document}\n" "%s\n" "\\end{document}\n", $1);}
    ;
elemento: abreele corpo fechaele        {asprintf(&$$, "%s %s %s", $1, $2, $3);}
        ;
corpo: corpo elemento                   {asprintf(&$$, "%s %s", $1, $2);}
    | corpo TXT                         {asprintf(&$$, "%s %s", $1, $2);}
    |                                   {$$="";}
    ;
abreele: '<' TAG atts '>'               {asprintf(&$$, "\\begin{%s}%s", $2, $3);}
        ;
atts: atts ATT '=' VATT                 {asprintf(&$$, "%s \\%s{%s}", $1, $2, $4);}
    |                                   {$$="";}
    ;
fechaele: '<' '/' TAG '>'               {asprintf(&$$, "\\end{%s}", $3);};
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
