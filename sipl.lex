%option noyywrap
%option yylineno

%%

<*>.|\n                 { yyerror("Invalid character!\n"); }
%%
