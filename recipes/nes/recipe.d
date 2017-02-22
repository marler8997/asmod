module recipe; // must be called recipe

import std.stdio : writeln, writefln, File;
import std.path  : setExtension;

import asmod.main : mainSourceFilename, SilentException;
import asmod.parseUtil : parseCommandArgument, pullAndAssertOneArgument;
import asmod.m6502 : M6502Instruction, m6502Instructions;
import asmod.commonDirectives : CommonDirective, commonDirectives;

alias Directive = void function(char*,char*);
immutable Directive[string] directiveMap;

alias Instruction = M6502Instruction;
immutable Instruction[string] instructionMap;
static this()
{
  foreach(directive; commonDirectives) {
    directiveMap[directive.name] = directive.handler;
  }
  directiveMap[".mirror_type"] = &handleMirrorTypeDirective;
  directiveMap[".battery_backed_ram"] = &handleMirrorTypeDirective;
  // TODO: add commands
  // NmiLocation (sets the Nmi Handler vector table value to the current location)
  // IrqLocation (sets the Irq Handler vector table value to the current location)
  // ResetLocation (sets the reset location in the vector table)
  
  foreach(instruction; m6502Instructions) {
    instructionMap[instruction.name] = instruction;
  }
}

enum _16K = 0x4000;

enum MirrorType {
  Horizontal = 0x00,
  Vertical   = 0x01,
  UseVram    = 0x02,
}
struct RomSettings
{
  MirrorType mirrorType;
  bool batteryBackedRam;
}
RomSettings romSettings;
void handleMirrorTypeDirective(char* ptr, char* limit)
{
  romSettings.mirrorType = parseCommandArgument!MirrorType(pullAndAssertOneArgument("GraphicsType", ptr, limit));
}
void handleBatteryBackedRamDirective(char* ptr, char* limit)
{
  romSettings.batteryBackedRam = parseCommandArgument!bool(pullAndAssertOneArgument("BatteryBackedRam", ptr, limit));
}

struct CodeBuilder
{
  ubyte[_16K] buffer;
  uint contentLength;
}
CodeBuilder codeBuilder;

int emit()
{
  string outputFilename = mainSourceFilename.setExtension("nes");
  File outputFile = File(outputFilename, "wb");
  
  //
  // Render the NES header
  //
  outputFile.write("NES\x1A");

  writefln("codeBuilder.buffer.length = %s", codeBuilder.buffer.length);
  outputFile.write(cast(char)(codeBuilder.buffer.length / _16K));

  outputFile.write(cast(char)0); // [5] CHR rom is 0 for now
  // TODO: there is where the TrainerIsPresent flag would be set
  //       and also the lower nibble of the mapper number
  outputFile.write(cast(char)(
                   (romSettings.mirrorType & 0x01) |
                   ((romSettings.mirrorType & 0x02) << 2) |
                   (romSettings.batteryBackedRam ? 0x02 : 0x00)
                              )); // [6] 

  outputFile.write(cast(char)0); // [7] just use 0 for now
  outputFile.write(cast(char)0); // [8] size of PRG RAM in 8KB units
  outputFile.write(cast(char)0); // [9] just use 0 for now
  outputFile.write(cast(char)0); // [10] just use 0 for now
  outputFile.write("\0\0\0\0\0"); // [11-15] just use 0s for now

  //
  // TODO: insert trainer here if present
  //

  //
  // Insert PRG ROM
  //
  for(int i = 0; i < codeBuilder.contentLength; i++) {
    writefln("code[%s] = 0x%x", i, codeBuilder.buffer[i]);
  }
  outputFile.write(cast(char[])codeBuilder.buffer[0..codeBuilder.contentLength]);
  {
    auto extra = codeBuilder.contentLength % _16K;
    if(extra > 0) {
      auto padding = _16K - 6 - extra; // leave 6 bytes for interrupt vector table
      for(;padding > 16; padding -= 16) {
        outputFile.write("\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0");
      }
      for(;padding > 0; padding--) {
        outputFile.write('\0');
      }
    }
    // The interrupt vector table
    outputFile.write("\x00\x80\x00\x80\x00\x80");
  }

  //
  // Insert CHR ROM
  //
  // TODO: insert code to add CHR ROM

  
  
  return 0;
}

/*
struct CodeBuilder
{
  // buffer.length will always be in increments of 16 K
  ubyte[] buffer;
  uint contentLength;
  this(bool ignoreMe)
  {
    buffer = new ubyte[_16K];
  }
  void ensureMoreCapacity(uint size)
  {
    if(contentLength + size > buffer.length) {
      throw new Exception("code larger than 16 K not implemented");
      buffer.length += _16K;
    }
  }
  void put(ubyte c)
  {
    ensureMoreCapacity(1);
    buffer[contentLength++] = c;
  }
  void put(ubyte c1, ubyte c2)
  {
    ensureMoreCapacity(2);
    buffer[contentLength++] = c1;
    buffer[contentLength++] = c2;
  }
  void put(ubyte c1, ubyte c2, ubyte c3)
  {
    ensureMoreCapacity(3);
    buffer[contentLength++] = c1;
    buffer[contentLength++] = c2;
    buffer[contentLength++] = c3;
  }
  void put(ubyte[] code)
  {
    ensureMoreCapacity(code.length);
    buffer[contentLength..contentLength+code.length] = code[];
  }
};
CodeBuilder codeBuilder = CodeBuilder(true);
*/
