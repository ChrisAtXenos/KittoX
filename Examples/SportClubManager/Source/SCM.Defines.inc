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

{ Compile-time switches of the Sport Club Manager example.

  KITTOX_FLEXCEL_SUPPORT
    Builds the Excel export of every grid on FlexCel (TMS FlexCel, commercial)
    instead of the ADO engine that ships with the framework. The views do not
    change: they all call the SCMExcelExport tool, and it is that tool which
    picks its ancestor -- see SCM.Tool.ExcelExport.pas.

    Undefined by default, because the example cannot ship a commercial library:
    without it the export runs on the ADO engine, which needs the
    Microsoft.ACE.OLEDB.12.0 provider installed.

    Three ways to turn it on. The first two add the library path as well, so
    there is nothing else to configure:

      - through the examples builder, with the FLEXCEL environment variable:

          set FLEXCEL=D:\FlexCel\Packages\D13
          Examples\build_Examples.cmd SportClubManager All Release

      - or one project at a time:

          msbuild SportClubManager.dproj /p:FLEXCEL=D:\FlexCel\Packages\D13

        The path can be either the folder that holds the .dcu of the platform
        being built, or the folder above the platforms: the projects look in
        both `$(FLEXCEL)` and `$(FLEXCEL)\$(Platform)\Release`, which is the
        layout the FlexCel packages produce. Mind the platform when you name
        the exact folder: the Apache module builds Win32, the other three Win64.

      - or by hand, from the IDE: remove the dot from the DEFINE below and add
        the same folder to the project's unit search path.
}

{.$DEFINE KITTOX_FLEXCEL_SUPPORT}
