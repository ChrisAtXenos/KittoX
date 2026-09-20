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
///  A brand-new session must not read as already expired. It used to: the
///  last-request time is 0 until the first request refreshes it, so HasExpired
///  compared Now against 0 + Timeout and returned True the instant the session
///  was created — while the cleanup thread, which frees whatever HasExpired
///  reports, could free it out from under the request that had just created it.
///  These tests exercise HasExpired directly; no server or database is needed.
/// </summary>
unit Kitto.SessionTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKWebSessionExpiryTests = class
  public
    /// <summary>Just created, well within the timeout: not expired.</summary>
    [Test]
    procedure AFreshlyCreatedSessionIsNotExpired;

    /// <summary>The timeout itself still works: once the deadline has passed,
    /// the session is expired.</summary>
    [Test]
    procedure ASessionPastItsTimeoutIsExpired;
  end;

implementation

uses
  System.DateUtils,
  Kitto.Web.Session;

procedure TKWebSessionExpiryTests.AFreshlyCreatedSessionIsNotExpired;
var
  LSession: TKWebSession;
begin
  LSession := TKWebSession.Create('127.0.0.1', 'sid-fresh', 10 * OneMinute);
  try
    Assert.IsFalse(LSession.HasExpired,
      'A session created a moment ago, with a 10-minute timeout, must not be ' +
      'reported as expired before it has served a single request.');
  finally
    LSession.Free;
  end;
end;

procedure TKWebSessionExpiryTests.ASessionPastItsTimeoutIsExpired;
var
  LSession: TKWebSession;
begin
  // A negative timeout puts the deadline (creation time + timeout) in the past,
  // so the session is expired now — deterministically, without waiting. This
  // pins that the fresh-session fix did not disable expiry altogether.
  LSession := TKWebSession.Create('127.0.0.1', 'sid-stale', -OneMinute);
  try
    Assert.IsTrue(LSession.HasExpired,
      'A session whose deadline has passed must still be reported as expired.');
  finally
    LSession.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKWebSessionExpiryTests);

end.
