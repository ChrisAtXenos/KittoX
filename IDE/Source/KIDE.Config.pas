{*******************************************************************}
{                                                                   }
{   KIDE Editor: GUI for Kitto                                      }
{                                                                   }
{   Copyright (c) 2012-2026 Ethea S.r.l.                            }
{   ALL RIGHTS RESERVED / TUTTI I DIRITTI RISERVATI                 }
{                                                                   }
{*******************************************************************}
{                                                                   }
{   The entire contents of this file is protected by                }
{   International Copyright Laws. Unauthorized reproduction,        }
{   reverse-engineering, and distribution of all or any portion of  }
{   the code contained in this file is strictly prohibited and may  }
{   result in severe civil and criminal penalties and will be       }
{   prosecuted to the maximum extent possible under the law.        }
{                                                                   }
{   RESTRICTIONS                                                    }
{                                                                   }
{   THE SOURCE CODE CONTAINED WITHIN THIS FILE AND ALL RELATED      }
{   FILES OR ANY PORTION OF ITS CONTENTS SHALL AT NO TIME BE        }
{   COPIED, TRANSFERRED, SOLD, DISTRIBUTED, OR OTHERWISE MADE       }
{   AVAILABLE TO OTHER INDIVIDUALS WITHOUT EXPRESS WRITTEN CONSENT  }
{   AND PERMISSION FROM ETHEA S.R.L.                                }
{                                                                   }
{   CONSULT THE END USER LICENSE AGREEMENT FOR INFORMATION ON       }
{   ADDITIONAL RESTRICTIONS.                                        }
{                                                                   }
{*******************************************************************}
{                                                                   }
{   Il contenuto di questo file � protetto dalle leggi              }
{   internazionali sul Copyright. Sono vietate la riproduzione, il  }
{   reverse-engineering e la distribuzione non autorizzate di tutto }
{   o parte del codice contenuto in questo file. Ogni infrazione    }
{   sar� perseguita civilmente e penalmente a termini di legge.     }
{                                                                   }
{   RESTRIZIONI                                                     }
{                                                                   }
{   SONO VIETATE, SENZA IL CONSENSO SCRITTO DA PARTE DI             }
{   ETHEA S.R.L., LA COPIA, LA VENDITA, LA DISTRIBUZIONE E IL       }
{   TRASFERIMENTO A TERZI, A QUALUNQUE TITOLO, DEL CODICE SORGENTE  }
{   CONTENUTO IN QUESTO FILE E ALTRI FILE AD ESSO COLLEGATI.        }
{                                                                   }
{   SI FACCIA RIFERIMENTO ALLA LICENZA D'USO PER INFORMAZIONI SU    }
{   EVENTUALI RESTRIZIONI ULTERIORI.                                }
{                                                                   }
{*******************************************************************}
unit KIDE.Config;

interface

uses
  EF.Classes,
  Kitto.Config;

type
  TKideConfig = class(TKConfig)
  strict private
    function GetTemplatePath: string;
    function GetMetadataTemplatePath: string;
    class function GetInstance: TKideConfig; static;
  private
  strict protected
    function GetConfigFileName: string; override;
    /// <summary>Loads Config.yaml from the embedded RCDATA resource
    /// CONFIG_YAML if present in the current module (the KittoXIDE package
    /// when running as IDE plugin). Otherwise falls back to disk loading,
    /// which is what KIDEX standalone uses (Bin\Config.yaml).</summary>
    function DoLoadConfig: TEFComponentConfig; override;
  public
    class property Instance: TKideConfig read GetInstance;
    /// <summary>Returns the Bin\ directory (parent of the platform-specific
    /// exe folder Bin\Win64 or Bin\Win32). All shared resources (Config.yaml,
    /// MetadataTemplates, ProjectTemplates, etc.) reside here.</summary>
    class function GetBasePath: string; static;
    property TemplatePath: string read GetTemplatePath;
    property MetadataTemplatePath: string read GetMetadataTemplatePath;
  end;

implementation

uses
  System.SysUtils,
  EF.Sys.Windows,
  EF.YAML,
  Kitto.AccessControl;

{ TKideConfig }

class function TKideConfig.GetBasePath: string;

  function HasConfig(const APath: string): Boolean;
  begin
    Result := (APath <> '') and FileExists(APath + 'Config.yaml');
  end;

var
  LModulePath, LKittoXHome: string;
begin
  // The base folder is ALWAYS the module's own folder first. We use
  // GetModuleName(HInstance) (NOT ParamStr(0)) so that:
  //  - KIDEX / MCPKittoX standalone (.exe): the executable's folder is the Bin
  //    folder, where Config.yaml and the shared resources live.
  //  - KittoXIDE plugin (.bpl loaded by bds.exe): we get the package's own
  //    location instead of bds.exe; for a packaged install Config.yaml and
  //    ProjectTemplates/ live next to the .bpl (installed under <root>\Kide\Bin).
  LModulePath := IncludeTrailingPathDelimiter(ExtractFilePath(GetModuleName(HInstance)));
  if HasConfig(LModulePath) then
    Exit(LModulePath);

  // Fallback (dev only): the .bpl is loaded from a Delphi build-output dir with
  // no Config.yaml alongside. KITTOX_HOME is set (by the setup) to the install
  // ROOT (e.g. C:\Dev\KittoX_4.0); the KIDE Bin lives under <root>\Kide\Bin.
  // Must NOT be reached by a standalone exe (handled above), which would
  // otherwise look in the root instead of Bin.
  LKittoXHome := GetEnvironmentVariable('KITTOX_HOME');
  if LKittoXHome <> '' then
    Exit(IncludeTrailingPathDelimiter(LKittoXHome) + 'Kide\Bin\');

  Result := LModulePath;
end;

function TKideConfig.GetConfigFileName: string;
begin
  Result := GetBasePath + 'Config.yaml';
end;

function TKideConfig.DoLoadConfig: TEFComponentConfig;
const
  RES_CONFIG_YAML = 'CONFIG_YAML';
var
  LBytes: TBytes;
begin
  // Inside the KittoXIDE package, the .bpl carries Config.yaml as an
  // embedded RCDATA resource so that loading the wizard does not depend on
  // the surrounding filesystem (where bds.exe lives, or whatever CWD the
  // IDE happens to be in). The KIDEX standalone .exe does NOT bundle the
  // resource, so the lookup returns nil and we fall through to disk loading.
  LBytes := GetRCDATAResourceBytes(HInstance, RES_CONFIG_YAML);
  if Assigned(LBytes) and (Length(LBytes) > 0) then
  begin
    Result := TEFComponentConfig.Create;
    TEFYAMLReader.ReadTree(Result, TEncoding.UTF8.GetString(LBytes));
    Result.PersistentName := 'embedded:CONFIG_YAML';
  end
  else
    Result := inherited DoLoadConfig;
end;

class function TKideConfig.GetInstance: TKideConfig;
begin
  // Use GetCanonicalInstance, NOT TKConfig.Instance — the latter goes
  // through TKConfig.OnGetInstance which KIDE.Project installs to
  // redirect TKConfig.Instance to the open project's TProjectConfig.
  // That redirection must NOT affect TKideConfig.Instance: KIDEX-specific
  // settings (theme, default DB drivers, locale paths, MetadataTemplates
  // etc.) live in KIDEX's own Bin/Config.yaml and are unrelated to any
  // open project. The cast `as TKideConfig` would fail with EInvalidCast
  // on TProjectConfig if we went through the hook.
  Result := TKConfig.GetCanonicalInstance as TKideConfig;
end;

function TKideConfig.GetTemplatePath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetBasePath + 'ProjectTemplates');
end;

function TKideConfig.GetMetadataTemplatePath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetBasePath + 'MetadataTemplates');
end;

initialization
  TKConfig.SetConfigClass(TKideConfig);
  //activation for memory leaks
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;

finalization
  // KittoXCore is a runtime package and stays loaded when this design-time
  // package (KittoXIDE) is uninstalled. The initialization above left two
  // references to THIS bpl inside Core: the metaclass Kitto.Config.FConfigClass
  // (= TKideConfig) and, once anything read TKConfig.Instance, a cached
  // TKideConfig object in Kitto.Config.FInstance — both with a VMT that is
  // about to be unmapped. Retract them here, while this code is still mapped:
  // free the cached instance now, then restore the base config class so Core
  // never re-creates a TKideConfig nor frees one through a dead VMT (which was
  // the design-package uninstall crash).
  TKConfig.DestroyInstance;
  TKConfig.SetConfigClass(TKConfig);

end.
