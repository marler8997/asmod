module asmod.commonDirectives;

import std.stdio : writeln, writefln;
import asmod.main : SilentException;

struct CommonDirective
{
  string name;
  void function(char*,char*) handler;
};
immutable commonDirectives =
  [immutable CommonDirective(".include", &handleIncludeDirective)];


void handleIncludeDirective(char* ptr, char* limit)
{
  writefln("Error: .include directive not implemented");
  throw new SilentException();
}
