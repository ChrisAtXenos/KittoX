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
unit EF.TreeTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFTreeTests = class
  public
    [Test]
    procedure AddChild_ThenFindNode_ReturnsTheChild;

    [Test]
    procedure GetChildIndex_WithOwnChild_ReturnsItsPosition;

    /// <summary>
    ///  KNOWN DEFECT (review 4.1, finding 31). The counter is incremented for
    ///  every child of the requested type and returned as-is when no match is
    ///  found, so a node that does not belong to the tree gets the index of the
    ///  last one instead of the documented -1: the caller then operates on - or
    ///  deletes - the wrong child.
    /// </summary>
    [Test]
    procedure GetChildIndex_WithForeignChild_ReturnsMinusOne;

    [Test]
    [TestCase('plain number', '100|100', '|')]
    [TestCase('kilobytes',    '2KB|2048', '|')]
    [TestCase('megabytes',    '100MB|104857600', '|')]
    procedure AsInteger_WithSizeSuffix_Converts(const AValue: string; const AExpected: Integer);

    /// <summary>
    ///  KNOWN DEFECT (review 4.1, finding 40). The suffix is applied as a 32-bit
    ///  multiplication, so a size that does not fit an Integer wraps around:
    ///  'MaxUploadSize: 4096MB' silently becomes 0, i.e. no upload allowed.
    ///  Returning a wrong number is the problem; raising would be acceptable.
    /// </summary>
    [Test]
    procedure AsInteger_WithSizeLargerThanInteger_DoesNotWrapAround;

    /// <summary>
    ///  A date coming from the browser is input: a malformed one has to be
    ///  reported with the value in the message, not turned into whatever
    ///  StrToInt or EncodeDateTime happened to say about integers and date
    ///  arguments.
    /// </summary>
    [Test]
    [TestCase('not a date at all', 'hello')]
    [TestCase('unknown month', 'Thu Xxx 01 1970 00:00:00')]
    [TestCase('letters where the year goes', 'Thu Jan 01 abcd 00:00:00')]
    [TestCase('truncated', 'Thu Jan 01 1970')]
    [TestCase('day 99', 'Thu Jan 99 1970 00:00:00')]
    procedure JSDateToDateTime_WithAMalformedDate_Raises(const AJSDate: string);
    /// <summary>And a real one still converts.</summary>
    [Test]
    procedure JSDateToDateTime_WithAValidDate_Converts;
    /// <summary>
    ///  An empty value is not a malformed date: JSONValueToNode documents it as
    ///  meaning null, and stops before the conversion. Pinned here so that the
    ///  validation added above is not mistaken for a reason to reject it.
    /// </summary>
    [Test]
    procedure JSDateToDateTime_WithAnEmptyValue_SetsTheNodeToNull;

    /// <summary>
    ///  Regression. Clear only clears the children, and the annotations were
    ///  copied only when the source had some: assigning a node with no comments
    ///  over one that had them left the old comments in place, attached to
    ///  content that was gone, and the writer put them back in the file.
    /// </summary>
    [Test]
    procedure Assign_FromANodeWithoutAnnotations_DropsTheOldOnes;

    /// <summary>
    ///  The data type factory is a singleton every thread goes through - each
    ///  value assignment on each node asks it for a type. It used to fill its
    ///  dictionary lazily, so two concurrent first uses of the same type could
    ///  both add it (EListError: Duplicate key) or read it while an add was
    ///  rehashing. Every registered type is now instantiated at startup.
    /// </summary>
    [Test]
    procedure DataTypeFactory_UnderConcurrency_ReturnsOneInstancePerType;

    /// <summary>
    ///  The factory is keyed case-insensitively, like the registry it draws
    ///  from: a model spelling a type 'string' must get the very same instance
    ///  as one spelling it 'String', or comparing two fields' DataType by
    ///  identity says they differ when they do not.
    /// </summary>
    [Test]
    procedure DataTypeFactory_IsCaseInsensitive;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  EF.Types,
  EF.Tree;

{ TEFTreeTests }

procedure TEFTreeTests.AddChild_ThenFindNode_ReturnsTheChild;
var
  LTree: TEFTree;
begin
  LTree := TEFTree.Create;
  try
    LTree.AddChild('Alpha').AsString := 'one';
    Assert.IsNotNull(LTree.FindNode('Alpha'), 'FindNode did not return the child just added.');
    Assert.AreEqual('one', LTree.GetString('Alpha'));
    Assert.IsNull(LTree.FindNode('Missing'), 'FindNode invented a node that was never added.');
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.GetChildIndex_WithOwnChild_ReturnsItsPosition;
var
  LTree: TEFTree;
  LSecond: TEFNode;
begin
  LTree := TEFTree.Create;
  try
    LTree.AddChild('A');
    LSecond := LTree.AddChild('B');
    LTree.AddChild('C');
    Assert.AreEqual(1, LTree.GetChildIndex<TEFNode>(LSecond));
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.GetChildIndex_WithForeignChild_ReturnsMinusOne;
var
  LTree: TEFTree;
  LForeign: TEFNode;
begin
  LTree := TEFTree.Create;
  try
    LTree.AddChild('A');
    LTree.AddChild('B');
    LTree.AddChild('C');
    LForeign := TEFNode.Create;
    try
      Assert.AreEqual(-1, LTree.GetChildIndex<TEFNode>(LForeign),
        'A node that is not a child must not be reported at a valid index.');
    finally
      LForeign.Free;
    end;
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.AsInteger_WithSizeSuffix_Converts(
  const AValue: string; const AExpected: Integer);
var
  LTree: TEFTree;
  LNode: TEFNode;
begin
  LTree := TEFTree.Create;
  try
    LNode := LTree.AddChild('Size');
    LNode.AsString := AValue;
    Assert.AreEqual(AExpected, LNode.AsInteger);
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.JSDateToDateTime_WithAMalformedDate_Raises(
  const AJSDate: string);
var
  LTree: TEFTree;
  LNode: TEFNode;
begin
  // Through JSONValueToNode with AUseJSDateFormat, which is the path a date
  // coming from the client actually takes.
  LTree := TEFTree.Create;
  try
    LNode := LTree.AddChild('D');
    LNode.DataType := TEFDataTypeFactory.Instance.GetDataType('Date');
    Assert.WillRaise(
      procedure
      begin
        LNode.DataType.JSONValueToNode(LNode, AJSDate, True,
          TFormatSettings.Create);
      end,
      EEFError,
      'A malformed date must be reported as such, with the value in the message.');
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.JSDateToDateTime_WithAnEmptyValue_SetsTheNodeToNull;
var
  LTree: TEFTree;
  LNode: TEFNode;
begin
  LTree := TEFTree.Create;
  try
    LNode := LTree.AddChild('D');
    LNode.DataType := TEFDataTypeFactory.Instance.GetDataType('Date');
    LNode.DataType.JSONValueToNode(LNode, '', True, TFormatSettings.Create);
    Assert.IsTrue(LNode.IsNull);
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.JSDateToDateTime_WithAValidDate_Converts;
var
  LTree: TEFTree;
  LDate, LTime: TEFNode;
begin
  LTree := TEFTree.Create;
  try
    LDate := LTree.AddChild('D');
    LDate.DataType := TEFDataTypeFactory.Instance.GetDataType('Date');
    LDate.DataType.JSONValueToNode(LDate, 'Wed Sep 02 2026 14:30:45', True,
      TFormatSettings.Create);
    Assert.AreEqual(EncodeDate(2026, 9, 2), LDate.AsDate);

    LTime := LTree.AddChild('T');
    LTime.DataType := TEFDataTypeFactory.Instance.GetDataType('Time');
    LTime.DataType.JSONValueToNode(LTime, 'Wed Sep 02 2026 14:30:45', True,
      TFormatSettings.Create);
    // A tolerance well under a second: the value travels through a TDateTime,
    // where a time of day is a fraction that does not come back bit for bit.
    Assert.AreEqual(Double(EncodeTime(14, 30, 45, 0)), Double(LTime.AsTime), 1E-6);
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.Assign_FromANodeWithoutAnnotations_DropsTheOldOnes;
var
  LTree: TEFTree;
  LWithComments, LWithout: TEFNode;
begin
  LTree := TEFTree.Create;
  try
    LWithComments := LTree.AddChild('Commented');
    LWithComments.AddAnnotation('# a comment about the old content');
    Assert.AreEqual(1, LWithComments.AnnotationCount);

    LWithout := LTree.AddChild('Plain');
    LWithout.AsString := 'a value';

    LWithComments.Assign(LWithout);
    Assert.AreEqual(0, LWithComments.AnnotationCount,
      'The comment survived the content it was about.');
    Assert.AreEqual('a value', LWithComments.AsString);
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.AsInteger_WithSizeLargerThanInteger_DoesNotWrapAround;
var
  LTree: TEFTree;
  LNode: TEFNode;
  LValue: Integer;
  LRaised: Boolean;
begin
  LTree := TEFTree.Create;
  try
    LNode := LTree.AddChild('MaxUploadSize');
    LNode.AsString := '4096MB';   // 4 GB: does not fit an Integer
    LRaised := False;
    LValue := 0;
    try
      LValue := LNode.AsInteger;
    except
      // Refusing the value is a fine answer; wrapping around silently is not.
      on E: Exception do
        LRaised := True;
    end;
    if not LRaised then
      Assert.IsTrue(LValue > 0,
        Format('4096MB was converted to %d instead of raising: the 32-bit ' +
          'multiplication wrapped around, so the configured limit is lost.', [LValue]));
  finally
    LTree.Free;
  end;
end;

procedure TEFTreeTests.DataTypeFactory_UnderConcurrency_ReturnsOneInstancePerType;
const
  THREAD_COUNT = 8;
  ITERATIONS = 500;
  TYPE_NAMES: array[0..5] of string =
    ('String', 'Integer', 'Currency', 'Date', 'Boolean', 'Decimal');
var
  LThreads: array of TThread;
  LFailures: Integer;
  LExpected: array[0..5] of TEFDataType;
  I: Integer;
begin
  // The instances the factory must keep handing back, whoever asks.
  for I := 0 to High(TYPE_NAMES) do
    LExpected[I] := TEFDataTypeFactory.Instance.GetDataType(TYPE_NAMES[I]);

  LFailures := 0;
  SetLength(LThreads, THREAD_COUNT);
  for I := 0 to THREAD_COUNT - 1 do
  begin
    LThreads[I] := TThread.CreateAnonymousThread(
      procedure
      var
        J, K: Integer;
      begin
        for J := 1 to ITERATIONS do
          for K := 0 to High(TYPE_NAMES) do
            if TEFDataTypeFactory.Instance.GetDataType(TYPE_NAMES[K]) <> LExpected[K] then
              TInterlocked.Increment(LFailures);
      end);
    LThreads[I].FreeOnTerminate := False;
  end;
  try
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Start;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].WaitFor;
  finally
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Free;
  end;

  Assert.AreEqual(0, LFailures,
    'The factory handed back a different instance for a type it had already ' +
    'returned: its dictionary is being written to while it is read.');
end;

procedure TEFTreeTests.DataTypeFactory_IsCaseInsensitive;
begin
  Assert.AreSame(
    TEFDataTypeFactory.Instance.GetDataType('String'),
    TEFDataTypeFactory.Instance.GetDataType('string'),
    'A type asked for in a different case must be the same instance.');
  Assert.AreSame(
    TEFDataTypeFactory.Instance.GetDataType('Currency'),
    TEFDataTypeFactory.Instance.GetDataType('CURRENCY'));
end;

initialization
  TDUnitX.RegisterTestFixture(TEFTreeTests);

end.
