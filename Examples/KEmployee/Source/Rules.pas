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

unit Rules;

interface

uses
  Kitto.Rules, Kitto.Store;

type
  TDefaultPhaseStartTime = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
  end;

implementation

uses
  System.SysUtils,
  System.Variants,
  EF.Localization,
  Kitto.Metadata.DataView;

{ TDefaultPhaseStartTime }

procedure TDefaultPhaseStartTime.NewRecord(const ARecord: TKRecord);
var
  LLastDate: Variant;
begin
  inherited;
  LLastDate := ARecord.Store.Max('END_DATE');
  if VarIsNull(LLastDate) then
    ARecord.FieldByName('START_DATE').AsDate := Date
  else
    ARecord.FieldByName('START_DATE').AsDate := LLastDate + 1;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TDefaultPhaseStartTime.GetClassId, TDefaultPhaseStartTime);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TDefaultPhaseStartTime.GetClassId);

end.
