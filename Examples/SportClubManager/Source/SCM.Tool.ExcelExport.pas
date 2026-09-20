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
///  The single Excel export tool of the application, registered as
///  <c>SCMExcelExport</c>: every grid that offers a download calls this one, and
///  it is here -- in one place, at compile time -- that the engine underneath is
///  chosen.
///
///  With <c>KITTOX_FLEXCEL_SUPPORT</c> defined it descends from
///  <c>TExportFlexCelToolController</c> and the export goes through FlexCel,
///  which is what the production application uses: it fills a real workbook
///  template, honouring its formatting and its formulas. Without the define it
///  descends from <c>TExportExcelToolController</c>, the engine that ships with
///  the framework, which writes through ADO and needs the
///  Microsoft.ACE.OLEDB.12.0 provider.
///
///  The two ancestors are interchangeable by construction: same base class
///  (<c>TKXDownloadFileController</c>), same virtual methods to override
///  (<c>AcceptRecord</c>, <c>AcceptField</c>, <c>PrepareFile</c>), and the same
///  three YAML nodes -- <c>ExcelRangeName</c>, <c>TemplateFileName</c>,
///  <c>UseDisplayLabels</c> -- on top of what a download tool already reads
///  (<c>ClientFileName</c>, <c>RequireSelection</c>). So the view metadata says
///  nothing about the engine, and switching it changes no YAML.
///
///  See SCM.Defines.inc for how to turn the define on.
/// </summary>
unit SCM.Tool.ExcelExport;

{$I SCM.Defines.inc}

interface

uses
{$IFDEF KITTOX_FLEXCEL_SUPPORT}
  Kitto.Tool.FlexCel;
{$ELSE}
  Kitto.Tool.ADO;
{$ENDIF}

type
  /// <summary>Excel export of a grid. Ancestor chosen at compile time: FlexCel
  /// when KITTOX_FLEXCEL_SUPPORT is defined, the framework's ADO engine
  /// otherwise. Adds nothing of its own -- its whole purpose is to give the
  /// views one controller name that does not change with the engine.</summary>
  TSCMExcelExportTool = class(
{$IFDEF KITTOX_FLEXCEL_SUPPORT}
    TExportFlexCelToolController
{$ELSE}
    TExportExcelToolController
{$ENDIF}
    );

implementation

uses
  Kitto.Html.Controller;

initialization
  TKXControllerRegistry.Instance.RegisterClass('SCMExcelExport', TSCMExcelExportTool);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('SCMExcelExport');

end.
