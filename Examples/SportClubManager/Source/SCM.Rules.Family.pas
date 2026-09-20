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

/// <summary>Business rules of the family model: alignment of the family with the person
/// chosen as its creator.</summary>
unit SCM.Rules.Family;

interface

uses
  Kitto.Rules, KItto.Store,
  Kitto.Web.Session;

type

  //Field rule: Person
  TFamilySetPerson = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

implementation

uses
  SysUtils
  , Data.DB
  , EF.Localization
  , EF.VariantUtils
  , Kitto.Config
  , Kitto.Metadata.DataView
  , SCM.DbUtils
  , EF.DB
  , SCM.Utils
  , SCM.Mail
  , System.Variants;

{ TFamilySetPerson }

procedure TFamilySetPerson.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LCommandText: string;
  LQuery: TEFDBQuery;
begin
  inherited;
  if (AField.Name = 'CreatorPerson') then
    begin
    if AField.IsNull then
      // Clear the person data
      begin
        AField.ParentRecord.FieldByName('Description').Value := Null;
        AField.ParentRecord.FieldByName('CreatorLastName').Value := Null;
        AField.ParentRecord.FieldByName('CreatorFirstName').Value := Null;
      end
    else
      // Read the tax code of the person
      begin
        try
          LQuery := TKConfig.Database.CreateDBQuery;

          LCommandText := 'SELECT CODFISC FROM NOMINATIVI '+
                          'WHERE NOMINATIVI.ID = :ID';

          LQuery.CommandText := LCommandText;
          try
            LQuery.Params.ParamByName('ID').AsString := AField.ParentRecord.FieldByName('CreatorPersonId').AsString;
            LQuery.Open;
            if not LQuery.DataSet.IsEmpty then
              AField.ParentRecord.FieldByName('Description').Value := LQuery.DataSet.FieldByName('CODFISC').AsString;
          finally
            LQuery.Close;
          end;
        finally
          FreeAndNil(LQuery);
        end;
      end;
    end;
end;

initialization
TKRuleImplRegistry.Instance.RegisterClass(TFamilySetPerson.GetClassId, TFamilySetPerson);

finalization
TKRuleImplRegistry.Instance.UnregisterClass(TFamilySetPerson.GetClassId);

end.
