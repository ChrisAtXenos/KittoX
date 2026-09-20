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

/// <summary>General-purpose helpers: date and string formatting, validation and decoding
/// of the Italian tax code, IBAN and VAT number checks, password generation,
/// amount-to-words conversion and plain-text logging.</summary>
unit SCM.Utils;

interface
uses
  Math, SysUtils, DateUtils, EF.DB, Kitto.Config, Variants, Kitto.Rules, EF.Localization,
  WinApi.Windows, WinApi.Messages, ShellApi, System.Types, Classes, Kitto.Web.Session;

const
  UPPER_LETTERS = ['A'..'Z'];
  LOWER_LETTERS = ['a'..'z'];
  LETTERS = UPPER_LETTERS + LOWER_LETTERS;
  DIGITS  = ['0'..'9'];
  SPACE_CHAR = ' ';
  QUOTE_CHAR  = '''';
  DOUBLE_QUOTE_CHAR = '"';
  DOUBLE_QUOTE_RIGHT_CHAR = '”';
  DOUBLE_QUOTE_LEFT_CHAR = '“';
  GENDER_MALE = 'M';
  GENDER_FEMALE = 'F';
  ONE_BILLION_STR = 'unmiliardo';
  ONE_MILLION_STR = 'unmilione';
  ONE_THOUSAND_STR = 'mille';
  ONE_STR = 'uno';
  BILLIONS_STR = 'miliardi';
  MILLIONS_STR = 'milioni';
  THOUSANDS_STR = 'mila';
  TEN_STR = 'dieci';
  ELEVEN_STR = 'undici';
  TWO_STR = 'due';
  TWELVE_STR = 'dodici';
  TWENTY_STR = 'venti';
  THREE_STR = 'tre';
  THIRTEEN_STR = 'tredici';
  THIRTY_STR = 'trenta';
  FOUR_STR = 'quattro';
  FOURTEEN_STR = 'quattordici';
  FORTY_STR = 'quaranta';
  FIVE_STR = 'cinque';
  FIFTEEN_STR = 'quindici';
  FIFTY_STR = 'cinquanta';
  SIX_STR = 'sei';
  SIXTEEN_STR = 'sedici';
  SIXTY_STR = 'sessanta';
  SEVEN_STR = 'sette';
  SEVENTEEN_STR = 'diciassette';
  SEVENTY_STR = 'settanta';
  EIGHT_STR = 'otto';
  EIGHTEEN_STR = 'diciotto';
  EIGHTY_STR = 'ottanta';
  NINE_STR = 'nove';
  NINETEEN_STR = 'diciannove';
  NINETY_STR = 'novanta';
  HUNDRED_STR = 'cento';
  EMPTY_STR = '';

resourcestring
  INCOMPATIBLE_MSG             = '%s is not compatible with %s';
  GENERIC_ERROR_MSG            = 'the value of %s is not valid ';

function DateToCompactStr(ADate: Variant): String;  // turns a date into a string of the form 'YYYYMMDD'
function DateTimeToDelimitedStr(ADateTime: Variant): String; // turns a date and time into a string of the form 'YYYYMMDD HH:MM:SS'
function DateTimeToCompactStr(ADateTime: Variant): String; // turns a date and time into a string of the form 'YYYYMMDDHHMMSS'
function TimeToDelimitedStr(ATime: Variant): String;   // turns a time into a string of the form 'HH:MM:SS'
function TimeToCompactStr(ATime: Variant): String;
function LastDayOfMonth(AYear,AMonth: string): string;  // returns the number of the last day of the given month and year
function PadL(Const AInputString: String; Len: Integer; FChar: Char): String;
function IsAlpha(AChar : Char) : Boolean;  // returns True when AChar is a letter, upper or lower case
function IsDigit(AChar : Char) : Boolean;   // returns True when AChar is a digit from 0 to 9
function IsUpper(AChar : Char) : Boolean;     // returns True when AChar is an upper case letter
function IsDigitString(AText : String) : Boolean; //Checks that the string holds digits only
function IsAlphaString(AText : String) : Boolean; //Checks that the string holds letters only
function IsUpperDigitString(AText : String) : Boolean;      //Checks whether the string holds anything other than digits and letters

function ReplaceSubStr( const S : string; OldPattern, NewPattern : string; AFirstOnly : Boolean = True; CaseSensitive : Boolean = False ) : string;
function IsValidTaxCode(const ATaxCode: string): Boolean;
function IsValidTaxCodeChecksum(const ATaxCode: string): Boolean;  // checks the tax code checksum; returns True when it is correct
function TaxCodeMatchesLastName(const ATaxCode,ALastName: string): Boolean;
function TaxCodeMatchesFirstName(const ATaxCode,AFirstName: string): Boolean;
function HomocodeCharToValue( C : Char ) : Char;
function DecodeTaxCodeMonth(M : String): Word; // returns the month number for the character taken from a tax code, or 0 when there is no match
function DecodeTaxCodeYear(Y : String): Word; // returns the year for the character taken from a tax code, or 0 when there is no match
function DecodeTaxCodeDay(G : String): Word; // returns the day number for the character taken from a tax code, or 0 when there is no match
function BirthDateFromTaxCode(const ATaxCode: string): TDateTime; //Computes the birth date from the tax code
function DecodeTaxCodeGender(G : String): string;
function GenderFromTaxCode(const ATaxCode: string): string; //Returns the gender (M or F) taken from the tax code
function BirthPlaceIdFromTaxCode(const ATaxCode: string): string; //Returns the birth place id taken from the tax code
function LetterToNumber( ALetter : Char ) : Integer; // returns the number 1..26 matching ALetter, or 0 when it is not a letter
function NumberToLetter( ANumber : Integer ) : Char;// returns the letter A..Z matching a number 1..26, or '?' when out of range
function DigitToValue( ADigit : Char ) : Integer;// returns the numeric value of a character '0'..'9', or -1 when out of range
function StrLeft(AText: string;  ACharCount: integer): string;     //returns the first n characters of a string
function StrRight(AText: string;  ACharCount: integer): string;     //returns the last n characters of a string
function StrMid(AText: string;  APosition: integer; ACharCount: integer = -1): string;     //returns a substring
function ValidateIban(aIban: string; out Errors : string): boolean;    //returns True when the IBAN is formally valid
function CheckIBAN(const aIban : string) : integer;
function GenerateGuid: string;
function GeneratePassword(const ALength: integer = 8): string;

function IsValidVatNumber(Const AVatNumber:string; AIsTaxCode : Boolean = False):boolean;

//log file handling
procedure CreateLogFile(ALogFileName: string);
procedure UpdateLogFile(ALogFileName,AText2: string);

function MonthName(AMonthNumber : Integer; ALanguage: string) : string;
// returns the name of the month, in Italian or English, for AMonthNumber;
// returns an empty string when AMonthNumber is outside 1..12

function GetStandardVatCode(ADate: TDateTime): string;
function GetSplitPaymentVatCode(ADate: TDateTime): string;
function Age(ABirthDate: TDate): integer;

//procedure ExecuteAndWait(const aCommand: string);

function ProfileExists(AProfileId: string): boolean;

procedure Split(Delimiter: Char; AText: string; ListOfStrings: TStrings) ;
function IsLoggedUserAMember: boolean;
function StripHTML(const AHTMLString: string): string;

function Num2LetWithoutDecimal(AAmount : Currency; nMaxLen : integer = 131) : string;
// Returns an amount spelled out in words.

function Num2Let(AAmount : Currency; ADecimals : integer; nMaxLen : integer = 131; ADropDecimals : boolean = false;
ADecimalsInWords : boolean = false ) : string;
// Returns an amount spelled out in words.

function KillSubString( const SubStr, S : string; StartIndex : Integer = 1 ) : string;
// returns S without the first occurrence of SubStr found from StartIndex on;

implementation

uses
  EF.VariantUtils
  ,EF.SQL
  ,EF.StrUtils
  //,Kitto.Html.Session
  ,StrUtils
  ,EF.Macros;

function DateToCompactStr(ADate: Variant): String;
Var
  Year, Month, Day: Word;
begin
  DecodeDate( ADate, Year, Month, Day );
  Result := IntToStr(Year) + PadL(IntToStr(Month),2,'0') + PadL(IntToStr(Day),2,'0');
end;

function TimeToCompactStr(ATime: Variant): String;
var
  Hour, Minutes, Seconds, MSeconds: Word;
begin
 if VarIsNull(ATime) then
   Result := StringOfChar(SPACE_CHAR,6)
 else
 begin
   DecodeTime( VarToDateTime(ATime), Hour, Minutes, Seconds, MSeconds );
   Result := PadL(IntToStr(Hour), 2, '0')+
             PadL(IntToStr(Minutes), 2, '0')+
             PadL(IntToStr(Seconds), 2, '0');
 end;
end;

function TimeToDelimitedStr(ATime: Variant): String;
var
  Hour, Minutes, Seconds, MSeconds: Word;
begin
 if VarIsNull(ATime) then
   Result := StringOfChar(SPACE_CHAR,8)
 else
 begin
   DecodeTime( VarToDateTime(ATime), Hour, Minutes, Seconds, MSeconds );
   Result := PadL(IntToStr(Hour), 2, '0')+ ':' +
             PadL(IntToStr(Minutes), 2, '0')+ ':' +
             PadL(IntToStr(Seconds), 2, '0');
 end;
end;

function DateTimeToCompactStr(ADateTime: Variant): String;
begin
  Result := DateToCompactStr(ADateTime)+TimeToCompactStr(ADateTime);
end;

function DateTimeToDelimitedStr(ADateTime: Variant): String;
begin
  Result := DateToCompactStr(ADateTime)+' ' + TimeToDelimitedStr(ADateTime);
end;

function LastDayOfMonth(AYear,AMonth: string): string;  // returns the number of the last day of the given month and year
var
  LYyyymmdd: string;
  LMonthStart,LMonthEnd: TDAteTime;
begin
  LYyyymmdd :=  '01/' + AMonth+ '/' + AYear ;
  LMonthStart :=  StrToDate(LYyyymmdd);
  LMonthEnd   := EndOftheMonth(LMonthStart);
  Result :=   RightStr(DateToCompactStr(LMonthEnd),2);
end;

function PadL(Const AInputString: String; Len: Integer; FChar: Char): String;
begin
  Result := StringOfChar(FChar,Len-Length(AInputString)) + AInputString;
end;

function IsAlpha(AChar : Char) : Boolean;
begin
  Result := CharInSet(AChar,LETTERS);
end;

function IsDigit(AChar : Char) : Boolean;
begin
  Result := CharInSet(AChar, DIGITS);
end;

function IsUpper(AChar : Char) : Boolean;
begin
  Result := CharInSet(AChar, UPPER_LETTERS);
end;

function IsDigitString(AText : String) : Boolean;
var
  i : integer;
begin
  Result := True;
  for i := 1 to Length(AText) do
  begin
    if not IsDigit(AText[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function IsAlphaString(AText : String) : Boolean;
var
  i : integer;
begin
  Result := True;
  for i := 1 to Length(AText) do
  begin
    if not IsAlpha(AText[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function IsUpperDigitString(AText : String) : Boolean;
var
  i : integer;
begin
  Result := True;
  for i := 1 to Length(AText) do
  begin
    if not isDigit(AText[i]) then
    begin
      if not IsUpper(AText[i]) then
      begin
        Result := False;
        Exit;
      end;
    end;
  end;
end;

function IsValidTaxCode(const ATaxCode: string): Boolean;
const
  HomocodeChars = ['L','M','N','P','Q','R','S','T','U','V'];
var
  i : integer;
  LYear, LMonth, LDay : Word;

begin
  Result := True;
  if Length(ATaxCode) = 16 then // the tax code is 16 characters long
  begin
    // check that the last name and first name characters are letters
    for i := 1 to 6 do
    begin
      if not IsAlpha( ATaxCode[i] ) then
      begin
        Result := False;
        Exit;
      end;
    end;

    // check that the birth year characters are digits or homocode letters
    for i := 7 to 8 do
    begin
      if not IsDigit( ATaxCode[i] ) and
         not CharInSet(ATaxCode[i], HomocodeChars) then
      begin
        Result := False;
        Exit;
      end;
    end;

    // compute the birth year
    LYear := DecodeTaxCodeYear( Copy(ATaxCode,7,2) );
    // compute the birth month number
    LMonth := DecodeTaxCodeMonth( ATaxCode[9] );
    if LMonth = 0 then
    begin
      Result := False;
      Exit;
    end;
    // check that the birth day characters are digits or homocode letters
    for i := 10 to 11 do
    begin
      if not IsDigit( ATaxCode[i] ) and
         not CharInSet(ATaxCode[i], HomocodeChars) then
      begin
        Result := False;
        Exit;
      end;
    end;
    // compute the birth day number
    LDay := DecodeTaxCodeDay( Copy(ATaxCode,10,2) );
    // check that the day number is consistent with the month
    if (LDay < 1) or (LDay >  EndOfTheMonth(EncodeDate(LYear,LMonth,1))) then
    begin
      Result := False;
      Exit;
    end;
    // check that the first character of the birth municipality code is a letter
    if not IsAlpha( ATaxCode[12] ) then
    begin
      Result := False;
      Exit;
    end;
    // check that the other characters of the birth municipality code are digits or homocode letters
    for i := 13 to 15 do
    begin
      if not IsDigit(ATaxCode[i]) and
         not CharInSet(ATaxCode[i], HomocodeChars) then
      begin
        Result := False;
        Exit;
      end;
    end;
  end
  else
    Result := False;
end;

function IsValidTaxCodeChecksum(const ATaxCode: string): Boolean;
var
  LCounter, LSum, i : Integer;
  C, Checksum : Char;

  // returns the numeric value of a character taken from a tax code;
  // returns -1 on error
  function TaxCodeCharToValue( C : Char ) : Integer;
  begin
    case UpCase(C) of
      'A', '0' : Result := 1;
      'B', '1' : Result := 0;
      'C', '2' : Result := 5;
      'D', '3' : Result := 7;
      'E', '4' : Result := 9;
      'F', '5' : Result := 13;
      'G', '6' : Result := 15;
      'H', '7' : Result := 17;
      'I', '8' : Result := 19;
      'J', '9' : Result := 21;
      'K'      : Result := 2;
      'L'      : Result := 4;
      'M'      : Result := 18;
      'N'      : Result := 20;
      'O'      : Result := 11;
      'P'      : Result := 3;
      'Q'      : Result := 6;
      'R'      : Result := 8;
      'S'      : Result := 12;
      'T'      : Result := 14;
      'U'      : Result := 16;
      'V'      : Result := 10;
      'W'      : Result := 22;
      'X'      : Result := 25;
      'Y'      : Result := 24;
      'Z'      : Result := 23;
    else
      Result := -1; // character not found
    end;
  end;
begin
  if Length(ATaxCode) = 16 then // the tax code is 16 characters long
  begin
    // check that the checksum character is a letter
    if not IsAlpha( ATaxCode[16] ) then
    begin
      Result := False;
      Exit;
    end;
    // compute the checksum
    LSum := 0;
    // walk the first 15 characters of the tax code
    LCounter := 1;
    while LCounter <= 15 do
    begin
      i := TaxCodeCharToValue( ATaxCode[LCounter] );
      if i < 0 then // no value found for this tax code character
      begin
        Result := False;
        Exit;
      end;
      Inc(LSum,i);
      // move on to the next character
      Inc(LCounter);
      if LCounter <= 15 then
      begin
        C := ATaxCode[LCounter];
        if IsAlpha(C) then
          Inc( LSum, LetterToNumber(C) )
        else if IsDigit(C) then
          Inc( LSum, DigitToValue(C) )
        else // neither a letter nor a digit
        begin
          Result := False;
          Exit;
        end;
      end;
      // move on to the next character
      Inc(LCounter);
    end;
    // compute the checksum character
    CheckSum := NumberToLetter(LSum mod 26 + 1);
    // compare the checksum with the last character of the tax code
    Result := UpCase(CheckSum) = UpCase(ATaxCode[16]);
  end
  else
    Result := False;
end;

function TaxCodeMatchesLastName(const ATaxCode,ALastName: string): Boolean;
Var
  LVowels : String; // Vowels = "AEIOU"
  LConsonants: String; // Consonants = "BCDFGHJKLMNPQRSTVWXYZ"
  LCodeFromLastName: string;
  i: Integer;
begin
  Result := False;
  LVowels:= '';
  LConsonants:= '';

  for i := 1 To Length(ALastName ) do begin
    If (Pos(Copy(ALastName, i, 1 ), 'AEIOU' ) > 0 ) then
      LVowels := LVowels + Copy(ALastName, i, 1 )
    else
      If (Pos(Copy(ALastName, i, 1 ), 'BCDFGHJKLMNPQRSTVWXYZ' ) >  0 ) then
        LConsonants := LConsonants + Copy(ALastName, i, 1 );
    If Length(LConsonants)  = 3  Then Break;
  End;

  LCodeFromLastName := Copy(LConsonants + LVowels + 'XX',0,3);
  If LCodeFromLastName = ATaxCode then
    Result := True;
end;

function TaxCodeMatchesFirstName(const ATaxCode,AFirstName: string): Boolean;
Var
  LVowels : String; // Vowels = "AEIOU"
  LConsonants: String; // Consonants = "BCDFGHJKLMNPQRSTVWXYZ"
  LCodeFromFirstName: string;
  i: Integer;
begin
  Result := False;
  LVowels:= '';
  LConsonants:= '';

  for i := 1 To Length(AFirstName ) do begin
    If (Pos(Copy(AFirstName, i, 1 ), 'AEIOU' ) > 0 ) then
      LVowels := LVowels + Copy(AFirstName, i, 1 )
    else
      If (Pos(Copy(AFirstName, i, 1 ), 'BCDFGHJKLMNPQRSTVWXYZ' ) >  0 ) then
        LConsonants := LConsonants + Copy(AFirstName, i, 1 );
    If Length(LConsonants)  = 4  Then Break;
  End;

  If Length(LConsonants)  <= 3 then
    LCodeFromFirstName := LConsonants
  else
    If Length(LConsonants)  = 4 then
      Delete(LConsonants,2,1);
  LCodeFromFirstName := Copy(LConsonants + LVowels + 'XX',0,3);
  If LCodeFromFirstName = ATaxCode then
    Result := True;
end;

function HomocodeCharToValue( C : Char ) : Char;
begin
  case UpCase(C) of
    'L' : Result := '0';
    'M' : Result := '1';
    'N' : Result := '2';
    'P' : Result := '3';
    'Q' : Result := '4';
    'R' : Result := '5';
    'S' : Result := '6';
    'T' : Result := '7';
    'U' : Result := '8';
    'V' : Result := '9';
  else
    Result := C;
  end;
end;


function LetterToNumber( ALetter : Char ) : Integer;
begin
  if IsAlpha(ALetter) then
    Result := Ord(UpCase(ALetter)) - Ord('A')
  else
    Result := 0;
end;

function NumberToLetter( ANumber : Integer ) : Char;
begin
  if (ANumber >= 1) and (ANumber <= 26) then
    Result := Chr( Ord('A')+(ANumber-1) )
  else
    Result := '?';
end;


function DigitToValue( ADigit : Char ) : Integer;
begin
  if IsDigit(ADigit) then
    Result := Ord(ADigit) - Ord('0')
  else
    Result := -1;
end;

function DecodeTaxCodeYear(Y : String): Word;
var
  LYear : Integer;
begin
  LYear := StrToInt(HomocodeCharToValue(Y[1])+HomocodeCharToValue(Y[2]));
  if LYear < YearOf(Date) - 2000 then
    Result := LYear + 2000
  else
    Result := LYear  + 1900
end;

// returns the month number for the character taken from a tax code;
// returns 0 when there is no match
function DecodeTaxCodeMonth(M : String): Word;
begin
  Result := 0;
  if M = 'A' then Result := 1;
  if M = 'B' then Result := 2;
  if M = 'C' then Result := 3;
  if M = 'D' then Result := 4;
  if M = 'E' then Result := 5;
  if M = 'H' then Result := 6;
  if M = 'L' then Result := 7;
  if M = 'M' then Result := 8;
  if M = 'P' then Result := 9;
  if M = 'R' then Result := 10;
  if M = 'S' then Result := 11;
  if M = 'T' then Result := 12;
end;

function DecodeTaxCodeDay(G : String): Word;
begin
  Result := StrToInt(HomocodeCharToValue(G[1])+HomocodeCharToValue(G[2]));
  if Result > 40 then
    Dec( Result, 40 );
end;

function BirthDateFromTaxCode(const ATaxCode: string): TDateTime;
var
  LDay, LMonth, LYear: word;
begin
  LYear := DecodeTaxCodeYear(Copy(ATaxCode,7,2));
  LMonth := DecodeTaxCodeMonth(Copy(ATaxCode,9,1));
  LDay := DecodeTaxCodeDay(Copy(ATaxCode,10,2));
  Result := EncodeDate(LYear, LMonth, LDay);
end;

function DecodeTaxCodeGender(G : String): String;
begin
  if StrToInt(HomocodeCharToValue(G[1])+HomocodeCharToValue(G[2])) > 40 then
    Result := GENDER_FEMALE
  else
    Result := GENDER_MALE;
end;

function GenderFromTaxCode(const ATaxCode: string): string;
begin
  if Length(ATaxCode) = 16 then
    Result := DecodeTaxCodeGender(Copy(ATaxCode, 10, 2))
  else
    Result := '';
end;

function BirthPlaceIdFromTaxCode(const ATaxCode: string): string;
var
  AMunicipalityCode : string;
begin
  if Length(ATaxCode) = 16 then
  begin
    AMunicipalityCode := Copy(ATaxCode,12,4);
    Result := AMunicipalityCode[1]+
              HomocodeCharToValue( AMunicipalityCode[2] )+
              HomocodeCharToValue( AMunicipalityCode[3] )+
              HomocodeCharToValue( AMunicipalityCode[4] );
  end
  else
    Result := '';
end;

procedure UpdateLogFile(ALogFileName,AText2: string);
var
  a: textfile;
begin
  if not FileExists(ALogFileName) then
    CreateLogFile(ALogFileName);
  AssignFile(a, ALogFileName);
  Append(a);
  WriteLn(a, AText2);
  CloseFile(a)
end;

procedure CreateLogFile(ALogFileName: string);
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    S.Add('Log file start ' + ALogFileName);
    S.Add(#13#10);
    S.SaveToFile(ALogFileName);
  finally
    FreeAndNil(S);
  end;
end;


function MonthName(AMonthNumber : Integer; ALanguage: string) : string;
var
  MonthNames : array[1..12] of string;
begin
  if ALanguage = 'IT' then
  begin
    MonthNames[ 1] := 'Gennaio';
    MonthNames[ 2] := 'Febbraio';
    MonthNames[ 3] := 'Marzo';
    MonthNames[ 4] := 'Aprile';
    MonthNames[ 5] := 'Maggio';
    MonthNames[ 6] := 'Giugno';
    MonthNames[ 7] := 'Luglio';
    MonthNames[ 8] := 'Agosto';
    MonthNames[ 9] := 'Settembre';
    MonthNames[10] := 'Ottobre';
    MonthNames[11] := 'Novembre';
    MonthNames[12] := 'Dicembre';
  end
  else begin
    MonthNames[ 1] := 'January';
    MonthNames[ 2] := 'February';
    MonthNames[ 3] := 'March';
    MonthNames[ 4] := 'April';
    MonthNames[ 5] := 'May';
    MonthNames[ 6] := 'June';
    MonthNames[ 7] := 'July';
    MonthNames[ 8] := 'August';
    MonthNames[ 9] := 'September';
    MonthNames[10] := 'October';
    MonthNames[11] := 'November';
    MonthNames[12] := 'December';
  end;
  if (AMonthNumber >= 1) and (AMonthNumber <= 12) then
    Result := MonthNames[AMonthNumber]
  else
    Result := '';
end;

function GetStandardVatCode(ADate: TDateTime): string;
begin
  Result := EFVarToStr(TKConfig.Database.GetSingletonValue(
    'SELECT ID from IVA WHERE STD = 1 AND ''' + DateToCompactStr(ADate) + ''' between DATA_INIZIO_VALIDITA AND DATA_FINE_VALIDITA'));
end;

function GetSplitPaymentVatCode(ADate: TDateTime): string;
begin
  Result := EFVarToStr(TKConfig.Database.GetSingletonValue(
    'SELECT ID from IVA WHERE SPLIT_PAYMENT = 1 AND ''' + DateToCompactStr(ADate) + ''' between DATA_INIZIO_VALIDITA AND DATA_FINE_VALIDITA'));
end;

function GenerateGuid: string;
begin
  Result := EFVarToStr(TKConfig.Database.GetSingletonValue(
    'SELECT Replace(Replace(Replace(NEWID(),''{'',''''),''}'',''''),''-'','''')'));
end;

function GeneratePassword(const ALength: integer = 8): string;
begin
  Result := GetRandomStringEx(ALength, '01Olo');
end;

function ReplaceSubStr( const S : string; OldPattern, NewPattern : string;
                        AFirstOnly : Boolean = True; CaseSensitive : Boolean = False ) : string;
var
  ReplaceFlags : TReplaceFlags;
begin
  ReplaceFlags := [];
  if not AFirstOnly then
    Include( ReplaceFlags, rfReplaceAll );
  if not CaseSensitive then
    Include( ReplaceFlags, rfIgnoreCase );
  Result := StringReplace( S, OldPattern, NewPattern, ReplaceFlags );
end;

function StrLeft(AText: string;  ACharCount: integer): string;
begin
  Result := Copy(AText,1,ACharCount);
end;

function StrRight(AText: string;  ACharCount: integer): string;
begin
  Result := StrMid(AText,Length(AText) - ACharCount + 1);
end;

function StrMid(AText: string;  APosition: integer; ACharCount: integer = -1): string;
begin
  if ACharCount < 0 then
    ACharCount := Length(AText) - APosition + 1;
  Result := Copy(AText,APosition, ACharCount);
end;

(*
procedure ExecuteAndWait(const aCommand: string);
var
  tmpStartupInfo: TStartupInfo;
  tmpProcessInformation: TProcessInformation;
  tmpProgram: String;
begin
  tmpProgram := Trim(aCommand);
  FillChar(tmpStartupInfo, SizeOf(tmpStartupInfo), 0);
  tmpStartupInfo.cb := SizeOf(TStartupInfo);
  tmpStartupInfo.wShowWindow := SW_HIDE;  // HIDE;

  if CreateProcess(nil, pchar(tmpProgram), nil, nil, true, CREATE_NO_WINDOW, nil, nil,
                   tmpStartupInfo, tmpProcessInformation) then begin
    while WaitForSingleObject(tmpProcessInformation.hProcess, 50) > 0 do    // loop every 50 ms
      Application.ProcessMessages;
    CloseHandle(tmpProcessInformation.hProcess);
    CloseHandle(tmpProcessInformation.hThread);
    end
  else
    RaiseLastOSError;
end;
*)

function ValidateIban(aIban: string; out Errors : string): boolean;
var
  CountIBAN : integer; //Length of the string
  sErrorMin5, sErrorMax34, sErrorWrongChar, sErrorIsoCountryCode, sErrorCheckDigits, sError27 : String;
begin

  Result := False;
  //Variable settings
  CountIBAN := Length(aIban);
  sErrorMin5 := '';
  sErrorMax34 := '';
  sErrorWrongChar := '';
  sErrorIsoCountryCode := '';
  sErrorCheckDigits := '';
  //The IBAN must be between 5 and 34 characters long, otherwise it is invalid
  //The IBAN must be at least 5 characters long
  if (CountIBAN = 0) then
    Exit;
  if (CountIBAN < 5) then
    sErrorMin5 := _('The IBAN is shorter than allowed.') + sLineBreak  ;
  if (CountIBAN > 34) then
    sErrorMax34 := _('The IBAN is longer than allowed.') + sLineBreak ;
  if (CountIBAN <> 27) and (UpperCase(Copy(aIban,0,2)) = 'IT')  then
    sError27 := _('An Italian IBAN must be 27 characters long.') +sLineBreak  ;
  //Check the characters: upper case letters and digits only,
  //nothing else (for instance /, ", [, = ...)
  if not IsUpperDigitString(aIban) then
    sErrorWrongChar := _('The IBAN contains invalid characters: enter digits or capital letters only.') + sLineBreak  ;

  //Check that the first 2 characters hold no digit and match one of the
  //codes listed in the country table.
  if not IsAlphaString(Copy(aIban,0,2)) then
    sErrorIsoCountryCode := _('The first 2 characters of the IBAN are the country code and must contain capital letters only, not digits.') + sLineBreak ;
  //Check that the 3rd and 4th characters hold no letter
  if not IsDigitString(Copy(aIban,3,2)) then
    sErrorCheckDigits := _('The third and fourth characters are check digits and must contain digits only, not letters.') +sLineBreak ;

  //Fill the error message, only when there are errors
  if (sErrorMin5 <> '') or (sErrorMax34 <> '') or (sErrorWrongChar <> '') or
     (sErrorIsoCountryCode <> '') or (sErrorCheckDigits <> '') or (sError27 <> '') then
  begin
    Result := False;
    Errors := _('Invalid IBAN') + sLinebreak+
              sErrorMin5           +
              sErrorMax34          +
              sError27             +
              sErrorWrongChar      +
              sErrorIsoCountryCode +
              sErrorCheckDigits;
    Exit;
  end;

  if CheckIBAN(aIban) <> 1 then
  begin
    //When the remainder of the division is not 1 the IBAN is invalid.
    Errors := _('The IBAN entered is not correct');
    Exit;
  end;
  Result := True;
end;

function CheckIBAN(const aIban : string) : integer;
var
	CountIBAN : Integer; // IBAN length
	sIBANInverted : string;  // IBAN swapped
	C : string; // code of current char
	K : Integer; // code normalyzed to range 0..35
	R : Integer; // remainder of division by 97
  i : integer;
begin
	R := 0;
  CountIBAN := Length(aIban);
  //Swap the first 4 characters: move them to the end of the string
  sIBANInverted := Trim(Copy(aIban,5,34) + Copy(aIban,0,4));
  for i := 1 to CountIBAN do
  begin
    //take the i-th character
    C := UpperCase(sIBANInverted[i]);

    //Convert the character, digit or letter, into a number
    if C = 'A' then K := 10
    else if C = 'B' then K := 11
    else if C = 'C' then K := 12
    else if C = 'D' then K := 13
    else if C = 'E' then K := 14
    else if C = 'F' then K := 15
    else if C = 'G' then K := 16
    else if C = 'H' then K := 17
    else if C = 'I' then K := 18
    else if C = 'J' then K := 19
    else if C = 'K' then K := 20
    else if C = 'L' then K := 21
    else if C = 'M' then K := 22
    else if C = 'N' then K := 23
    else if C = 'O' then K := 24
    else if C = 'P' then K := 25
    else if C = 'Q' then K := 26
    else if C = 'R' then K := 27
    else if C = 'S' then K := 28
    else if C = 'T' then K := 29
    else if C = 'U' then K := 30
    else if C = 'V' then K := 31
    else if C = 'W' then K := 32
    else if C = 'X' then K := 33
    else if C = 'Y' then K := 34
    else if C = 'Z' then K := 35
    else K := StrToInt(C);

		// Accumulate the remainder of the division by 97
		if K > 9 then
			R := (100 * R + K) mod 97
		else
			R := (10 * R + K) mod 97;
  end;
  Result := R;
end;

function IsValidVatNumber(Const AVatNumber:string; AIsTaxCode : Boolean = False):boolean;
const
  MIN_UFFICIO_IVA = 1;
  MAX_UFFICIO_IVA = 200;
  UFFICIO_IVA_NON_RESIDENTI  = 999;
  UFFICIO_IVA_CONTRIB_MINIMI = 888;
Var
 c, j, i, u : integer;
begin
 Result := False;

 if Length(AVatNumber) <> 11 then Exit;

 // the Italian tax authority confirmed that no VAT number can start with 8 or 9, because
 // 11 character codes starting with 8 or 9 are tax codes, usually issued to public bodies and non profits, which have no VAT number.
 if not AIsTaxCode then
 begin
   if (AVatNumber[1]='8') or (AVatNumber[1]='9') then
    Exit;
 end;

 for i := 1 to Length(AVatNumber) do
  if not CharInSet(AVatNumber[i], ['0'..'9']) then Exit; j := 0;
 for i := 1 to 10 do begin
  if Odd(i) then begin
  j := j + Ord(AVatNumber[i]) - 48
  end else begin
  c := 2 * (Ord(AVatNumber[i]) - 48);
  j := j + (c div 10) + (c mod 10);
  end;
 end;c := j mod 10;
 if c <> 0 then c := 10 - c;

 //computes and checks the number of the VAT office that issued the VAT number
 u := StrToIntDef( Copy(AVatNumber,8,3), -1 );
 if (u < MIN_UFFICIO_IVA) or (u > MAX_UFFICIO_IVA) and (u <> UFFICIO_IVA_NON_RESIDENTI) and (u <> UFFICIO_IVA_CONTRIB_MINIMI) then
   Exit;
 if (AVatNumber[11] = Chr(c + 48)) then Result := True;
end;

procedure Split(Delimiter: Char; AText: string; ListOfStrings: TStrings) ;
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter       := Delimiter;
   ListOfStrings.StrictDelimiter := True; // Requires D2006 or newer.
   ListOfStrings.DelimitedText   := AText;
end;

function ProfileExists(AProfileId: string): boolean;
var
  LCommandText: string;
begin
  LCommandText := 'SELECT COUNT(*) FROM AC_PROFILO where ID = ''' + AProfileId + '''';
  Result := EFVarToInt(TKConfig.Instance.GetDBSingletonValue(TKConfig.Instance.DatabaseName, LCommandText)) > 0;
end;

function Age(ABirthDate: TDate): integer;
var
  I: TDateTime;
begin
  I := Date() +1 - ABirthDate;
  Result := Trunc(I/365.25);
end;

function IsLoggedUserAMember: boolean;
begin
  Result := TKWebSession.Current.AuthData.GetString('PROFILEID') = 'USER';
end;

function StripHTML(const AHTMLString: string): string;
var
  TagBegin, TagEnd, TagLength: integer;
begin
  Result := AHTMLString;
  Result := StringReplace(Result, '&agrave;', 'à' , [rfReplaceAll]);
  Result := StringReplace(Result, '&eacute;', 'é' , [rfReplaceAll]);
  Result := StringReplace(Result, '&egrave;', 'è' , [rfReplaceAll]);
  Result := StringReplace(Result, '&iacute;', 'í' , [rfReplaceAll]);
  Result := StringReplace(Result, '&igrave;', 'ì' , [rfReplaceAll]);
  Result := StringReplace(Result, '&oacute;', 'ó' , [rfReplaceAll]);
  Result := StringReplace(Result, '&ograve;', 'ò' , [rfReplaceAll]);
  Result := StringReplace(Result, '&uacute;', 'ú' , [rfReplaceAll]);
  Result := StringReplace(Result, '&ugrave;', 'ù' , [rfReplaceAll]);
  Result := StringReplace(Result, '&nbsp;'  , ' ' , [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;'  , '"' , [rfReplaceAll]);
  Result := StringReplace(Result, '&apos;'  , '''', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;'    , '>' , [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;'    , '<' , [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;'   , '&' , [rfReplaceAll]);
  Result := StringReplace(Result, '&euro;'  , '€' , [rfReplaceAll]);

  Result := StringReplace(Result, #10, '',  [rfReplaceAll]);
  Result := StringReplace(Result, #13, '',  [rfReplaceAll]);
  Result := StringReplace(Result, '<br/>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '<br>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '</br>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '</p>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '<p>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '</ul>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '<ul>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '</li>', #10#13,  [rfReplaceAll]);
  Result := StringReplace(Result, '<li>', #10#13,  [rfReplaceAll]);

  TagBegin := Pos( '<', Result);  // search position of first <
  TagLength := 0;
  while (TagBegin > 0) and (TagLength >= 0) do // while there is a < in Result
  begin
    TagEnd := Pos('>', Result);  // find the matching >
    TagLength := TagEnd - TagBegin + 1;
    Delete(Result, TagBegin, TagLength); // delete the tag
    TagBegin:= Pos( '<', Result);        // search for next <
  end;
end;


function Num2LetWithoutDecimal(AAmount : Currency; nMaxLen : integer = 131) : string;
begin
  Result:= Num2Let(AAmount, 0, nMaxLen, True);
end;

// Returns an amount spelled out in words.
// nMaxLen keeps the result no longer than the given length, otherwise the
// transcription is truncated (for instance mille/350).
//
// Note: the largest number that can be spelled out is 999,999,999,999.
// Note: the longest one in words is 454,454,454,454, which takes 131 characters.
// ADecimals was added for the euro: the decimals are printed in the /xx form
// according to the number of decimals requested, and only when non zero
function Num2Let(AAmount : Currency; ADecimals : integer; nMaxLen : integer = 131; ADropDecimals : boolean = false;
ADecimalsInWords : boolean = false) : string;
const
  cOne      : Array[1..4] of string = (ONE_BILLION_STR,ONE_MILLION_STR,ONE_THOUSAND_STR,ONE_STR);
  cMultiples    : Array[1..4] of string = (BILLIONS_STR ,MILLIONS_STR ,THOUSANDS_STR , EMPTY_STR  );


  cLet      : Array[1..10,1..3] of string =
    ((EMPTY_STR       ,TEN_STR      ,EMPTY_STR         ),
     (EMPTY_STR       ,ELEVEN_STR     ,EMPTY_STR         ),
     (TWO_STR         ,TWELVE_STR     ,TWENTY_STR         ),
     (THREE_STR         ,THIRTEEN_STR    ,THIRTY_STR        ),
     (FOUR_STR     ,FOURTEEN_STR,FORTY_STR      ),
     (FIVE_STR      ,FIFTEEN_STR   ,FIFTY_STR     ),
     (SIX_STR         ,SIXTEEN_STR     ,SIXTY_STR      ),
     (SEVEN_STR       ,SEVENTEEN_STR,SEVENTY_STR      ),
     (EIGHT_STR        ,EIGHTEEN_STR   ,EIGHTY_STR       ),
     (NINE_STR        ,NINETEEN_STR ,NINETY_STR      ));

var
  aNum : array [1..4] of Int64;

  LNumberText : string;
  i,nNum : integer;
  LHundreds : integer;//the hundreds only
  LTens    : integer;//tens plus units, to handle the numbers from 10 to 20
  LUnits     : integer;//the units only
  lMaxLen : boolean;
  LIntegerPart : Currency;
  LDecimalPart : Currency;
  LNegDecimals: integer;
begin
  lMaxLen := false;
  LNumberText   := '';
  Result   := '';
  LNegDecimals := - ADecimals;
  AAmount := RoundTo(AAmount,LNegDecimals);
  LIntegerPart := Int(AAmount);  //take the integer part
  LDecimalPart :=  Frac(AAmount)*IntPower(10,ADecimals); //take the decimal part

  aNum[1] := Trunc(LIntegerPart/1000000000);
  aNum[2] := Trunc((LIntegerPart/1000000)-(aNum[1]*1000));
  aNum[3] := Trunc((LIntegerPart/1000)-(aNum[1]*1000000)-(aNum[2]*1000));
  aNum[4] := Trunc(LIntegerPart-(aNum[1]*1000000000)-(aNum[2]*1000000)-(aNum[3]*1000));

  //4 passes, scanning the number in groups of 3 digits
  if (LIntegerPart <= 0) or (LIntegerPart > 999999999999) then
    LNumberText := 'zero' else
  begin
    for i := 1 to 4 do
    begin
      LNumberText := '';
      nNum    := aNum[i];
      LHundreds := Trunc(nNum/100);
      LTens    := nNum - LHundreds*100;
      LUnits     := LTens - Trunc(LTens/10)*10;

      if nNum = 1 then
       LNumberText := LNumberText + cOne[i]
      else if nNum <> 0 then
      begin
        // hundreds
        if LHundreds <> 0 then
          LNumberText := LNumberText + cLet[LHundreds+1,1] + HUNDRED_STR;
        // tens
        if (LTens >= 10) and (LTens <=19) then
          LNumberText := LNumberText + cLet[LTens-9,2] else
        begin
          IF (LTens > 19) then
          begin
            LNumberText := LNumberText + cLet[Trunc(LTens/10)+1,3];
            if (LUnits = 1) or (LUnits = 8) then
            begin
              //drop the last letter (venti -> vent)
              LNumberText := copy(LNumberText,1,length(LNumberText)-1);
            end;
          end;

          // units, unless already covered by the tens
          if (LUnits = 1) then
            LNumberText := LNumberText + ONE_STR
          else if (LUnits > 1) then
            LNumberText := LNumberText + cLet[LUnits+1,1];
        end;
        LNumberText := LNumberText + cMultiples[i];
      end;
      if (Length(Result)+Length(LNumberText)+((4-i)*4) > nMaxLen) or(lMaxLen) then
      begin
        lMaxLen := true;
        Result := Result +PADL(inttoStr(nNum),3,'0');
      end
      else
      begin
        Result := Result + LNumberText;
      end;
    end;
  end;
  //-- decimals as digits
  if not ADropDecimals then
  begin
    if ADecimalsInWords then
    begin
      // decimals in words
      if (LDecimalPart <> 0) then
        Result := Result + '/'+
                  ReplaceSubStr(KillSubString(IntToStr(Round(LDecimalPart)), PADL(IntToStr(Round(LDecimalPart)),ADecimals,'0')), '0', 'zero', False)+
                  Num2Let(LDecimalPart,0,131, True)
      else
        Result := Result + '/'+
                  ReplaceSubStr(PADL(IntToStr(Round(LDecimalPart)),ADecimals,'0'), '0', 'zero', False);
    end
    else
      Result := Result + '/'+PADL(IntToStr(Round(LDecimalPart)),ADecimals,'0');
  end;
end;

function KillSubString( const SubStr, S : string; StartIndex : Integer = 1 ) : string;
var
  I : Integer;
begin
  I := Pos( SubStr, S, StartIndex );
  if I = 0 then // substring not found in S from StartIndex on
  begin
    Result := S;
    Exit;
  end;
  // substring found: copy the parts of the string before and after it
  Result := Copy(S,1,I-1) + Copy(S,I+Length(SubStr),MaxInt);
end;

end.
