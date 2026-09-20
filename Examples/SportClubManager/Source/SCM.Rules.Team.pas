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

/// <summary>Business rules of the team model.</summary>
unit SCM.Rules.Team;

interface

uses
  Kitto.Rules, KItto.Store;

type

///--- MODEL RULES
  TTeamCheck = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
  end;

implementation

uses
  System.SysUtils
  ,System.DateUtils
  ,Data.DB
  ,EF.Localization
  ,EF.VariantUtils
  ,EF.StrUtils
  ,Kitto.Config
  ,Kitto.Metadata.DataView
  ,Kitto.Web.Session
  ,EF.DB
  ,SCM.Utils;

{ TTeamCheck }

procedure TTeamCheck.NewRecord(const ARecord: TKRecord);
begin
  inherited;
  ARecord.FieldByName('SeasonId').AsString := EFVarToStr(TKConfig.Database.GetSingletonValue('SELECT ID FROM STAGIONE WHERE DATAINI <= ' + QuotedStr(DateTimeToDelimitedStr(Now))+' AND DATAFINE >= ' + QuotedStr(DateTimeToDelimitedStr(Now))));
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TTeamCheck.GetClassId, TTeamCheck);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TTeamCheck.GetClassId);

end.
