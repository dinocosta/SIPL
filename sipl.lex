%option noyywrap
%option yylineno
%x INTS INSTRUCTIONS

%%
<INITIAL>Int        { BEGIN INTS; return Int; }
<INTS>[a-z]+        { yylval.s = strdup(yytext); return VAR; }
<INTS>\,            { return yytext[0]; }
<INTS>\;            { BEGIN INITIAL; return yytext[0]; }
<INTS>[ \t\n]*      { }

<INITIAL>START      { BEGIN INSTRUCTIONS; return START; }
<INSTRUCTIONS>STOP  { BEGIN INITIAL; return STOP; }

<*>.|\n             { }
%%
