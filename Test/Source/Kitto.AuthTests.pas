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
///  A credential a user types at the login form must be compared verbatim. It
///  used to be run through the macro expansion engine first, which let anyone
///  type %Config:Auth/PassepartoutPassword% and have it resolve to the real
///  passepartout — logging in as any existing user without knowing it — or
///  %Auth:UserName% and drive the engine into a self-referential loop. Macros
///  belong only on the CONFIG side (Auth/Defaults, e.g. %ENV_VAR% for a service
///  password), expanded in ApplyConfigDefaults, never on the supplied side.
///
///  These tests reach the supplied-credential accessors through a thin
///  subclass; they need no database (the accessors do not query one) and no
///  session (the authenticator constructor seeds session data only when a
///  session exists).
/// </summary>
unit Kitto.AuthTests;

interface

uses
  DUnitX.TestFramework,
  EF.Tree,
  Kitto.Auth.DB;

type
  /// <summary>Exposes the strict-protected supplied-credential accessors.</summary>
  TTestableDBAuthenticator = class(TKDBAuthenticator)
  public
    function PublicGetSuppliedUserName(const AAuthData: TEFNode): string;
    function PublicGetSuppliedPasswordHash(const AAuthData: TEFNode;
      const AHashNeeded: Boolean): string;
  end;

  [TestFixture]
  TKDBAuthenticatorSuppliedCredentialsTests = class
  strict private
    FAuth: TTestableDBAuthenticator;
    FAuthData: TEFNode;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>A typed password carrying a macro is returned unchanged.</summary>
    [Test]
    procedure ATypedPasswordIsNotMacroExpanded;

    /// <summary>A typed user name carrying a macro is returned unchanged.</summary>
    [Test]
    procedure ATypedUserNameIsNotMacroExpanded;
  end;

  /// <summary>Exposes the protected random-password generator.</summary>
  TTestableDBCryptAuthenticator = class(TKDBCryptAuthenticator)
  public
    function PublicGenerateRandomPassword: string;
  end;

  [TestFixture]
  TKDBCryptAuthenticatorPolicyTests = class
  public
    /// <summary>
    ///  DBCrypt without a ValidatePassword node used to read the policy off a
    ///  nil node — an access violation in GenerateRandomPassword and an
    ///  assertion in SetPassword. The node is optional, so a random password
    ///  must still be produced against the built-in default rule.
    /// </summary>
    [Test]
    procedure GenerateRandomPassword_WithNoValidatePasswordNode_DoesNotCrash;
  end;

implementation

uses
  System.SysUtils,
  Kitto.Config,
  // Referenced so the test build compiles it from the working copy: none of the
  // buildable examples use Auth: DBServer, yet the connection-string-injection
  // guard added to it must not silently rot.
  Kitto.Auth.DBServer,
  // Referenced so the test build compiles it from the working copy: the same
  // "typed credentials are never macro-expanded" change was applied here, and
  // this example-less authenticator is not reached by any buildable example.
  Kitto.Auth.TextFile;

const
  // A macro the standard engine always expands (to a single space), so the
  // "before the fix" behaviour is unambiguous and the assertions below mean
  // something.
  MACRO = 'a%SPACE%b';

{ TTestableDBAuthenticator }

function TTestableDBAuthenticator.PublicGetSuppliedUserName(
  const AAuthData: TEFNode): string;
begin
  Result := GetSuppliedUserName(AAuthData);
end;

function TTestableDBAuthenticator.PublicGetSuppliedPasswordHash(
  const AAuthData: TEFNode; const AHashNeeded: Boolean): string;
begin
  Result := GetSuppliedPasswordHash(AAuthData, AHashNeeded);
end;

{ TKDBAuthenticatorSuppliedCredentialsTests }

procedure TKDBAuthenticatorSuppliedCredentialsTests.Setup;
var
  LSanity: string;
begin
  // Premise: the macro really expands through the engine the accessor used to
  // call. If it did not, these tests would pass whether or not the fix is in
  // place and prove nothing; so fail loudly here instead.
  LSanity := MACRO;
  TKConfig.Instance.MacroExpansionEngine.Expand(LSanity);
  Assert.AreNotEqual(MACRO, LSanity,
    'Test premise broken: %SPACE% must expand through the config macro engine.');

  FAuth := TTestableDBAuthenticator.Create;
  FAuthData := TEFNode.Create;
  FAuthData.SetString('UserName', MACRO);
  FAuthData.SetString('Password', MACRO);
end;

procedure TKDBAuthenticatorSuppliedCredentialsTests.TearDown;
begin
  FAuthData.Free;
  FAuth.Free;
end;

procedure TKDBAuthenticatorSuppliedCredentialsTests.ATypedPasswordIsNotMacroExpanded;
begin
  Assert.AreEqual(MACRO, FAuth.PublicGetSuppliedPasswordHash(FAuthData, False),
    'A typed password must be compared verbatim, not macro-expanded.');
end;

procedure TKDBAuthenticatorSuppliedCredentialsTests.ATypedUserNameIsNotMacroExpanded;
begin
  Assert.AreEqual(MACRO, FAuth.PublicGetSuppliedUserName(FAuthData),
    'A typed user name must be compared verbatim, not macro-expanded.');
end;

{ TTestableDBCryptAuthenticator }

function TTestableDBCryptAuthenticator.PublicGenerateRandomPassword: string;
begin
  Result := GenerateRandomPassword;
end;

{ TKDBCryptAuthenticatorPolicyTests }

procedure TKDBCryptAuthenticatorPolicyTests.GenerateRandomPassword_WithNoValidatePasswordNode_DoesNotCrash;
var
  LAuth: TTestableDBCryptAuthenticator;
  LPassword: string;
begin
  // No config file, hence no ValidatePassword node: the getter must default the
  // rule instead of dereferencing nil.
  LAuth := TTestableDBCryptAuthenticator.Create;
  try
    LPassword := LAuth.PublicGenerateRandomPassword;
    Assert.IsTrue(Length(LPassword) >= 8,
      'A random password must still be produced against the default policy when '
      + 'no ValidatePassword node is configured.');
  finally
    LAuth.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKDBAuthenticatorSuppliedCredentialsTests);
  TDUnitX.RegisterTestFixture(TKDBCryptAuthenticatorPolicyTests);

end.
