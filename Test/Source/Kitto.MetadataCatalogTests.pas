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
///  Loads the whole metadata catalogue of the example applications, models and
///  views, exactly as KIDE does when it opens a project and as an application
///  does on its first request.
///
///  This exists because of a regression that nothing else here could have
///  caught. Review finding 29 made TKDataView build its containers at load
///  time, and one of the accessors it called did more than build a container:
///  for a view whose MainTable has no model -- a dashboard -- it went on to
///  build the default fields from that model and raised on an empty model
///  name, so no project could be opened at all. The suite had no test that
///  ever loaded a catalogue, so the compiler was the only net, and it does not
///  catch that.
/// </summary>
unit Kitto.MetadataCatalogTests;

interface

uses
  DUnitX.TestFramework,
  Kitto.Config,
  Kitto.Metadata.Models,
  Kitto.Metadata.DataView,
  Kitto.Auth,
  Kitto.AccessControl;

type
  [TestFixture]
  TKMetadataCatalogTests = class
  strict private
    FProbeAuth: TKAuthenticator;
    FProbeAC: TKAccessController;
    /// <summary>The Home directory of the named example, or '' when it is not
    /// in this working copy.</summary>
    function ExampleHome(const AName: string): string;
    /// <summary>Opens every model and every view of the named example. Calls
    /// Assert.Pass with a SKIPPED message when the example is not there.</summary>
    procedure LoadCatalogueOf(const AExampleName: string);
    /// <summary>Points the configuration at the named example and returns it,
    /// or nil when the example is not in this working copy.</summary>
    function OpenConfigOf(const AExampleName: string): TKConfig;
  public
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///  Every view of the example loads. A view is only read from disk when
    ///  something asks for it, so the test walks the whole index: that is what
    ///  KIDE's project tree does, and it is the path the regression broke.
    /// </summary>
    [Test]
    [TestCase('TasKitto', 'TasKitto')]
    [TestCase('HelloKitto', 'HelloKitto')]
    [TestCase('KEmployee', 'KEmployee')]
    [TestCase('SportClubManager', 'SportClubManager')]
    procedure EveryObjectOfTheCatalogueLoads(const AExampleName: string);

    /// <summary>
    ///  Every model field must report a decimal precision that a Byte can hold,
    ///  because TKField.GetAsJSONValue puts it straight into
    ///  TFormatSettings.CurrencyDecimals, which is one.
    ///
    ///  A reference field used to report -1: GetFieldSpec sets that as a
    ///  'not applicable' sentinel, and the guard below it caught only the 0 a
    ///  plain field gets when its spec does not say. Rendering any list or form
    ///  containing a reference then raised a range error on that assignment.
    ///  It stayed hidden for as long as {$R} was forced off in Debug builds --
    ///  which EF.Defines.inc did until the first correction of this review --
    ///  and in Release the -1 is stored as 255, so 255 decimal digits are asked
    ///  for and nothing says a word.
    ///
    ///  The check is on the models rather than on the views: that is where the
    ///  sentinel comes from, and it needs no view-to-model resolution, which in
    ///  KEmployee raises on its own account (a view field named Proj whose
    ///  model field does not exist -- unrelated to this, and reported).
    /// </summary>
    [Test]
    [TestCase('TasKitto', 'TasKitto')]
    [TestCase('HelloKitto', 'HelloKitto')]
    [TestCase('KEmployee', 'KEmployee')]
    [TestCase('SportClubManager', 'SportClubManager')]
    procedure EveryModelFieldHasAUsableDecimalPrecision(const AExampleName: string);

    /// <summary>
    ///  Reading any property of any view of the catalogue must not raise.
    ///
    ///  This walks the published properties by RTTI, which is what the tree
    ///  validator and the KIDE/MCP tooling do, and what the render path ends up
    ///  doing one accessor at a time. It exists because of a whole family of
    ///  defects it would have caught at once: a data view with no Model -- a
    ///  dashboard, a chart, a tool panel, which declare Type: Data for the
    ///  controller's sake and never a MainTable -- had EIGHT properties of its
    ///  MainTable falling through to the model regardless (IsReadOnly,
    ///  PreventAdding/Editing/Deleting, IsLarge, DefaultSorting, DatabaseName
    ///  and the label/image ones), each asking the catalogue for the object
    ///  named '' and raising 'Object  not found.'; and ModelDetailReference
    ///  dereferenced the master table that a MainTable does not have, giving an
    ///  access violation. Loading the catalogue exercises none of this, so
    ///  EveryObjectOfTheCatalogueLoads stayed green throughout.
    ///
    ///  Two groups are skipped, both deliberately:
    ///   - Model, which raises BY CONTRACT when the table declares none, so
    ///     that a caller assuming a table hears about it. FindModel is the
    ///     accessor for callers to which having none is a legitimate outcome.
    ///   - every As* property, which are TEFNode's value conversions. A view
    ///     table IS a node, and one that carries children rather than a value,
    ///     so reading it as a time or an object is a type error wherever it
    ///     happens and says nothing about views.
    /// </summary>
    [Test]
    [TestCase('TasKitto', 'TasKitto')]
    [TestCase('HelloKitto', 'HelloKitto')]
    [TestCase('KEmployee', 'KEmployee')]
    [TestCase('SportClubManager', 'SportClubManager')]
    procedure NoPropertyOfAnyViewRaises(const AExampleName: string);

    /// <summary>
    ///  The access check on a view table that declares no model asks only the
    ///  table's own resource URI.
    ///
    ///  This is the call that put 'declares no Model' on screen at every login:
    ///  IsAccessGranted tested a SECOND gate, the model's URI, unconditionally,
    ///  and the home page checks access on every view it opens. It is a method,
    ///  not a property, so NoPropertyOfAnyViewRaises cannot see it.
    ///
    ///  It runs on the catalogue's own Dashboard rather than on a view built
    ///  here, because GetACURI resolves through the view's catalogue. The null
    ///  authenticator and access controller are the pair a check needs outside a
    ///  running application: the base TKAuthenticator.GetUserName answers the
    ///  constant 'PUBLIC' and the null controller grants everything.
    /// </summary>
    [Test]
    procedure IsAccessGranted_OnAViewTableWithNoModel_DoesNotRaise;

  end;

  /// <summary>
  ///  Tests for asking a model for a key field it does not have.
  ///
  ///  The index does not come from a contract between callers: it is the
  ///  position of a subfield of a reference field, so a reference declaring one
  ///  subfield more than the referenced model has key fields lands there. It
  ///  used to be checked with an Assert, which means that in Release -- where
  ///  assertions are compiled out -- the read went past the end of the array
  ///  and the field name looked up was whatever happened to be in memory.
  ///  Three places pass such an index: TKModelField.GetActualDataType, GetSize
  ///  and GetDecimalPrecision, so it is on the path of every field of every
  ///  grid.
  ///
  ///  The other shape -- KeyFields[0] on a model with no primary key at all --
  ///  was already reported properly, by GetKeyFieldNames. That guard is pinned
  ///  below, because it is what makes those call sites safe without one of
  ///  their own.
  /// </summary>
  /// <summary>
  ///  A data view whose MainTable declares no Model.
  ///
  ///  It is a legitimate shape, and a common one: a dashboard, a chart or a
  ///  tool panel says Type: Data so that the controller is a data controller,
  ///  and never declares a MainTable. Asking such a table for its fields used
  ///  to build the default ones from the model, which meant asking the
  ///  catalogue for the object named '' -- and that raised
  ///  'Object  not found.', an error naming nothing, in the middle of
  ///  rendering. It is what a TasKitto login landed on: the Dashboard is among
  ///  the SubViews the home TabPanel opens.
  ///
  ///  Loading the catalogue does not exercise this -- TKDataView.AfterLoad
  ///  avoids the Fields accessor on purpose -- so
  ///  EveryObjectOfTheCatalogueLoads passes either way. Only asking for the
  ///  fields does.
  /// </summary>
  [TestFixture]
  TKViewTableWithoutModelTests = class
  strict private
    /// <summary>A data view named AName built from AYaml. The caller frees it.
    /// </summary>
    function DataViewFromYaml(const AName, AYaml: string): TKDataView;
  public
    /// <summary>Its MainTable reports no fields, instead of raising.</summary>
    [Test]
    procedure Fields_OnATableWithNoModel_IsEmpty;

    /// <summary>And asking it for the model outright says which table and
    /// which view are missing it, rather than reporting an object with an
    /// empty name.</summary>
    [Test]
    procedure Model_OnATableWithNoModel_RaisesNamingTheViewTable;

    /// <summary>FindModel is the accessor for callers that may legitimately
    /// have no model: nil, no exception.</summary>
    [Test]
    procedure FindModel_OnATableWithNoModel_IsNil;

    /// <summary>
    ///  The decorations of a table with no model degrade to nothing instead of
    ///  raising. They are property getters, and since r479 two of them are
    ///  reachable through RTTI as well (YamlContainer on FieldList /
    ///  DetailTableList), so anything walking the metadata -- the tree
    ///  validator, the KIDE and MCP tooling -- evaluates them. A getter that
    ///  raises on a legitimate shape takes down whatever is walking.
    /// </summary>
    [Test]
    procedure Decorations_OnATableWithNoModel_AreEmpty;

    /// <summary>And the VIEW keeps its own label and image, which is where a
    /// dashboard declares them.</summary>
    [Test]
    procedure TheViewKeepsItsOwnLabelAndImage;

  end;

  [TestFixture]
  TKModelKeyFieldTests = class
  strict private
    /// <summary>A model named AName, built from AYaml. The caller frees it.
    /// The name matters: TKModel.ModelName is its PersistentName, which the
    /// catalogue sets from the file name and nothing else does.</summary>
    function ModelFromYaml(const AName, AYaml: string): TKModel;
  public
    [Test]
    procedure KeyFields_ReturnsTheKeyFieldsInOrder;
    /// <summary>
    ///  Asking beyond the last key field says which model, how many keys it
    ///  has and which one was asked for -- enough to find the YAML at fault.
    /// </summary>
    [Test]
    procedure KeyFields_PastTheLastOne_RaisesNamingTheModel;
    [Test]
    procedure KeyFields_WithANegativeIndex_Raises;
    /// <summary>
    ///  A model with no primary key is reported by GetKeyFieldNames, and has
    ///  been all along. Pinned here so that the check above is not mistaken
    ///  for the one that covers this.
    /// </summary>
    [Test]
    procedure KeyFieldCount_OnAModelWithNoKey_Raises;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Rtti,
  EF.Tree,
  Kitto.Metadata,
  Kitto.Metadata.Views,
  Kitto.Types,
  EF.YAML,
  Kitto.TestUtils;

{ TKMetadataCatalogTests }

function TKMetadataCatalogTests.ExampleHome(const AName: string): string;
var
  LPath: string;
begin
  // Test\Source\..\..\Examples\<name>\Home
  LPath := TPath.GetFullPath(TPath.Combine(TKTestUtils.DataPath,
    '..' + PathDelim + '..' + PathDelim + 'Examples' + PathDelim + AName +
    PathDelim + 'Home'));
  if TDirectory.Exists(TPath.Combine(LPath, 'Metadata')) then
    Result := IncludeTrailingPathDelimiter(LPath)
  else
    Result := '';
end;

procedure TKMetadataCatalogTests.TearDown;
begin
  // The configuration is a process-wide singleton keyed on the home path, so
  // it goes before the next case points it somewhere else.
  TKConfig.DestroyInstance;
end;

function TKMetadataCatalogTests.OpenConfigOf(const AExampleName: string): TKConfig;
var
  LHome: string;
begin
  LHome := ExampleHome(AExampleName);
  if LHome = '' then
    Exit(nil);
  TKConfig.AppHomePath := LHome;
  TKConfig.DestroyInstance;
  Result := TKConfig.Instance;
end;

procedure TKMetadataCatalogTests.LoadCatalogueOf(const AExampleName: string);
var
  LConfig: TKConfig;
  I: Integer;
  LModelCount, LViewCount: Integer;
begin
  LConfig := OpenConfigOf(AExampleName);
  if LConfig = nil then
    Assert.Pass(Format('SKIPPED: %s is not in this working copy.', [AExampleName]));

  // Touching every object is the point: the index is built from the file names
  // and each object is read from disk on first access.
  LModelCount := LConfig.Models.ModelCount;
  for I := 0 to LModelCount - 1 do
    Assert.IsNotNull(LConfig.Models.Models[I],
      Format('%s: model %d did not load.', [AExampleName, I]));

  LViewCount := LConfig.Views.ViewCount;
  for I := 0 to LViewCount - 1 do
    Assert.IsNotNull(LConfig.Views.Views[I],
      Format('%s: view %d did not load.', [AExampleName, I]));

  Assert.IsTrue(LModelCount > 0,
    Format('%s: no models were found, so this proves nothing.', [AExampleName]));
  Assert.IsTrue(LViewCount > 0,
    Format('%s: no views were found, so this proves nothing.', [AExampleName]));
end;

procedure TKMetadataCatalogTests.EveryObjectOfTheCatalogueLoads(
  const AExampleName: string);
begin
  LoadCatalogueOf(AExampleName);
end;

procedure TKMetadataCatalogTests.IsAccessGranted_OnAViewTableWithNoModel_DoesNotRaise;
var
  LConfig: TKConfig;
  LView: TKView;
begin
  LConfig := OpenConfigOf('TasKitto');
  if LConfig = nil then
    Assert.Pass('SKIPPED: TasKitto is not in this working copy.');
  LView := LConfig.Views.FindView('Dashboard');
  if not (LView is TKDataView) then
    Assert.Pass('SKIPPED: TasKitto has no Dashboard data view.');
  Assert.IsFalse(TKDataView(LView).MainTable.HasModelName,
    'The Dashboard is the shape under test: its MainTable must have no model');

  FProbeAuth := TKNullAuthenticator.Create;
  TKAuthenticator.Current := FProbeAuth;
  FProbeAC := TKNullAccessController.Create;
  TKAccessController.Current := FProbeAC;
  try
    Assert.IsTrue(TKDataView(LView).MainTable.IsAccessGranted(ACM_VIEW),
      'The null access controller grants everything');
  finally
    TKAuthenticator.Current := nil;
    TKAccessController.Current := nil;
    FreeAndNil(FProbeAuth);
    FreeAndNil(FProbeAC);
  end;
end;

procedure TKMetadataCatalogTests.NoPropertyOfAnyViewRaises(
  const AExampleName: string);
const
  // See the test's comment: raising here is the documented behaviour.
  SKIPPED_NAME = 'Model';
  SKIPPED_PREFIX = 'As';
var
  LConfig: TKConfig;
  LCtx: TRttiContext;
  LReport: string;
  I: Integer;

  function IsSkipped(const AName: string): Boolean;
  begin
    Result := SameText(AName, SKIPPED_NAME) or AName.StartsWith(SKIPPED_PREFIX);
  end;

  procedure ReadEveryProperty(const ALabel: string; const AObj: TObject);
  var
    LProp: TRttiProperty;
  begin
    if not Assigned(AObj) then
      Exit;
    for LProp in LCtx.GetType(AObj.ClassType).GetProperties do
    begin
      if not LProp.IsReadable or IsSkipped(LProp.Name) then
        Continue;
      try
        LProp.GetValue(AObj);
      except
        on E: Exception do
          LReport := LReport + ALabel + '.' + LProp.Name + ' -> ' +
            E.ClassName + ': ' + E.Message + sLineBreak;
      end;
    end;
  end;

  procedure ReadViewTable(const ALabel: string; const AViewTable: TKViewTable);
  var
    J: Integer;
  begin
    if not Assigned(AViewTable) then
      Exit;
    ReadEveryProperty(ALabel, AViewTable);
    for J := 0 to AViewTable.DetailTableCount - 1 do
      ReadViewTable(ALabel + '.DetailTables[' + IntToStr(J) + ']',
        AViewTable.DetailTables[J]);
  end;

var
  LView: TKView;
begin
  LConfig := OpenConfigOf(AExampleName);
  if LConfig = nil then
    Assert.Pass(Format('SKIPPED: %s is not in this working copy.', [AExampleName]));

  LCtx := TRttiContext.Create;
  try
    for I := 0 to LConfig.Views.ViewCount - 1 do
    begin
      LView := LConfig.Views.Views[I];
      ReadEveryProperty(LView.PersistentName, LView);
      if LView is TKDataView then
        ReadViewTable(LView.PersistentName + '.MainTable',
          TKDataView(LView).MainTable);
    end;
  finally
    LCtx.Free;
  end;
  Assert.AreEqual('', LReport, sLineBreak + LReport);
end;

procedure TKMetadataCatalogTests.EveryModelFieldHasAUsableDecimalPrecision(
  const AExampleName: string);
var
  LConfig: TKConfig;
  LChecked: Integer;

  procedure CheckField(const AField: TKModelField; const AWhere: string);
  var
    I, LPrecision: Integer;
  begin
    LPrecision := AField.DecimalPrecision;
    Assert.IsTrue((LPrecision >= 0) and (LPrecision <= High(Byte)),
      Format('%s, %s: decimal precision %d does not fit the Byte that ' +
        'TFormatSettings.CurrencyDecimals is.',
        [AExampleName, AWhere, LPrecision]));
    Inc(LChecked);
    // A field's own fields are its parts, when it is a multi-part field.
    for I := 0 to AField.FieldCount - 1 do
      CheckField(AField.Fields[I], AWhere + '/' + AField.Fields[I].FieldName);
  end;

var
  I, J: Integer;
  LModel: TKModel;
begin
  LConfig := OpenConfigOf(AExampleName);
  if LConfig = nil then
    Assert.Pass(Format('SKIPPED: %s is not in this working copy.', [AExampleName]));

  LChecked := 0;
  for I := 0 to LConfig.Models.ModelCount - 1 do
  begin
    LModel := LConfig.Models.Models[I];
    for J := 0 to LModel.FieldCount - 1 do
      CheckField(LModel.Fields[J],
        LModel.ModelName + '.' + LModel.Fields[J].FieldName);
  end;
  Assert.IsTrue(LChecked > 0,
    Format('%s: no model field was checked, so this proves nothing.',
      [AExampleName]));
end;

{ TKModelKeyFieldTests }

{ TKViewTableWithoutModelTests }

function TKViewTableWithoutModelTests.DataViewFromYaml(const AName,
  AYaml: string): TKDataView;
begin
  Result := TKDataView.Create;
  try
    Result.PersistentName := AName;
    TEFYAMLReader.ReadTree(Result, AYaml);
  except
    Result.Free;
    raise;
  end;
end;

procedure TKViewTableWithoutModelTests.Fields_OnATableWithNoModel_IsEmpty;
var
  LView: TKDataView;
begin
  // The shape of TasKitto's Dashboard.yaml, cut down to what matters.
  LView := DataViewFromYaml('Dashboard',
    'Type: Data'#13#10 +
    'DisplayLabel: Activity Dashboard'#13#10 +
    'Controller: Dashboard'#13#10 +
    '  MaxColumns: 4'#13#10);
  try
    Assert.AreEqual(0, LView.MainTable.FieldCount,
      'A table with no Model has no fields');
  finally
    LView.Free;
  end;
end;

procedure TKViewTableWithoutModelTests.FindModel_OnATableWithNoModel_IsNil;
var
  LView: TKDataView;
begin
  LView := DataViewFromYaml('Dashboard',
    'Type: Data'#13#10 +
    'Controller: Dashboard'#13#10);
  try
    Assert.IsNull(LView.MainTable.FindModel);
  finally
    LView.Free;
  end;
end;

procedure TKViewTableWithoutModelTests.Decorations_OnATableWithNoModel_AreEmpty;
var
  LView: TKDataView;
begin
  LView := DataViewFromYaml('Dashboard',
    'Type: Data'#13#10 +
    'Controller: Dashboard'#13#10);
  try
    Assert.AreEqual('', LView.MainTable.DisplayLabel, 'DisplayLabel');
    Assert.AreEqual('', LView.MainTable.PluralDisplayLabel, 'PluralDisplayLabel');
    Assert.AreEqual('', LView.MainTable.ImageName, 'ImageName');
  finally
    LView.Free;
  end;
end;

procedure TKViewTableWithoutModelTests.TheViewKeepsItsOwnLabelAndImage;
var
  LView: TKDataView;
begin
  LView := DataViewFromYaml('Dashboard',
    'Type: Data'#13#10 +
    'DisplayLabel: Activity Dashboard'#13#10 +
    'ImageName: dashboard'#13#10 +
    'Controller: Dashboard'#13#10);
  try
    Assert.AreEqual('Activity Dashboard', LView.DisplayLabel);
    Assert.AreEqual('dashboard', LView.ImageName);
  finally
    LView.Free;
  end;
end;

procedure TKViewTableWithoutModelTests.Model_OnATableWithNoModel_RaisesNamingTheViewTable;
var
  LView: TKDataView;
begin
  LView := DataViewFromYaml('Dashboard',
    'Type: Data'#13#10 +
    'Controller: Dashboard'#13#10);
  try
    Assert.WillRaiseWithMessage(
      procedure
      begin
        LView.MainTable.Model;
      end,
      EKError, 'View table MainTable of view Dashboard declares no Model.');
  finally
    LView.Free;
  end;
end;

{ TKModelKeyFieldTests }

function TKModelKeyFieldTests.ModelFromYaml(const AName, AYaml: string): TKModel;
begin
  Result := TKModel.Create;
  try
    Result.PersistentName := AName;
    TEFYAMLReader.ReadTree(Result, AYaml);
  except
    Result.Free;
    raise;
  end;
end;

procedure TKModelKeyFieldTests.KeyFields_ReturnsTheKeyFieldsInOrder;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('TwoKeys',
    'ModelName: TwoKeys'#13#10 +
    'Fields:'#13#10 +
    '  K1: Integer not null primary key'#13#10 +
    '  Name: String(50)'#13#10 +
    '  K2: Integer not null primary key'#13#10);
  try
    Assert.AreEqual(2, LModel.KeyFieldCount);
    Assert.AreEqual('K1', LModel.KeyFields[0].FieldName);
    Assert.AreEqual('K2', LModel.KeyFields[1].FieldName);
  finally
    LModel.Free;
  end;
end;

procedure TKModelKeyFieldTests.KeyFields_PastTheLastOne_RaisesNamingTheModel;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('OneKey',
    'ModelName: OneKey'#13#10 +
    'Fields:'#13#10 +
    '  Id: Integer not null primary key'#13#10 +
    '  Name: String(50)'#13#10);
  try
    Assert.AreEqual(1, LModel.KeyFieldCount);
    Assert.WillRaiseWithMessage(
      procedure
      var
        LField: TKModelField;
      begin
        LField := LModel.KeyFields[1];
      end,
      EKError,
      'Model OneKey has 1 key field(s), so there is no key field 1. A ' +
      'reference field pointing at this model has to declare exactly as many ' +
      'subfields as it has key fields, in the same order.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelKeyFieldTests.KeyFieldCount_OnAModelWithNoKey_Raises;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('NoKey',
    'ModelName: NoKey'#13#10 +
    'Fields:'#13#10 +
    '  Name: String(50)'#13#10);
  try
    // Not from the check added above: GetKeyFieldNames has always reported
    // this, and it fires before anything can index the empty array.
    Assert.WillRaiseWithMessage(
      procedure
      var
        LCount: Integer;
      begin
        LCount := LModel.KeyFieldCount;
      end,
      nil,
      'Model NoKey has no primary key.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelKeyFieldTests.KeyFields_WithANegativeIndex_Raises;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('OneKey',
    'ModelName: OneKey'#13#10 +
    'Fields:'#13#10 +
    '  Id: Integer not null primary key'#13#10);
  try
    Assert.WillRaise(
      procedure
      var
        LField: TKModelField;
      begin
        LField := LModel.KeyFields[-1];
      end,
      EKError);
  finally
    LModel.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKMetadataCatalogTests);
  TDUnitX.RegisterTestFixture(TKModelKeyFieldTests);
  TDUnitX.RegisterTestFixture(TKViewTableWithoutModelTests);

end.
