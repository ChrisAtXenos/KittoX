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
///  What a detail row knows about the master it belongs to, while that master
///  has not been saved yet: the reference to it is rendered by the caption of a
///  row no select can find, so those values have to come from the master record
///  in memory. They are not only displayed -- a rule may compute a stored
///  column out of them.
///
///  These tests need no database: everything they assert happens between the
///  metadata and the in-memory store.
///
///  NOT IN THE TEST PROJECT YET, and it should not be added until building a
///  store outside a running application works. TKViewTableStore.SetupFields
///  asks every field IsAccessGranted, and TKMetadata.IsAccessGranted reads
///  TKAccessController.Current and TKAuthenticator.Current, which only
///  TKWebApplication ever assigns: with both nil, creating any store is an
///  access violation, and installing a TKNullAuthenticator by hand raises one
///  of its own. The framework needs a supported way to bring up a headless
///  pair first. Everything else here is finished.
/// </summary>
unit Kitto.MasterDetailTests;

interface

uses
  DUnitX.TestFramework,
  Kitto.Config,
  Kitto.Metadata.DataView;

type
  [TestFixture]
  TKMasterDetailTests = class
  strict private
    FMasterStore: TKViewTableStore;
    FAuthenticator: TObject;
    FAccessController: TObject;
    /// <summary>The Home directory of an application in this working copy, by
    /// its path relative to the repository root, or '' when it is not there.
    /// </summary>
    function HomeOf(const ARelativePath: string): string;
    /// <summary>Points the configuration at that Home and returns it, or nil.
    /// </summary>
    function OpenConfigOf(const ARelativePath: string): TKConfig;
    /// <summary>
    ///  Builds a master record in memory for the named view and returns the
    ///  detail store at AIndex, with its MasterRecord wired. AMasterValues is
    ///  applied to the master record first, as "Field=Value" pairs.
    ///  Returns nil when the application is not in this working copy.
    /// </summary>
    function BuildPendingMaster(const ARelativeHome, AViewName: string;
      const AIndex: Integer; const AMasterValues: array of string): TKViewTableStore;
    /// <summary>Appends a detail row the way the save handler does: append,
    /// then read the view table's default values, which is what runs
    /// InternalAfterReadFromNode.</summary>
    function AppendDetail(const AStore: TKViewTableStore): TKViewTableRecord;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///  The master's key reaches the detail's foreign key. This has always
    ///  worked; it is here because the caption test below would also pass if
    ///  the two records were not related at all.
    /// </summary>
    [Test]
    procedure MasterKeyReachesTheDetailForeignKey;

    /// <summary>
    ///  The detail shows the master's caption, taken from the master record in
    ///  memory. Before the fix this was empty until the master was saved.
    /// </summary>
    [Test]
    procedure DetailOfAPendingMasterShowsTheMasterCaption;

    /// <summary>
    ///  Renaming the master afterwards is reflected: the value is refreshed
    ///  whenever it is asked for, not copied once when the row is added.
    /// </summary>
    [Test]
    procedure TheCaptionFollowsALaterChangeOfTheMaster;

    /// <summary>
    ///  Only the reference that IS the link to the master is filled from the
    ///  master. A detail's other references still resolve the ordinary way, and
    ///  must not be given the master's caption -- HelloKitto's Invitation has
    ///  two references, Party (the master) and Invitee (a Girl).
    /// </summary>
    [Test]
    procedure OtherReferencesAreLeftAlone;

    /// <summary>
    ///  The derived values the reference declares through AutoAddFields come
    ///  from the master too, not only its caption. Needs an application that
    ///  declares them on the reference back to its own master: KittoSCM's
    ///  MembershipFee does, no example application does, so this is SKIPPED on
    ///  a working copy without it.
    /// </summary>
    [Test]
    procedure DerivedValuesOfTheMasterReferenceComeFromTheMaster;
  end;

implementation

uses
  System.SysUtils
  , System.IOUtils
  , System.StrUtils
  , EF.Tree
  , Kitto.Metadata.Views
  , Kitto.Store
  , Kitto.Auth
  , Kitto.AccessControl
  , Kitto.TestUtils
  ;

{ TKMasterDetailTests }

procedure TKMasterDetailTests.Setup;
begin
  FMasterStore := nil;
  FAuthenticator := nil;
  FAccessController := nil;
end;

procedure TKMasterDetailTests.TearDown;
begin
  FreeAndNil(FMasterStore);
  TKAuthenticator.Current := nil;
  TKAccessController.Current := nil;
  FreeAndNil(FAuthenticator);
  FreeAndNil(FAccessController);
  // The configuration is a process-wide singleton keyed on the home path, so it
  // goes before the next case points it somewhere else.
  TKConfig.DestroyInstance;
end;

function TKMasterDetailTests.HomeOf(const ARelativePath: string): string;
var
  LPath: string;
begin
  // Test\Data\..\..\<relative path>
  LPath := TPath.GetFullPath(TPath.Combine(TKTestUtils.DataPath,
    '..' + PathDelim + '..' + PathDelim + ReplaceStr(ARelativePath, '/', PathDelim)));
  // The default Metadata\Config.yaml, and not just the Metadata directory: an
  // application can carry per-tenant configurations named Config_<name>.yaml
  // and no default one — KittoSCM does — so the directory is there and there is
  // nothing to open. Checking only the directory, the case that should have
  // skipped went on instead and died later on 'Node Databases/Main/Connection
  // not found', and only when the fixture that ran before it happened to leave
  // a different application's configuration live: a test passing by accident of
  // execution order.
  if TFile.Exists(TPath.Combine(TPath.Combine(LPath, 'Metadata'), 'Config.yaml')) then
    Result := IncludeTrailingPathDelimiter(LPath)
  else
    Result := '';
end;

function TKMasterDetailTests.OpenConfigOf(const ARelativePath: string): TKConfig;
var
  LHome: string;
begin
  LHome := HomeOf(ARelativePath);
  if LHome = '' then
    Exit(nil);
  TKConfig.AppHomePath := LHome;
  TKConfig.DestroyInstance;
  Result := TKConfig.Instance;
end;

function TKMasterDetailTests.BuildPendingMaster(const ARelativeHome,
  AViewName: string; const AIndex: Integer;
  const AMasterValues: array of string): TKViewTableStore;
var
  LConfig: TKConfig;
  LView: TKView;
  LMasterTable: TKViewTable;
  LMasterRecord: TKViewTableRecord;
  LDefaults: TEFNode;
  LPair: TArray<string>;
  LField: TKViewTableField;
  LStep: string;
  I: Integer;
begin
  Result := nil;
  LStep := 'OpenConfigOf';
  try
  LConfig := OpenConfigOf(ARelativeHome);
  if not Assigned(LConfig) then
    Exit;

  // A store cannot be built without these two, and they have to be installed
  // after the configuration is open. TKViewTableStore.SetupFields asks every
  // field IsAccessGranted, and TKMetadata.IsAccessGranted goes straight through
  // TKAccessController.Current and TKAuthenticator.Current: outside a running
  // application both are nil and creating any store is an access violation.
  // The null pair grants everything and needs no session -- the base
  // TKAuthenticator.GetUserName answers the constant 'PUBLIC'.
  LStep := 'install null authenticator';
  FAuthenticator := TKNullAuthenticator.Create;
  TKAuthenticator.Current := TKNullAuthenticator(FAuthenticator);
  LStep := 'install null access controller';
  FAccessController := TKNullAccessController.Create;
  TKAccessController.Current := TKNullAccessController(FAccessController);

  LStep := 'FindView';
  LView := LConfig.Views.FindView(AViewName);
  if not Assigned(LView) or not (LView is TKDataView) then
    Exit;
  LMasterTable := TKDataView(LView).MainTable;
  if not Assigned(LMasterTable) or (LMasterTable.DetailTableCount <= AIndex) then
    Exit;

  LStep := 'CreateStore';
  FMasterStore := LMasterTable.CreateStore;
  LStep := 'AppendAndInitialize (master)';
  LMasterRecord := FMasterStore.Records.AppendAndInitialize;
  LStep := 'GetDefaultValues (master)';
  LDefaults := LMasterTable.GetDefaultValues;
  try
    LStep := 'ReadFromNode (master)';
    LMasterRecord.ReadFromNode(LDefaults);
  finally
    FreeAndNil(LDefaults);
  end;
  LMasterRecord.MarkAsNew;

  // The values the user would have typed. They reach the record through the
  // notify cycle in a running application; here they are simply set.
  for I := Low(AMasterValues) to High(AMasterValues) do
  begin
    LPair := AMasterValues[I].Split(['=']);
    Assert.IsTrue(Length(LPair) = 2,
      'Test data must be "Field=Value": ' + AMasterValues[I]);
    LField := LMasterRecord.FindField(LPair[0]);
    Assert.IsNotNull(LField, Format('%s has no field %s', [AViewName, LPair[0]]));
    LField.AsString := LPair[1];
  end;

  LStep := 'EnsureDetailStores';
  LMasterRecord.EnsureDetailStores;
  Assert.IsTrue(LMasterRecord.DetailStoreCount > AIndex,
    Format('%s has no detail store %d', [AViewName, AIndex]));
  LStep := 'DetailStores[AIndex]';
  Result := TKViewTableStore(LMasterRecord.DetailStores[AIndex]);
  Result.MasterRecord := LMasterRecord;
  except
    on E: Exception do
      Assert.Fail(Format('%s raised %s at step "%s": %s',
        [AViewName, E.ClassName, LStep, E.Message]));
  end;
end;

function TKMasterDetailTests.AppendDetail(
  const AStore: TKViewTableStore): TKViewTableRecord;
var
  LDefaults: TEFNode;
begin
  // The same two steps HandleDetailSave takes. AppendAndInitialize alone does
  // not go through ReadFromNode, and it is ReadFromNode that runs
  // InternalAfterReadFromNode -- where the master's values are propagated.
  Result := AStore.Records.AppendAndInitialize;
  LDefaults := AStore.ViewTable.GetDefaultValues;
  try
    Result.ReadFromNode(LDefaults);
  finally
    FreeAndNil(LDefaults);
  end;
  Result.MarkAsNew;
end;

procedure TKMasterDetailTests.MasterKeyReachesTheDetailForeignKey;
var
  LDetailStore: TKViewTableStore;
  LDetail: TKViewTableRecord;
begin
  LDetailStore := BuildPendingMaster('Examples/HelloKitto/Home', 'Parties', 0,
    ['Party_Name=Festa di prova']);
  if not Assigned(LDetailStore) then
    Assert.Pass('SKIPPED: HelloKitto is not in this working copy.');

  LDetail := AppendDetail(LDetailStore);

  Assert.AreEqual(LDetailStore.MasterRecord.FieldByName('Party_Id').AsString,
    LDetail.FieldByName('Party_Id').AsString, False,
    'The detail''s foreign key must hold the master''s key.');
  Assert.IsFalse(LDetail.FieldByName('Party_Id').AsString = '',
    'The foreign key must not be empty.');
end;

procedure TKMasterDetailTests.DetailOfAPendingMasterShowsTheMasterCaption;
var
  LDetailStore: TKViewTableStore;
  LDetail: TKViewTableRecord;
begin
  LDetailStore := BuildPendingMaster('Examples/HelloKitto/Home', 'Parties', 0,
    ['Party_Name=Festa di prova']);
  if not Assigned(LDetailStore) then
    Assert.Pass('SKIPPED: HelloKitto is not in this working copy.');

  LDetail := AppendDetail(LDetailStore);

  // Party_Name is Party's caption field: the first visible non-key field, since
  // the model declares no CaptionField of its own.
  Assert.AreEqual('Festa di prova', LDetail.FieldByName('Party').AsString, False,
    'The detail must show the caption of the master it belongs to, even though '
    + 'that master has no row in the database yet.');
end;

procedure TKMasterDetailTests.TheCaptionFollowsALaterChangeOfTheMaster;
var
  LDetailStore: TKViewTableStore;
  LDetail: TKViewTableRecord;
begin
  LDetailStore := BuildPendingMaster('Examples/HelloKitto/Home', 'Parties', 0,
    ['Party_Name=Festa di prova']);
  if not Assigned(LDetailStore) then
    Assert.Pass('SKIPPED: HelloKitto is not in this working copy.');

  LDetail := AppendDetail(LDetailStore);
  Assert.AreEqual('Festa di prova', LDetail.FieldByName('Party').AsString);

  // The user goes back to the master and renames it.
  LDetailStore.MasterRecord.FieldByName('Party_Name').AsString := 'Compleanno di Louise';
  LDetail.RefreshMasterReferenceValues;

  Assert.AreEqual('Compleanno di Louise', LDetail.FieldByName('Party').AsString, False,
    'Asking again must give the master''s current caption, not the one it had '
    + 'when the row was added.');
end;

procedure TKMasterDetailTests.OtherReferencesAreLeftAlone;
var
  LDetailStore: TKViewTableStore;
  LDetail: TKViewTableRecord;
begin
  LDetailStore := BuildPendingMaster('Examples/HelloKitto/Home', 'Parties', 0,
    ['Party_Name=Festa di prova']);
  if not Assigned(LDetailStore) then
    Assert.Pass('SKIPPED: HelloKitto is not in this working copy.');

  LDetail := AppendDetail(LDetailStore);

  // Invitee points at a Girl, not at the master. Nothing may put the master's
  // caption there: it is resolved from the database like any other reference.
  Assert.IsTrue(LDetail.FieldByName('Invitee').IsNull
    or (LDetail.FieldByName('Invitee').AsString = ''),
    'A reference that is not the link to the master must be left untouched, '
    + 'and it came out holding "' + LDetail.FieldByName('Invitee').AsString + '".');
end;

procedure TKMasterDetailTests.DerivedValuesOfTheMasterReferenceComeFromTheMaster;
var
  LDetailStore: TKViewTableStore;
  LDetail: TKViewTableRecord;
  LField: TKViewTableField;
begin
  LDetailStore := BuildPendingMaster('MyProjects/KittoSCM/Home',
    'ADMIN_MembersRegister', 0, ['LastName=Rossi', 'FirstName=Mario']);
  if not Assigned(LDetailStore) then
    Assert.Pass('SKIPPED: KittoSCM is not in this working copy.');

  LDetail := AppendDetail(LDetailStore);

  // MembershipFee's reference back to MembersRegister declares
  //   AutoAddFields: LastName -> MembersRegister_LastName
  //                  FirstName -> MembersRegister_FirstName
  // and those two feed the CalcDescription rule that fills the stored
  // Description column.
  LField := LDetail.FindField('MembersRegister_LastName');
  Assert.IsNotNull(LField, 'MembersRegister_LastName is not in the detail store; '
    + 'the AutoAddFields of the master reference did not become view fields.');
  Assert.AreEqual('Rossi', LField.AsString, False,
    'A derived value of the master reference must come from the master record '
    + 'in memory. This is the assertion that catches guarding on HasModelField, '
    + 'which answers for the detail''s own model and so skips every one of them.');

  LField := LDetail.FindField('MembersRegister_FirstName');
  Assert.IsNotNull(LField, 'MembersRegister_FirstName is not in the detail store.');
  Assert.AreEqual('Mario', LField.AsString);
end;

initialization
  TDUnitX.RegisterTestFixture(TKMasterDetailTests);

end.
