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
unit EF.LoggerTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFTextFileLogEndpointTests = class
  strict private
    FTempPath: string;
    /// <summary>Points the text file endpoint at AFileName and enables it, the
    /// way an application does: through the logger's configuration.</summary>
    procedure ConfigureLogTo(const AFileName: string);
    procedure DisableLog;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///  Concurrent writes must not corrupt one another. The lock used to cover
    ///  only the creation of the stream, so several threads wrote to the same
    ///  TFileStream at once and their lines came out interleaved - the log
    ///  became unreadable exactly under the load that makes one want to read it.
    /// </summary>
    [Test]
    procedure Log_FromSeveralThreads_WritesWholeLines;

    /// <summary>
    ///  Reconfiguring the logger changes the file name, which frees the open
    ///  stream. That used to happen outside any lock, so a thread writing at
    ///  that moment used a freed object. It is the ISAPI/Apache sequence: the
    ///  handler logs before the engine is initialized, and the initialization
    ///  reconfigures the logger - so the access violation surfaced in the
    ///  thread of an unrelated request.
    /// </summary>
    [Test]
    procedure Reconfigure_WhileOtherThreadsLog_DoesNotBreak;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  EF.Tree,
  EF.Logger,
  EF.Logger.TextFile,
  Kitto.TestUtils;

const
  THREAD_COUNT = 6;
  LINES_PER_THREAD = 120;
  // Long enough that an interleaved write shows up as a broken line.
  LINE_BODY = 'abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz';

{ TEFTextFileLogEndpointTests }

procedure TEFTextFileLogEndpointTests.Setup;
begin
  FTempPath := TKTestUtils.CreateTempPath;
end;

procedure TEFTextFileLogEndpointTests.TearDown;
begin
  DisableLog;
  TKTestUtils.RemoveTempPath(FTempPath);
end;

procedure TEFTextFileLogEndpointTests.ConfigureLogTo(const AFileName: string);
var
  LConfig: TEFTree;
begin
  LConfig := TEFTree.Create;
  try
    LConfig.SetString('Level', '5');
    LConfig.SetString('TextFile/IsEnabled', 'True');
    TEFLogger.Instance.Configure(LConfig, nil);
  finally
    LConfig.Free;
  end;
  // Set through the property: Configure only reads TextFile/FileName when a
  // macro expansion engine is supplied, and there is none here.
  ForceDirectories(ExtractFilePath(AFileName));
  TEFTextFileLogEndpoint.Instance.FileName := AFileName;
end;

procedure TEFTextFileLogEndpointTests.DisableLog;
var
  LConfig: TEFTree;
begin
  LConfig := TEFTree.Create;
  try
    LConfig.SetString('TextFile/IsEnabled', 'False');
    TEFLogger.Instance.Configure(LConfig, nil);
  finally
    LConfig.Free;
  end;
  // Releases the file handle, so the temp folder can be removed.
  TEFTextFileLogEndpoint.Instance.FileName := '';
end;

procedure TEFTextFileLogEndpointTests.Log_FromSeveralThreads_WritesWholeLines;
var
  LFileName: string;
  LThreads: array of TThread;
  I: Integer;
  LLines: TStrings;
  LGoodLines: Integer;
begin
  LFileName := FTempPath + 'concurrent.log';
  ConfigureLogTo(LFileName);

  SetLength(LThreads, THREAD_COUNT);
  for I := 0 to THREAD_COUNT - 1 do
  begin
    LThreads[I] := TThread.CreateAnonymousThread(
      procedure
      var
        J: Integer;
      begin
        for J := 1 to LINES_PER_THREAD do
          TEFLogger.Instance.Log(LINE_BODY);
      end);
    LThreads[I].FreeOnTerminate := False;
  end;
  try
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Start;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].WaitFor;
  finally
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Free;
  end;

  DisableLog;   // closes the file

  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LFileName);
    LGoodLines := 0;
    for I := 0 to LLines.Count - 1 do
      // A whole line is a timestamp followed by exactly the body written.
      if LLines[I].StartsWith('[') and LLines[I].EndsWith(LINE_BODY) then
        Inc(LGoodLines);
    Assert.AreEqual(THREAD_COUNT * LINES_PER_THREAD, LGoodLines,
      Format('%d of %d lines came out whole (%d lines in the file): concurrent ' +
        'writes are interleaving.',
        [LGoodLines, THREAD_COUNT * LINES_PER_THREAD, LLines.Count]));
  finally
    LLines.Free;
  end;
end;

procedure TEFTextFileLogEndpointTests.Reconfigure_WhileOtherThreadsLog_DoesNotBreak;
var
  LThreads: array of TThread;
  LSwitcher: TThread;
  LFailures: Integer;
  LTempPath: string;
  I: Integer;
begin
  ConfigureLogTo(FTempPath + 'switch_0.log');
  LFailures := 0;
  LTempPath := FTempPath;

  SetLength(LThreads, THREAD_COUNT);
  for I := 0 to THREAD_COUNT - 1 do
  begin
    LThreads[I] := TThread.CreateAnonymousThread(
      procedure
      var
        J: Integer;
      begin
        for J := 1 to LINES_PER_THREAD do
        try
          TEFLogger.Instance.Log(LINE_BODY);
        except
          TInterlocked.Increment(LFailures);
        end;
      end);
    LThreads[I].FreeOnTerminate := False;
  end;
  // Meanwhile someone reconfigures the logger, as the engine initialization
  // does under ISAPI/Apache while other requests are already being served.
  LSwitcher := TThread.CreateAnonymousThread(
    procedure
    var
      J: Integer;
    begin
      for J := 1 to 25 do
      try
        TEFTextFileLogEndpoint.Instance.FileName :=
          Format('%sswitch_%d.log', [LTempPath, J]);
        Sleep(1);
      except
        TInterlocked.Increment(LFailures);
      end;
    end);
  LSwitcher.FreeOnTerminate := False;
  try
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Start;
    LSwitcher.Start;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].WaitFor;
    LSwitcher.WaitFor;
  finally
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Free;
    LSwitcher.Free;
  end;

  Assert.AreEqual(0, LFailures,
    'Logging raised while the file name was being changed: the stream is freed ' +
    'from under the threads writing to it.');
end;

initialization
  TDUnitX.RegisterTestFixture(TEFTextFileLogEndpointTests);

end.
