%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
  #import <glib.h>
  int yylex();
  int yyerror(char *);
  void add_var(char *);
%}

%union{
  char * s;
  int n;
}

%token Int RUN STOP
%token <s> VAR
%token <n> NUM
%type <s> intvars ints

%%
siplp: ints RUN STOP                { printf("%sstart\nstop\n", $1); }
     ;
ints: Int intvars ';'               { $$ = $2; }
    ;
intvars: intvars ',' VAR            { asprintf(&$$, "%spushi 0\n", $1); add_var($3); }
       | intvars ',' VAR '=' NUM    { asprintf(&$$, "%spushi %d\n", $1, $5); add_var($3); }
       | VAR '=' NUM                { asprintf(&$$, "pushi %d\n", $3); add_var($1); }
       | VAR                        { asprintf(&$$, "pushi 0\n"); add_var($1); }
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
