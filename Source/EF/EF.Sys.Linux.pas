unit EF.Sys.Linux;

interface

implementation

uses
  System.SysUtils,
  System.Classes,
  Posix.Base,
  Posix.Fcntl,
  EF.Sys;

type
  TEFSysLinux = class(TEFSys)
  public
    function GetUserName: string; override;
    // Execute and wait.
    function ExecuteCommand(const ACommand: string): Integer; override;
    procedure GetRandomBytes(var ABuffer; const ACount: Integer); override;
  end;

{ TEFSysLinux }

// http://man7.org/linux/man-pages/man3/system.3p.html
function system(const command: MarshaledAString): Integer; cdecl; external libc name _PU + 'system';

function TEFSysLinux.ExecuteCommand(const ACommand: string): Integer;
begin
  Result := system(@(TEncoding.ASCII.GetBytes(ACommand) + [0])[0]);
end;
function TEFSysLinux.GetUserName: string;
begin
  Result := GetEnvironmentVariable('USER');
end;

// /dev/urandom is the kernel's cryptographic random source, and the one to use
// for keys and passwords: it never blocks once the pool is initialised, which
// on a running system it always is. TFileStream raises if it cannot open it or
// cannot deliver the whole count, which is what we want -- a caller asking for
// these bytes must not receive predictable ones instead.
procedure TEFSysLinux.GetRandomBytes(var ABuffer; const ACount: Integer);
var
  LStream: TFileStream;
begin
  if ACount <= 0 then
    Exit;
  LStream := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
  try
    LStream.ReadBuffer(ABuffer, ACount);
  finally
    LStream.Free;
  end;
end;

initialization
  EF.Sys.EFSys := TEFSysLinux.Create;

end.
