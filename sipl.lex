%option noyywrap
%option yylineno
%x INTS INSTRUCTIONS READ WRITE ARRAYS INSTR EXPR COND

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

<INSTRUCTIONS>wr      { BEGIN WRITE; return wr; }
<WRITE>[()]           { return yytext[0]; }
<WRITE>["]            { BEGIN INSTR; return yytext[0]; }
<WRITE>[A-Za-z]+      { yylval.s = strdup(yytext); return VAR; }
<INSTR>[^"]+          { yylval.s = strdup(yytext); return STRING; }
<INSTR>["]            { BEGIN WRITE; return yytext[0]; }
<WRITE>;              { BEGIN INSTRUCTIONS; return yytext[0]; }

<INSTRUCTIONS>rd      { BEGIN READ; return rd; }
<READ>[()]            { return yytext[0]; }
<READ>[A-Za-z]+       { yylval.s = strdup(yytext); return VAR; }
<READ>;               { BEGIN INSTRUCTIONS; return yytext[0]; }

<INSTRUCTIONS>[A-Za-z]+ { BEGIN EXPR; yylval.s = strdup(yytext); return VAR; }
<EXPR>[-+*/%()=]       { return yytext[0]; }
<EXPR>[0-9]+            { yylval.n = atof(yytext); return NUM; }
<EXPR>[A-Za-z]+         { yylval.s = strdup(yytext); return VAR; }
<EXPR>;                 { BEGIN INSTRUCTIONS; return yytext[0]; }

<INSTRUCTIONS>[?]       { BEGIN COND; return yytext[0]; }
<COND>[-+*/()=><!]      { return yytext[0]; }
<COND>[0-9]+            { yylval.n = atof(yytext); return NUM; }
<COND>[A-Za-z]+         { yylval.s = strdup(yytext); return VAR; }
<COND>[{]               { BEGIN INSTRUCTIONS; return yytext[0]; }
<COND>[ \t\n]*          { }

<INSTRUCTIONS>[}]       { return yytext[0]; }

<*>.|\n               { }
%%
