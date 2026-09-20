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

unit Kitto.DbUtils;

interface

uses
  Data.DB,
  KItto.Store,
  Kitto.Metadata.Models,
  EF.Tree;

const
  PROGRESS_STR = 'Progressivo per';

/// <summary>Computes the next progressive code, incrementing IdProgress padded to CharSize digits.</summary>
function CalcNewProgress(const IdProgress: string; CharSize: integer): string;
/// <summary>
///  Builds a SQL statement that counts rows in ATableName where AFieldName equals
///  AFieldValue, optionally excluding the row whose key equals AIdToExclude.
///  Used for uniqueness checks.
/// </summary>
function GetSQLCountValue(const ATableName, AFieldName, AFieldValue: string;
  const AIdToExclude: string = ''): string;
/// <summary>Builds a SQL statement that reads AFieldName from ATableName for the given key value.</summary>
function GetSQLFieldValue(const ATableName, AFieldName, AKeyFieldName, AKeyFieldValue: string): string;
/// <summary>Returns the database table name of the model that owns the given store field.</summary>
function GetTableName(const AField: TKField): string;
/// <summary>Returns the physical (database) column name for the given store field.</summary>
function GetPhysicalName(const AField: TKField): string;
/// <summary>Returns the model that owns the given store field.</summary>
function ModelByField(const AField: TKField): TKModel;
/// <summary>Returns the model that owns the given store record.</summary>
function ModelByRecord(const ARecord: TKRecord): TKModel;
/// <summary>Returns the model field corresponding to the given store field.</summary>
function ModelFieldByField(const AField: TKField): TKModelField;
/// <summary>Returns True if a model field can be resolved for the given store field.</summary>
function ModelFindField(const AField: TKField): boolean;
/// <summary>Builds a SQL DELETE statement for ATableName matching the given key field/value.</summary>
function GetSQLDeleteStatement(const ATableName, AKeyFieldName, AFieldValue: string): string;
/// <summary>Executes a DELETE on ATableName for the row whose key field matches AFieldValue.</summary>
procedure DeleteRecord(const ATableName, AKeyFieldName, AFieldValue: string);
/// <summary>Sets the value of the named parameter in AParams, handling Null/Variant conversion.</summary>
procedure UpdateParamValue(AParams: TParams; const AParamName: string; AValue: Variant);
/// <summary>Validates password strength; raises an exception if the password is too weak.</summary>
procedure CheckPasswordStrength(const APassword: string);

implementation

uses
  System.RegularExpressions,
  System.SysUtils,
  System.Variants,
  EF.Localization,
  Kitto.Metadata.DataView,
  EF.DB,
  Kitto.Config,
  Kitto.Auth.DB,
  Kitto.Rules,
  EF.StrUtils;

procedure UpdateParamValue(AParams: TParams; const AParamName: string; AValue: Variant);
var
  LParam: TParam;
begin
  LParam := AParams.FindParam(AParamName);
  if not Assigned(LParam) then
    Exit;

  // Fallback DataType for untyped values (Null/Unassigned/empty): the MS ODBC
  // Driver 17/18 no longer infers it through SQLDescribeParam the way Native
  // Client 11 did, so an untyped Null/empty param would otherwise fail.
  if VarIsNull(AValue) or VarIsEmpty(AValue) or
     (VarIsStr(AValue) and (AValue = '')) then
  begin
    LParam.DataType := ftWideString;
    LParam.Value := Null;
  end
  else
    LParam.Value := AValue;
end;

function ModelByField(const AField: TKField): TKModel;
begin
  Result := (AField.ParentRecord as TKViewTableRecord).ViewTable.Model;
end;

function ModelByRecord(const ARecord: TKRecord): TKModel;
begin
  Result := (ARecord as TKViewTableRecord).ViewTable.Model;
end;

function ModelFieldByField(const AField: TKField): TKModelField;
begin
  Result := (AField.ParentRecord as TKViewTableRecord).ViewTable.Model.FindField(AField.FieldName);
end;

function ModelFindField(const AField: TKField): boolean;
begin
  Result := (AField.ParentRecord as TKViewTableRecord).ViewTable.Model.FindField(AField.FieldName) <> nil;
end;

function GetTableName(const AField: TKField): string;
begin
  Result := ModelByField(AField).PhysicalName;
end;

function GetPhysicalName(const AField: TKField): string;
var
  LModelField: TKModelField;
begin
  LModelField := ModelByField(AField).FindField(AField.FieldName);
  if Assigned(LModelField) then
    Result := LModelField.PhysicalName
  else
    Result := '';
end;

// The values these helpers embed in a SQL string literal come from record
// fields, i.e. from the user. They were concatenated raw, so a value carrying a
// single quote broke out of the literal (SQL injection). These functions return
// a SQL string the caller then executes, so the value cannot be a parameter
// here; the standard escape -- doubling the single quote -- is applied instead.
// The table/field identifiers are the caller's own constants and are left as
// they are (they must be trusted, not client input).
function SQLQuote(const AValue: string): string;
begin
  Result := StringReplace(AValue, '''', '''''', [rfReplaceAll]);
end;

function GetSQLCountValue(const ATableName, AFieldName, AFieldValue: string;
  const AIdToExclude: string = ''): string;
begin
  if AIdToExclude <> '' then
    Result := Format('SELECT COUNT(*) TOT FROM %s WHERE Id <> ''%s'' and %s = ''%s''',
      [ATableName, SQLQuote(AIdToExclude), AFieldName, SQLQuote(AFieldValue)])
  else
    Result := Format('SELECT COUNT(*) TOT FROM %s WHERE %s = ''%s''',
      [ATableName, AFieldName, SQLQuote(AFieldValue)]);
end;

function GetSQLDeleteStatement(const ATableName, AKeyFieldName, AFieldValue: string): string;
begin
  Result := Format('DELETE FROM %s WHERE %s = ''%s''',
    [ATableName, AKeyFieldName, SQLQuote(AFieldValue)]);
end;

function GetSQLFieldValue(const ATableName, AFieldName, AKeyFieldName, AKeyFieldValue: string): string;
begin
    Result := Format('SELECT %s TOT FROM %s WHERE %s = ''%s''',
      [AFieldName, ATableName, AKeyFieldName, SQLQuote(AKeyFieldValue)]);
end;

function CalcNewProgress(const IdProgress: string;
      CharSize: integer): string;
var
  LQueryText: string;
  LQuery: TEFDBQuery;
  LCommandText: string;
  LCommand: TEFDBCommand;
  GeneratedId : integer;
  LNumRec: integer;
  LWasInTransaction: Boolean;
begin

  LQueryText := 'SELECT COUNT(*) REC_NUMBER FROM IDGENERATOR WHERE ID = :Id';
  LQuery := TKConfig.Database.CreateDBQuery;
  Try
    LQuery.CommandText := LQueryText;
    LQuery.Params.ParamByName('Id').AsString := UpperCase(IdProgress);
    LQuery.Open;
    LNumRec := LQuery.DataSet.Fields[0].AsInteger;
    LQuery.Close;

    LCommand := TKConfig.Database.CreateDBCommand;
    Try
      LWasInTransaction := LCommand.Connection.IsInTransaction;

      if not LWasInTransaction then
        LCommand.Connection.StartTransaction;
      try
        if LNumRec = 0 then
        begin
          LCommandText := 'INSERT INTO IDGENERATOR '+
                          '(CLASS, ID, UPDATECOUNT, DX, UPDTIMESTAMP, GENERATEDID, CHARSNUM) '+
                          'VALUES '+
                          '(''TISIdGenerator'', :Id, 1, :DX, CURRENT_TIMESTAMP, :GENERATEDID, :CHARSNUM)';

          LCommand.CommandText := LCommandText;
          GeneratedId := 1;
          UpdateParamValue(LCommand.Params,'DX', PROGRESS_STR+' '+UpperCase(IdProgress));
          UpdateParamValue(LCommand.Params,'CHARSNUM', CharSize);
        end
        else
        begin
          LQueryText := 'SELECT GENERATEDID FROM IDGENERATOR WHERE ID = :Id';
          LCommandText := 'UPDATE IDGENERATOR SET GENERATEDID = :GENERATEDID WHERE ID = :Id';
          LCommand.CommandText := LCommandText;
          LQuery.Close;
          LQuery.CommandText := LQueryText;

          LQuery.Params.ParamByName('Id').AsString := UpperCase(IdProgress);

          LQuery.Open;
          GeneratedId := LQuery.DataSet.Fields[0].AsInteger;
        end;

        LQuery.Close;
        UpdateParamValue(LCommand.Params,'Id', UpperCase(IdProgress));
        UpdateParamValue(LCommand.Params,'GENERATEDID', GeneratedId+1);
        LCommand.Execute;

        if CharSize <> 0 then
          Result := PadLeft(IntToStr(GeneratedId),CharSize,'0')
        else
          Result := IntToStr(GeneratedId);

        if not LWasInTransaction then
          LCommand.Connection.CommitTransaction;
      except
        if not LWasInTransaction then
          LCommand.Connection.RollbackTransaction;

        raise;
      end;


    Finally
      FreeAndNil(LCommand);
    End;

  Finally
    FreeAndNil(LQuery);
  End;
end;

procedure DeleteRecord(const ATableName, AKeyFieldName, AFieldValue: string);
var
  LCommand: TEFDbCommand;
  LWasInTransaction: Boolean;
begin
  LCommand := TKConfig.Database.CreateDBCommand;
  try
    // Do not open a transaction if one is already running (rules run inside the
    // master save): otherwise the inner rollback below would tear down the
    // enclosing unit of work. Same guard as CalcNewProgress.
    LWasInTransaction := LCommand.Connection.IsInTransaction;
    try
      if not LWasInTransaction then
        LCommand.Connection.StartTransaction;
      LCommand.CommandText := GetSQLDeleteStatement(ATableName, AKeyFieldName, AFieldValue);
      LCommand.Execute;
      if not LWasInTransaction then
        LCommand.Connection.CommitTransaction;
    except
      // RE-RAISE: swallowing the error made a failed DELETE (FK constraint,
      // deadlock, offline DB) look like success, so a cascade-delete rule went
      // on believing the child rows were gone.
      if not LWasInTransaction then
        LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

procedure CheckPasswordStrength(const APassword: string);
var
  LValidatePasswordNode: TEFNode;
  LErrorMsg, LRegEx: string;
  LRegularExpression : TRegEx;
  LMatch: TMatch;
begin
  // Example of enforcement of password strength rules.
  // The node belongs to the authenticator, so it must not be looked up by the
  // absolute path 'Auth/ValidatePassword': under Auth: JWT the authenticator's
  // own options live under Auth/Inner, and EffectiveConfigNode returns the right
  // node either way.
  LValidatePasswordNode := TKConfig.Instance.Authenticator.EffectiveConfigNode
    .FindNode('ValidatePassword');
  Assert(Assigned(LValidatePasswordNode), 'Assigned(LValidatePasswordNode)');
  LErrorMsg := LValidatePasswordNode.GetExpandedString('Message',
    _('Min. 8 characters with letters and digits'));
  LRegEx := LValidatePasswordNode.GetExpandedString('RegEx','^[ -~]{8,63}$');
  LRegularExpression.Create(LRegEx);
  LMatch := LRegularExpression.Match(APassword);
  if not LMatch.Success then
    raise EKValidationError.CreateWithAdditionalInfo(LErrorMsg, _('Password validation'));
end;

end.
