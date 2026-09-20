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

/// <summary>
///   Shell/OS helper routines (Windows shell API wrappers).
/// </summary>
unit EF.Shell;

interface

{
  Deletes all files in APath using the Windows shell API.
}
/// <summary>
///   Deletes all files in APath using the Windows shell API.
/// </summary>
procedure ShellDeleteAllFiles(const APath: string);

{
  Opens a document with the default application synchronously (AWait = True)
  or Asynchronously (AWait = False).
  If AWait is True, the function waits that the launched process finishes,
  and returns the process' exit code (or -1 in case of errors).
  If AWait is False, the function returns 0 if the call succeeds or -1 in case
  of errors.
}
/// <summary>
///   Opens a document with its default application. When AWait is True, waits
///   for the launched process to finish and returns its exit code (or -1 on
///   error); when AWait is False, returns 0 on success or -1 on error.
/// </summary>
function OpenDocument(const AFileName: string; const AWait: Boolean = False): Integer;

implementation

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  EF.Localization;

procedure ShellDeleteAllFiles(const APath: string);
var
  LFileOpStruct: TSHFileOpStruct;
begin
  FillChar(LFileOpStruct, SizeOf(LFileOpStruct), 0);
  with LFileOpStruct do begin
    Wnd := 0;
    wFunc := FO_DELETE;
    pFrom := PChar(APath + '*.*'#0);
    fFlags := FOF_NOCONFIRMATION + FOF_SILENT;
  end;
  if ShFileOperation(LFileOpStruct) <> 0 then
    raise Exception.CreateFmt(_('Error deleting files from folder "%s".'), [APath]);
end;

function OpenDocument(const AFileName: string; const AWait: Boolean = False): Integer;
var
  LExecInfo: TShellExecuteInfo;
  LReturnValue: Boolean;
  LUnsignedResult: Cardinal;
begin
  FillChar(LExecInfo, SizeOf(LExecInfo), #0);
  LExecInfo.cbSize := SizeOf(LExecInfo);
  LExecInfo.fMask := SEE_MASK_NOCLOSEPROCESS + SEE_MASK_NOASYNC;
  LExecInfo.lpVerb := PChar('open');
  LExecInfo.nShow := SW_SHOW;
  LExecInfo.lpFile := PChar(AFileName);

  LReturnValue := ShellExecuteEx(@LExecInfo);

  if LReturnValue then
  begin
    // SEE_MASK_NOCLOSEPROCESS asks for the process handle, but ShellExecuteEx
    // succeeds with a null one when no process was started -- the document was
    // handed to an instance already running. There is then nothing to wait for
    // and nothing to close.
    if AWait and (LExecInfo.hProcess <> 0) then
    begin
      WaitForSingleObject(LExecInfo.hProcess, INFINITE);
      // GetExitCodeProcess leaves its argument untouched when it fails, and
      // LUnsignedResult is a plain local: it used to be read either way, so a
      // failed call returned whatever was on the stack as the document's exit
      // code.
      LUnsignedResult := 0;
      GetExitCodeProcess(LExecInfo.hProcess, LUnsignedResult);
      Result := LUnsignedResult;
    end
    else
      Result := 0;
    if LExecInfo.hProcess <> 0 then
      CloseHandle(LExecInfo.hProcess);
  end
  else
    Result := -1;
end;

end.
