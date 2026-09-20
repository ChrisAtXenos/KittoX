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

/// <summary>Business rules of the subscription fee model: total recalculated from the
/// single installments.</summary>
unit SCM.Rules.SubscriptionFee;

interface

uses
  Kitto.Rules, KItto.Store,
  Kitto.Web.Session;

type

  //Field rule: Person
  TSubscriptionFeeSetInstalment = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

implementation

{ TSubscriptionFeeSetInstalment }

procedure TSubscriptionFeeSetInstalment.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'Instalment1Amount') or
     (AField.Name = 'Instalment2Amount') or
     (AField.Name = 'Instalment3Amount') or
     (AField.Name = 'Instalment4Amount') or
     (AField.Name = 'Instalment5Amount') then
  begin
    AField.ParentRecord.FieldByName('TotalFee').AsCurrency := AField.ParentRecord.FieldByName('Instalment1Amount').AsCurrency+
                                                                 AField.ParentRecord.FieldByName('Instalment2Amount').AsCurrency+
                                                                 AField.ParentRecord.FieldByName('Instalment3Amount').AsCurrency+
                                                                 AField.ParentRecord.FieldByName('Instalment4Amount').AsCurrency+
                                                                 AField.ParentRecord.FieldByName('Instalment5Amount').AsCurrency;
  end;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionFeeSetInstalment.GetClassId, TSubscriptionFeeSetInstalment);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionFeeSetInstalment.GetClassId);

end.
