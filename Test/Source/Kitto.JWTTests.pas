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
///  The JWT validator (Kitto.Web.JWT) is the gate every request passes when
///  Auth/JWT is configured: what it accepts is authenticated. These tests
///  need no web server and no database: they build a TKJWTConfig from an
///  in-memory Auth/JWT node, forge tokens with the JOSE library the way an
///  attacker would with any JWT tool, and ask the validator.
///
///  The forging deliberately bypasses the library's key validation
///  (SerializeCompact with ASkipValidation = True): the producer's checks
///  protect the SIGNER from its own mistakes, an attacker is not bound by them.
/// </summary>
unit Kitto.JWTTests;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  EF.Tree,
  Kitto.Web.JWT;

type
  [TestFixture]
  TKJWTValidatorTests = class
  strict private
    FAuthNode: TEFNode;
    /// <summary>A config whose Auth/JWT node declares the algorithm and the
    /// inline key(s). Owned by the caller.</summary>
    function MakeConfig(const AAlgorithm, ASigningKey: string;
      const ASigningPublicKey: string = ''): TKJWTConfig;
    /// <summary>A token carrying the claims the validator requires (iss, aud,
    /// sub, iat, exp), signed with AAlgorithm and AKeyBytes, whatever they
    /// are: no key validation, like an attacker's tool.</summary>
    function ForgeToken(const AAlgorithm: string; const AKeyBytes: TBytes;
      const AIssuer, ASubject: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>Control: what the framework itself signs, it accepts.</summary>
    [Test]
    procedure ATokenBuiltByTheFrameworkValidates;

    /// <summary>Control: the right algorithm with the wrong secret is refused.</summary>
    [Test]
    procedure ATokenSignedWithAnotherSecretIsRejected;

    /// <summary>
    ///  Algorithm confusion. The application is configured for RS256 and holds
    ///  the PUBLIC key, which is public by definition. The attacker takes the
    ///  PEM text of that key, uses it as an HMAC secret, and sends an HS256
    ///  token. A verifier that lets the token's own header choose the
    ///  algorithm computes HMAC(public key, ...) and finds the signature
    ///  correct: the attacker chose any 'sub' they liked.
    /// </summary>
    [Test]
    procedure AnHmacTokenSignedWithThePublicKeyIsRejected;

    /// <summary>
    ///  Pinning: with HS256 configured, an HS512 token signed with the real
    ///  secret is still not what the configuration says, and must be refused.
    ///  Today it passes because the accepted algorithms are the library's
    ///  default list, not the one configured.
    /// </summary>
    [Test]
    procedure ATokenWithAnAlgorithmOtherThanTheConfiguredOneIsRejected;

    /// <summary>
    ///  M3 (absolute cap). The 'sst' claim (session start) is set once and must
    ///  survive a slide unchanged, so the cap measures from the original login
    ///  and not from the last renewal (unlike iat, which every slide moves).
    /// </summary>
    [Test]
    procedure SessionStart_SurvivesASlide;

    /// <summary>
    ///  M3 (revocation). A jti added to the denylist is refused until its
    ///  expiry, an unknown one is not, and an already-expired entry is purged.
    /// </summary>
    [Test]
    procedure TheDenylistRejectsARevokedJtiUntilItExpires;

    /// <summary>
    ///  M3 (absolute cap). Past MaxSessionLifetime measured from SessionStart the
    ///  cap is reached (token no longer slid and then refused); within it, not.
    /// </summary>
    [Test]
    procedure TheSessionCapIsReachedPastMaxSessionLifetime;
  end;

implementation

uses
  System.DateUtils,
  JOSE.Types.Bytes,
  JOSE.Core.JWA,
  JOSE.Core.JWT,
  JOSE.Core.JWK,
  JOSE.Core.Builder;

const
  APP_NAME = 'JWTTestApp';
  // 32+ bytes: the producer refuses shorter HMAC secrets, and the control test
  // signs through the framework.
  SECRET = 'a-test-hmac-secret-of-at-least-32-bytes-0123456789';
  OTHER_SECRET = 'another-test-hmac-secret-of-32-bytes-9876543210';
  // Any PEM-armoured text will do: the verifier under test never looks inside.
  // This is the shape of an RSA public key as `openssl rsa -pubout` writes it.
  PUBLIC_KEY_PEM =
    '-----BEGIN PUBLIC KEY-----'#10 +
    'MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAL5tZ0Wf0Q6kQH0m9y3fPmO6mQ6x1G6d'#10 +
    'x8WQ0x3e1VJq8Zc3eZ0c9x7qkq7oWmZ9U2Kz9m4kF0QpQyE0k2k1wq0CAwEAAQ=='#10 +
    '-----END PUBLIC KEY-----'#10;

{ TKJWTValidatorTests }

procedure TKJWTValidatorTests.Setup;
begin
  FAuthNode := TEFNode.Create('JWT');
end;

procedure TKJWTValidatorTests.TearDown;
begin
  FreeAndNil(FAuthNode);
end;

function TKJWTValidatorTests.MakeConfig(const AAlgorithm, ASigningKey,
  ASigningPublicKey: string): TKJWTConfig;
begin
  FAuthNode.ClearChildren;
  FAuthNode.SetString('SigningAlgorithm', AAlgorithm);
  FAuthNode.SetString('SigningKey', ASigningKey);
  if ASigningPublicKey <> '' then
    FAuthNode.SetString('SigningPublicKey', ASigningPublicKey);
  Result := TKJWTConfig.Create(APP_NAME, FAuthNode);
end;

function TKJWTValidatorTests.ForgeToken(const AAlgorithm: string;
  const AKeyBytes: TBytes; const AIssuer, ASubject: string): string;
var
  LToken: TJWT;
  LKey: TJWK;
  LKeyBytes: TJOSEBytes;
  LAlg: TJOSEAlgorithmId;
  LNow: TDateTime;
begin
  LKeyBytes := AKeyBytes;
  LAlg.AsString := AAlgorithm;
  LNow := Now;
  LToken := TJWT.Create;
  try
    LToken.Claims.Issuer := AIssuer;
    LToken.Claims.Audience := 'kx-app';
    LToken.Claims.Subject := ASubject;
    LToken.Claims.IssuedAt := LNow;
    LToken.Claims.Expiration := IncHour(LNow, 1);
    LKey := TJWK.Create(LKeyBytes);
    try
      Result := TJOSE.SerializeCompact(LKey, LAlg, LToken, True).AsString;
    finally
      LKey.Free;
    end;
  finally
    LToken.Free;
  end;
end;

procedure TKJWTValidatorTests.ATokenBuiltByTheFrameworkValidates;
var
  LConfig: TKJWTConfig;
  LContext: TKJWTContext;
  LToken, LError: string;
begin
  LConfig := MakeConfig('HS256', SECRET);
  try
    LContext.Clear;
    LContext.UserName := 'alice';
    LContext.Sid := 'session-1';
    LToken := TKJWTBuilder.Build(LContext, LConfig);

    Assert.IsTrue(TKJWTValidator.Validate(LToken, LConfig, LContext, LError), LError);
    Assert.AreEqual('alice', LContext.UserName);
    Assert.AreEqual('session-1', LContext.Sid);
  finally
    LConfig.Free;
  end;
end;

procedure TKJWTValidatorTests.ATokenSignedWithAnotherSecretIsRejected;
var
  LConfig: TKJWTConfig;
  LContext: TKJWTContext;
  LToken, LError: string;
begin
  LConfig := MakeConfig('HS256', SECRET);
  try
    LToken := ForgeToken('HS256', TEncoding.UTF8.GetBytes(OTHER_SECRET), APP_NAME, 'admin');
    Assert.IsFalse(TKJWTValidator.Validate(LToken, LConfig, LContext, LError),
      'A token signed with a different secret was accepted');
    Assert.IsFalse(LContext.IsValid);
  finally
    LConfig.Free;
  end;
end;

procedure TKJWTValidatorTests.AnHmacTokenSignedWithThePublicKeyIsRejected;
var
  LConfig: TKJWTConfig;
  LContext: TKJWTContext;
  LToken, LError: string;
begin
  // Verifier-only deploy: the application only has the public key.
  LConfig := MakeConfig('RS256', PUBLIC_KEY_PEM);
  try
    // The attacker signs with the exact key bytes the verifier resolves. The
    // config trims the inline spec, so use the trimmed form: an attacker who
    // knows the public key knows its canonical bytes just as the server does.
    LToken := ForgeToken('HS256', TEncoding.UTF8.GetBytes(Trim(PUBLIC_KEY_PEM)), APP_NAME, 'admin');
    Assert.IsFalse(TKJWTValidator.Validate(LToken, LConfig, LContext, LError),
      'An HS256 token HMACed with the RS256 public key was accepted as admin');
    Assert.IsFalse(LContext.IsValid);
  finally
    LConfig.Free;
  end;
end;

procedure TKJWTValidatorTests.ATokenWithAnAlgorithmOtherThanTheConfiguredOneIsRejected;
var
  LConfig: TKJWTConfig;
  LContext: TKJWTContext;
  LToken, LError: string;
begin
  LConfig := MakeConfig('HS256', SECRET);
  try
    LToken := ForgeToken('HS512', TEncoding.UTF8.GetBytes(SECRET), APP_NAME, 'alice');
    Assert.IsFalse(TKJWTValidator.Validate(LToken, LConfig, LContext, LError),
      'An HS512 token was accepted by an HS256 configuration');
  finally
    LConfig.Free;
  end;
end;

procedure TKJWTValidatorTests.SessionStart_SurvivesASlide;
var
  LConfig: TKJWTConfig;
  LContext: TKJWTContext;
  LToken, LError: string;
  LFirstStart: TDateTime;
begin
  LConfig := MakeConfig('HS256', SECRET);
  try
    // Login: no SessionStart in the context, so the builder stamps 'now'.
    LContext.Clear;
    LContext.UserName := 'alice';
    LToken := TKJWTBuilder.Build(LContext, LConfig);
    Assert.IsTrue(TKJWTValidator.Validate(LToken, LConfig, LContext, LError), LError);
    LFirstStart := LContext.SessionStart;
    Assert.IsTrue(LFirstStart > 0, 'SessionStart was not set at login.');

    // Slide: rebuild from the validated context (as SlideToken does). sst must
    // be carried over unchanged.
    LToken := TKJWTBuilder.Build(LContext, LConfig);
    Assert.IsTrue(TKJWTValidator.Validate(LToken, LConfig, LContext, LError), LError);
    Assert.IsTrue(SecondsBetween(LFirstStart, LContext.SessionStart) <= 1,
      'SessionStart changed across a slide.');
  finally
    LConfig.Free;
  end;
end;

procedure TKJWTValidatorTests.TheDenylistRejectsARevokedJtiUntilItExpires;
begin
  Assert.IsFalse(TKJWTRevocation.Instance.IsRevoked('m3-unknown'),
    'An unknown jti must not be reported revoked.');
  TKJWTRevocation.Instance.Revoke('m3-live', IncHour(Now, 1));
  Assert.IsTrue(TKJWTRevocation.Instance.IsRevoked('m3-live'),
    'A revoked jti must be reported revoked.');
  // An entry whose expiry is already past is purged on the next touch.
  TKJWTRevocation.Instance.Revoke('m3-stale', IncSecond(Now, -1));
  Assert.IsFalse(TKJWTRevocation.Instance.IsRevoked('m3-stale'),
    'An expired revocation must be purged.');
end;

procedure TKJWTValidatorTests.TheSessionCapIsReachedPastMaxSessionLifetime;
var
  LConfig: TKJWTConfig;
  LContext: TKJWTContext;
begin
  LConfig := MakeConfig('HS256', SECRET); // default MaxSessionLifetime = 12h
  try
    LContext.Clear;
    LContext.SessionStart := Now;
    Assert.IsFalse(TKJWTCookieHelper.IsSessionCapReached(LContext, LConfig),
      'A session started now must be within the cap.');
    LContext.SessionStart := IncHour(Now, -13); // older than the 12h cap
    Assert.IsTrue(TKJWTCookieHelper.IsSessionCapReached(LContext, LConfig),
      'A session older than the cap must be reported reached.');
  finally
    LConfig.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKJWTValidatorTests);

end.
