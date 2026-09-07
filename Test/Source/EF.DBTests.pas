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
///  Tests for the SQL that the dialect classes assemble. No database is
///  involved: these check the statement text, which is where the defects that
///  break a whole back-end tend to live.
/// </summary>
unit EF.DBTests;

interface

uses
  DUnitX.TestFramework,
  Data.DB,
  EF.DB;

type
  [TestFixture]
  TEFDBEngineTypeTests = class
  strict private
    const
      // Built the way TKSQLBuilder builds them: the where clause has a leading
      // space and no trailing one, the order by clause has neither.
      SELECT_CLAUSE = 'select ORDER_ID, ORDER_DATE';
      FROM_CLAUSE = 'from ORDERS';
      WHERE_CLAUSE = ' where (CUSTOMER_ID = :CUSTOMER_ID)';
      ORDER_BY_CLAUSE = 'order by ORDER_DATE';
  public
    /// <summary>
    ///  Regression. The where and the order by clauses used to be concatenated
    ///  with nothing between them, producing '...where (X)order by Y'. On
    ///  Oracle that is a syntax error on any view that has both a filter (a
    ///  DefaultFilter, a search, or just the foreign key of a detail table) and
    ///  an ordering; on the base dialect it happens as soon as the view is
    ///  paginated. It went unnoticed because with no filter the missing space
    ///  is supplied by the from clause.
    /// </summary>
    [Test]
    procedure BaseDialect_WithPaging_SeparatesWhereFromOrderBy;
    [Test]
    procedure BaseDialect_WithoutPaging_SeparatesWhereFromOrderBy;
    [Test]
    procedure OracleDialect_SeparatesWhereFromOrderBy;
    [Test]
    procedure OracleDialect_WithPaging_SeparatesWhereFromOrderBy;

    [Test]
    procedure BaseDialect_WithoutPaging_KeepsTheClausesInOrder;
  end;

  /// <summary>
  ///  A DB adapter that counts how many times it is destroyed instead of
  ///  actually destroying itself. That is deliberate: the defect under test
  ///  frees the same adapter twice, and both the destructor body and the
  ///  release of the memory would then run on an instance that is already gone
  ///  -- the run above reported it as 'Invalid pointer operation', which aborts
  ///  the test instead of failing an assertion about how many times the adapter
  ///  was freed. Note that overriding Destroy without calling inherited is not
  ///  enough: the compiler-generated epilogue of the outermost destructor calls
  ///  FreeInstance regardless, so the memory has to be kept by overriding that.
  ///  The instance is leaked on purpose: a handful of bytes, a few per run.
  /// </summary>
  TCountingDBAdapter = class(TEFDBAdapter)
  strict private
    class var FDestroyCount: Integer;
  protected
    function InternalCreateDBConnection: TEFDBConnection; override;
  public
    destructor Destroy; override;
    procedure FreeInstance; override;
    /// <summary>Zeroes the counter, so each test starts from a known state.</summary>
    class procedure ResetDestroyCount;
    /// <summary>How many times an instance of this class has been destroyed
    /// since the last ResetDestroyCount.</summary>
    class property DestroyCount: Integer read FDestroyCount;
  end;

  /// <summary>
  ///  Tests for the ownership of the adapters the registry holds. The registry
  ///  is a process-wide singleton, but the class is a plain one: these tests
  ///  build their own instances and leave the singleton -- and the FireDAC
  ///  adapter registered in it -- alone.
  /// </summary>
  [TestFixture]
  TEFDBAdapterRegistryTests = class
  public
    /// <summary>
    ///  Regression. BeforeDestruction freed every registered adapter and then
    ///  called Clear on the dictionary, which owns them through its value
    ///  notification and freed each of them a second time. It stayed invisible
    ///  because every EF.DB.* unit unregisters its own adapter in its
    ///  finalization section, which runs first and leaves the dictionary empty;
    ///  an adapter registered by an application, with nothing requiring it to
    ///  unregister, reaches this point and is freed twice at shutdown.
    /// </summary>
    [Test]
    procedure Destruction_FreesEachRegisteredAdapterOnce;
    /// <summary>
    ///  The same with more than one adapter left registered: the loop covered
    ///  them all, so all of them were freed twice.
    /// </summary>
    [Test]
    procedure Destruction_WithSeveralAdapters_FreesEachOfThemOnce;
    /// <summary>
    ///  Unregistering must keep freeing the adapter -- it is the dictionary's
    ///  value notification that does it, and the fix above now relies on it
    ///  alone -- and must not free it again when the registry goes.
    /// </summary>
    [Test]
    procedure Unregister_FreesTheAdapterExactlyOnce;
  end;

  /// <summary>
  ///  A foreign key that counts how many times it is destroyed, kept alive the
  ///  same way TCountingDBAdapter is and for the same reason.
  /// </summary>
  TCountingForeignKeyInfo = class(TEFDBForeignKeyInfo)
  strict private
    class var FDestroyCount: Integer;
  public
    destructor Destroy; override;
    procedure FreeInstance; override;
    /// <summary>Zeroes the counter, so each test starts from a known state.</summary>
    class procedure ResetDestroyCount;
    /// <summary>How many times an instance of this class has been destroyed
    /// since the last ResetDestroyCount.</summary>
    class property DestroyCount: Integer read FDestroyCount;
  end;

  /// <summary>
  ///  Tests for who owns the sub-objects of a TEFDBTableInfo. What the metadata
  ///  fetchers in EF.DB.FD and EF.DB.ADO are allowed to do on their exception
  ///  paths follows from this, and getting it wrong there was finding 17.
  /// </summary>
  [TestFixture]
  TEFDBTableInfoTests = class
  public
    /// <summary>
    ///  AddForeignKey hands the foreign key over to the table: from that point
    ///  on the table frees it, exactly once.
    /// </summary>
    [Test]
    procedure AddForeignKey_TransfersOwnershipToTheTable;
    /// <summary>
    ///  FindForeignKey returns the very instance the table owns -- not a copy.
    ///  A caller that frees what it got back is freeing the table's object.
    /// </summary>
    [Test]
    procedure FindForeignKey_ReturnsTheInstanceTheTableOwns;
    /// <summary>
    ///  Regression, and the reason the exception handler in
    ///  FetchTableForeignKeys had to go rather than be narrowed. This
    ///  reproduces what that handler did -- free a foreign key that had already
    ///  been added -- and shows the table then freeing the same object again.
    ///  In the real code the second free happened inside the handler of
    ///  FetchTables, which frees the table: an access violation while cleaning
    ///  up after an unrelated error, surfacing as a model that fails to load.
    /// </summary>
    [Test]
    procedure FreeingAnAddedForeignKey_MakesTheTableFreeItTwice;
  end;

  /// <summary>
  ///  Tests for how the FireDAC metadata reader turns the rows a driver returns
  ///  for a key into an ordered list of column names. No database: the rows are
  ///  supplied by an in-memory dataset shaped like the metadata query, which is
  ///  the only way to present them out of order on purpose.
  /// </summary>
  [TestFixture]
  TEFDBFDKeyColumnsTests = class
  strict private
    /// <summary>An in-memory dataset with the fields the metadata queries have.
    /// Each row is a position, a column name and a referenced column name; the
    /// cursor is left on the first record.</summary>
    function MetaDataSet(const APositions: array of Integer;
      const ANames, AReferencedNames: array of string): TDataSet;
  public
    /// <summary>
    ///  Regression. The reader used to append each name as it arrived and
    ///  Assert that the position the driver reported matched the index the name
    ///  had landed on. A driver returning the rows in another order therefore
    ///  raised EAssertionFailed in Debug and -- with assertions off in Release
    ///  since EF.Defines.inc stopped forcing {$C+} -- built the list in the
    ///  driver's order without a word. Column order is what couples a master's
    ///  key to a detail's reference, so the quiet outcome reads another
    ///  master's rows.
    /// </summary>
    [Test]
    procedure AddKeyColumns_OrdersByPositionNotByArrival;
    /// <summary>
    ///  The two lists of a foreign key are filled in one pass, so they stay
    ///  coupled: the local column at index I references the foreign column at
    ///  index I, whatever order the rows arrived in.
    /// </summary>
    [Test]
    procedure AddKeyColumns_CouplesTheTwoListsByPosition;
    /// <summary>
    ///  Positions that are not 1..n each exactly once do not describe the key.
    ///  Failing to open the view is the visible, harmless outcome; a key built
    ///  out of that metadata is the invisible, harmful one.
    /// </summary>
    [Test]
    procedure AddKeyColumns_WithADuplicatePosition_Raises;
    [Test]
    procedure AddKeyColumns_WithAPositionAboveTheColumnCount_Raises;
    [Test]
    procedure AddKeyColumns_WithAZeroPosition_Raises;
    [Test]
    procedure AddKeyColumns_WithNoRows_AddsNothing;
    /// <summary>
    ///  A list that already has entries is appended to, and the appended block
    ///  is ordered on its own. The old code compared positions against the
    ///  whole list's length instead, so anything already in the list made every
    ///  comparison fail.
    /// </summary>
    [Test]
    procedure AddKeyColumns_AppendsAfterWhatIsAlreadyInTheList;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  FireDAC.Comp.Client,
  EF.DB.FD;

{ TEFDBEngineTypeTests }

procedure TEFDBEngineTypeTests.BaseDialect_WithPaging_SeparatesWhereFromOrderBy;
var
  LEngine: TEFDBEngineType;
  LSQL: string;
begin
  LEngine := TEFDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 100);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'The where clause runs into the order by clause: ' + LSQL);
    Assert.IsTrue(ContainsText(LSQL, ') order by'), LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.BaseDialect_WithoutPaging_SeparatesWhereFromOrderBy;
var
  LEngine: TEFDBEngineType;
  LSQL: string;
begin
  LEngine := TEFDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 0);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'The where clause runs into the order by clause: ' + LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.OracleDialect_SeparatesWhereFromOrderBy;
var
  LEngine: TEFOracleDBEngineType;
  LSQL: string;
begin
  LEngine := TEFOracleDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 0);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'ORA-00933 waiting to happen: ' + LSQL);
    Assert.IsTrue(ContainsText(LSQL, ') order by'), LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.OracleDialect_WithPaging_SeparatesWhereFromOrderBy;
var
  LEngine: TEFOracleDBEngineType;
  LSQL: string;
begin
  LEngine := TEFOracleDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 1);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'ORA-00933 waiting to happen: ' + LSQL);
    // The single-record case: ROWNUM starts at 1, so the upper bound is
    // inclusive. 'ROWNUM < 1' would never be true and the edit form of a record
    // would come back empty.
    Assert.IsTrue(ContainsText(LSQL, 'ROWNUM <= 1'), LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.BaseDialect_WithoutPaging_KeepsTheClausesInOrder;
var
  LEngine: TEFDBEngineType;
  LSQL: string;
begin
  LEngine := TEFDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 0);
    Assert.IsTrue(Pos(FROM_CLAUSE, LSQL) > Pos(SELECT_CLAUSE, LSQL), LSQL);
    Assert.IsTrue(Pos('where', LSQL) > Pos(FROM_CLAUSE, LSQL), LSQL);
    Assert.IsTrue(Pos(ORDER_BY_CLAUSE, LSQL) > Pos('where', LSQL), LSQL);
  finally
    LEngine.Free;
  end;
end;

{ TCountingDBAdapter }

destructor TCountingDBAdapter.Destroy;
begin
  Inc(FDestroyCount);
  // No inherited, and no released memory -- see the class comment.
end;

procedure TCountingDBAdapter.FreeInstance;
begin
  // Deliberately empty -- see the class comment.
end;

function TCountingDBAdapter.InternalCreateDBConnection: TEFDBConnection;
begin
  Result := nil;
end;

class procedure TCountingDBAdapter.ResetDestroyCount;
begin
  FDestroyCount := 0;
end;

{ TEFDBAdapterRegistryTests }

procedure TEFDBAdapterRegistryTests.Destruction_FreesEachRegisteredAdapterOnce;
var
  LRegistry: TEFDBAdapterRegistry;
begin
  TCountingDBAdapter.ResetDestroyCount;
  LRegistry := TEFDBAdapterRegistry.Create;
  try
    LRegistry.RegisterDBAdapter('COUNTING', TCountingDBAdapter.Create);
  finally
    LRegistry.Free;
  end;
  Assert.AreEqual(1, TCountingDBAdapter.DestroyCount,
    'The registered adapter was not freed exactly once.');
end;

procedure TEFDBAdapterRegistryTests.Destruction_WithSeveralAdapters_FreesEachOfThemOnce;
var
  LRegistry: TEFDBAdapterRegistry;
begin
  TCountingDBAdapter.ResetDestroyCount;
  LRegistry := TEFDBAdapterRegistry.Create;
  try
    LRegistry.RegisterDBAdapter('COUNTING1', TCountingDBAdapter.Create);
    LRegistry.RegisterDBAdapter('COUNTING2', TCountingDBAdapter.Create);
    LRegistry.RegisterDBAdapter('COUNTING3', TCountingDBAdapter.Create);
  finally
    LRegistry.Free;
  end;
  Assert.AreEqual(3, TCountingDBAdapter.DestroyCount,
    'The three registered adapters were not freed exactly once each.');
end;

procedure TEFDBAdapterRegistryTests.Unregister_FreesTheAdapterExactlyOnce;
var
  LRegistry: TEFDBAdapterRegistry;
begin
  TCountingDBAdapter.ResetDestroyCount;
  LRegistry := TEFDBAdapterRegistry.Create;
  try
    LRegistry.RegisterDBAdapter('COUNTING', TCountingDBAdapter.Create);
    LRegistry.UnregisterDBAdapter('COUNTING');
    Assert.AreEqual(1, TCountingDBAdapter.DestroyCount,
      'Unregistering did not free the adapter.');
    Assert.AreEqual(0, LRegistry.DBAdapterCount);
  finally
    LRegistry.Free;
  end;
  Assert.AreEqual(1, TCountingDBAdapter.DestroyCount,
    'The adapter was freed again when the registry was destroyed.');
end;

{ TCountingForeignKeyInfo }

destructor TCountingForeignKeyInfo.Destroy;
begin
  Inc(FDestroyCount);
  // No inherited, and no released memory -- see TCountingDBAdapter.
end;

procedure TCountingForeignKeyInfo.FreeInstance;
begin
  // Deliberately empty -- see TCountingDBAdapter.
end;

class procedure TCountingForeignKeyInfo.ResetDestroyCount;
begin
  FDestroyCount := 0;
end;

{ TEFDBTableInfoTests }

procedure TEFDBTableInfoTests.AddForeignKey_TransfersOwnershipToTheTable;
var
  LTable: TEFDBTableInfo;
  LForeignKey: TCountingForeignKeyInfo;
begin
  TCountingForeignKeyInfo.ResetDestroyCount;
  LTable := TEFDBTableInfo.Create;
  try
    LForeignKey := TCountingForeignKeyInfo.Create;
    LForeignKey.Name := 'FK_CHILD_PARENT';
    LTable.AddForeignKey(LForeignKey);
    Assert.AreEqual(1, LTable.ForeignKeyCount);
    Assert.AreSame(LTable, LForeignKey.TableInfo,
      'AddForeignKey did not record the table on the foreign key.');
    Assert.AreEqual(0, TCountingForeignKeyInfo.DestroyCount,
      'The foreign key was freed while the table was still alive.');
  finally
    LTable.Free;
  end;
  Assert.AreEqual(1, TCountingForeignKeyInfo.DestroyCount,
    'The table did not free its foreign key exactly once.');
end;

procedure TEFDBTableInfoTests.FindForeignKey_ReturnsTheInstanceTheTableOwns;
var
  LTable: TEFDBTableInfo;
  LForeignKey: TEFDBForeignKeyInfo;
begin
  LTable := TEFDBTableInfo.Create;
  try
    LForeignKey := TEFDBForeignKeyInfo.Create;
    LForeignKey.Name := 'FK_CHILD_PARENT';
    LTable.AddForeignKey(LForeignKey);
    Assert.AreSame(LForeignKey, LTable.FindForeignKey('FK_CHILD_PARENT'));
    // Case-insensitively, too: it is how the fetchers look one up again on the
    // second row of a composite key.
    Assert.AreSame(LForeignKey, LTable.FindForeignKey('fk_child_parent'));
    Assert.IsNull(LTable.FindForeignKey('FK_SOMETHING_ELSE'));
  finally
    LTable.Free;
  end;
end;

procedure TEFDBTableInfoTests.FreeingAnAddedForeignKey_MakesTheTableFreeItTwice;
var
  LTable: TEFDBTableInfo;
  LForeignKey: TCountingForeignKeyInfo;
begin
  TCountingForeignKeyInfo.ResetDestroyCount;
  LTable := TEFDBTableInfo.Create;
  try
    LForeignKey := TCountingForeignKeyInfo.Create;
    LForeignKey.Name := 'FK_CHILD_PARENT';
    LTable.AddForeignKey(LForeignKey);
    // What the removed handler did.
    FreeAndNil(LForeignKey);
    Assert.AreEqual(1, TCountingForeignKeyInfo.DestroyCount);
  finally
    LTable.Free;
  end;
  Assert.AreEqual(2, TCountingForeignKeyInfo.DestroyCount,
    'Freeing a foreign key already added to a table is expected to leave the ' +
    'table freeing it again -- if this ever stops being true, the comment in ' +
    'FetchTableForeignKeys explaining why it has no handler is out of date.');
end;

{ TEFDBFDKeyColumnsTests }

function TEFDBFDKeyColumnsTests.MetaDataSet(const APositions: array of Integer;
  const ANames, AReferencedNames: array of string): TDataSet;
var
  LTable: TFDMemTable;
  I: Integer;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.FieldDefs.Add('COLUMN_POSITION', ftInteger);
    LTable.FieldDefs.Add('COLUMN_NAME', ftString, 50);
    LTable.FieldDefs.Add('PKEY_COLUMN_NAME', ftString, 50);
    LTable.CreateDataSet;
    for I := Low(APositions) to High(APositions) do
      LTable.AppendRecord([APositions[I], ANames[I], AReferencedNames[I]]);
    LTable.First;
  except
    LTable.Free;
    raise;
  end;
  Result := LTable;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_OrdersByPositionNotByArrival;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  // The driver hands them over as C, A, B.
  LDataSet := MetaDataSet([3, 1, 2], ['C', 'A', 'B'], ['', '', '']);
  try
    LNames := TStringList.Create;
    try
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
        LNames, nil, 'the key under test');
      Assert.AreEqual('A,B,C', LNames.CommaText);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_CouplesTheTwoListsByPosition;
var
  LDataSet: TDataSet;
  LNames, LReferenced: TStrings;
begin
  LDataSet := MetaDataSet([2, 1], ['LOCAL_B', 'LOCAL_A'], ['FOREIGN_B', 'FOREIGN_A']);
  try
    LNames := TStringList.Create;
    LReferenced := TStringList.Create;
    try
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME',
        'PKEY_COLUMN_NAME', LNames, LReferenced, 'the foreign key under test');
      Assert.AreEqual('LOCAL_A,LOCAL_B', LNames.CommaText);
      Assert.AreEqual('FOREIGN_A,FOREIGN_B', LReferenced.CommaText);
    finally
      LReferenced.Free;
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithADuplicatePosition_Raises;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  LDataSet := MetaDataSet([1, 1], ['A', 'B'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      Assert.WillRaise(
        procedure
        begin
          TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
            LNames, nil, 'the key under test');
        end,
        EEFDBError);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithAPositionAboveTheColumnCount_Raises;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  // Two columns, so 3 is not a position this key can have.
  LDataSet := MetaDataSet([1, 3], ['A', 'B'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      Assert.WillRaise(
        procedure
        begin
          TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
            LNames, nil, 'the key under test');
        end,
        EEFDBError);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithAZeroPosition_Raises;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  // Positions are 1-based: a 0 means the driver is counting differently, and
  // the list built from it would be off by one all the way through.
  LDataSet := MetaDataSet([0, 1], ['A', 'B'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      Assert.WillRaise(
        procedure
        begin
          TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
            LNames, nil, 'the key under test');
        end,
        EEFDBError);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithNoRows_AddsNothing;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  LDataSet := MetaDataSet([], [], []);
  try
    LNames := TStringList.Create;
    try
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
        LNames, nil, 'the key under test');
      Assert.AreEqual(0, LNames.Count);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_AppendsAfterWhatIsAlreadyInTheList;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  LDataSet := MetaDataSet([2, 1], ['B', 'A'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      LNames.Add('ALREADY_THERE');
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
        LNames, nil, 'the key under test');
      Assert.AreEqual('ALREADY_THERE,A,B', LNames.CommaText);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEFDBEngineTypeTests);
  TDUnitX.RegisterTestFixture(TEFDBAdapterRegistryTests);
  TDUnitX.RegisterTestFixture(TEFDBTableInfoTests);
  TDUnitX.RegisterTestFixture(TEFDBFDKeyColumnsTests);

end.
