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

/// <summary>Business rules of the enrollment campaign model: discount setup and
/// propagation of the campaign defaults to its fees.</summary>
unit SCM.Rules.SubscriptionCampaign;

interface

uses
  Kitto.Rules, KItto.Store;

Type

///--- FIELD RULES
///
  TSubscriptionCampaignSetSuggestedRef = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue: Variant; const ANewValue: Variant); override;
  end;

  TSubscriptionCampaignSetDiscount = class(TKRuleImpl)
  private
    procedure UpdateEditors(ARecord: TKRecord; AFieldChanged: TKField);
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue: Variant; const ANewValue: Variant); override;
    procedure AfterShowEditWindow(const ARecord: TKRecord); override;
  end;

implementation

uses
   Data.DB, EF.DB,  Kitto.Config, System.SysUtils;

{ TSubscriptionCampaignSetSuggestedRef }

procedure TSubscriptionCampaignSetSuggestedRef.AfterFieldChange(
  const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LQuery: TEFDBQuery;
  LDBConnection: TEFDBConnection;
begin
  inherited;
  if (AField.Name = 'SeasonId') then
  begin
    LDBConnection := TKConfig.Database;
    LQuery := LDBConnection.CreateDBQuery;
    LQuery.CommandText :=  'SELECT ID, DX, DATAINI, DATAFINE '+
                           'FROM STAGIONE '+
                           'WHERE ID = :ID';
    try
      LQuery.Params.ParamByName('ID').Value := ANewValue;
      LQuery.Open;
      if not LQuery.DataSet.IsEmpty then
      begin
        if not LQuery.DataSet.FieldByName('DATAINI').isNull then
          AField.ParentRecord.FieldByName('StartDate').AsDateTime := LQuery.DataSet.FieldByName('DATAINI').AsDateTime;
        if not LQuery.DataSet.FieldByName('DATAFINE').isNull then
          AField.ParentRecord.FieldByName('EndDate').AsDateTime := LQuery.DataSet.FieldByName('DATAFINE').AsDateTime;
      end;
      LQuery.Close;
    finally
      FreeAndNil(LQuery);
    end;
  end
end;

{ TSubscriptionCampaignSetDiscount }

procedure TSubscriptionCampaignSetDiscount.UpdateEditors(ARecord: TKRecord;
  AFieldChanged: TKField);
var
  LSiblingDiscountField: TKField;
  LSiblingDiscountPercentField: TKField;
begin
  if Assigned(ARecord) and Assigned(AFieldChanged) then
  begin
    LSiblingDiscountPercentField := ARecord.FieldByName('SiblingDiscountPercent');
    LSiblingDiscountField := ARecord.FieldByName('SiblingDiscount');
    if AFieldChanged.FieldName = 'SiblingDiscount' then
    begin
      if LSiblingDiscountField.AsFloat <> 0 then
        LSiblingDiscountPercentField.AsFloat := 0;
    end
    else if AFieldChanged.FieldName = 'SiblingDiscountPercent' then
    begin
      if LSiblingDiscountPercentField.AsFloat <> 0 then
        LSiblingDiscountField.AsFloat := 0
    end;
  end;
end;

procedure TSubscriptionCampaignSetDiscount.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.FieldName = 'SiblingDiscount') or (AField.FieldName = 'SiblingDiscountPercent') then
    UpdateEditors(AField.ParentRecord, AField);
end;

procedure TSubscriptionCampaignSetDiscount.AfterShowEditWindow(const ARecord: TKRecord);
begin
  inherited;
  UpdateEditors(ARecord, nil);
end;


initialization
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionCampaignSetSuggestedRef.GetClassId, TSubscriptionCampaignSetSuggestedRef);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionCampaignSetDiscount.GetClassId, TSubscriptionCampaignSetDiscount);
finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionCampaignSetSuggestedRef.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionCampaignSetDiscount.GetClassId);
end.
