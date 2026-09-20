{ -------------------------------------------------------------------------------
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
  ------------------------------------------------------------------------------- }

{ -------------------------------------------------------------------------------
  Based on code by David Hoyle
  http://www.davidghoyle.co.uk/
  ------------------------------------------------------------------------------- }
unit KIDE.IOTA.Register;

interface

procedure Register;

implementation

// Splash/About bitmaps: KITTOXSPLASH48PNG (RCDATA, used on Delphi 11+) and
// KITTOXSPLASH24BMP (bitmap, older IDEs). The .res lives next to the package
// projects (Packages), so the path is relative to the .dproj folder
// (Packages\Dxx).
{$R ..\KittoXSplashAbout.res}

uses
  System.SysUtils
  , System.Classes
  , Winapi.Windows
  , Vcl.Graphics
  , Vcl.Forms
  , Vcl.Imaging.PngImage
  , ToolsAPI
  , DesignIntf
  , Kitto.Types
  , KIDE.IOTA.ProjectWizard
  , KIDE.MainDataModuleUnit
  , KIDE.YAMLHighlighter
  ;

const
{$IF CompilerVersion >= 35.0} // Delphi 11+ (About/splash accept a PNG-sourced bitmap)
  ABOUT_RES_NAME = 'KITTOXSPLASH48PNG';
  SPLASH_RES_NAME = 'KITTOXSPLASH48PNG';
{$ELSE}
  ABOUT_RES_NAME = 'KITTOXSPLASH24BMP';
  SPLASH_RES_NAME = 'KITTOXSPLASH24BMP';
{$IFEND}
  RsAboutTitle = 'Ethea KittoX';
  RsAboutDescription =
    'KittoX - Framework for creating data-driven web applications with Delphi and HTMX' + sLineBreak +
    'https://ethea.it/docs/kittox/';
  RsAboutLicense = 'Core: Apache 2.0 - Enterprise & KIDEX: Commercial (Ethea S.r.l.)';

var
  AboutBoxServices: IOTAAboutBoxServices = nil;
  AboutBoxIndex: Integer;

{$IF CompilerVersion >= 35.0}
function CreateBitmapFromPngRes(const AResName: string): Vcl.Graphics.TBitmap;
var
  LPngImage: TPngImage;
  LResStream: TResourceStream;
begin
  LPngImage := nil;
  try
    Result := Vcl.Graphics.TBitmap.Create;
    LPngImage := TPngImage.Create;
    LResStream := TResourceStream.Create(HInstance, AResName, RT_RCDATA);
    try
      LPngImage.LoadFromStream(LResStream);
      Result.Assign(LPngImage);
    finally
      LResStream.Free;
    end;
  finally
    LPngImage.Free;
  end;
end;

procedure RegisterAboutBox;
var
  LBitmap: Vcl.Graphics.TBitmap;
begin
  Supports(BorlandIDEServices, IOTAAboutBoxServices, AboutBoxServices);
  LBitmap := CreateBitmapFromPngRes(ABOUT_RES_NAME);
  try
    AboutBoxIndex := AboutBoxServices.AddPluginInfo(
      RsAboutTitle + ' ' + KITTOX_VERSION,
      RsAboutDescription, LBitmap.Handle, False, RsAboutLicense);
  finally
    LBitmap.Free;
  end;
end;

procedure RegisterWithSplashScreen;
var
  LBitmap: Vcl.Graphics.TBitmap;
begin
  LBitmap := CreateBitmapFromPngRes(SPLASH_RES_NAME);
  try
    SplashScreenServices.AddPluginBitmap(
      RsAboutTitle + ' ' + KITTOX_VERSION,
      LBitmap.Handle, False, RsAboutLicense, '');
  finally
    LBitmap.Free;
  end;
end;
{$ELSE}
procedure RegisterAboutBox;
var
  LProductImage: HBITMAP;
begin
  Supports(BorlandIDEServices, IOTAAboutBoxServices, AboutBoxServices);
  LProductImage := LoadBitmap(FindResourceHInstance(HInstance), ABOUT_RES_NAME);
  AboutBoxIndex := AboutBoxServices.AddPluginInfo(RsAboutTitle + ' ' + KITTOX_VERSION,
    RsAboutDescription, LProductImage, False, RsAboutLicense);
end;

procedure RegisterWithSplashScreen;
var
  LProductImage: HBITMAP;
begin
  LProductImage := LoadBitmap(FindResourceHInstance(HInstance), SPLASH_RES_NAME);
  SplashScreenServices.AddPluginBitmap(RsAboutTitle, LProductImage,
    False, RsAboutLicense);
end;
{$IFEND}

procedure UnregisterAboutBox;
begin
  if (AboutBoxIndex <> 0) and Assigned(AboutBoxServices) then
  begin
    AboutBoxServices.RemovePluginInfo(AboutBoxIndex);
    AboutBoxIndex := 0;
    AboutBoxServices := nil;
  end;
end;

procedure Register;
begin
  // Show KittoX on the IDE splash screen (must be done while the splash is up).
  RegisterWithSplashScreen;

  // Le form del wizard contengono TVirtualImageList agganciate a
  // MainDataModule.ImageCollection. Nell'applicazione standalone quel data
  // module lo crea il .dpr di KIDEX; qui non lo creerebbe nessuno e le form si
  // aprirebbero senza icone, senza alcun errore. Creato una volta sola, al
  // caricamento del package.
  EnsureMainDataModule;

  // YAML Syntax Highlighter
  RegisterYAMLHighlighter;

  // KittoX projects — one entry per supported deployment mode under
  // File / New / Other / KittoX Projects. The BDS 37 gallery sorts items
  // alphabetically with no public priority API, so the desired display
  // order is enforced via the "1. " / "2. " / "3. " / "4. " prefix on
  // each wizard's Name (see KIDE.IOTA.ProjectWizard).
  RegisterPackageWizard(TStandaloneIOTAProjectWizard.Create);
  RegisterPackageWizard(TDesktopIOTAProjectWizard.Create);
  RegisterPackageWizard(TIsapiIOTAProjectWizard.Create);
  RegisterPackageWizard(TApacheIOTAProjectWizard.Create);
end;

initialization
  // Add KittoX to the IDE About box (removed when the package unloads).
  RegisterAboutBox;

finalization
  UnregisterAboutBox;

end.

