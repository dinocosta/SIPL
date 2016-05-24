%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
  #import <glib.h>
  int yylex();
  int yyerror(char *);
  void add_var(char *);
  int get_addr(char *);
  int label;
%}

%union{
  char * s;
  int n;
}

%token Int RUN STOP wr rd IF
%token <s> VAR STRING
%token <n> NUM
%type <s> intvars ints insts expr parcel factor cond inst

%%
siplp: ints RUN insts STOP          { printf("%sstart\n%sstop\n", $1, $3); }
     ;
ints: Int intvars ';'               { $$ = $2; }
    ;
intvars: intvars ',' VAR          { asprintf(&$$, "%s\tpushi 0\n", $1); add_var($3); }
       | intvars ',' VAR '=' NUM  { asprintf(&$$, "%s\tpushi %d\n", $1, $5); add_var($3); }
       | VAR '=' NUM              { asprintf(&$$, "\tpushi %d\n", $3); add_var($1); }
       | VAR                      { asprintf(&$$, "\tpushi 0\n"); add_var($1); }
       ;
insts: inst                         { $$ = $1; }
     | insts inst                   { asprintf(&$$, "%s%s", $1, $2); }
inst: wr '(' VAR ')'';'             { asprintf(&$$, "\tpushg %d\n\twritei\n", get_addr($3));
                                      }
     | wr '(''"' STRING '"'')'';'   { asprintf(&$$, "\tpushs \"%s\"\n\twrites\n", $4); }
     | rd '(' VAR ')' ';'           { asprintf(&$$, "\tread\n\tatoi\n\tstoreg %d\n",
                                      get_addr($3)); }
     | VAR '=' expr ';'             { asprintf(&$$, "%s\tstoreg %d\n", $3, get_addr($1)); }
     | '?''('cond')' '{' insts '}'  { asprintf(&$$, "%s\tjz label%d\n%slabel%d: \b", $3, label, $6, label);
                                      label++; }
     |                              { $$ = ""; }
     ;
expr: parcel                { $$ = $1; }
    | expr '+' parcel       { asprintf(&$$, "%s%s\tadd\n", $1, $3); }
    | expr '-' parcel       { asprintf(&$$, "%s%s\tsub\n", $1, $3); }
    ;
parcel: parcel '*' factor   { asprintf(&$$, "%s%s\tmul\n", $1, $3); }
      | parcel '/' factor   { asprintf(&$$, "%s%s\tdiv\n", $1, $3); }
      | parcel '%' factor   { asprintf(&$$, "%s%s\tmod\n", $1, $3); }
      | factor              { $$ = $1; }
      ;
factor: NUM                 { asprintf(&$$, "\tpushi %d\n", $1); }
      | VAR                 { asprintf(&$$, "\tpushg %d\n", get_addr($1)); }
      | '(' expr ')'        { $$ = $2; }
      ;
cond: expr '>' expr         { asprintf(&$$, "%s%s\tsup\n", $1, $3); }
    | expr '<' expr         { asprintf(&$$, "%s%s\tinf\n", $1, $3); }
    | expr '>''=' expr      { asprintf(&$$, "%s%s\tsupeq\n", $1, $4); }
    | expr '<''=' expr      { asprintf(&$$, "%s%s\tinfeq\n", $1, $4); }
    | expr '!''=' expr      { asprintf(&$$, "%s%s\tequal\npushi 1\ninf\n", $1, $4); }
    | expr '=''=' expr      { asprintf(&$$, "%s%s\tequal\n", $1, $4); }
    ;
%%

#include "lex.yy.c"

// Hashtable used to map variable names to addresses.
GHashTable * addresses;
int pointer;

int yyerror (char *s) {
  fprintf(stderr, "%s (%d)\n", s, yylineno);
  return 0;
}

int main() {
  // Initialize variables needed to store the variable addresses.
  addresses = g_hash_table_new(g_str_hash, g_str_equal);
  pointer   = 0;
  label     = 0;

  yyparse();

  // Run through all the variables and print their addresses.
  /*
  GList * keys = g_hash_table_get_keys(addresses);
  while (keys != NULL) {
    int * addr = (int *) g_hash_table_lookup(addresses, keys->data);
    printf("%s - %d\n", keys->data, *addr);
    keys = keys->next;
  }
  */

  return 0;
}

/*  Add a variable to the hashtable, saving its global address. */
void add_var(char * var) {
  // Check if variable does not exist.
  int * addr = (int *) g_hash_table_lookup(addresses, var);
  if (addr == NULL) {
    addr = (int *) malloc(sizeof(int)); *addr = pointer;
    g_hash_table_insert(addresses, var, addr);
    pointer++;
  } else {
    // Stop execution if variable name is already in use.
    yyerror("Variável já em utilização.");
  }
}

/*  Get the global address of a given variable name. */
int get_addr(char * var) {
  int * addr = (int *) g_hash_table_lookup(addresses, var);
  if (addr == NULL) { // Variable does not exist.
    yyerror("A variável não existe.");
  } else {
    return *addr;
  }

  return 0;
}
