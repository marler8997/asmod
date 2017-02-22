module asmod.m6502;

// There may be a particular ordering of these
// enums that could provide some efficiencies
// when creating opcodes, but not sure.
enum AddressMode : ubyte {
  immediate          =  0, // #aa
  absoluteOrRelative =  1, // aaaa
  zeroPage           =  2, // aa
  implied            =  3, // nothing
  indirectAbsolute   =  4, // (aaaa)
  absoluteIndexedX   =  5, // aaaa,X
  absoluteIndexedY   =  6, // aaaa,Y
  zeroPageIndexedX   =  7, // aa,X
  zeroPageIndexedY   =  8, // aa,Y
  indexedIndirect    =  9, // (aa,X)
  indirectIndexed    = 10, // (aa),Y
  accumulator        = 12, // A
}
enum AddressModeFlags : ushort {
  immediate          = 0x0001, // #aa
  absoluteOrRelative = 0x0002, // aaaa
  zeroPage           = 0x0004, // aa
  implied            = 0x0008, // nothing
  indirectAbsolute   = 0x0010, // (aaaa)
  absoluteIndexedX   = 0x0020, // aaaa,X
  absoluteIndexedY   = 0x0040, // aaaa,Y
  zeroPageIndexedX   = 0x0080, // aa,X
  zeroPageIndexedY   = 0x0100, // aa,Y
  indexedIndirect    = 0x0200, // (aa,X)
  indirectIndexed    = 0x0400, // (aa),Y
  accumulator        = 0x0800, // A
}

enum addressModeSetBasic3 = cast(AddressModeFlags)(
  AddressModeFlags.immediate |
  AddressModeFlags.absoluteOrRelative |
  AddressModeFlags.zeroPage);
enum addressModeSetRegisterY3 = cast(AddressModeFlags)(
  AddressModeFlags.absoluteOrRelative |
  AddressModeFlags.zeroPage |
  AddressModeFlags.zeroPageIndexedX);
enum addressModeSetDefault4 = cast(AddressModeFlags)(
  AddressModeFlags.absoluteOrRelative |
  AddressModeFlags.zeroPage |
  AddressModeFlags.zeroPageIndexedX |
  AddressModeFlags.absoluteIndexedX);
enum addressModeSetDefault8 = cast(AddressModeFlags)(
  AddressModeFlags.immediate |
  AddressModeFlags.absoluteOrRelative |
  AddressModeFlags.zeroPage |
  AddressModeFlags.zeroPageIndexedX |
  AddressModeFlags.absoluteIndexedX |
  AddressModeFlags.absoluteIndexedY |
  AddressModeFlags.indexedIndirect |
  AddressModeFlags.indirectIndexed);

enum addressModeSet_2 = cast(AddressModeFlags)(
  AddressModeFlags.immediate |
  AddressModeFlags.absoluteOrRelative |
  AddressModeFlags.zeroPage |
  AddressModeFlags.zeroPageIndexedY |
  AddressModeFlags.absoluteIndexedY);
enum addressModeSet_3 = cast(AddressModeFlags)(
  AddressModeFlags.immediate |
  AddressModeFlags.absoluteOrRelative |
  AddressModeFlags.zeroPage |
  AddressModeFlags.zeroPageIndexedX |
  AddressModeFlags.absoluteIndexedX);
enum addressModeSet_4 = cast(AddressModeFlags)(
  AddressModeFlags.absoluteOrRelative |
  AddressModeFlags.zeroPage |
  AddressModeFlags.zeroPageIndexedX |
  AddressModeFlags.absoluteIndexedX |
  AddressModeFlags.accumulator);

struct M6502Instruction
{
  string name;
  AddressModeFlags addressModes;
}
struct InstructionDefinitionStorage(int N)
{
  M6502Instruction base;
  ubyte[N] op;
}

struct InstructionSet
{
  // stores the size of each element in the array
  uint elementSize;
  // this union seems to be necessary to keep the typer checker happy
  // I would rather cast all the arrays to ubyte[], but doesn't seem to work
  union {
    ubyte[] array; // use when looping
    immutable(InstructionDefinitionStorage!1)[] storage1;
    immutable(InstructionDefinitionStorage!3)[] storage3;
    immutable(InstructionDefinitionStorage!4)[] storage4;
    immutable(InstructionDefinitionStorage!5)[] storage5;
    immutable(InstructionDefinitionStorage!8)[] storage8;
  }
  this(immutable(InstructionDefinitionStorage!1)[] storage) {
    this.elementSize = storage[0].sizeof;
    this.storage1 = storage;
  }
  this(immutable(InstructionDefinitionStorage!3)[] storage) {
    this.elementSize = storage[0].sizeof;
    this.storage3 = storage;
  }
  this(immutable(InstructionDefinitionStorage!4)[] storage) {
    this.elementSize = storage[0].sizeof;
    this.storage4 = storage;
  }
  this(immutable(InstructionDefinitionStorage!5)[] storage) {
    this.elementSize = storage[0].sizeof;
    this.storage5 = storage;
  }
  this(immutable(InstructionDefinitionStorage!8)[] storage) {
    this.elementSize = storage[0].sizeof;
    this.storage8 = storage;
  }
}

// The instruction definitions are grouped by how many addressing modes
// they supports. If an instruction supports more address modes, then it requires
// more memory because it will have a unique opcode for every address mode.
//
// Grouping by storage size increases memory effeciency becase instructions of
// the same size can be packed contiguously.
immutable instructionSets =
  [InstructionSet   
   ([
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BRK", AddressModeFlags.implied), 0x00),
     // Clear/Set status flags
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("CLC", AddressModeFlags.implied), 0x18),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("SEC", AddressModeFlags.implied), 0x38),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("CLI", AddressModeFlags.implied), 0x58),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("SEI", AddressModeFlags.implied), 0x78),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("CLV", AddressModeFlags.implied), 0xB8),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("CLD", AddressModeFlags.implied), 0xD8),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("SED", AddressModeFlags.implied), 0xF8),
     // Increment/Decrement registers
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("DEY", AddressModeFlags.implied), 0x88),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("DEX", AddressModeFlags.implied), 0xCA),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("INY", AddressModeFlags.implied), 0xC8),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("INX", AddressModeFlags.implied), 0xE8),
     // Register tranfer
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("TXA", AddressModeFlags.implied), 0x8A),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("TYA", AddressModeFlags.implied), 0x98),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("TXS", AddressModeFlags.implied), 0x9A),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("TAY", AddressModeFlags.implied), 0xA8),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("TAX", AddressModeFlags.implied), 0xAA),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("TSX", AddressModeFlags.implied), 0xBA),
     // Branching
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BPL", AddressModeFlags.absoluteOrRelative), 0x10),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BMI", AddressModeFlags.absoluteOrRelative), 0x30),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BVC", AddressModeFlags.absoluteOrRelative), 0x50),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BVS", AddressModeFlags.absoluteOrRelative), 0x70),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BCC", AddressModeFlags.absoluteOrRelative), 0x90),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BCS", AddressModeFlags.absoluteOrRelative), 0xB0),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BNE", AddressModeFlags.absoluteOrRelative), 0xD0),
     immutable InstructionDefinitionStorage!1(immutable M6502Instruction("BEQ", AddressModeFlags.absoluteOrRelative), 0xF0),
     ]),InstructionSet
   ([
     immutable InstructionDefinitionStorage!3(immutable M6502Instruction("CPY", addressModeSetBasic3), [0x00,0x00,0x00]),
     immutable InstructionDefinitionStorage!3(immutable M6502Instruction("STY", addressModeSetRegisterY3), [0x00,0x00,0x00]),
     ]),InstructionSet
   ([
     immutable InstructionDefinitionStorage!4(immutable M6502Instruction("INC", addressModeSetDefault4), [0x00,0x00,0x00,0x00]),
     ]),InstructionSet
   ([
     immutable InstructionDefinitionStorage!5(immutable M6502Instruction("LDX", addressModeSet_2), [0x00,0x00,0x00,0x00,0x00]),
     immutable InstructionDefinitionStorage!5(immutable M6502Instruction("LDY", addressModeSet_3), [0x00,0x00,0x00,0x00,0x00]),
     immutable InstructionDefinitionStorage!5(immutable M6502Instruction("STA", addressModeSet_4), [0x00,0x00,0x00,0x00,0x00]),
     ]),InstructionSet
   ([
     immutable InstructionDefinitionStorage!8(immutable M6502Instruction("ADC", addressModeSetDefault8), [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]),
     immutable InstructionDefinitionStorage!8(immutable M6502Instruction("AND", addressModeSetDefault8), [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]),
     immutable InstructionDefinitionStorage!8(immutable M6502Instruction("CMP", addressModeSetDefault8), [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]),
     immutable InstructionDefinitionStorage!8(immutable M6502Instruction("LDA", addressModeSetDefault8), [0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00]),
     ])];
