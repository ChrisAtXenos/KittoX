# Kitto<sup>x</sup> - A framework for creating data-driven web applications with Delphi and HTMX
[![Core License](https://img.shields.io/badge/Core-Apache%202.0-yellowgreen.svg)](https://opensource.org/licenses/Apache-2.0)
[![Enterprise License](https://img.shields.io/badge/Enterprise-AGPL--3.0%20%2F%20Commercial-blue.svg)](KittoLicensing)

**Latest Version 4.0.19 - 07 Sep 2026**

![KittoX_logo.png](./images/kittoX_logo_200.png)

**Kitto<sup>x</sup>** allows to create **Rich Internet Applications** based on a data model that can be mapped onto any database. The client-side part uses **HTMX** (through webbroker technology) to create a fully **AJAX** application, allowing you to build standard and advanced data-manipulating forms in a fraction of the time.

**Kitto<sup>x</sup>** is aimed at **Delphi** developers that need to create web or mobile applications without delving into the intricacies of HTML, CSS or Javascript, yet it allows access to the bare metal if required.

**Kitto<sup>x</sup>** includes a **database-agnostic** data-access layer, allowing to create applications that work on any database engine and port applications between database engines.

A **Kitto<sup>x</sup>** application is described as a set of easily maintained **YAML** files, keeping definitions abstract and declarative and allowing for future extensions. Business rules are enforced either declaratively or through small javascript fragments on the client, or in Delphi code on the server.

---

## Full documentation

- [Documentation site](https://ethea.it/docs/kittox/) with 150+ pages
- Pages for all controllers, filters, data concepts, how-to guides, FAQ
- Three example applications: HelloKitto, TasKitto, KEmployee

---

## Enterprise Edition ##

Beyond the Apache 2.0 Core, **Kitto<sup>x</sup>** ships with Enterprise modules and developer tools under commercial license:

- **Enterprise components** &mdash; interactive Charts (Chart.js), Calendars (EventCalendar), Google Maps with geocoding and markers, Dashboards and FlexPanels &mdash; all driven by YAML metadata, no client-side coding required.

- **KIDE<sup>x</sup>** &mdash; the visual IDE for designing **Kitto<sup>x</sup>** applications. Tree-based YAML editor with **RTTI-based property discovery**, database reverse engineering (FireDAC / DBExpress / ADO), a New Project Wizard that scaffolds complete apps for up to 4 deployment modes (Standalone .exe / Desktop .exe / ISAPI .dll / Apache .dll), and an integrated HTTP server for live preview. Ships with a RAD Studio design-time package (`KittoXIDE.bpl`) that integrates the same wizard under **File &gt; New &gt; Other &gt; KittoX Projects** and adds a YAML syntax highlighter to the IDE editor.

- **MCP-KittoX** &mdash; standalone Model Context Protocol server (`MCPKittoX.exe`) that exposes KIDE<sup>x</sup> functionality to AI agents (Claude Desktop / Code, Codex, LM Studio, any MCP-compatible client). Agents can scaffold complete **Kitto<sup>x</sup>** apps and reverse-engineer Models from a live database conversationally; metadata validation, locale refresh and view scaffolding tools are on the next-phases roadmap. Bundled with KIDE<sup>x</sup>: a single OnGuard registration unlocks both.

---

## Licensing ##

**Kitto<sup>x</sup>** uses an **Open Core** licensing model:

- **Core** (List, Form, Wizard, FlexPanel, routing, database, auth): [Apache 2.0](https://opensource.org/licenses/Apache-2.0) &mdash; free for any use, commercial or non-commercial.

- **Enterprise Modules** (Chart, Calendar, GoogleMap, Dashboard): [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) for open-source applications, or Ethea Commercial License for closed-source applications. [Please contact Ethea](https://ethea.it/supporto/) for detailed informations about commercial license.

- **KIDEX** (Visual IDE): commercial license only.

See the [Licensing](https://ethea.it/docs/kittox/KittoLicensing.html) page and [Enterprise Edition](KittoEnt) for full details.

Visit [this site](https://ethea.it/Kitto-Demo/) for online demos.

---

# Release Notes

## 07 Sep 2026: ver. 4.0.19 Beta

- **Automated test suite** — 216 tests, green on Win64/Win32 × Debug/Release; 24 of them run against real MSSQL, PostgreSQL, Firebird and Oracle servers, and the whole metadata catalogue of the three examples is loaded and walked. `Test\run_tests.cmd`
- **Detail grids work before the master exists**: full data entry on a master still in memory, saved to the database exactly as the grid showed it
- **`CascadeDelete`** on a detail reference deletes the details inside the master's transaction, recursively. Off by default; where it is not declared the refusal names the record and counts what holds it back
- **The framework's own messages in four languages** — 93 strings now translated in it/de/es/pt: wizard buttons, grid and calendar toolbars, GoogleMap controls, dialogs, authenticator messages. New `Tools\update_locale.cmd` keeps the catalogues in step and recompiles the `.mo`
- **KIDE<sup>x</sup> — Update Database Structure**: the reverse of the Model Wizard, generating and running the DDL that brings the database in line with the Models, multi-dialect, with an editable preview. *New and incomplete — read the limitations*
- **KIDE<sup>x</sup> — YAML validation driven by RTTI**: the validator reads the declarations on the framework classes instead of a hand-written list, and checks enum and integer values too
- **KIDE<sup>x</sup> — configuration editor completed**: Auth, Email/SMTP, Defaults, Log and Help Chat now offer every node the framework reads
- **KIDE<sup>x</sup> — scalable DPI-aware icons**, a theme selector with a live preview of the twelve VCL styles, and an SVG editor for the project's own icons
- **Changed**: a server-rendered error dialog now carries a truthful HTTP status (500 / 422 / 400 / 409) and an `X-KittoX-Dialog` header. **If you drive Kitto<sup>x</sup> endpoints from your own client, a dialog response is no longer a `2xx`**

## 25 Aug 2026: ver. 4.0.18 Beta

- **Per-domain config readers** (`Kitto.Config.<Domain>`) for Server, Auth, Notifications, UserFormats, AccessControl, Log, Desktop and Theme, with each view/model descriptor moved next to its consumer; new typed **`[YamlChildType(name, Class)]`**
- **The setup installer now compiles the framework packages** (Core + Enterprise + IDE) for every selected Delphi version, creates `KITTOX_HOME` and registers the IDE library search paths — the examples and your own projects compile with no manual step
- **KIDE<sup>x</sup> Model Wizard follows changes to the schema**: re-running *Update models* reports added, removed and reordered key and foreign-key columns, a foreign key redirected to another table, and a changed primary key
- **KIDE<sup>x</sup> New Project Wizard**: ODAC as a selectable engine, and generated databases named after their engine instead of `Other1`/`Other2`
- Master and detail no longer require the Model's field names to match the database's column names
- ThirdParty units namespaced with a `Kitto.` prefix, to avoid clashes with the same libraries shipped by other packages

## 23 Aug 2026: ver. 4.0.17 Beta

- **The JWT envelope is an optional `JWT:` sub-block under any authenticator**: write `Auth: DB`, `Auth: LDAP`, `Auth: MyOwn` and add `JWT:` to issue and validate a self-contained `kx_token`; without the block the same authenticator uses a plain session cookie. The JOSE crypto lives in an opt-in engine, so the core carries no dependency on it

## 21 Aug 2026: ver. 4.0.16 Beta

- **Help Chat can answer through Claude**: streamed token by token, grounded on the documentation index (RAG), with replies rendered from Markdown to safe HTML, on every deployment mode
- Help Chat and Notification Center are **opt-in units**: add them to `UseKitto.pas`, and a clear startup error names the one missing when a feature is enabled in config

## 12 Aug 2026: ver. 4.0.15 Beta

- New **`TKAuthenticator.SupportsPasswordChange`**, interrogated before writing, so an authenticator that does not own the credentials can refuse instead of reporting a success it discarded
- New **`TKAuthenticatorDecorator`**: the forwarding contract of a wrapping authenticator is now checked by the compiler
- A security pass over the authentication and session layer. **Upgrading is recommended**

## 10 Aug 2026: ver. 4.0.14 Beta

- **Full multi-language support**: new **LanguageSwitcher** controller (flag dropdown) for login and home, interface language auto-detected from the browser when `LanguageId` is empty, and the examples shipped in English, Italian, German, Spanish and Portuguese
- **Help Chat** — an in-app assistant: floating bubble and drawer, enabled with `HelpChat/Enabled`, with a pluggable provider model and a deterministic **docsearch** provider that answers from the documentation index and links back to it. Contextual **?** button on the List and Form toolbars
- **Notification Center** refinements: opt-in via `Notifications/Enabled`, clear-all, per-job remove, downloads via fetch + blob
- New **`[Retry]/[Reset]` dialog** for every user-initiated action that fails or times out; background polling stays silent

## 04 Aug 2026: ver. 4.0.13 Beta

- **Notification Center and background tools** — run a download-file tool (CSV/TXT/XML/Excel, MergePDF, ReportBuilder) as a **background job** on a worker pool separate from the HTTP threads, opt-in per tool with one YAML line, `RunMode: Background`. A bell shows each job with its status and lets the user download, cancel or dismiss it; jobs are persisted per user on disk and survive logout and a process restart. Configurable under `Server/Jobs`
- **Licensing**: registration under `HKEY_CURRENT_USER\Software\Ethea\KIDEX`, company name and developer e-mail, and several versions of Kitto<sup>x</sup> usable on the same machine
- **Changed**: the framework packages folder is renamed from `Projects/` to `Packages/`

## 31 Jul 2026: ver. 4.0.12 Beta

- **LDAP / Active Directory authentication** — new `Auth: LDAP`: simple bind against Active Directory or a generic LDAP, no local user table, name and e-mail read from the directory
- `Controller: ReportBuilderTool` updated to the latest ReportBuilder

## 28 Jul 2026: ver. 4.0.11 Beta

- **REST / JSON API** — expose an application's data views as a web service, by default under `/api/v4/{View}`, in parallel to the HTML<sup>x</sup> GUI and on the same engine, models, rules and ACL. Opt-in by adding `Kitto.Web.Rest` to `UseKitto.pas`: full CRUD with model-level permissions, stateless bearer-token auth, a self-describing **OpenAPI 3.0** spec with a built-in **Swagger UI**, configurable base path and opt-in CORS

## 20 Jul 2026: ver. 4.0.10 Beta

- **Oracle is a fully supported backend**: DDL and data scripts for the examples on Oracle XE 21c, the Oracle SQL dialect completed, and FireDAC's `Ora` driver wired into the examples. New portable `%DB.CONCAT%`, `%DB.FROM_DUAL%` and `%DB.CURRENT_DATE%` macros make hand-written YAML SQL work across all five dialects
- **New optional ODAC backend** (`EF.DB.ODAC`) on Devart ODAC, an alternative Oracle path enabled per application
- **Attribute-based routing complete**: the whole `kx/*` surface is served by typed handlers under one shared request-filter chain, and the monolithic dispatcher is gone. New **`TKXResourceRegistry.RegisterOverride`** lets an application subclass a framework handler and replace a single endpoint **without forking** the route
- **Navigation guard**: a browser navigation typed straight at an internal `kx/*` fragment endpoint is rejected and redirected, instead of serving a bare partial
- **`{MasterRecord.*}` macros resolve in detail-form lookup filters**, so dependent lookups populate from the master record being edited
- Public-API documentation coverage raised from ~32% to ~74%, surfaced in KIDE<sup>x</sup> through `[YamlNode]` descriptions

## 06 Jul 2026: ver. 4.0.9 Beta

- The authentication family (`kx/login`, `kx/logout`, `kx/resetpassword`, `kx/changepassword`) is the first group to **bring its own routing** through the attribute-based router, running inside the full per-request context
- `Examples/build_Examples.cmd` takes arguments, so a single example, deployment mode and configuration can be built from the command line

## 08 Jun 2026: ver. 4.0.8 Beta

- **User-selectable theme**: set `Theme/UserSelection: True`, drop a `Controller: ThemeSwitcher` anywhere in the GUI, and the end user picks Light / Auto / Dark live, persisted per application, with no page reload
- **`Theme` is a structured config block** discoverable by KIDE<sup>x</sup>: `Mode`, shared font and icon settings, and per-mode `Light:` / `Dark:` palettes each with its own `Primary-Color`
- **MCP-KittoX: 40+ tools** (up from 16) — full CRUD on Models, Views and Layouts, database introspection, config read and update, `.po` reading, metadata validation and view scaffolding

## 18 May 2026: ver. 4.0.7 Beta

- **RAD Studio IDE plugin gallery**: four entries under **File > New > Other > KittoX Projects** (Standalone, Desktop, ISAPI, Apache), so there are now **three ways to scaffold an application** — KIDE<sup>x</sup>, the IDE gallery, and MCP-KittoX
- A generated project **authenticates out of the box**: `Auth: TextFile` with a ready-to-use file, no users table required
- **Model Wizard**: editable `DisplayLabel` and `Hint` on every field, auto-populated from the database's own column comments (MSSQL, PostgreSQL, Firebird, MySQL, Oracle); *Beautify names* handles names with spaces; *New TreeView…* is idempotent and merges into an existing `MainMenu.yaml`
- **MCP-KittoX `models_create_from_db`** — the headless Model Wizard, so an AI agent can reverse-engineer Models conversationally, byte-identical to what the visual wizard writes. Plus `models_list`/`read`, `views_list`/`read`, `resources_list`/`read` and `menu_generate_main_menu`
- `Controller/AutoOpen` and `Controller/PagingTools` follow the Model's `IsLarge` flag, and a Reference to a large Model renders as a searchable lookup popup
- **ACL enforced server-side on every endpoint**, with the toolbar's Add/Edit/Delete/Dup disabled for a denied user

## 01 May 2026: ver. 4.0.6 Beta

- New **`Auth: JWT`** wrapper authenticator (signed `kx_token` cookie, sliding expiration) and **`AccessControl: JWT`**, reading grants from a `kx_acl` claim snapshotted at login
- **Multi-database applications**: TasKitto and HelloKitto on SQL Server, PostgreSQL and Firebird, with an optional *Environment* combo on the login form (`Auth/DatabaseChoices`) and cross-dialect macros `%DB.TRUE%`, `%DB.FALSE%`, `%DB.DATEDIFF`, `%DB.DATETIME_FROM`
- New `Tools/SetVersion.ps1`: one-shot version bump across constant, dproj, README and installer script
- YAML metadata files included in every `.dproj`, visible in the Project Manager with KIDE<sup>x</sup> highlighting

## 23 Apr 2026: ver. 4.0.5 Beta

- Database connection ownership unified in `TKConfig`, with the new `DatabaseFor(Name)` and `CreateStandaloneDBConnection(Name)` API and the `InDBConnection` / `InDBTransaction` helpers

## 22 Apr 2026: ver. 4.0.4 Beta

- **DetailTables Style**: `Tabs`, `Bottom` or `Popup`
- Multi-column sort and manual column resize in grids, with a tooltip on a cell only when its text is actually truncated
- Multi-page form validation
- Edit-mode accent border on comboboxes and other non-text-editable fields

## 23 Apr 2026: ver. 4.0.3 Beta

- **ExportExcel / ExportFlexCel** tools
- Grid keyboard navigation
- Editing-mode field borders and form toolbar anchoring

## 19 Apr 2026: ver. 4.0.2 Beta

- **Apache and IIS deployment simplified**: static resources are served internally, with no `RewriteRule` to write
- **New deployment mode**: Windows Service behind a reverse proxy (nginx, Apache, IIS), with install and uninstall scripts
- The `Apply*Rules` event chain (`EditRecord`, `NewRecord`, `Duplicate`, `AfterShowEditWindow`)
- HTTP error feedback with a Retry/Reset dialog
- DDL and DML scripts for the example databases

## 09 Apr 2026: ver. 4.0.1 Beta

*Corrections only.*

## 07 Apr 2026: ver. 4.0.0 Beta (first public release)

First public release of **Kitto<sup>x</sup>**, the fourth generation of the Kitto framework: a complete rewrite of the client side from ExtJS to **HTMX + AlpineJS + TemplatePro**, on a new modular server architecture.

### Architecture

- **HTMX + AlpineJS client**: the server generates HTML fragments and the page updates in place. No heavy JavaScript framework
- **Attribute-based routing (RTTI)**: URL routing declared with Delphi custom attributes, resource classes discovered at startup, request context injected
- **Server-side store**: in-session data stores with record state tracking, transactional master-detail saving in a single database transaction, blob lazy-loading
- **Open Core licensing**: Core under Apache 2.0, Enterprise modules under AGPL-3.0 or commercial, KIDE<sup>x</sup> commercial

### Controllers

- **List** (grid with CRUD toolbar, server-side paging, sorting, column layouts, row colours, grouping), **GroupingList**, **Form** (field pages, detail tabs, ViewMode/EditMode), **Wizard** (multi-step with per-step validation)
- **BorderPanel**, **TabPanel**, **FlexPanel**, **TreePanel**, **TilePanel**, **HtmlPanel**, **StatusBar**, **ToolBar**
- **Enterprise**: **ChartPanel** (Chart.js), **CalendarPanel**, **GoogleMap**, **Dashboard** (auto-refresh)
- **Card view**: the List controller with a `TemplateFileName` for custom HTML cards, with full CRUD

### Data and forms

- **Database agnostic** through FireDAC (preferred), DBExpress or ADO
- **Detail CRUD in memory**: add, edit and delete detail records with no database round-trip until Save All
- **Form state machine**: ViewMode (Edit / Save All / Close) and EditMode (Save / Cancel)
- **Filter panel**: `FreeSearch`, `List`, `DynaList`, `ButtonList`, `DynaButtonList`, plus `DateSearch`, `TimeSearch`, `DateTimeSearch`, `NumericSearch`, `BooleanSearch`
- **Custom layouts** for grid and form, including a multi-page form with collapsible regions

### Mobile

- Automatic detection from user agent and screen size, fullscreen dialogs, a **TilePanel** menu for phone home pages, and a home view chosen per size (`HomeTinyView`, `HomeSmallView`, `HomeView`)

### Authentication and tools

- Pluggable authenticators `DB`, `DBCrypt`, `TextFile`, `DBServer`, `OSDB`, `Null` and access controllers `DB`, `Null`, with BCrypt hashing, TOTP two-factor and QR code generation
- CSV and Excel export, SQL tool, file download and upload; FlexCel, ReportBuilder and DebenuQuickPDF integration (commercial)

### Deployment

- **Standalone** (VCL desktop or Windows service, embedded Indy HTTP server), **Desktop Embedded** (WebView2 in a VCL window), **Console**, **IIS** (ISAPI) and **Apache** (module)

### KIDE<sup>x</sup> (visual IDE — Enterprise)

- RTTI-based property discovery, replacing 215 template files, through six YAML attributes; SVG icons; database reverse engineering; project wizard, validators and tree editors

### Examples

- **HelloKitto** (party and invitation manager), **TasKitto** (activity tracking with dashboard, charts and calendar), **KEmployee** (employee management with master-detail and card views)

### Supported Delphi versions

Delphi 10.4 to the latest, Win32 and Win64.

![Supporting Delphi](./images/SupportingDelphi.jpg)
