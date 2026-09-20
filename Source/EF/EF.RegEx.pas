{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}

///	<summary>
///	  Regex support.
///	</summary>
unit EF.RegEx;

{$I EF.Defines.inc}

interface

///	<summary>
///   Matches a string to a pattern. If the specified pattern includes a regex
///   introducer, the rest is interpreted as a regular expression, otherwise
///   the whole string is interpreted as a (optionally negated) pattern and
///   passed to StrMatchesEx. The regex introducer is either the string
///   'REGEX:' (the function returns True if the string matches the expression)
///   or '~REGEX:' (the function returns True if the string DOESN'T match the
///   expression) at the beginning of the pattern.
///	</summary>
///	<para>
///	  When AIgnoreCase is True the comparison is case-blind: the wildcard sides
///	  are folded to upper case (the '~', '*' and '?' metacharacters are not
///	  affected), and the regex is matched with roIgnoreCase. The default False
///	  keeps the historical case-sensitive behaviour for existing callers.
///	</para>
function StrMatchesPatternOrRegex(const AString, APatternOrRegex: string;
  const AIgnoreCase: Boolean = False): Boolean;

///	<summary>
///	  Simple regex pattern matching. With AIgnoreCase the match is case-blind.
///	</summary>
function RegExMatches(const AString, APattern: string;
  const AIgnoreCase: Boolean = False): Boolean;

implementation

uses
  System.SysUtils,
  System.RegularExpressions,
  EF.StrUtils;

function RegExMatches(const AString, APattern: string;
  const AIgnoreCase: Boolean = False): Boolean;
var
  LOptions: TRegExOptions;
begin
  // Each call gets its own state on purpose. A single TPerlRegEx instance used
  // to be cached in a unit variable: since the instance carries both the
  // pattern and the subject, two threads evaluating a permission at the same
  // time overwrote each other's values, and the access controller could answer
  // on somebody else's pattern. TRegEx is a record over the same PCRE engine,
  // so pattern syntax and matching semantics are unchanged. Caching bought
  // little anyway: assigning a different pattern recompiles it every time, so
  // only the allocation was saved.
  LOptions := [];
  if AIgnoreCase then
    Include(LOptions, roIgnoreCase);
  Result := TRegEx.IsMatch(AString, APattern, LOptions);
end;

function RegExDoesntMatch(const AString, APattern: string): Boolean;
begin
  Result := not RegExMatches(AString, APattern);
end;

function StrMatchesPatternOrRegex(const AString, APatternOrRegex: string;
  const AIgnoreCase: Boolean = False): Boolean;
const
  REGEX_INTRODUCER = 'REGEX:';
  REGEX_NEGATED_INTRODUCER = '~REGEX:';
var
  LPattern: string;
begin
  LPattern := APatternOrRegex;
  // Regexes are costly to process, so we only support them if explicitly
  // declared.
  if Pos(REGEX_INTRODUCER, LPattern) = 1 then
  begin
    Delete(LPattern, 1, Length(REGEX_INTRODUCER));
    Result := RegExMatches(AString, LPattern, AIgnoreCase);
  end
  else if Pos(REGEX_NEGATED_INTRODUCER, LPattern) = 1 then
  begin
    Delete(LPattern, 1, Length(REGEX_NEGATED_INTRODUCER));
    Result := not RegExMatches(AString, LPattern, AIgnoreCase);
  end
  // A plain (optionally negated) wildcard pattern. When case is to be ignored
  // both sides are folded to upper case first: '~', '*' and '?' -- the only
  // characters StrMatchesEx treats specially -- are unaffected by folding, so
  // the pattern behaves the same, only case-blind.
  else if AIgnoreCase then
    Result := StrMatchesEx(AnsiUpperCase(AString), AnsiUpperCase(LPattern))
  else
    Result := StrMatchesEx(AString, LPattern);
end;

end.

