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

/// <summary>Unit registration for the application: pulls in the framework and project
/// units that must be linked, and registers the JWT signing key shared by every
/// deployment target.</summary>
unit UseKitto;

{$I Kitto.Defines.inc}

interface

uses
  //Core Kitto Units
  Kitto.Html.All
  ,Kitto.Web.Enterprise //Enterprise SCM.Controllers (Chart, Calendar, GoogleMap, Dashboard)
  ,EF.Logger.TextFile
  ,EF.DB.ADO
  ,EF.DB.FD
  //,EF.DB.DBX
  // ---------------------------------------------------------------------------
  // REQUIRES DELPHI ENTERPRISE (or ARCHITECT) for the client/server database
  // drivers below: the FireDAC FireDAC.Phys.* ones (and the DBExpress Data.DBX*)
  // for remote DBMS (MS SQL Server, Oracle, PostgreSQL, MySQL, Firebird...).
  // Client/server database access is a feature of the Enterprise and Architect
  // editions only. Delphi PROFESSIONAL ships FireDAC/DBExpress with the local
  // and embedded drivers only (SQLite, InterBase ToGo), so with a Professional
  // licence these uses do NOT compile ("unit FireDAC.Phys.MSSQL not found").
  // A KittoX web application normally talks to a client/server database, so
  // building it needs the licence upgraded from Professional to Enterprise
  // (or Architect). With Professional only a local database can be used
  // (SQLite/InterBase; ADO/dbGo is in Professional too).
  // ---------------------------------------------------------------------------
  ,FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLMeta //FireDac support for MS-SQL
  //Framework units
  ,Kitto.AccessControl.DB     // stays: used by AccessControl: JWT FallbackToDB
  ,Kitto.AccessControl.JWT    // registers the 'JWT' AccessController
  ,Kitto.Auth.DB              // stays: TSCMAuthenticator extends TKDBAuthenticator
  ,Kitto.Auth.JWT             // registered the 'JWT' Authenticator envelope, removed from the framework
  ,Kitto.Auth.DBServer
  ,Kitto.Tool.ADO //For Excel via ADO import/export
  ,Kitto.Tool.DebenuQuickPDF //For PDF Merge
  ,Kitto.Tool.XSL //For XSL Transformation
  ,Kitto.html.TilePanel
  ,Kitto.Metadata.ModelImplementation
  ,Kitto.Metadata.ViewBuilders
  ,Kitto.Html.CalendarPanel
  //Help chat: the "?" button opens the assistant grounded on the SCM VitePress docs
  ,Kitto.Web.Handler.Chat      //endpoint /kx/chat/*
  ,Kitto.Chat.DocSearch        //documentation index (KXSearchHelpPages)
  ,Kitto.Chat.Provider.Claude  //provider 'claude'
  //Project units
  ,SCM.Auth //Application specific authenticator
  ,SCM.Macros //Macro used by SCM
  ,SCM.Rules //General SCM.Rules
  ,SCM.Rules.Subscription //Subscription SCM.Rules
  ,SCM.Rules.Family //Family SCM.Rules
  ,SCM.Rules.User //User SCM.Rules
  ,SCM.Rules.Person //Person SCM.Rules
  ,SCM.Rules.MedicalVisit //Medical visit SCM.Rules
  ,SCM.Utils //General purpose helpers
  ,SCM.DbUtils //General purpose helpers that reach the database
  ,SCM.Mail //General purpose e-mail helpers
  ,SCM.Rules.Payment //Payment SCM.Rules
  ,SCM.Rules.SubscriptionFee //Subscription fee SCM.Rules
  ,SCM.Tool.ExcelExport //The single Excel export tool: FlexCel or ADO, see SCM.Defines.inc
  ,SCM.Tools //Tool button SCM.Controllers
  ,SCM.Mail.Consts //Constants for sending mail on localhost and in DEBUG
  ,SCM.Rules.CustomerSupplier //Customer and supplier SCM.Rules
  ,SCM.Rules.MembersRegister //Members register SCM.Rules
  ,SCM.Accounting //Accounting helpers
  ,SCM.Rules.AccountingEntry //Accounting entry SCM.Rules
  ,SCM.Rules.Team //Team SCM.Rules
  ,SCM.Rules.SubscriptionCampaign //Subscription campaign SCM.Rules
  ,SCM.Rules.FederationRegistration //Federation registration SCM.Rules
  ,SCM.Rules.Conversation //Internal messaging SCM.Rules
  ;

implementation

uses
  System.SysUtils,
  Kitto.Web.JWT,
  JOSE.Core.JWA;

initialization
{$WARN SYMBOL_PLATFORM OFF}
  // check memory leaks at the end of the app
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
{$WARN SYMBOL_PLATFORM ON}

  // Signing key of the SCM JWT envelope. Registered programmatically so that every
  // .dpr (KittoXSCM, KittoLibertasCernusco, ... and the ISAPI/Apache modules)
  // shares the same key. The AppName ('SportClubManager') is the one in the
  // Config_*.yaml of the sport clubs; the match is case insensitive.
  // PRODUCTION: replace the literal with a load from a vault or secret manager
  // (the registered provider always wins over Auth/JWT/SigningKey in the YAML).
  TKJWTSigningKeyRegistry.Instance.RegisterProvider('SportClubManager',
    function: TKJWTSigningKey
    begin
      Result.Algorithm := TJOSEAlgorithmId.HS256;
      Result.PrivateKey := TEncoding.UTF8.GetBytes(
        'scm-dev-hs256-shared-key-do-not-use-this-in-prod');
    end);

end.
