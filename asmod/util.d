module asmod.util;

import std.format : formattedWrite;

class Utf8Exception : Exception {
  this(string msg) pure {
    super(msg);
  }
}
enum invalidEndMessage = "input ended with invalid UTF-8 character";
// This method assumes that utf8 points to at least one character
// and that the first non-valid pointer is at the limit pointer
// (this means that utf8 < limit)
dchar decodeUtf8(const(char)** utf8InOut, const char* limit) pure
{
  auto utf8 = *utf8InOut;
  dchar c = *utf8;
  utf8++;
  if((c & 0x80) == 0) {
    *utf8InOut = utf8;
    return c;
  }

  if((c & 0x20) == 0) {
    if(utf8 >= limit) throw new Utf8Exception(invalidEndMessage);
    utf8++;
    *utf8InOut = utf8;
    return ((c << 6) & 0x7C0) | (*(utf8 - 1) & 0x3F);
  }

  throw new Exception("utf8 not fully implemented");
}

// A wrapper that will print any character in a human readable format
// only using ascii characters
struct AsciiPrint
{
  dchar c;
  void toString(scope void delegate(const(char)[]) sink) const
  {
    if(c >= 127) {
      if(c <= 255) {
	formattedWrite(sink, "\\x%02x", c);
      } else {
	formattedWrite(sink, "\\u%04x", c);
      }
    } else if (c >= 32) {
      sink((cast(char*)&c)[0..1]);
    } else {
      if(c == '\n') {
	sink(`\n`);
      } else if(c == '\t') {
	sink(`\t`);
      } else if(c == '\r') {
	sink(`\r`);
      } else if(c == '\0') {
	sink(`\0`);
      } else {
	formattedWrite(sink, "\\x%02x", c);
      }
    }
  }
}
// A wrapper that will print any character in a human readable format
// only using ascii characters
struct AsciiPrintString
{
  const(char)[] str;
  void toString(scope void delegate(const(char)[]) sink) const
  {
    const(char)* next = str.ptr;
    const char* limit = next + str.length;
    while(next < limit) {
      AsciiPrint(decodeUtf8(&next, limit)).toString(sink);
    }
  }
}

