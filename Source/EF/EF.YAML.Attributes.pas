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
///  Custom attributes for declarative mapping between Delphi properties
///  and YAML metadata nodes. Used by KIDE for RTTI-based property discovery.
/// </summary>
/// <remarks>
///  Attribute types:
///   - YamlNode: optional scalar property (string, integer, boolean, enum)
///   - YamlRequiredNode: required scalar property (ModelName, etc.)
///   - YamlContainer: collection of N homogeneous children (Fields, Rules)
///   - YamlSubNode: single sub-object with fixed properties (HTMLEditor, PreviewWindow)
///   - YamlEnumValue: maps an enum ordinal to its YAML string representation
/// </remarks>
unit EF.YAML.Attributes;

interface

type
  /// <summary>
  ///  Marks a read-only property as mapped to an optional YAML node.
  ///  This is the most common attribute — used for scalar values like
  ///  IsVisible, DisplayWidth, PhysicalName, Expression, etc.
  /// </summary>
  /// <example>
  ///  [YamlNode('IsVisible', 'True', 'Field visibility in the UI')]
  ///  property IsVisible: Boolean read GetIsVisible;
  ///
  ///  [YamlNode('DisplayLabel', '', 'Label shown in forms and grids', True)]
  ///  property DisplayLabel: string read GetDisplayLabel;  // localizable
  /// </example>
  /// <remarks>
  ///  DefaultValue is stored as string (not Variant) because Delphi's RTTI
  ///  attribute construction does not support Variant constructor parameters.
  /// </remarks>
  YamlNodeAttribute = class(TCustomAttribute)
  private
    FNodePath: string;
    FDefaultValue: string;
    FHasDefaultValue: Boolean;
    FDescription: string;
    FIsLocalizable: Boolean;
  public
    /// <summary>
    ///  Optional node without an explicit default value.
    ///  The implicit default depends on the property type ('' for string, 0 for integer, etc.)
    /// </summary>
    constructor Create(const ANodePath, ADescription: string;
      const AIsLocalizable: Boolean = False); overload;
    /// <summary>
    ///  Optional node with an explicit default value (as string representation).
    /// </summary>
    constructor Create(const ANodePath: string; const ADefaultValue: string;
      const ADescription: string; const AIsLocalizable: Boolean = False); overload;
    /// <summary>
    ///  Optional node with an explicit Integer default value. Lets a declaration
    ///  reference a shared Integer constant instead of duplicating the literal
    ///  as a string, e.g. [YamlNode('MaxTokens', KX_CLAUDE_DEF_MAXTOKENS, '...')].
    ///  The value is stored as its string representation.
    /// </summary>
    constructor Create(const ANodePath: string; const ADefaultValue: Integer;
      const ADescription: string; const AIsLocalizable: Boolean = False); overload;
    /// <summary>
    ///  Optional node with an explicit Boolean default value (stored as
    ///  'True'/'False'). Lets a declaration reference a shared Boolean constant.
    /// </summary>
    constructor Create(const ANodePath: string; const ADefaultValue: Boolean;
      const ADescription: string; const AIsLocalizable: Boolean = False); overload;
    /// <summary>
    ///  Slash-separated path to the YAML node (e.g. 'IsVisible', 'PreviewWindow/Width').
    /// </summary>
    property NodePath: string read FNodePath;
    /// <summary>
    ///  Default value as string representation. Check HasDefaultValue to distinguish
    ///  "no default" from "default is empty string".
    /// </summary>
    property DefaultValue: string read FDefaultValue;
    /// <summary>
    ///  True if an explicit default value was provided in the attribute constructor.
    /// </summary>
    property HasDefaultValue: Boolean read FHasDefaultValue;
    /// <summary>
    ///  English description used as tooltip in KIDE and as code documentation.
    /// </summary>
    property Description: string read FDescription;
    /// <summary>
    ///  When True, KIDE generates a secondary input for the alternate language
    ///  (the node path with '2' suffix, e.g. 'DisplayLabel2').
    /// </summary>
    property IsLocalizable: Boolean read FIsLocalizable;
  end;

  /// <summary>
  ///  Marks a read-only property as mapped to a required YAML node.
  ///  KIDE displays these with bold label and asterisk.
  ///  Few nodes are required: ModelName, ViewName, Model (in ViewTable), etc.
  /// </summary>
  /// <example>
  ///  [YamlRequiredNode('ModelName', 'Unique model identifier')]
  ///  property ModelName: string read GetModelName;
  /// </example>
  YamlRequiredNodeAttribute = class(YamlNodeAttribute)
  end;

  /// <summary>
  ///  Class-level attribute: declares that this class is the config reader/schema
  ///  for a specific YAML node, identified by its full slash-separated path
  ///  (e.g. 'HelpChat/Claude'). Lets a config class live in its own feature/domain
  ///  unit and still be discovered by KIDE via RTTI, without the parent config
  ///  class referencing it by type. KIDE scans the linked types for classes
  ///  carrying this attribute and maps NodePath -> class.
  /// </summary>
  /// <example>
  ///  [YamlConfigNode('HelpChat/Claude')]
  ///  TKClaudeProviderConfig = class
  ///    [YamlNode('Model', 'claude-haiku-4-5', 'Claude model id')]
  ///    property Model: string read FModel;
  ///  end;
  /// </example>
  YamlConfigNodeAttribute = class(TCustomAttribute)
  private
    FNodePath: string;
  public
    /// <summary>Creates the attribute binding the decorated class to the YAML
    /// node at ANodePath (full path from the config root).</summary>
    constructor Create(const ANodePath: string);
    /// <summary>Full slash-separated path of the YAML node this class describes.</summary>
    property NodePath: string read FNodePath;
  end;

  /// <summary>
  ///  Marks a read-only property as a container of N homogeneous children.
  ///  KIDE renders this as an expandable tree node with an "Add child" button.
  ///  Examples: Fields (N TKModelField), Rules (N TKRule),
  ///  DetailReferences (N TKModelDetailReference).
  /// </summary>
  /// <example>
  ///  [YamlContainer('Fields', TKModelField, 'Data fields of this model')]
  ///  property Fields: TKModelFields read GetFields;
  /// </example>
  YamlContainerAttribute = class(TCustomAttribute)
  private
    FNodePath: string;
    FChildClass: TClass;
    FDescription: string;
  public
    /// <summary>
    ///  Creates the attribute for the container at ANodePath whose children are instances of AChildClass.
    /// </summary>
    constructor Create(const ANodePath: string; AChildClass: TClass;
      const ADescription: string);
    /// <summary>
    ///  Path to the container node in the YAML tree.
    /// </summary>
    property NodePath: string read FNodePath;
    /// <summary>
    ///  Delphi class of each child element. KIDE uses this to discover
    ///  the child's own YAML attributes via RTTI.
    /// </summary>
    property ChildClass: TClass read FChildClass;
    /// <summary>
    ///  English description shown as tooltip in KIDE.
    /// </summary>
    property Description: string read FDescription;
  end;

  /// <summary>
  ///  Marks a read-only property as a single sub-object with a fixed set of properties.
  ///  Unlike YamlContainer, this node has no "Add" button — it is a single config block.
  ///  KIDE navigates into the SubNodeClass via RTTI to show its properties.
  ///  Examples: HTMLEditor, PreviewWindow, Thumbnail, MobileSettings.
  /// </summary>
  /// <example>
  ///  [YamlSubNode('HTMLEditor', TKHTMLEditorConfig, 'Rich-text editor toolbar options')]
  ///  property HTMLEditor: TKHTMLEditorConfig read GetHTMLEditor;
  /// </example>
  YamlSubNodeAttribute = class(TCustomAttribute)
  private
    FNodePath: string;
    FSubNodeClass: TClass;
    FDescription: string;
  public
    /// <summary>
    ///  Creates the attribute for the single sub-object at ANodePath, described by ASubNodeClass.
    /// </summary>
    constructor Create(const ANodePath: string; ASubNodeClass: TClass;
      const ADescription: string);
    /// <summary>
    ///  Path to the sub-object node in the YAML tree.
    /// </summary>
    property NodePath: string read FNodePath;
    /// <summary>
    ///  Delphi class representing the sub-object. KIDE discovers its
    ///  YAML-mapped properties via RTTI.
    /// </summary>
    property SubNodeClass: TClass read FSubNodeClass;
    /// <summary>
    ///  English description shown as tooltip in KIDE.
    /// </summary>
    property Description: string read FDescription;
  end;

  /// <summary>
  ///  Maps an enumerated type's ordinal value to its YAML string representation.
  ///  Applied to the enum type itself, not to individual properties.
  ///  KIDE reads these to populate combo box drop-downs.
  /// </summary>
  /// <example>
  ///  type
  ///    [YamlEnumValue('Top', 'Label above the field')]
  ///    [YamlEnumValue('Left', 'Label to the left, left-aligned')]
  ///    [YamlEnumValue('Right', 'Label to the left, right-aligned')]
  ///    TKLabelAlign = (laTop, laLeft, laRight);
  /// </example>
  YamlEnumValueAttribute = class(TCustomAttribute)
  private
    FYamlValue: string;
    FDescription: string;
  public
    /// <summary>
    ///  Creates the attribute mapping the enum ordinal it decorates to the YAML string AYamlValue.
    /// </summary>
    constructor Create(const AYamlValue: string; const ADescription: string = '');
    /// <summary>
    ///  The string value as written in the YAML file (e.g. 'Top', 'Left', 'Right').
    /// </summary>
    property YamlValue: string read FYamlValue;
    /// <summary>
    ///  English description shown in KIDE combo box and tooltips.
    /// </summary>
    property Description: string read FDescription;
  end;

  /// <summary>
  ///  Declares a child type that can be added to a container class.
  ///  Applied to container classes (TKModelFields, TKRules, etc.) to list
  ///  the types of children that KIDE should offer in the "Add" popup menu.
  ///  Multiple attributes can be applied to the same class.
  /// </summary>
  /// <example>
  ///  [YamlChildType('StringField', 'String(10)', 'String field with max length')]
  ///  [YamlChildType('IntegerField', 'Integer', 'Integer numeric field')]
  ///  TKModelFields = class(TKMetadataItem)
  /// </example>
  YamlChildTypeAttribute = class(TCustomAttribute)
  private
    FName: string;
    FChildClass: TClass;
    FDefaultValue: string;
    FDescription: string;
  public
    /// <summary>
    ///  Creates the attribute declaring an addable child named AName, with an optional default value and description.
    ///  Use this form for scalar/marker children (e.g. 'StringField' -> 'String(10)').
    /// </summary>
    constructor Create(const AName: string; const ADefaultValue: string = '';
      const ADescription: string = ''); overload;
    /// <summary>
    ///  Creates the attribute binding an addable child named AName to a descriptor
    ///  class AChildClass. Use this form for heterogeneous config children whose
    ///  per-type shape KIDE should edit (e.g. 'Field' -> TKLayoutFieldConfig,
    ///  'FreeSearch' -> TKFilterItemFreeSearch). KIDE resolves the node to
    ///  AChildClass via GetSubNodeClassFromParent and renders its property editor.
    /// </summary>
    constructor Create(const AName: string; const AChildClass: TClass;
      const ADefaultValue: string = ''; const ADescription: string = ''); overload;
    /// <summary>
    ///  Node name for the child (e.g. 'StringField', 'ForceUpperCase').
    /// </summary>
    property Name: string read FName;
    /// <summary>
    ///  Descriptor class for the child node, or nil for scalar/marker children.
    ///  When assigned, KIDE renders this class's [YamlNode]/[YamlSubNode] editor
    ///  for the added child.
    /// </summary>
    property ChildClass: TClass read FChildClass;
    /// <summary>
    ///  Default value for the child node (e.g. 'String(10)', 'Integer').
    ///  Empty string if no default value.
    /// </summary>
    property DefaultValue: string read FDefaultValue;
    /// <summary>
    ///  English description shown as tooltip in KIDE.
    /// </summary>
    property Description: string read FDescription;
  end;

implementation

uses
  System.SysUtils;

{ YamlNodeAttribute }

constructor YamlNodeAttribute.Create(const ANodePath, ADescription: string;
  const AIsLocalizable: Boolean);
begin
  inherited Create;
  FNodePath := ANodePath;
  FDefaultValue := '';
  FHasDefaultValue := False;
  FDescription := ADescription;
  FIsLocalizable := AIsLocalizable;
end;

constructor YamlNodeAttribute.Create(const ANodePath: string;
  const ADefaultValue: string; const ADescription: string;
  const AIsLocalizable: Boolean);
begin
  inherited Create;
  FNodePath := ANodePath;
  FDefaultValue := ADefaultValue;
  FHasDefaultValue := True;
  FDescription := ADescription;
  FIsLocalizable := AIsLocalizable;
end;

constructor YamlNodeAttribute.Create(const ANodePath: string;
  const ADefaultValue: Integer; const ADescription: string;
  const AIsLocalizable: Boolean);
begin
  inherited Create;
  FNodePath := ANodePath;
  FDefaultValue := IntToStr(ADefaultValue);
  FHasDefaultValue := True;
  FDescription := ADescription;
  FIsLocalizable := AIsLocalizable;
end;

constructor YamlNodeAttribute.Create(const ANodePath: string;
  const ADefaultValue: Boolean; const ADescription: string;
  const AIsLocalizable: Boolean);
begin
  inherited Create;
  FNodePath := ANodePath;
  // Stored as 'True'/'False' to match the string form used across the codebase.
  FDefaultValue := BoolToStr(ADefaultValue, True);
  FHasDefaultValue := True;
  FDescription := ADescription;
  FIsLocalizable := AIsLocalizable;
end;

{ YamlConfigNodeAttribute }

constructor YamlConfigNodeAttribute.Create(const ANodePath: string);
begin
  inherited Create;
  FNodePath := ANodePath;
end;

{ YamlContainerAttribute }

constructor YamlContainerAttribute.Create(const ANodePath: string;
  AChildClass: TClass; const ADescription: string);
begin
  inherited Create;
  FNodePath := ANodePath;
  FChildClass := AChildClass;
  FDescription := ADescription;
end;

{ YamlSubNodeAttribute }

constructor YamlSubNodeAttribute.Create(const ANodePath: string;
  ASubNodeClass: TClass; const ADescription: string);
begin
  inherited Create;
  FNodePath := ANodePath;
  FSubNodeClass := ASubNodeClass;
  FDescription := ADescription;
end;

{ YamlEnumValueAttribute }

constructor YamlEnumValueAttribute.Create(const AYamlValue: string;
  const ADescription: string);
begin
  inherited Create;
  FYamlValue := AYamlValue;
  FDescription := ADescription;
end;

{ YamlChildTypeAttribute }

constructor YamlChildTypeAttribute.Create(const AName: string;
  const ADefaultValue: string; const ADescription: string);
begin
  inherited Create;
  FName := AName;
  FChildClass := nil;
  FDefaultValue := ADefaultValue;
  FDescription := ADescription;
end;

constructor YamlChildTypeAttribute.Create(const AName: string;
  const AChildClass: TClass; const ADefaultValue: string; const ADescription: string);
begin
  inherited Create;
  FName := AName;
  FChildClass := AChildClass;
  FDefaultValue := ADefaultValue;
  FDescription := ADescription;
end;

end.
