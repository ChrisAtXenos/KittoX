unit UseKitto;

interface

uses
  // ---------------------------------------------------------------------------
  // DELPHI ENTERPRISE (or ARCHITECT) REQUIRED for the client/server database
  // drivers the wizard emits below ({DB/FD} -> FireDAC.Phys.* drivers, {DB/DBX}
  // -> DBExpress Data.DBX* drivers) for remote DBMS (MS SQL Server, Oracle,
  // PostgreSQL, MySQL, Firebird...). Access to client/server databases is a
  // feature of the Enterprise and Architect editions only. Delphi PROFESSIONAL
  // ships FireDAC/DBExpress with local/embedded drivers only (SQLite, InterBase
  // ToGo), so on a Professional license these uses do NOT compile (e.g. "unit
  // FireDAC.Phys.MSSQL not found"). A KittoX web app normally connects to a
  // client/server DB, so building it needs a license upgrade from Professional
  // to Enterprise (or Architect). With Professional you can only target a local
  // DB (SQLite/InterBase). (ADO/dbGo and SQLite/InterBase are in Professional.)
  // ---------------------------------------------------------------------------
  {DB/ADO},
  {DB/FD},
  {DB/DBX},{AC}{Auth}
  Kitto.Metadata.ModelImplementation,
  Kitto.Metadata.ViewBuilders,
  // Activates the file logger endpoint declared in Config.yaml under
  // Log/TextFile (auto-registered via the unit's initialization).
  EF.Logger.TextFile,
  Kitto.Html.All
  ;

implementation

end.
