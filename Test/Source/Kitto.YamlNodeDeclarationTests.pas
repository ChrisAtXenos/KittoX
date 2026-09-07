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
///  The YAML nodes a metadata class declares through [YamlNode]. KIDE's tree
///  validator, its node completion and the MCP server's validate tools all
///  read them through TYamlAttributeReader, so a node that works at runtime
///  but is not declared is invisible to all of them.
///
///  Two things have to be true for a class to take part:
///    - RTTI for public properties has to be on where the class is declared,
///      which in these units comes from a {$RTTI EXPLICIT PROPERTIES} earlier
///      in the same file -- the directive stays in effect until changed, so
///      most classes do not carry one of their own;
///    - KIDE.Utils.GetNodeMetadataClass has to map a node of that kind to the
///      class, or nobody ever asks the reader about it. That one lives in the
///      KIDE tree and cannot be reached from here, so this test covers the
///      declaration and not the mapping.
/// </summary>
unit Kitto.YamlNodeDeclarationTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKYamlNodeDeclarationTests = class
  strict private
    /// <summary>The declared node paths of AClass, or an empty array.</summary>
    function DeclaredNodesOf(const AClass: TClass): TArray<string>;
    /// <summary>Fails unless AClass declares a node at APath.</summary>
    procedure AssertDeclares(const AClass: TClass; const APath: string);
  public
    /// <summary>
    ///  A detail reference declares every node it honours. A class that
    ///  declares some and not others is worse than one that declares none: the
    ///  validator only checks a class that declares at least one, and then
    ///  treats every undeclared node as an application custom node.
    /// </summary>
    [Test]
    procedure DetailReferenceDeclaresItsNodes;

    /// <summary>
    ///  And it declares them with a description, since that is what a reader
    ///  gets to see.
    /// </summary>
    [Test]
    procedure DetailReferenceNodesAreDescribed;
  end;

implementation

uses
  System.SysUtils
  , System.StrUtils
  , EF.YAML.AttributeUtils
  , Kitto.Metadata.Models
  ;

{ TKYamlNodeDeclarationTests }

function TKYamlNodeDeclarationTests.DeclaredNodesOf(
  const AClass: TClass): TArray<string>;
var
  LProperties: TArray<TYamlPropertyInfo>;
  I: Integer;
begin
  Result := [];
  LProperties := TYamlAttributeReader.GetYamlProperties(AClass);
  for I := 0 to High(LProperties) do
    Result := Result + [LProperties[I].NodePath];
end;

procedure TKYamlNodeDeclarationTests.AssertDeclares(const AClass: TClass;
  const APath: string);
var
  LNodes: TArray<string>;
begin
  LNodes := DeclaredNodesOf(AClass);
  Assert.IsTrue(IndexText(APath, LNodes) >= 0,
    Format('%s does not declare the node "%s". Declared: [%s]',
      [AClass.ClassName, APath, string.Join(', ', LNodes)]));
end;

procedure TKYamlNodeDeclarationTests.DetailReferenceDeclaresItsNodes;
begin
  AssertDeclares(TKModelDetailReference, 'CascadeDelete');
  AssertDeclares(TKModelDetailReference, 'ReferenceField');
  AssertDeclares(TKModelDetailReference, 'DisplayLabel');
  AssertDeclares(TKModelDetailReference, 'PhysicalName');
end;

procedure TKYamlNodeDeclarationTests.DetailReferenceNodesAreDescribed;
var
  LProperties: TArray<TYamlPropertyInfo>;
  I: Integer;
begin
  LProperties := TYamlAttributeReader.GetYamlProperties(TKModelDetailReference);
  Assert.IsTrue(Length(LProperties) > 0,
    'TKModelDetailReference declares no node at all. Either the [YamlNode] '
    + 'attributes are gone, or RTTI for public properties is no longer on where '
    + 'the class is declared -- which compiles them away without a word.');
  for I := 0 to High(LProperties) do
    Assert.IsTrue(LProperties[I].Description <> '',
      Format('The node "%s" is declared without a description.',
        [LProperties[I].NodePath]));
end;

initialization
  TDUnitX.RegisterTestFixture(TKYamlNodeDeclarationTests);

end.
