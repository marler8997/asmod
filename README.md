An extensible assembler.

Usage
--------------------------------------------------------------------------------
Download the D compiler from dlang.org/download.html
Make sure that rdmd is in your PATH.
```
> rdmd asmod <source-file>
```
The first-line of the <source-file> given to asmod should contain the module set
using the `.module_set` directive.
```
.module_set <module-list>
```

Language Format
--------------------------------------------------------------------------------
```asm
           ; comments begin with a semi-colon
label:     ; labels end with a colon
.directive ; directives start with a .
           ; a directive differs from an instruction in that
           ; it directs the assembler as opposed to emitting code
```

Recipe Interface
--------------------------------------------------------------------------------
For now I'm just going to support assembler recipes.

Recipe Interface:
* defines the DirectiveDefinition and InstructionDefinition structs along with
  directiveDefinitionMap and instructionDefinitionMap which are maps of the
  names to the respective structs.
* defines the functions
```
void handleInstruction(string label, immutable(InstructionDefinition)* definition, char* ptr, char* limit);
int emit();
```
Modules
--------------------------------------------------------------------------------
Not sure exactly how modules will work yet.  For now I'm going to start with
the following assemblers:
* m6502 (A generic 6502 assembler)
  creates .bin files
  Run with `rdmd -I. recipes\m6502\recipe.d`
* nes
  Reuses structures in the m6502 module, however, modifies the expected
  format of the source code and various directives/instructions.
  Run with `rdmd -I. recipes\nes\recipe.d`

I think there should be a way to compile the assembler with a static set of
modules, and also a way to build one big assembler with all the modules.

The modules should be specifiable in the assembly files themselves. If you have
an existing assembly program, you could create a wrapper file that can use asmod
that might look like this:
```asm
asmod my_processor      ; specifies the module set that this program uses
include my_program.asm  ; includes the original program assembly
```

Modules can be used to extend the assembler. A module can add instructions and
directives to the language.

One idea I have is possibly making different module categories. For example,
the NES module category may affect certain aspects of the assembler that are
incompatible with other modules. For exampe, the NES module will affect
the default output filename extension (will create a .nes file) and this would
be incompatible with other modules.

Modules should also have dependencies. The NES module will be dependent on the
6502 module for example.

### Module Components

* Emitter

A module can contain an emitter that is in charge of pulling all the pieces
together and creating output.


Decisions
--------------------------------------------------------------------------------

"Code Normalization" VS "Flexibility"

As of right now, I think that prioritizing code normalization over flexibility
is probably the best decision.  This is because code normalization allows code
to be useful accross projects and puts less strain on programmers that work
on different projects.

Take the example of keyword case sensitivity.  Deciding to make them case
sensitive is prioritizing normalization over flexibility.  The argument in this case
is that it makes code more portable/easier to maintain between projects because
it will look and feel more similar. In this case I don't really see any cons in
this loss the flexibility of case-insensitivity. This is also takes away one
more decision that projects need to make.

That being said, since this is an extensible assembler, it could possibly be
used in different fields that prefer different casing. I think this is an argument
for supporting different case standards based on the modules, but maintaining
case-sensitivity accross every field is preffered because it has the advantage
of code normalization.

