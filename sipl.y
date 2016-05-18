%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
  #import <glib.h>
  int yylex();
  int yyerror(char *);
  void add_var(char *);
  int get_addr(char *);
%}

%union{
  char * s;
  int n;
}

%token Int RUN STOP wr rd
%token <s> VAR STRING
%token <n> NUM
%type <s> intvars ints insts

%%
siplp: ints RUN insts STOP          { printf("%sstart\n%sstop\n", $1, $3); }
     ;
ints: Int intvars ';'               { $$ = $2; }
    ;
intvars: intvars ',' VAR            { asprintf(&$$, "%spushi 0\n", $1); add_var($3); }
       | intvars ',' VAR '=' NUM    { asprintf(&$$, "%spushi %d\n", $1, $5); add_var($3); }
       | VAR '=' NUM                { asprintf(&$$, "pushi %d\n", $3); add_var($1); }
       | VAR                        { asprintf(&$$, "pushi 0\n"); add_var($1); }
       ;
insts: wr '(' VAR ')'';' insts      { asprintf(&$$, "pushg %d\nwritei\n%s", get_addr($3), $6); }
     | wr '(''"' STRING '"'')'';' insts
     {
      asprintf(&$$, "pushs \"%s\"\nwrites\n%s", $4, $8);
     }
     | rd '(' VAR ')' ';' insts     { asprintf(&$$, "read\natoi\nstoreg %d\n%s", get_addr($3),
                                      $6); }
     |                              { $$ = ""; }
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
