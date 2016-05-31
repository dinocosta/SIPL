%{
  #define _GNU_SOURCE
  #include <string.h>
  #include <stdio.h>
  #import <glib.h>
  int yylex();
  int yyerror(char *);
  void add_var(char *);
  void add_array(char *, int, int);
  int get_var_addr(char *);
  int get_array_addr(char *);
  int get_array_cols_length(char *);

  int label;

  typedef struct ArrayInfo {
    int address;
    int rows;
    int cols;
  } ArrayInfo;

%}

%union{
  char * s;
  int n;
}

%token Int RUN STOP wr rd f call
%token <s> VAR STRING
%token <n> NUM
%type <s> intvars intvar ints insts expr parcel factor cond inst fnc funcs

%%
siplp: ints funcs RUN insts STOP    { printf("%sjump inic\n%sstart\ninic: %sstop\n", $1, $2, $4); }
     ;

ints: Int intvars ';'               { $$ = $2; }
    ;

intvars: intvar                     { $$ = $1; }
       | intvars ',' intvar         { asprintf(&$$, "%s%s", $1, $3); }
       ;

intvar: VAR                         { asprintf(&$$, "\tpushi 0\n"); add_var($1); }
      | VAR '=' NUM                 { asprintf(&$$, "\tpushi %d\n", $3); add_var($1); }
      | VAR '[' NUM ']'             { asprintf(&$$, "\tpushn %d\n", $3); add_array($1, $3, 0);}
      | VAR '[' NUM ']' '[' NUM ']' { asprintf(&$$, "\tpushn %d\n", $3 * $6); add_array($1, $3, $6);}

funcs: fnc                          { $$ = $1; }
     | funcs fnc                    { asprintf(&$$, "%s%s", $1, $2); }
     |                              { $$ = ""; }
     ;

fnc: f STRING '{' insts '}'         { asprintf(&$$, "%s: nop\n%s\treturn\n", $2, $4); }
   ;

insts: inst                         { $$ = $1; }
     | insts inst                   { asprintf(&$$, "%s%s", $1, $2); }

inst: wr '(' factor ')' ';'         { asprintf(&$$, "%s\twritei\n", $3);}
    | wr '(''"' STRING '"'')'';'    { asprintf(&$$, "\tpushs \"%s\"\n\twrites\n", $4); }
    | rd '(' VAR ')' ';'            { asprintf(&$$, "\tread\n\tatoi\n\tstoreg %d\n",
                                    get_var_addr($3)); }
    | rd '(' VAR '[' expr ']' ')' ';' { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tread\n\tatoi\n\tstoren\n", get_array_addr($3), $5); }
    | rd '(' VAR '[' expr ']' '[' expr ']' ')' ';' { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tpushi %d\n\tmul\n%s\tadd\n\tread\n\tatoi\n\tstoren\n", get_array_addr($3), $5, get_array_cols_length($3), $8); }
    | VAR '=' expr ';'              { asprintf(&$$, "%s\tstoreg %d\n", $3, get_var_addr($1)); }
    | VAR '[' expr ']' '=' expr ';' { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s%s\tstoren\n", get_array_addr($1), $3, $6); }
    | VAR '[' expr ']' '[' expr ']' '=' expr ';' { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tpushi %d\n\tmul\n%s\tadd\n%s\tstoren\n", get_array_addr($1), $3, get_array_cols_length($1), $6, $9); }
    | '?''('cond')' '{' insts '}'   { asprintf(&$$, "%s\tjz label%d\n%slabel%d: ", $3, label,
                                    $6, label); label++; }
    | '?''('cond')''{' insts '}''_''{' insts '}'     /* IF ELSE */
    { asprintf(&$$, "%s\tjz label%d\n%sjump label%d\nlabel%d: %slabel%d: ",
              $3, label, $6, label + 1, label, $10, label + 1); label += 2; }
    | '$''('cond')' '{' insts '}'                    /* WHILE */
    { asprintf(&$$, "label%d: %s\tjz label%d\n%sjump label%d\nlabel%d: ",
     label, $3, label + 1, $6, label, label + 1); label += 2; }
    | call STRING ';'              { asprintf(&$$, "\tpusha %s\n\tcall\n\tnop\n", $2); }
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
      | VAR                 { asprintf(&$$, "\tpushg %d\n", get_var_addr($1)); }
      | VAR '[' expr ']'    { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tloadn\n", get_array_addr($1), $3); }
      | VAR '[' expr ']' '[' expr ']' { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tpushi %d\n\tmul\n%s\tadd\n\tloadn\n", get_array_addr($1), $3, get_array_cols_length($1), $6); }
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
  char *error_message;
  // Check if variable does not exist.
  int *addr = (int *) g_hash_table_lookup(var_addresses, var);
  ArrayInfo *array = (ArrayInfo *) g_hash_table_lookup(array_addresses, var);
  if (addr == NULL && array == NULL) {
    addr = (int *) malloc(sizeof(int)); *addr = pointer;
    g_hash_table_insert(var_addresses, var, addr);
    pointer++;
  } else {
    // Stop execution if variable name is already in use.
    asprintf(&error_message, "Variável '%s' já em utilização.", var);
    yyerror(error_message);
  }
}

/*  Add an array to the hashtable, saving its global address. */
void add_array(char * var, int rows, int cols) {
  char *error_message;
  // Check if variable does not exist.
  int *addr = (int *) g_hash_table_lookup(var_addresses, var);
  ArrayInfo *array = (ArrayInfo *) g_hash_table_lookup(array_addresses, var);
  if (array == NULL && addr == NULL && rows > 0) {
    array = (ArrayInfo *) malloc(sizeof(ArrayInfo));
    array->address = pointer;
    array->rows = rows;
    array->cols = cols;
    g_hash_table_insert(array_addresses, var, array);
    pointer += rows;
  }
  else {
    if (rows < 1) {
      // Stop execution if rows is too small.
      asprintf(&error_message, "Tamanho do array '%s' demasiado baixo.", var);
      yyerror(error_message);
    }
    if (array != NULL || addr != NULL) {
      // Stop execution if variable name is already in use.
      asprintf(&error_message, "Variável '%s' já em utilização.", var);
      yyerror(error_message);
    }
  }
}

/*  Get the global address of a given variable name. */
int get_var_addr(char * var) {
  char *error_message;
  int * addr = (int *) g_hash_table_lookup(var_addresses, var);
  if (addr == NULL) {
    // Variable does not exist.
    asprintf(&error_message, "Variável '%s' não inicializada.", var);
    yyerror(error_message);
  }
  else {
    return *addr;
  }

  return 0;
}

int get_array_addr(char * var) {
  char *error_message;
  ArrayInfo *array = (ArrayInfo *) g_hash_table_lookup(array_addresses, var);
  if (array == NULL) {
    // Variable does not exist.
    asprintf(&error_message, "Array '%s' não inicializado.", var);
    yyerror(error_message);
  }
  else {
    return array->address;
  }

  return 0;
}

int get_array_cols_length(char * var) {
  char *error_message;
  ArrayInfo *array = (ArrayInfo *) g_hash_table_lookup(array_addresses, var);
  if (array == NULL) {
    // Variable does not exist.
    asprintf(&error_message, "Array '%s' não inicializado.", var);
    yyerror(error_message);
  }
  else {
    return array->cols;
  }

  return 0;
}
