// Shared include for every EF and Kitto unit (see also Kitto.Defines.inc).
//
// It holds ONLY what must be identical across the whole framework:
//   * the legacy Dnn+ version defines;
//   * the three UNSAFE_* warnings, which are noise outside .NET-targeted code.
//
// It deliberately does NOT set compiler switches ($O, $R, $Q, $C, $D, $W, ...).
// Those belong to the project's Debug/Release configuration: a switch set here
// silently overrides what the .dproj asked for, in EVERY unit that includes
// this file. Doing so used to force optimization on and stack frames off in
// Debug builds (making the debugger report wrong values and truncated call
// stacks), keep range and overflow checking off even in Debug (so out-of-range
// accesses corrupted memory instead of raising ERangeError where it could be
// caught), and keep assertions and debug info on in Release builds.

// Version defines, inherited from Kitto 1. Only D15+ and D22+ are actually
// tested by the code base; the rest of the cumulative series is kept for
// application code that may rely on it.
//
// They are expressed as CompilerVersion ranges rather than VERxxx blocks on
// purpose: with per-version blocks, a compiler newer than the last one listed
// matched nothing, so every Dnn+ stayed undefined and the units silently fell
// back to their pre-XE8 code paths instead of failing to build.

{$IF CompilerVersion < 34}
  {$MESSAGE FATAL 'KittoX requires Delphi 10.4 Sydney (CompilerVersion 34) or later.'}
{$IFEND}

// 10.4 Sydney and later (minimum supported).
{$DEFINE D7+}
{$DEFINE D9+}
{$DEFINE D10+}
{$DEFINE D11+}
{$DEFINE D12+}
{$DEFINE D14+}
{$DEFINE D15+}
{$DEFINE D16+}
{$DEFINE D17+}
{$DEFINE D18+}
{$DEFINE D19+}
{$DEFINE D20+}
{$DEFINE D21+}
{$DEFINE D22+}
{$DEFINE D23+}
{$DEFINE D24+}
{$DEFINE D25+}
{$DEFINE D26+}
{$DEFINE D27+}

// 11 Alexandria and later.
{$IF CompilerVersion >= 35}
  {$DEFINE D28+}
{$IFEND}

// 12 Athens and later.
{$IF CompilerVersion >= 36}
  {$DEFINE D29+}
{$IFEND}

// 13 Florence and later. D37+ names the compiler version rather than the
// product one, unlike D27+/D28+/D29+ above; both spellings are defined so
// that either test keeps working.
{$IF CompilerVersion >= 37}
  {$DEFINE D30+}
  {$DEFINE D37+}
{$IFEND}

// Pointer-safety warnings: they only mean something for code compiled for
// .NET, which this framework never was.
{$WARN UNSAFE_TYPE OFF}
{$WARN UNSAFE_CODE OFF}
{$WARN UNSAFE_CAST OFF}
