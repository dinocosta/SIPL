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

  typedef struct WrapString {
    char *begin;
    char *end;
  } WrapString;

%}

%union{
  char * s;
  int n;
  WrapString ss;
}

%token Int RUN STOP wr rd f call
%token <s> VAR STRING
%token <n> NUM
%type <s> intvars intvar ints insts expr parcel factor inst func funcs
%type <ss> data

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

funcs: func                         { $$ = $1; }
     | funcs func                   { asprintf(&$$, "%s%s", $1, $2); }
     |                              { $$ = ""; }
     ;

func: f STRING '{' insts '}'        { asprintf(&$$, "%s: nop\n%s\treturn\n", $2, $4); }
   ;

insts: inst                         { $$ = $1; }
     | insts inst                   { asprintf(&$$, "%s%s", $1, $2); }

inst: wr '(' factor ')' ';'         { asprintf(&$$, "%s\twritei\n", $3);}
    | wr '(' '"' STRING '"' ')'';'  { asprintf(&$$, "\tpushs \"%s\"\n\twrites\n", $4); }
    | rd '(' data ')' ';'           { asprintf(&$$, "%s\tread\n\tatoi\n\%s", $3.begin, $3.end); }
    | data '=' expr ';'             { asprintf(&$$, "%s%s%s", $1.begin, $3, $1.end); }
    | '?''('expr')' '{' insts '}'   { asprintf(&$$, "%s\tjz label%d\n%slabel%d: ", $3, label,
                                    $6, label); label++; }
    | '?''('expr')''{' insts '}''_''{' insts '}'     /* IF ELSE */
    { asprintf(&$$, "%s\tjz label%d\n%sjump label%d\nlabel%d: %slabel%d: ",
              $3, label, $6, label + 1, label, $10, label + 1); label += 2; }
    | '$''('expr')' '{' insts '}'                    /* WHILE */
    { asprintf(&$$, "label%d: %s\tjz label%d\n%sjump label%d\nlabel%d: ",
     label, $3, label + 1, $6, label, label + 1); label += 2; }
    | call STRING ';'              { asprintf(&$$, "\tpusha %s\n\tcall\n\tnop\n", $2); }
    |                              { $$ = ""; }
    ;

data: VAR                           { asprintf(&$$.begin, "");
                                      asprintf(&$$.end, "\tstoreg %d\n", get_var_addr($1)); }
    | VAR '[' expr ']'              { asprintf(&$$.begin, "\tpushgp\n\tpushi %d\n\tpadd\n%s", get_array_addr($1), $3);
                                      asprintf(&$$.end, "\tstoren\n"); }
    | VAR '[' expr ']' '[' expr ']' { asprintf(&$$.begin, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tpushi %d\n\tmul\n%s\tadd\n", get_array_addr($1), $3, get_array_cols_length($1), $6);
                                      asprintf(&$$.end, "\tstoren\n"); }

expr: parcel                 { $$ = $1; }
    | expr '+' parcel        { asprintf(&$$, "%s%s\tadd\n", $1, $3); }
    | expr '-' parcel        { asprintf(&$$, "%s%s\tsub\n", $1, $3); }
    ;

parcel: parcel '*' factor    { asprintf(&$$, "%s%s\tmul\n", $1, $3); }
      | parcel '/' factor    { asprintf(&$$, "%s%s\tdiv\n", $1, $3); }
      | parcel '%' factor    { asprintf(&$$, "%s%s\tmod\n", $1, $3); }
      | parcel '>' factor    { asprintf(&$$, "%s%s\tsup\n", $1, $3); }
      | parcel '<' factor    { asprintf(&$$, "%s%s\tinf\n", $1, $3); }
      | parcel '>''=' factor { asprintf(&$$, "%s%s\tsupeq\n", $1, $4); }
      | parcel '<''=' factor { asprintf(&$$, "%s%s\tinfeq\n", $1, $4); }
      | parcel '!''=' factor { asprintf(&$$, "%s%s\tequal\npushi 1\ninf\n", $1, $4); }
      | parcel '=''=' factor { asprintf(&$$, "%s%s\tequal\n", $1, $4); }
      | parcel '&' factor    { asprintf(&$$, "%s%s\tadd\n\tpushi 2\n\tequal\n", $1, $3); }
      | parcel '|' factor    { asprintf(&$$, "%s%s\tadd\n\tpushi 0\n\tsup\n", $1, $3); }
      | factor               { $$ = $1; }
      ;

factor: NUM                 { asprintf(&$$, "\tpushi %d\n", $1); }
      | VAR                 { asprintf(&$$, "\tpushg %d\n", get_var_addr($1)); }
      | VAR '[' expr ']'    { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tloadn\n", get_array_addr($1), $3); }
      | VAR '[' expr ']' '[' expr ']' { asprintf(&$$, "\tpushgp\n\tpushi %d\n\tpadd\n%s\tpushi %d\n\tmul\n%s\tadd\n\tloadn\n", get_array_addr($1), $3, get_array_cols_length($1), $6); }
      | '(' expr ')'        { $$ = $2; }
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
