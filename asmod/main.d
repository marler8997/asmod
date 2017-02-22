module asmod.main;

import std.stdio  : writeln, writefln, File;
import std.getopt : getopt;
import std.file   : exists;

import recipe : InstructionDefinition, instructionDefinitionMap, handleInstruction, emit;

import asmod.parseUtil : limitBeforeNewline, skipWhitespace, toWhitespace;

// Throw when the thrower has already logged the error message
class SilentException : Exception
{
  this() { super("Check log for error message"); }
}

__gshared string mainSourceFilename;

__gshared string currentSourceFilename;
__gshared uint currentLineNumber;

SilentException sourceFileError(T...)(string fmt, T args)
{
  writefln("%s(%s) " ~ fmt, currentSourceFilename, currentLineNumber, args);
  return new SilentException();
}

int main(string[] args)
{
  getopt(args);
  
  args = args[1..$];
  if(args.length == 0) {
    writefln("Error: please provide a source file");
    return 1;
  }
  if(args.length > 1) {
    writefln("Error: too many command line arguments");
    return 1;
  }

  mainSourceFilename = args[0];
  if(!exists(mainSourceFilename)) {
    writefln("Error: source file '%s' does not exist", mainSourceFilename);
    return 1;
  }

  try {
    currentLineNumber = 0;
    {
      char[] lineBuffer = new char[512]; // probably a good initial size
      currentSourceFilename = mainSourceFilename;
      auto sourceFile = File(mainSourceFilename, "r");
      string currentLabel = null;
      while(sourceFile.readln(lineBuffer)) {
        currentLineNumber++;

        char* ptr = lineBuffer.ptr;
        char* limit = lineBuffer.ptr + lineBuffer.length;
      
        // strip ending newline.
        // Do this first so you don't have to check for newline/carriage return
        // when checking for whitespace in the line itself.
        limit = limitBeforeNewline(ptr, limit);
        /*
          if(limit > ptr && *(limit-1) == '\n') {
          limit--;
          if(limit > ptr && *(limit-1) == '\r') {
          //writeln("[DEBUG] stripped \\r\\n");
          limit--;
          } else {
          //writeln("[DEBUG] stripped \\n");
          }
          }
        */

        ptr = ptr.skipWhitespace(limit);
        if(ptr >= limit || *ptr == ';') {
          continue;
        }
      
        char[] firstWord;
        {
          char *start = ptr;
          ptr++;
          ptr = ptr.toWhitespace(limit);
          firstWord = start[0..ptr-start];
        }

        if(firstWord[0] == '.') {
          if(currentLabel) {
            throw sourceFileError("an assembler directive was labeled '%s'", currentLabel);
          }
          writefln("directive not implemented");
          return 1;
        } else if(firstWord[$-1] == ':') {
	  if(firstWord.length == 1) {
	    throw sourceFileError("found a ':' with no label before it");
	  }
	  
          // it is a label
          if(currentLabel) {
            throw sourceFileError("the same location had multiple labels '%s' and '%s'",
                                  currentLabel, firstWord);
          }
          currentLabel = firstWord[0..$-1].idup;
        } else {
          // must be an instruction
          auto instructionDefinition = firstWord in instructionDefinitionMap;
          if(instructionDefinition is null) {
            throw sourceFileError("unknown instruction '%s'", firstWord);
          }
          //ptr = ptr.skipWhitespace(limit); // might as well skip whitespace here
          handleInstruction(currentLabel, *instructionDefinition, ptr, limit);
          currentLabel = null;
        }
      }
    }
    return emit();
  } catch(SilentException) {
    return 1;
  }
}

