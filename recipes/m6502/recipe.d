module recipe; // must be called recipe

import std.stdio  : writeln, writefln;
import std.format : formattedWrite;

import asmod.util : AsciiPrintString;
import asmod.main : sourceFileError, SilentException;
import asmod.parseUtil : skipWhitespace, skipWhileTrue;
import asmod.m6502 : M6502Instruction, instructionSets, AddressMode;

version(unittest)
{
  import std.format : format;
  import asmod.main : currentSourceFilename, currentLineNumber;
}

// Recipe Interface
// Instruction : the instruction type (should be a struct)
// instructionMap : a map of instruction name to Instruction
// addInstruction(string name, Instruction ins)
// emit: a function that emits the final code (returns an int)

alias InstructionDefinition = M6502Instruction*;
/*
struct Instruction
{
  void function(char*,char*) handler;
}
*/
immutable InstructionDefinition[string] instructionDefinitionMap;
static this()
{
  foreach(instructionSet; instructionSets) {
    immutable(ubyte)* limit = instructionSet.array.ptr + (instructionSet.elementSize * instructionSet.array.length);
    for(immutable(ubyte)* ptr = instructionSet.array.ptr;
        ptr < limit;
        ptr += instructionSet.elementSize) {
      auto definition = cast(immutable(M6502Instruction)*)ptr;
      instructionDefinitionMap[definition.name] = definition;
      //writefln("[DEBUG] added instruction '%s'", definition.name);
    }
  }
}

struct Instruction
{
  immutable(InstructionDefinition) definition;
  InstructionArgs args;
}

import std.array : Appender, appender;

// The base address of the current instruction section
ushort instructionBaseAddress = 0;
Appender!(Instruction[]) instructions = appender!(Instruction[])();
// mapping from label to an offset into the instructions array
ushort[string] labelMap;

inout(char)* parseNumber(ushort* outValue, inout(char)* ptr, inout(char)* limit, ubyte maxHexDigits)
{
  if(ptr >= limit) {
    throw sourceFileError("expected number but reached end of line");
  }

  char c = *ptr;
  // handle hex
  if(c == '$') {
    ptr++;
    if(ptr >= limit) {
      throw sourceFileError("missing hex digits after '$'");
    }
    ubyte digitCount = 0;
    ushort value = 0;
    do {
      c = *ptr;
      ubyte nextValue;
      if(c <= '9') {
        if(c < '0') break;
        nextValue = cast(ubyte)(c - '0');
      } else if(c < 'A') {
        break;
      } else if(c <= 'F') {
        nextValue = cast(ubyte)(c + 10 - 'A');
      } else if(c < 'a') {
        break;
      } else if(c <= 'f') {
        nextValue = cast(ubyte)(c + 10 - 'a');
      } else {
        break;
      }
      digitCount++;
      if(digitCount > maxHexDigits) {
        throw sourceFileError("too many hex digits after '$'");
      }
      value <<= 4;
      value += nextValue;
      ptr++;
    } while(ptr < limit);
    if(digitCount == 0) {
      throw sourceFileError("expected hex digits after '$' but got '$%s'", AsciiPrintString(ptr[0..limit-ptr]));
    }
    *outValue = value;
  } else {
    if(c < '0' || c > '9') {
      throw sourceFileError("expected a number starting with '$' or '0-9' but got '%s'", AsciiPrintString(ptr[0..limit-ptr]));
    }
    uint value = c - '0';
    while(true) {
      ptr++;
      if(ptr >= limit) {
        break;
      }
      c = *ptr;
      if(c < '0' || c > '9') {
        break;
      }
      value *= 10;
      value += (c - '0');
      if(value > ushort.max) {
        throw sourceFileError("value too large");
      }
    }
    *outValue = cast(ushort)value;
  }
  return ptr;
}
unittest
{
  void testGoodNumber(ushort expected, const(char)[] testCase, uint line = __LINE__)
  {
    currentLineNumber = line;
    ushort value;
    auto newPtr = parseNumber(&value, testCase.ptr, testCase.ptr + testCase.length);
    assert(expected == value, format("test cast '%s' should have parsed to %s, but got %s",
                                     testCase, expected, value));
    //writefln("testCase '%s' worked!", testCase);
  }
  testGoodNumber(0, "0");
  testGoodNumber(0, "00");
  testGoodNumber(0, "000000000");
  testGoodNumber(0, "$0");
  testGoodNumber(0, "$00");
  testGoodNumber(0, "$000");
  testGoodNumber(0, "$0000");

  testGoodNumber(1, "1");
  testGoodNumber(65535, "65535");
  testGoodNumber(1, "1a");
  testGoodNumber(1, "1z");
  testGoodNumber(1, "1!");
  testGoodNumber(1900, "1900");
  testGoodNumber(1900, "1900A");

  testGoodNumber(1, "$1");
  testGoodNumber(1, "$01");
  testGoodNumber(1, "$001");
  testGoodNumber(1, "$0001");
  testGoodNumber(0xF, "$F");
  testGoodNumber(0xFF, "$FF");
  testGoodNumber(0xFFF, "$FFF");
  testGoodNumber(0xFFFF, "$FFFF");
  
  testGoodNumber(0x0123, "$0123");
  testGoodNumber(0x4567, "$4567");
  testGoodNumber(0x89AB, "$89AB");
  testGoodNumber(0xCDEF, "$CDEF");
}
unittest
{
  void testBadNumber(const(char)[] testCase, uint line = __LINE__)
  {
    currentLineNumber = line;
    try {
      ushort value;
      parseNumber(&value, testCase.ptr, testCase.ptr + testCase.length);
      assert(0, format("expected exception but did not get one (testline %s)", line));
    } catch(SilentException) {
    }
  }
  currentSourceFilename = __FILE__;
  testBadNumber("");
  {
    char[1] badString;
    // invalid 1st character
    for(char c = '\0'; c < 127; c++) {
      if(c < '0' || c > '9') {
        badString[0] = c;
        testBadNumber(badString);
      }
    }
  }
  testBadNumber("65536"); // too large
  testBadNumber("$");
  {
    char[2] badString;
    badString[0] = '$';
    // invalid 2nd character
    for(char c = '\0'; c < 127; c++) {
      if(c < '0' ||
         (c > '9' && c < 'A') ||
         (c > 'F' && c < 'a') ||
         c > 'f') {
        badString[1] = c;
        testBadNumber(badString);
      }
    }
  }
  testBadNumber("$00000"); // too many digits
  testBadNumber("$19208"); // too many digits
  testBadNumber("$ABCDE"); // too many digits
  testBadNumber("$abcde"); // too many digits
}

struct InstructionArgs
{
  AddressMode addressMode;
  union {
    ubyte ubyteValue;
    ushort ushortValue;
  }
  this(AddressMode addressMode)
  {
    this.addressMode = addressMode;
  }
  this(AddressMode addressMode, ubyte value)
  {
    this.addressMode = addressMode;
    this.ubyteValue = value;
  }
  this(AddressMode addressMode, ushort value)
  {
    this.addressMode = addressMode;
    this.ushortValue = value;
  }
}

enum IndexRegister : bool { x, y }

// regex: [_A-Za-z]
bool isFirstCharOfLabel(char c)
{
  return c >= 'A' && (c <= 'Z' ||
		      (c >= 'a' && c <= 'z') ||
		      c == '_');
}
// regex: [_A-Za-z]
bool isLabelChar(char c)
{
  return c >= '0' && (c <= '9' ||
		      (c >= 'A' && c <= 'Z') ||
		      (c >= 'a' && c <= 'z') ||
		      c == '_');
}
inout(char)* skipWhitespaceAndComment(inout(char)* str, inout(char)* limit)
{
  for(; str < limit; str++) {
    if(*str != ' ' && *str != '\t') {
      if(*str == ';') {
	return limit; // if comment found, skip to end
      }
      break;
    }
  }
  return str;
}



InstructionArgs parseArgs(const(char)* ptr, const(char)* limit)
{
  ptr = skipWhitespaceAndComment(ptr, limit);
  if(ptr >= limit) {
    return InstructionArgs(AddressMode.implied);
  }
  char firstChar = *ptr;
  if(firstChar == '#') {
    ushort immediate;
    ptr = parseNumber(&immediate, ptr+1, limit, 2).skipWhitespaceAndComment(limit);
    if(ptr >= limit) {
      if(immediate > 0xFF) {
        throw sourceFileError("immediate value is too large");
      }
      return InstructionArgs(AddressMode.immediate, cast(ubyte)immediate);
    } else {
      throw sourceFileError("immediate value instruction args '%s' not implemented", ptr[0..limit-ptr]);
    }
  }
  if(firstChar == '$' || (firstChar >= '0' && firstChar <= '9')) {
    ushort number;
    ptr = parseNumber(&number, ptr, limit, 4).skipWhitespaceAndComment(limit);
    if(ptr >= limit) {
      if(number <= 0xFF) {
	return InstructionArgs(AddressMode.zeroPage, cast(ubyte)number);
      } else {
	return InstructionArgs(AddressMode.absoluteOrRelative, number);
      }
    }
    if(*ptr == ',') {
      ptr = skipWhitespaceAndComment(ptr+1, limit);
      if(ptr >= limit) {
	throw sourceFileError("expected 'X' or 'Y' after ',' but reached end of line");
      }
      IndexRegister indexRegister;
      if(*ptr == 'X') {
	indexRegister = IndexRegister.x;
      } else if(*ptr == 'Y') {
	indexRegister = IndexRegister.y;
      } else {
	throw sourceFileError("expected 'X' or 'Y' after ',' but got '%s'", AsciiPrintString(ptr[0..limit-ptr]));
      }

      ptr = skipWhitespaceAndComment(ptr+1, limit);
      if(ptr >= limit) {
	if(number <= 0xFF) {
	  return InstructionArgs((indexRegister == IndexRegister.x) ?
				 AddressMode.zeroPageIndexedX : AddressMode.zeroPageIndexedY, cast(ubyte)number);
	} else {
	  return InstructionArgs((indexRegister == IndexRegister.x) ?
				 AddressMode.absoluteIndexedX : AddressMode.absoluteIndexedY, number);
	}
      }

      throw sourceFileError("instruction args '%s' not implemented", ptr[0..limit-ptr]);
      
    } else {
      throw sourceFileError("instruction args '%s' not implemented", ptr[0..limit-ptr]);
    }
  }
  if(firstChar == '(') {
    throw sourceFileError("args starting with '(' not implemented");
  }
  if(isFirstCharOfLabel(firstChar)) {
    const(char)[] label;
    {
      auto start = ptr;
      ptr = skipWhileTrue!isLabelChar(ptr+1, limit);
      label = start[0..ptr-start];
      writefln("found label '%s'", label);
    }
    if(ptr >= limit) {
      auto offset = (cast(string)label) in labelMap;
      if(offset is null) {
	throw sourceFileError("label '%s' has not been defined yet", label);
      }
      // todo: handle when valueis larger than ushort.max
      ushort number = cast(ushort)(instructionBaseAddress + offset);
      if(number <= 0xFF) {
	return InstructionArgs(AddressMode.zeroPage, cast(ubyte)number);
      } else {
	return InstructionArgs(AddressMode.absoluteOrRelative, number);
      }
    }
    throw sourceFileError("label with more args not implemented");
  }

  throw sourceFileError("unexpected char at '%s'", AsciiPrintString(ptr[0..limit-ptr]));
}
unittest
{
  void testBadArgs(const(char)[] testCase, uint line = __LINE__)
  {
    currentLineNumber = line;
    try {
      parseArgs(testCase.ptr, testCase.ptr + testCase.length);
      assert(0, format("expected exception but did not get one (testline %s)", line));
    } catch(SilentException) {
    }
  }
  currentSourceFilename = __FILE__;
  testBadArgs("$");
  testBadArgs("$0,");
  testBadArgs("0,");
  testBadArgs("$1,");
  testBadArgs("1,");
  {
    char[3] badString;
    badString[0] = '0';
    badString[1] = ',';
    for(char c = '\0'; c < 127; c++) {
      if(c != 'X' && c != 'Y') {
        badString[2] = c;
        testBadArgs(badString);
      }
    }
  }
}

// label should not include the colon
void handleInstruction(string label, immutable(InstructionDefinition) definition, char* ptr, char* limit)
{
  if(label) {
    if(label in labelMap) {
      throw sourceFileError("label '%s' was used multiple times", label);
    }
    // todo: handle when data.length is larger than ushort.max
    labelMap[label] = cast(ushort)instructions.data.length;
  }

  InstructionArgs args = parseArgs(ptr, limit);
  writefln("label '%s' instruction '%s' address mode '%s'", label ? label : "(null)", definition.name, args.addressMode);
  
  instructions.put(Instruction(definition, args));
}

int emit()
{
  foreach(instruction; instructions.data) {
    writefln("need to emit '%s'", instruction.definition.name);
  }
  writeln("todo: m6502 recipe emit function");
  return 1;
}
