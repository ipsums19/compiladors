#header
<<
#include <string>
#include <iostream>
#include <map>
using namespace std;

// struct to store information about tokens
typedef struct {
  string kind;
  string text;
} Attrib;

// function to fill token information (predeclaration)
void zzcr_attr(Attrib *attr, int type, char *text);

// fields for AST nodes
#define AST_FIELDS string kind; string text;
#include "ast.h"

// macro to create a new AST node (and function predeclaration)
#define zzcr_ast(as,attr,ttype,textt) as=createASTnode(attr,ttype,textt)
AST* createASTnode(Attrib* attr,int ttype, char *textt);
>>

<<
#include <cstdlib>
#include <cmath>

struct File {
  bool read;
  bool write;
  File(){
    read = false;
    write = false;
  }
};
//global structures
AST *root;
std::map<std::string,AST *> roles;
map<string,File> files;

inline int max(int a, int b)
{
    return a > b ? a : b;
}

// function to fill token information
void zzcr_attr(Attrib *attr, int type, char *text) {
    attr->kind = text;
    attr->text = "";
    }

// function to create a new AST node
AST* createASTnode(Attrib* attr, int type, char* text) {
  AST* as = new AST;
  as->kind = attr->kind; 
  as->text = attr->text;
  as->right = NULL; 
  as->down = NULL;
  return as;
}


/// create a new "list" AST node with one element
AST* createASTlist(AST *child) {
 AST *as=new AST;
 as->kind="list";
 as->right=NULL;
 as->down=child;
 return as;
}

/// get nth child of a tree. Count starts at 0.
/// if no such child, returns NULL
AST* child(AST *a,int n) {
AST *c=a->down;
for (int i=0; c!=NULL && i<n; i++) c=c->right;
return c;
}



/// print AST, recursively, with indentation
void ASTPrintIndent(AST *a,string s)
{
  if (a==NULL) return;

  cout<<a->kind;
  if (a->text!="") cout<<"("<<a->text<<")";
  cout<<endl;

  AST *i = a->down;
  while (i!=NULL && i->right!=NULL) {
    cout<<s+"  \\__";
    ASTPrintIndent(i,s+"  |"+string(i->kind.size()+i->text.size(),' '));
    i=i->right;
  }
  
  if (i!=NULL) {
      cout<<s+"  \\__";
      ASTPrintIndent(i,s+"   "+string(i->kind.size()+i->text.size(),' '));
      i=i->right;
  }
}

/// print AST 
void ASTPrint(AST *a)
{
  while (a!=NULL) {
    cout<<" ";
    ASTPrintIndent(a,"");
    a=a->right;
  }
}


bool calc_difference(AST *a1, AST *a2) {
    if(a1->down == a2->down) return true;
    else if(a1->kind == a2->kind) return calc_difference(a1->down,a2->down);
    else false;
}

int calc_critical(AST *a) {
    if(a == NULL) return 0;
    else if(a->down == NULL) return 1;
    else if(a->kind == ";") return calc_critical(a->down) + calc_critical(a->down->right);
    else return max(calc_critical(a->down), calc_critical(a->down->right));
}

int critical(string role) {
    AST* a = roles[role];
    if(a == NULL) return -1;
    else {
        return calc_critical(a->down);
    }
}

bool difference(string role1, string role2) {
    AST* a = roles[role1];
    AST* b = roles[role2];
    if(a == NULL or b == NULL) return false;
    else return calc_difference(a->down, b->down);
}

bool file(string role) {
    if(files[role].write and files[role].read) return true;
    else false;
}

void recorre(AST *a) {
  while (a!=NULL) {
    if (a->kind == "critical") {
      cout << "Critical " << child(a,0)->kind << " : " << critical(child(a,0)->kind) << endl;
    }
    else if (a->kind == "difference") {
      cout << "Difference: " << child(a,0)->kind << " and " << child(a,1)->kind<< " : " << difference(child(a,0)->kind,child(a,1)->kind) << endl;
    }
    else if (a->kind == "correctfile") {
      cout << "File " << child(a,0)->kind << " : " << file(child(a,0)->kind) <<endl;
    }
    a=a->right;
  }
}



int main() {
  root = NULL;
  ANTLR(bpmn(&root), stdin);
  for(AST *a = root->down->down; a != NULL; a = a->right)
  {
    if(a->kind == "connection") continue;
    else if(a->kind == "file") {
        AST * t = a->down;
        File& file = files[t->down->kind];
        file.read = file.read or t->kind == "->";
        file.write = file.write or t->kind == "<-";
    }
    else roles[a->kind] = a;
  }
  ASTPrint(root);
  recorre(child(child(root,1),0));
}
>>

#lexclass START
#token STARTP "start"
#token ENDP "end"
#token CONN "connection"
#token FILECONN "file"
#token CRIT "critical"
#token DIFFER "difference"
#token CORRECTF "correctfile"
#token FILEREAD "\->"
#token FILEWRITE "<\-"
#token OPENP "\("
#token CLOSEP "\)"
#token QUERIES "queries"
#token GPAR "\+"
#token GOR "\|"
#token GXOR "\#"
#token SEQ ";"
#token ID "[a-zA-Z][a-zA-Z0-9]*"
#token SPACE "[\ \n]" << zzskip();>>

bpmn: process QUERIES! queries <<#0=createASTlist(_sibling);>>;
process: (ini)+ (conn)* (file)* <<#0=createASTlist(_sibling);>>;
ini: STARTP! par ENDP! ID^;
par: exclusio (GPAR^ (exclusio|open))*;
exclusio: inclusio (GXOR^ (inclusio|open))*;
inclusio: seq (GOR^ (seq|open))*;
seq: ID (SEQ^ (ID|open))*;
open: OPENP! par CLOSEP!;

conn: CONN^ ID ID;
file: FILECONN^ file2;
file2: ID (FILEREAD^|FILEWRITE^) ID ;

queries: (critical)* (difference)* (correctfile)* <<#0=createASTlist(_sibling);>>;

critical: CRIT^ ID;
difference: DIFFER^ ID ID;
correctfile: CORRECTF^ ID;

