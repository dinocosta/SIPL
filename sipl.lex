%option noyywrap
%option yylineno
%x INTS INSTRUCTIONS READ WRITE ARRAYS

%%
<INITIAL>Int          { BEGIN INTS; return Int; }
<INTS>[A-Za-z]+       { yylval.s = strdup(yytext); return VAR; }
<INTS>[0-9]+          { yylval.n = atof(yytext); return NUM; }
<INTS>[,=]            { return yytext[0]; }
<INTS>;               { BEGIN INITIAL; return yytext[0]; }
<INTS>[ \t\n]*        { }

<INITIAL>RUN          { BEGIN INSTRUCTIONS; return RUN; }
<INSTRUCTIONS>STOP    { BEGIN INITIAL; return STOP; }
<INSTRUCTIONS>[ \t\n] { }

<*>.|\n               { }
%%
