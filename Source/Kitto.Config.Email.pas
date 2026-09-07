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
///  Typed config readers for the e-mail domain (Config.yaml node <c>Email</c>
///  and its <c>SMTP</c> servers). Part of the per-domain organization of the
///  config metadata. Each class reads its subtree once into typed fields (see
///  TKConfigReader) AND carries the [YamlNode]/[YamlSubNode] attributes that
///  KIDE reads via RTTI to drive the Config editor.
///
///  A server is looked up by name, so an application can declare several and
///  pick one per message: the tool that sends mail reads <c>Email/SMTP/Default</c>
///  unless told otherwise.
/// </summary>
unit Kitto.Config.Email;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Settings of one SMTP server.
  ///  YAML path: Email/SMTP/&lt;Name&gt; (the framework reads 'Default' unless
  ///  a tool names another one).
  /// </summary>
  /// <example>
  ///  Email:
  ///    SMTP:
  ///      Default:
  ///        HostName: smtp.example.com
  ///        Port: 587
  ///        UserName: user@example.com
  ///        Password: secret
  ///        UseTLS: True
  ///        TLSMode: Explicit
  /// </example>
  TKSMTPConfig = class(TKConfigReader)
  private
    FHostName: string;
    FPort: Integer;
    FUserName: string;
    FPassword: string;
    FUseTLS: Boolean;
    FTLSMode: string;
    FVerifyCertificate: Boolean;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('HostName', 'SMTP server host name')]
    property HostName: string read FHostName;

    [YamlNode('Port', '25', 'SMTP server port. Usually 25 without encryption, 587 with explicit TLS (STARTTLS), 465 with implicit TLS')]
    property Port: Integer read FPort;

    [YamlNode('UserName', 'User name for SMTP authentication. Leave empty on a server that does not authenticate')]
    property UserName: string read FUserName;

    [YamlNode('Password', 'Password for SMTP authentication')]
    property Password: string read FPassword;

    [YamlNode('UseTLS', 'True', 'Encrypt the connection. Leave it on unless the server truly does not support TLS: without it the credentials travel in clear')]
    property UseTLS: Boolean read FUseTLS;

    [YamlNode('TLSMode', 'Explicit', 'How TLS is established: Explicit (STARTTLS on the plain port, the usual choice on 587) | Implicit (TLS from the first byte, port 465) | Required (explicit, and refuse to send if the server does not offer it)')]
    property TLSMode: string read FTLSMode;

    [YamlNode('VerifyCertificate', 'True', 'Check the server certificate. Set to False only for an internal server with a self-signed certificate, knowing that the connection is then open to interception')]
    property VerifyCertificate: Boolean read FVerifyCertificate;
  end;

  /// <summary>
  ///  E-mail settings from Config.yaml.
  ///  YAML path: Email
  /// </summary>
  TKEmailConfig = class(TKConfigReader)
  private
    FSMTP: TKSMTPConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    /// <summary>
    ///  The default SMTP server, i.e. Email/SMTP/Default. Servers declared
    ///  under other names are read by name from the node itself; this property
    ///  exists so the common case is typed, and so KIDE has something to show.
    /// </summary>
    [YamlSubNode('SMTP', TKSMTPConfig, 'SMTP servers, by name. The framework uses the one called Default unless a tool names another')]
    property SMTP: TKSMTPConfig read FSMTP;
  end;

implementation

{ TKSMTPConfig }

procedure TKSMTPConfig.ReadConfig;
begin
  FHostName := GetExpandedString('HostName');
  FPort := GetInteger('Port', 25);
  FUserName := GetExpandedString('UserName');
  FPassword := GetExpandedString('Password');
  FUseTLS := GetBoolean('UseTLS', True);
  FTLSMode := GetString('TLSMode', 'Explicit');
  // On by default: an unverified certificate makes the encryption pointless
  // against anyone able to sit in the middle.
  FVerifyCertificate := GetBoolean('VerifyCertificate', True);
end;

{ TKEmailConfig }

procedure TKEmailConfig.ReadConfig;
begin
  if FSMTP = nil then
    FSMTP := TKSMTPConfig.Create(SubNode('SMTP/Default'))
  else
    FSMTP.Refresh(SubNode('SMTP/Default'));
end;

destructor TKEmailConfig.Destroy;
begin
  FSMTP.Free;
  inherited;
end;

end.
