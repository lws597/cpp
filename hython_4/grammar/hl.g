grammar hl;

options {
    language = C;
    output = AST;
    ASTLabelType=pANTLR3_BASE_TREE;
}

@header {
    #include <assert.h>
}

// The suffix '^' means make it a root.
// The suffix '!' means ignore it.

defid_expr
    : DEF! defid (','! defid)*
    ;

defid
    : ID^ (ASSIGN! condition_expr)?
    ;

expr: multExpr ((PLUS^ | MINUS^) multExpr)*
    ;

multExpr
    : invoExpr ((TIMES^ | DIV^ | MOD^) invoExpr)*
    ;

invoExpr
    : atom (POWER^ atom)*
    ;

atom: INT
    | ID
    | STRING
    | FLOAT
    | func_call
    | list_atom -> ^(LIST list_atom)
    | list_id -> ^(LIST_CALL list_id)
    | '('! expr ')'!
    ;

list_id: ID '['! expr ']'!;

list_atom: '['! exprs? ']'!;

exprs: expr (','! expr)*;

if_expr
    : IF^ '('! condition_expr ')'! stmt ( (ELSE) => ELSE! stmt )?
    ;

for_expr
    : FOR^ '('! init_expr ';'! condition_expr ';'! for_do_expr ')'! stmt
    ;

while_expr
    : WHILE^ '('! condition_expr ')'! stmt
    | DO block WHILE '(' condition_expr ')' ';' -> ^(DOWHILE condition_expr block)
    ;

init_expr
    : defid_expr -> ^(DEF defid_expr)
    | ID ASSIGN expr -> ^(ASSIGN ID expr)
    | -> ^(NOPE)
    ;

for_do_expr
    : ID ASSIGN expr -> ^(ASSIGN ID expr)
    | ID PLUS ASSIGN expr -> ^(ASSIGN ID ^(PLUS ID expr))
    | ID MINUS ASSIGN expr -> ^(ASSIGN ID ^(MINUS ID expr))
    | ID TIMES ASSIGN expr -> ^(ASSIGN ID ^(TIMES ID expr))
    | ID DIV ASSIGN expr -> ^(ASSIGN ID ^(DIV ID expr))
    | ID MOD ASSIGN expr -> ^(ASSIGN ID ^(MOD ID expr))
    | ID POWER ASSIGN expr -> ^(ASSIGN ID ^(POWER ID expr))
    | -> ^(NOPE)
    ;

switch_expr
    : SWITCH^ '('! condition_expr ')'! '{'! case_expr+ default_expr? '}'!
    ;

case_expr
    : CASE^ expr ':'! (stmt)*
    ;

default_expr
    : DEFAULT^ ':'! (stmt)*
    ;

condition_expr
    : andExpr (OR^ andExpr)*
    ;

andExpr
    : cmp_atom (AND^ cmp_atom)*
    ;

cmp_atom
    : cond_atom ((GT^ | LITTLE^ | EQ^ | GE^ | LE^ | NE^) cond_atom)?
    ;

cond_atom
    : expr
    | -> ^(NOPE)
    ;

block: block_expr -> ^(BLOCK block_expr);

block_expr
    : '{'! (stmt)* '}'!
    ;

print_atom
    : condition_expr
    ;

expr_stmt
    : expr ';' -> expr // tree rewrite syntax
    | ID ASSIGN expr ';' -> ^(ASSIGN ID expr) // tree notation
    | ID '[' INT ']' ASSIGN expr ';' -> ^(LIST_DEF ID INT expr)
    | ID PLUS ASSIGN expr ';' -> ^(ASSIGN ID ^(PLUS ID expr))
    | ID MINUS ASSIGN expr ';' -> ^(ASSIGN ID ^(MINUS ID expr))
    | ID TIMES ASSIGN expr ';' -> ^(ASSIGN ID ^(TIMES ID expr))
    | ID DIV ASSIGN expr ';' -> ^(ASSIGN ID ^(DIV ID expr))
    | ID MOD ASSIGN expr ';' -> ^(ASSIGN ID ^(MOD ID expr))
    | ID POWER ASSIGN expr ';' -> ^(ASSIGN ID ^(POWER ID expr))
    | PRINT^ print_atom (','! print_atom)* ';'!
    ;

control_stmt
    : for_expr
    | if_expr
    | while_expr
    | defid_expr ';' -> ^(DEF defid_expr)
    | block
    | BREAK ';'!
    | CONTINUE ';'!
    | RETURN^ condition_expr ';'!
    ;

def_param_expr: ID (','! ID)*;

param
    : '(' def_param_expr? ')' -> ^(PARAM def_param_expr?)
    ;

param_sub_expr: condition_expr (','! condition_expr)*;

param_expr
    : '(' param_sub_expr ')' -> ^(PARAM param_sub_expr)
    ;

func_stmt: FUNC^ ID param block;

func_call: ID param_expr -> ^(FUNC_CALL ID param_expr);

stmt: expr_stmt
    | control_stmt
    | func_stmt
    ;

prog: 
    (stmt {
            pANTLR3_STRING s = $stmt.tree->toStringTree($stmt.tree);
            assert(s->chars);
            printf("tree \%s\n", s->chars);
        }
    )+
    ;

SWITCH: 'switch';
CASE: 'case';
DEFAULT: 'default';
LIST: 'list';
LIST_CALL: 'list_call';
LIST_DEF: 'list_def';
FUNC: 'func';
RETURN: 'return';
PARAM: 'param';
FUNC_CALL: 'func_call';
MOD: '%';
DIV: '/';
POWER: '^';
NOPE: '404';
DO: 'do';
DOWHILE: 'dowhile';
WHILE: 'while';
FOR: 'for';
PRINT: 'print';
IF: 'if';
ELSE: 'else';
BREAK: 'break';
CONTINUE: 'continue';
OR: '||';
AND: '&&';
GE: '>=' | '=>';
NE: '!=';
LITTLE: '<';
LE: '<=' | '=<';
GT: '>';
EQ: '==';
PLUS: '+';
MINUS: '-';
TIMES: '*';
DOT : ',';
ASSIGN: '=';
BLOCK: '{}';
DEF: 'def';

INT: '-'? ('0'..'9')+;

ID: ('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*;

FLOAT
    : ('0'..'9')+ '.' ('0'..'9')* EXPONENT?
    | '.' ('0'..'9')+ EXPONENT?
    | ('0'..'9')+ EXPONENT
    ;

COMMENT
    : '//' ~('\n'|'\r')* '\r'? '\n' {$channel=HIDDEN;}
    | '/*' ( options {greedy=false;} : . )* '*/' {$channel=HIDDEN;}
    ;

WS: ( ' '
    | '\t'
    | '\r'
    | '\n'
    ) {$channel=HIDDEN;}
    ;

STRING
    : '"' ( ESC_SEQ | ~('\\'|'"') )* '"'
    ;

fragment
EXPONENT: ('e'|'E') ('+'|'-')? ('0'..'9')+ ;

fragment
HEX_DIGIT: ('0'..'9'|'a'..'f'|'A'..'F') ;

fragment
ESC_SEQ
    : '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
    | UNICODE_ESC
    | OCTAL_ESC
    ;

fragment
OCTAL_ESC
    : '\\' ('0'..'3') ('0'..'7') ('0'..'7')
    | '\\' ('0'..'7') ('0'..'7')
    | '\\' ('0'..'7')
    ;

fragment
UNICODE_ESC
    : '\\' 'u' HEX_DIGIT HEX_DIGIT HEX_DIGIT HEX_DIGIT
    ;
