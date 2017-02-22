module asmod.parseUtil;

import std.stdio : writeln, writefln;
import std.conv  : to, ConvException;

import asmod.main : sourceFileError;

inout(char)* limitBeforeNewline(inout(char)* ptr, inout(char)* limit)
{
  if(limit > ptr && *(limit-1) == '\n') {
    limit--;
    if(limit > ptr && *(limit-1) == '\r') {
      //writeln("[DEBUG] stripped \\r\\n");
      limit--;
    } else {
      //writeln("[DEBUG] stripped \\n");
    }
  }
  return limit;
}

inout(char)* skipWhitespace(inout(char)* str, inout(char)* limit)
{
  for(; str < limit && (*str == ' ' || *str == '\t'); str++) {
  }
  return str;
}
inout(char)* toWhitespace(inout(char)* str, inout(char)* limit)
{
  for(; str < limit && (*str != ' ' && *str != '\t'); str++) {
  }
  return str;
}
inout(char)* skipWhileTrue(alias predicate)(inout(char)* str, inout(char)* limit)
{
  for(; str < limit && predicate(*str); str++) {
  }
  return str;
}

// assumption: ptr is not at whitespace
char[] pullAndAssertOneArgument(string command, char* ptr, char* limit)
{
  if(ptr >= limit) {
    throw sourceFileError("command '%s' requires 1 argument but got 0", command);
  }
  char* start = ptr;
  ptr++;
  ptr = ptr.toWhitespace(limit);
  if(ptr < limit) {
    throw sourceFileError("command '%s' requires 1 argument but got more", command);
  }
  return start[0..ptr-start];
}
void assertNoArguments(string command, char* ptr, char* limit)
{
  if(ptr < limit) {
    throw sourceFileError("command '%s' requires 0 arguments but got more", command);
  }
}

T parseCommandArgument(T)(const(char)[] str)
{
  try {
    return to!T(str);
  } catch(ConvException e) {
    throw sourceFileError("'%s' is not a valid %s", str, T.stringof);
  }
}
