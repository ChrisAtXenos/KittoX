To use the Sport Club Manager database you need to:

1) Create an empty database named "KITTOXSCM" on your MS SQL Server instance.
2) Run DB\SCM_SQLServer_DDL.sql against it (123 tables, 25 views, 11 functions),
   then DB\SCM_SQLServer_Data.sql (about 12.400 rows of demo data). Neither script
   carries a USE statement: select the target database before running them.
3) Optionally edit the database connection parameters in Home\Metadata\Config.yaml.

Demo accounts, all with password "demo1234":

  ADMIN              administrator  -> the full management interface
  SEGRETERIA         office account -> the same interface, fewer rights
  SYSDBA             administrator  -> what the login form pre-fills
  BLDDRD68B12C523H   a parent       -> the member interface (three children)

A member's user name is their tax code: that is how the application asks parents
to sign in, and the login form says "Codice Fiscale" for that reason. Any tax code
in the NOMINATIVI table works. The passepartout password ("password" in
Config.yaml) also gets you in as any existing user.

The demo data contains no real person, club or account. DB\README.md tells what was
anonymised and how, and DB\SCM_SQLServer_Anonymize.sql is the script that did it.

Documents uploaded by the application (attachments, medical certificates, invoices)
are written under KittoDocs\SCM, which ships empty.

URL to launch demo
------------------
http://localhost:2220/scm/

(the trailing slash is required)
