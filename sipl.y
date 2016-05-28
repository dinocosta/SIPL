%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
  #import <glib.h>
  int yylex();
  int yyerror(char *);
  void add_var(char *);
  void add_array(char *, int);
  int get_addr(char *);
  int label;

  typedef struct ArrayInfo {
    int address;
    int size;
  } ArrayInfo;

%}

%union{
  char * s;
  int n;
}

%token Int RUN STOP wr rd IF WHILE
%token <s> VAR STRING
%token <n> NUM
%type <s> intvars intvar ints insts expr parcel factor cond inst

%%
siplp: ints RUN insts STOP          { printf("%sstart\n%sstop\n", $1, $3); }
     ;

ints: Int intvars ';'               { $$ = $2; }
    ;

intvars: intvar                     { $$ = $1; }
       | intvars ',' intvar         { asprintf(&$$, "%s%s", $1, $3); }
       ;

intvar: VAR                         { asprintf(&$$, "\tpushi 0\n"); add_var($1); }
      | VAR '=' NUM                 { asprintf(&$$, "\tpushi %d\n", $3); add_var($1); }
      | VAR '[' NUM ']'             { asprintf(&$$, "\tpushn %d\n", $3); add_array($1, $3);}

insts: inst                         { $$ = $1; }
     | insts inst                   { asprintf(&$$, "%s%s", $1, $2); }

inst: wr '(' VAR ')'';'             { asprintf(&$$, "\tpushg %d\n\twritei\n", get_addr($3));
                                      }
     | wr '(''"' STRING '"'')'';'   { asprintf(&$$, "\tpushs \"%s\"\n\twrites\n", $4); }
     | rd '(' VAR ')' ';'           { asprintf(&$$, "\tread\n\tatoi\n\tstoreg %d\n",
                                      get_addr($3)); }
     | VAR '=' expr ';'             { asprintf(&$$, "%s\tstoreg %d\n", $3, get_addr($1)); }
     | '?''('cond')' '{' insts '}'  { asprintf(&$$, "%s\tjz label%d\n%slabel%d: ", $3, label,
                                      $6, label); label++; }
     | '?''('cond')''{' insts '}''_''{' insts '}'     /* IF ELSE */
     { asprintf(&$$, "%s\tjz label%d\n%sjump label%d\nlabel%d: %slabel%d: ",
                $3, label, $6, label + 1, label, $10, label + 1); label += 2; }
     | '$''('cond')' '{' insts '}'                    /* WHILE */
     { asprintf(&$$, "label%d: %s\tjz label%d\n%sjump label%d\nlabel%d: ",
       label, $3, label + 1, $6, label, label + 1); label += 2; }
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

// Hashtable used to map variable names to var_addresses.
GHashTable * var_addresses;
GHashTable * array_addresses;
int pointer;

int yyerror (char *s) {
  fprintf(stderr, "%s (%d)\n", s, yylineno);
  return 0;
}

int main() {
  // Initialize variable addresses.
  var_addresses = g_hash_table_new(g_str_hash, g_str_equal);
  array_addresses = g_hash_table_new(g_str_hash, g_str_equal);
  pointer   = 0;
  label     = 0;

  yyparse();

  // Run through all the variables and print their var_addresses.
  /*
  GList * keys = g_hash_table_get_keys(var_addresses);
  while (keys != NULL) {
    int * addr = (int *) g_hash_table_lookup(var_addresses, keys->data);
    printf("%s - %d\n", keys->data, *addr);
    keys = keys->next;
  }
  */

  return 0;
}

/*  Add a variable to the hashtable, saving its global address. */
void add_var(char * var) {
  // Check if variable does not exist.
  int * addr = (int *) g_hash_table_lookup(var_addresses, var);
  if (addr == NULL) {
    addr = (int *) malloc(sizeof(int)); *addr = pointer;
    g_hash_table_insert(var_addresses, var, addr);
    pointer++;
  } else {
    // Stop execution if variable name is already in use.
    yyerror("Variável já em utilização.");
  }
}

/*  Add an array to the hashtable, saving its global address. */
void add_array(char * var, int size) {
  // Check if variable does not exist.
  ArrayInfo *array = (ArrayInfo *) g_hash_table_lookup(array_addresses, var);
  if (array == NULL && size > 0) {
    array = (ArrayInfo *) malloc(sizeof(ArrayInfo));
    array->address = pointer;
    g_hash_table_insert(array_addresses, var, array);
    pointer += size;
  }
  else if (size < 0) {
    // Stop execution if size is too small.
    yyerror("Tamanho do Array demasiado baixo.");
  }
  else {
    // Stop execution if variable name is already in use.
    yyerror("Variável já em utilização.");
  }
}

/*  Get the global address of a given variable name. */
int get_addr(char * var) {
  int * addr = (int *) g_hash_table_lookup(var_addresses, var);
  if (addr == NULL) { // Variable does not exist.
    yyerror("A variável não existe.");
  } else {
    return *addr;
  }

  return 0;
}
