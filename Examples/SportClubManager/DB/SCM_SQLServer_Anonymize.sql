/*-------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------*/

/*  Sport Club Manager - anonymisation of the demo database.
    ---------------------------------------------------------------------------
    This is the script the shipped SCM_SQLServer_Data.sql was produced with. It
    is kept in the repository because it documents how the demo data came to be,
    and because it can be run again if the demo database is rebuilt from a real
    club's archive.

    It replaces, in place, every piece of personal data: surnames, first names,
    tax codes, addresses, phone numbers, e-mail addresses, IBANs, photographs,
    free-text notes, the mail queue, the club's own identity, and the user
    accounts with their passwords.

    RUN IT ON A COPY. It refuses to run on a database named SCM_MILLENNIUM, but
    that guard protects one name, not your data: point it at a restored copy.

    The tax codes it generates are structurally valid and keep their check
    character, because the application validates both (CheckTaxCodeFormat,
    CheckTaxCodeChecksum) and derives birth date, gender and birthplace from the
    code itself (SetRegistryDataFromTaxCode). Only the six name letters and the
    check character are recomputed: everything the code says about when and
    where a person was born is carried over from the original, which identifies
    nobody once the name is gone.

    After running it, sign in with the demo password below, or with the
    passepartout in Config.yaml.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = 'SCM_MILLENNIUM'
BEGIN
    RAISERROR('This script rewrites every personal field. Run it on a COPY, not on SCM_MILLENNIUM.', 20, -1) WITH LOG;
END;

/*  Every account ends up on the same password, 'demo1234', stored the way the
    framework stores one: the lowercase hex of its MD5 (EF.StrUtils.GetStringHash).
    The club becomes 'A.S.D. ETHEA', which is what Config.yaml already names. */
IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'APPUSER')
   AND EXISTS (SELECT 1 FROM APPUSER WHERE PASSWD =
       LOWER(CONVERT(varchar(32), HASHBYTES('MD5', CAST('demo1234' AS varchar(30))), 2)))
BEGIN
    /*  A second run would map already synthetic names onto other synthetic
        ones and pull the tax codes out of step with them. */
    RAISERROR('This database is already anonymised: reload the real data before running the script again.', 20, -1) WITH LOG;
END;

PRINT 'Anonymising ' + DB_NAME() + ' - demo password: demo1234';

/* ===========================================================================
   1. Tax code helpers
   =========================================================================== */
IF OBJECT_ID('dbo.fn_AnonNameCode') IS NOT NULL DROP FUNCTION dbo.fn_AnonNameCode;
IF OBJECT_ID('dbo.fn_AnonCheckChar') IS NOT NULL DROP FUNCTION dbo.fn_AnonCheckChar;
IF OBJECT_ID('dbo.AnonCharValue') IS NOT NULL DROP TABLE dbo.AnonCharValue;
GO

/*  The three letters a tax code takes from a surname or a first name:
    consonants in order, then vowels, then X as padding. For a first name with
    four or more consonants the second one is skipped, which is the only
    difference between the two cases. */
CREATE FUNCTION dbo.fn_AnonNameCode(@Name varchar(100), @IsFirstName bit)
RETURNS char(3)
AS
BEGIN
    DECLARE @s varchar(100) = UPPER(@Name), @i int = 1, @c char(1);
    DECLARE @cons varchar(100) = '', @vow varchar(100) = '';

    WHILE @i <= LEN(@s)
    BEGIN
        SET @c = SUBSTRING(@s, @i, 1);
        IF @c BETWEEN 'A' AND 'Z'
        BEGIN
            IF @c IN ('A', 'E', 'I', 'O', 'U')
                SET @vow = @vow + @c;
            ELSE
                SET @cons = @cons + @c;
        END;
        SET @i = @i + 1;
    END;

    IF @IsFirstName = 1 AND LEN(@cons) >= 4
        SET @cons = SUBSTRING(@cons, 1, 1) + SUBSTRING(@cons, 3, 2);

    RETURN LEFT(@cons + @vow + 'XXX', 3);
END;
GO

/*  Character values of the check-digit algorithm: one column for the odd
    positions, one for the even ones. */
CREATE TABLE dbo.AnonCharValue (C char(1) PRIMARY KEY, OddValue int NOT NULL, EvenValue int NOT NULL);
GO

INSERT INTO dbo.AnonCharValue (C, OddValue, EvenValue) VALUES
 ('0',1,0),('1',0,1),('2',5,2),('3',7,3),('4',9,4),('5',13,5),('6',15,6),('7',17,7),('8',19,8),('9',21,9),
 ('A',1,0),('B',0,1),('C',5,2),('D',7,3),('E',9,4),('F',13,5),('G',15,6),('H',17,7),('I',19,8),('J',21,9),
 ('K',2,10),('L',4,11),('M',18,12),('N',20,13),('O',11,14),('P',3,15),('Q',6,16),('R',8,17),('S',12,18),
 ('T',14,19),('U',16,20),('V',10,21),('W',22,22),('X',25,23),('Y',24,24),('Z',23,25);
GO

/*  The sixteenth character of a tax code, from the first fifteen. */
CREATE FUNCTION dbo.fn_AnonCheckChar(@First15 varchar(15))
RETURNS char(1)
AS
BEGIN
    DECLARE @i int = 1, @sum int = 0, @v int;
    WHILE @i <= 15
    BEGIN
        SELECT @v = CASE WHEN @i % 2 = 1 THEN OddValue ELSE EvenValue END
        FROM dbo.AnonCharValue WHERE C = SUBSTRING(UPPER(@First15), @i, 1);
        IF @v IS NULL RETURN NULL;   -- not a well formed code: leave it alone
        SET @sum = @sum + @v;
        SET @i = @i + 1;
    END;
    RETURN CHAR(65 + (@sum % 26));
END;
GO

/* ===========================================================================
   2. Synthetic pools
   =========================================================================== */
IF OBJECT_ID('dbo.AnonSurname') IS NOT NULL DROP TABLE dbo.AnonSurname;
IF OBJECT_ID('dbo.AnonFirstName') IS NOT NULL DROP TABLE dbo.AnonFirstName;
IF OBJECT_ID('dbo.AnonStreet') IS NOT NULL DROP TABLE dbo.AnonStreet;
IF OBJECT_ID('dbo.AnonPerson') IS NOT NULL DROP TABLE dbo.AnonPerson;

CREATE TABLE dbo.AnonSurname (N int PRIMARY KEY, S varchar(30) NOT NULL);
INSERT INTO dbo.AnonSurname (N, S) VALUES
 (1,'Adriani'),(2,'Alberti'),(3,'Amadori'),(4,'Andreoli'),(5,'Arduini'),(6,'Baldini'),
 (7,'Barbieri'),(8,'Bellotti'),(9,'Benedetti'),(10,'Bertani'),(11,'Bertolazzi'),(12,'Boschi'),
 (13,'Brancaleoni'),(14,'Calabrese'),(15,'Camerini'),(16,'Cantoni'),(17,'Carminati'),(18,'Casadei'),
 (19,'Castaldini'),(20,'Cavalli'),(21,'Cerutti'),(22,'Chiodi'),(23,'Cimino'),(24,'Colombini'),
 (25,'Comini'),(26,'Corsini'),(27,'Cremonesi'),(28,'Dalmasso'),(29,'Dominici'),(30,'Donati'),
 (31,'Fabbri'),(32,'Falcone'),(33,'Fantini'),(34,'Ferrero'),(35,'Fiorini'),(36,'Fontanesi'),
 (37,'Franchini'),(38,'Fumagalli'),(39,'Gallina'),(40,'Garbini'),(41,'Gattoni'),(42,'Ghezzi'),
 (43,'Giordani'),(44,'Gobbi'),(45,'Granata'),(46,'Grassi'),(47,'Guerrini'),(48,'Iannone'),
 (49,'Invernizzi'),(50,'Laghi'),(51,'Lanzoni'),(52,'Leoni'),(53,'Lodigiani'),(54,'Lorenzi'),
 (55,'Maggioni'),(56,'Malusardi'),(57,'Mancuso'),(58,'Marchetti'),(59,'Mariani'),(60,'Martinelli'),
 (61,'Mazzoni'),(62,'Melloni'),(63,'Merlini'),(64,'Molteni'),(65,'Montanari'),(66,'Morandi'),
 (67,'Moretti'),(68,'Nardi'),(69,'Negrini'),(70,'Oliva'),(71,'Orlandi'),(72,'Pagani'),
 (73,'Palmieri'),(74,'Panzeri'),(75,'Parisi'),(76,'Pedretti'),(77,'Pellegrini'),(78,'Perego'),
 (79,'Pierini'),(80,'Pozzi'),(81,'Quadri'),(82,'Ravasi'),(83,'Rinaldi'),(84,'Rovelli'),
 (85,'Sacchi'),(86,'Salerno'),(87,'Sartori'),(88,'Scala'),(89,'Sironi'),(90,'Spinelli'),
 (91,'Tagliabue'),(92,'Tosi'),(93,'Vaccari'),(94,'Ventura'),(95,'Zaccaria'),(96,'Zanotti');

CREATE TABLE dbo.AnonFirstName (Sex char(1), N int, S varchar(30) NOT NULL, PRIMARY KEY (Sex, N));
INSERT INTO dbo.AnonFirstName (Sex, N, S) VALUES
 ('M',1,'Alessio'),('M',2,'Anselmo'),('M',3,'Bruno'),('M',4,'Corrado'),('M',5,'Damiano'),
 ('M',6,'Edoardo'),('M',7,'Fabrizio'),('M',8,'Gaudenzio'),('M',9,'Giulio'),('M',10,'Ignazio'),
 ('M',11,'Lodovico'),('M',12,'Manuele'),('M',13,'Nazario'),('M',14,'Osvaldo'),('M',15,'Patrizio'),
 ('M',16,'Romualdo'),('M',17,'Rodolfo'),('M',18,'Saverio'),('M',19,'Sebastiano'),('M',20,'Tommaso'),
 ('M',21,'Ubaldo'),('M',22,'Valerio'),('M',23,'Vittorio'),('M',24,'Zeno'),
 ('F',1,'Adelaide'),('F',2,'Alessia'),('F',3,'Beatrice'),('F',4,'Clementina'),('F',5,'Doriana'),
 ('F',6,'Eleonora'),('F',7,'Federica'),('F',8,'Gabriella'),('F',9,'Giulietta'),('F',10,'Ilaria'),
 ('F',11,'Lucrezia'),('F',12,'Manuela'),('F',13,'Nicoletta'),('F',14,'Ornella'),('F',15,'Patrizia'),
 ('F',16,'Rebecca'),('F',17,'Rosalia'),('F',18,'Samantha'),('F',19,'Serena'),('F',20,'Teresa'),
 ('F',21,'Ursula'),('F',22,'Valentina'),('F',23,'Viviana'),('F',24,'Zita');

CREATE TABLE dbo.AnonStreet (N int PRIMARY KEY, S varchar(40) NOT NULL);
INSERT INTO dbo.AnonStreet (N, S) VALUES
 (1,'Via dei Tigli'),(2,'Via delle Betulle'),(3,'Via dei Platani'),(4,'Via degli Aceri'),
 (5,'Via dei Cedri'),(6,'Viale delle Robinie'),(7,'Via dei Gelsi'),(8,'Via delle Magnolie'),
 (9,'Via dei Faggi'),(10,'Via degli Olmi'),(11,'Corso dei Larici'),(12,'Via dei Pioppi'),
 (13,'Via delle Querce'),(14,'Via dei Frassini'),(15,'Via degli Ontani'),(16,'Via dei Carpini'),
 (17,'Piazza dei Salici'),(18,'Via delle Acacie'),(19,'Via dei Noccioli'),(20,'Via dei Bagolari'),
 (21,'Via degli Ippocastani'),(22,'Via dei Ciliegi'),(23,'Via delle Mimose'),(24,'Via dei Lecci');

/* ===========================================================================
   3. One synthetic identity per person, wherever the person appears
   ===========================================================================
   The map is keyed on the surname/first-name pair, which is what the archive
   repeats from table to table -- the tax code is carried along, and is the only
   thing the new code keeps: its year, month, day and place of birth.        */
CREATE TABLE dbo.AnonPerson (
    OldLast     varchar(100) NOT NULL,
    OldFirst    varchar(100) NOT NULL,
    OldCF       varchar(16)  NULL,
    Sex         char(1)      NOT NULL,
    Seq         int          NOT NULL,
    NewLast     varchar(100) NULL,
    NewFirst    varchar(100) NULL,
    NewCF       varchar(16)  NULL,
    NewEmail    varchar(100) NULL,
    NewPhone    varchar(30)  NULL,
    NewMobile   varchar(30)  NULL,
    NewAddress  varchar(100) NULL,
    NewIban     varchar(30)  NULL,
    PRIMARY KEY (OldLast, OldFirst)
);

WITH P AS (
    SELECT COGNOME AS L, NOME AS F, CODFISC AS CF FROM NOMINATIVI
    UNION SELECT COGNOME, NOME, CODFISC FROM ISCRIZIONI
    UNION SELECT COGNOME_GENITORE, NOME_GENITORE, COD_FISCALE_GENITORE FROM ISCRIZIONI
    UNION SELECT COGNOME, NOME, CODICE_FISCALE FROM LIBRO_SOCI
    UNION SELECT COGNOME, NOME, CODFISC FROM DETRAZIONI_FISCALI
    UNION SELECT ISCR_COGNOME, ISCR_NOME, ISCR_CODFISC FROM DETRAZIONI_FISCALI
    UNION SELECT PRES_COGNOME, PRES_NOME, NULL FROM DETRAZIONI_FISCALI
    UNION SELECT COGNOME, NOME, CODFISCALE FROM CLIENTI
    UNION SELECT COGNOME, NOME, CODFISCALE FROM FORNITORI
    UNION SELECT LAST_NAME, FIRST_NAME, FISCAL_ID FROM APPUSER
    /*  The old staff is not in the registry: their name lives only in the
        description, "Surname Firstname", so it has to reach the map for the
        sweep to find it. */
    UNION SELECT LEFT(DX, CHARINDEX(' ', DX + ' ') - 1),
                 LTRIM(SUBSTRING(DX, CHARINDEX(' ', DX + ' '), 200)), NULL
          FROM ADDETTI WHERE NOMINATIVOID IS NULL AND DX LIKE '% %'
), G AS (
    SELECT LTRIM(RTRIM(L)) AS OldLast, LTRIM(RTRIM(ISNULL(F,''))) AS OldFirst,
           MAX(CASE WHEN LEN(CF) = 16 THEN CF END) AS OldCF
    FROM P
    WHERE L IS NOT NULL AND LTRIM(RTRIM(L)) <> ''
    GROUP BY LTRIM(RTRIM(L)), LTRIM(RTRIM(ISNULL(F,'')))
)
INSERT INTO dbo.AnonPerson (OldLast, OldFirst, OldCF, Sex, Seq)
SELECT OldLast, OldFirst, OldCF,
       /* the tax code encodes the sex in the day of birth: 41..71 means female */
       CASE WHEN OldCF IS NOT NULL AND ISNUMERIC(SUBSTRING(OldCF, 10, 2)) = 1
                 AND CAST(SUBSTRING(OldCF, 10, 2) AS int) > 40 THEN 'F' ELSE 'M' END,
       ROW_NUMBER() OVER (ORDER BY OldLast, OldFirst)
FROM G;

GO

/*  A family shares its surname, and in the archive it shares its address and
    its landline too: so the surname is mapped once per surname, not once per
    person, and the street and telephone follow it. Only the first name, the
    mobile number, the e-mail address, the IBAN and the tax code are per
    person -- and within one family the first names stay distinct. */
IF OBJECT_ID('dbo.AnonLastMap') IS NOT NULL DROP TABLE dbo.AnonLastMap;
CREATE TABLE dbo.AnonLastMap (
    OldLast varchar(100) PRIMARY KEY,
    N       int          NOT NULL,
    NewLast varchar(100) NULL
);

INSERT INTO dbo.AnonLastMap (OldLast, N)
SELECT OldLast, ROW_NUMBER() OVER (ORDER BY OldLast)
FROM (SELECT DISTINCT OldLast FROM dbo.AnonPerson) d;

UPDATE m SET NewLast = s.S
FROM dbo.AnonLastMap m
JOIN dbo.AnonSurname s ON s.N = ((m.N - 1) % (SELECT COUNT(*) FROM dbo.AnonSurname)) + 1;

UPDATE p SET
    NewLast    = m.NewLast,
    NewFirst   = f.S,
    NewAddress = st.S + ' ' + CAST(((m.N * 7) % 90) + 1 AS varchar(3)),
    NewPhone   = '02 ' + RIGHT('0000000' + CAST(1000000 + m.N * 613 AS varchar(10)), 7),
    NewMobile  = '33' + RIGHT('00000000' + CAST(10000000 + p.Seq * 971 AS varchar(10)), 8),
    NewIban    = 'IT60X0542811101' + RIGHT('000000000000' + CAST(p.Seq AS varchar(12)), 12)
FROM dbo.AnonPerson p
JOIN dbo.AnonLastMap m ON m.OldLast = p.OldLast
JOIN (SELECT OldLast, OldFirst,
             ROW_NUMBER() OVER (PARTITION BY OldLast ORDER BY OldFirst) AS RN
      FROM dbo.AnonPerson) r ON r.OldLast = p.OldLast AND r.OldFirst = p.OldFirst
JOIN dbo.AnonFirstName f ON f.Sex = p.Sex AND f.N = ((m.N + r.RN - 2) % 24) + 1
JOIN dbo.AnonStreet st ON st.N = ((m.N - 1) % 24) + 1;

UPDATE dbo.AnonPerson SET NewEmail = LOWER(NewFirst + '.' + NewLast + '@example.com');

/*  The new tax code: six letters from the new name, everything about the birth
    from the old code, and a freshly computed check character. */
UPDATE dbo.AnonPerson SET
    NewCF = UPPER(dbo.fn_AnonNameCode(NewLast, 0) + dbo.fn_AnonNameCode(NewFirst, 1)
          + SUBSTRING(OldCF, 7, 9))
WHERE OldCF IS NOT NULL;

UPDATE dbo.AnonPerson SET
    NewCF = NewCF + dbo.fn_AnonCheckChar(NewCF)
WHERE NewCF IS NOT NULL AND LEN(NewCF) = 15;

DECLARE @nPers int = (SELECT COUNT(*) FROM dbo.AnonPerson);
DECLARE @nCF int = (SELECT COUNT(*) FROM dbo.AnonPerson WHERE NewCF IS NOT NULL);
DECLARE @nDupCF int = @nCF - (SELECT COUNT(DISTINCT NewCF) FROM dbo.AnonPerson WHERE NewCF IS NOT NULL);
DECLARE @nFam int = (SELECT COUNT(*) FROM dbo.AnonLastMap);
PRINT 'Persone: ' + CAST(@nPers AS varchar(10))
    + ' - cognomi: ' + CAST(@nFam AS varchar(10))
    + ' - codici fiscali: ' + CAST(@nCF AS varchar(10))
    + ' - duplicati: ' + CAST(@nDupCF AS varchar(10));
GO

/* ===========================================================================
   4. The structured personal fields, table by table
   =========================================================================== */
SET NOCOUNT ON;

/* --- people ------------------------------------------------------------- */
UPDATE n SET
    COGNOME   = p.NewLast,
    NOME      = p.NewFirst,
    CODFISC   = ISNULL(p.NewCF, n.CODFISC),
    INDIRIZZO = p.NewAddress,
    TELEFONO  = CASE WHEN NULLIF(n.TELEFONO, '') IS NULL THEN n.TELEFONO ELSE p.NewPhone END,
    CELLULARE = CASE WHEN NULLIF(n.CELLULARE, '') IS NULL THEN n.CELLULARE ELSE p.NewMobile END,
    EMAIL     = CASE WHEN NULLIF(n.EMAIL, '') IS NULL THEN n.EMAIL ELSE p.NewEmail END,
    IBAN      = CASE WHEN NULLIF(n.IBAN, '') IS NULL THEN n.IBAN ELSE p.NewIban END,
    FOTO      = NULL
FROM NOMINATIVI n
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(n.COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(n.NOME, '')));

/* --- subscriptions: the subscriber ... ---------------------------------- */
UPDATE i SET
    COGNOME   = p.NewLast,
    NOME      = p.NewFirst,
    CODFISC   = ISNULL(p.NewCF, i.CODFISC),
    INDIRIZZO = p.NewAddress,
    CELLULARE = CASE WHEN NULLIF(i.CELLULARE, '') IS NULL THEN i.CELLULARE ELSE p.NewMobile END,
    EMAIL     = CASE WHEN NULLIF(i.EMAIL, '') IS NULL THEN i.EMAIL ELSE p.NewEmail END
FROM ISCRIZIONI i
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(i.COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(i.NOME, '')));

/* --- ... and the parent who enrolled them ------------------------------- */
UPDATE i SET
    COGNOME_GENITORE      = p.NewLast,
    NOME_GENITORE         = p.NewFirst,
    COD_FISCALE_GENITORE  = ISNULL(p.NewCF, i.COD_FISCALE_GENITORE),
    TELEFONO_GENITORE     = CASE WHEN NULLIF(i.TELEFONO_GENITORE, '') IS NULL THEN i.TELEFONO_GENITORE ELSE p.NewPhone END,
    CELLULARE_GENITORE    = CASE WHEN NULLIF(i.CELLULARE_GENITORE, '') IS NULL THEN i.CELLULARE_GENITORE ELSE p.NewMobile END,
    EMAIL_GENITORE        = CASE WHEN NULLIF(i.EMAIL_GENITORE, '') IS NULL THEN i.EMAIL_GENITORE ELSE p.NewEmail END
FROM ISCRIZIONI i
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(i.COGNOME_GENITORE))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(i.NOME_GENITORE, '')));

UPDATE ISCRIZIONI SET
    INDIRIZZO_IP = CASE WHEN NULLIF(INDIRIZZO_IP, '') IS NULL THEN INDIRIZZO_IP ELSE '127.0.0.1' END,
    NOTE = NULL,
    NOTE_ADMIN = NULL;

/* --- members register --------------------------------------------------- */
UPDATE l SET
    COGNOME        = p.NewLast,
    NOME           = p.NewFirst,
    CODICE_FISCALE = ISNULL(p.NewCF, l.CODICE_FISCALE),
    INDIRIZZO      = p.NewAddress,
    MOTIVAZIONE    = NULL
FROM LIBRO_SOCI l
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(l.COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(l.NOME, '')));

/* --- tax deductions: holder, subscriber, and who filed it --------------- */
UPDATE d SET
    COGNOME   = p.NewLast,
    NOME      = p.NewFirst,
    CODFISC   = ISNULL(p.NewCF, d.CODFISC),
    INDIRIZZO = p.NewAddress
FROM DETRAZIONI_FISCALI d
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(d.COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(d.NOME, '')));

UPDATE d SET
    ISCR_COGNOME = p.NewLast,
    ISCR_NOME    = p.NewFirst,
    ISCR_CODFISC = ISNULL(p.NewCF, d.ISCR_CODFISC)
FROM DETRAZIONI_FISCALI d
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(d.ISCR_COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(d.ISCR_NOME, '')));

UPDATE d SET
    PRES_COGNOME = p.NewLast,
    PRES_NOME    = p.NewFirst
FROM DETRAZIONI_FISCALI d
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(d.PRES_COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(d.PRES_NOME, '')));

/* --- customers and suppliers -------------------------------------------- */
UPDATE c SET
    COGNOME       = p.NewLast,
    NOME          = p.NewFirst,
    CODFISCALE    = ISNULL(p.NewCF, c.CODFISCALE),
    INDIRIZZO     = p.NewAddress,
    INDIRIZZO_AMM = CASE WHEN NULLIF(c.INDIRIZZO_AMM, '') IS NULL THEN c.INDIRIZZO_AMM ELSE p.NewAddress END,
    IBAN          = CASE WHEN NULLIF(c.IBAN, '') IS NULL THEN c.IBAN ELSE p.NewIban END,
    EMAIL         = CASE WHEN NULLIF(c.EMAIL, '') IS NULL THEN c.EMAIL ELSE p.NewEmail END,
    EMAIL_PEC     = CASE WHEN NULLIF(c.EMAIL_PEC, '') IS NULL THEN c.EMAIL_PEC ELSE p.NewEmail END,
    TELEFONO      = CASE WHEN NULLIF(c.TELEFONO, '') IS NULL THEN c.TELEFONO ELSE p.NewPhone END,
    CELLULARE     = CASE WHEN NULLIF(c.CELLULARE, '') IS NULL THEN c.CELLULARE ELSE p.NewMobile END
FROM CLIENTI c
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(c.COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(c.NOME, '')));

UPDATE f SET
    COGNOME       = p.NewLast,
    NOME          = p.NewFirst,
    CODFISCALE    = ISNULL(p.NewCF, f.CODFISCALE),
    INDIRIZZO     = p.NewAddress,
    INDIRIZZO_AMM = CASE WHEN NULLIF(f.INDIRIZZO_AMM, '') IS NULL THEN f.INDIRIZZO_AMM ELSE p.NewAddress END,
    IBAN          = CASE WHEN NULLIF(f.IBAN, '') IS NULL THEN f.IBAN ELSE p.NewIban END,
    EMAIL         = CASE WHEN NULLIF(f.EMAIL, '') IS NULL THEN f.EMAIL ELSE p.NewEmail END,
    EMAIL_PEC     = CASE WHEN NULLIF(f.EMAIL_PEC, '') IS NULL THEN f.EMAIL_PEC ELSE p.NewEmail END,
    TELEFONO      = CASE WHEN NULLIF(f.TELEFONO, '') IS NULL THEN f.TELEFONO ELSE p.NewPhone END,
    CELLULARE     = CASE WHEN NULLIF(f.CELLULARE, '') IS NULL THEN f.CELLULARE ELSE p.NewMobile END
FROM FORNITORI f
JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(f.COGNOME))
                     AND p.OldFirst = LTRIM(RTRIM(ISNULL(f.NOME, '')));

/* ===========================================================================
   5. User accounts
   ===========================================================================
   Members sign in with their tax code, so their user name follows the new one.
   The three administrator accounts, which carried the names of real people, are
   replaced by role accounts; SYSDBA stays, it names nobody. Every password
   becomes the same documented demo one, and nobody is forced to change it.  */
IF OBJECT_ID('dbo.AnonUser') IS NOT NULL DROP TABLE dbo.AnonUser;
CREATE TABLE dbo.AnonUser (OldId varchar(50) PRIMARY KEY, NewId varchar(50) NOT NULL);

/*  The names of the accounts are the first thing anybody types into the demo,
    so they are plain: SYSDBA keeps its own, the administrators become ADMIN
    (and ADMIN2, if there is more than one), the office accounts SEGRETERIA,
    and every member's user name is their own new tax code, which is how the
    application expects a member to sign in. */
WITH U AS (
    SELECT u.ID, u.PROFILEID, u.ADMINISTRATOR, p.NewCF,
           ROW_NUMBER() OVER (PARTITION BY CASE WHEN u.ID = 'SYSDBA' THEN 0
                                                WHEN u.PROFILEID = 'USER' THEN 1
                                                WHEN u.ADMINISTRATOR = 1 THEN 2
                                                ELSE 3 END
                              ORDER BY u.ID) AS RN
    FROM APPUSER u
    LEFT JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(ISNULL(u.LAST_NAME, '')))
                              AND p.OldFirst = LTRIM(RTRIM(ISNULL(u.FIRST_NAME, '')))
)
INSERT INTO dbo.AnonUser (OldId, NewId)
SELECT ID,
       CASE
         WHEN ID = 'SYSDBA' THEN 'SYSDBA'
         WHEN PROFILEID = 'USER' AND NewCF IS NOT NULL THEN NewCF
         WHEN PROFILEID = 'USER' THEN 'USER' + RIGHT('000' + CAST(RN AS varchar(3)), 3)
         WHEN ADMINISTRATOR = 1 THEN 'ADMIN' + CASE WHEN RN = 1 THEN '' ELSE CAST(RN AS varchar(2)) END
         ELSE 'SEGRETERIA' + CASE WHEN RN = 1 THEN '' ELSE CAST(RN AS varchar(2)) END
       END
FROM U;

/*  the three tables that record who entered a row */
UPDATE t SET UTENTE_INSERIMENTOID = u.NewId
FROM ISCRIZIONI t JOIN dbo.AnonUser u ON u.OldId = t.UTENTE_INSERIMENTOID;
UPDATE t SET UTENTE_INSERIMENTOID = u.NewId
FROM MOVIMENTI_CONTABILI t JOIN dbo.AnonUser u ON u.OldId = t.UTENTE_INSERIMENTOID;
UPDATE t SET UTENTE_INSERIMENTOID = u.NewId
FROM RIGHE_CONTABILI t JOIN dbo.AnonUser u ON u.OldId = t.UTENTE_INSERIMENTOID;

UPDATE u SET
    ID            = a.NewId,
    LAST_NAME     = ISNULL(p.NewLast, u.LAST_NAME),
    FIRST_NAME    = ISNULL(p.NewFirst, u.FIRST_NAME),
    DX            = ISNULL(p.NewLast + ' ' + p.NewFirst, a.NewId),
    FISCAL_ID     = CASE WHEN NULLIF(u.FISCAL_ID, '') IS NULL THEN u.FISCAL_ID ELSE ISNULL(p.NewCF, u.FISCAL_ID) END,
    EMAIL_ADDRESS = CASE WHEN NULLIF(u.EMAIL_ADDRESS, '') IS NULL THEN u.EMAIL_ADDRESS
                         ELSE ISNULL(p.NewEmail, LOWER(a.NewId) + '@example.com') END,
    PHONE_NUMBER  = CASE WHEN NULLIF(u.PHONE_NUMBER, '') IS NULL THEN u.PHONE_NUMBER ELSE ISNULL(p.NewPhone, '02 1000000') END,
    IP_ADDRESS    = NULL,
    PHOTO         = NULL,
    PASSWD        = LOWER(CONVERT(varchar(32), HASHBYTES('MD5', CAST('demo1234' AS varchar(30))), 2)),
    MUST_CHANGE_PASSWORD = 0,
    ACCESS_DENIED = 0
FROM APPUSER u
JOIN dbo.AnonUser a ON a.OldId = u.ID
LEFT JOIN dbo.AnonPerson p ON p.OldLast = LTRIM(RTRIM(ISNULL(u.LAST_NAME, '')))
                          AND p.OldFirst = LTRIM(RTRIM(ISNULL(u.FIRST_NAME, '')));

/* ===========================================================================
   6. The club's own identity, and the other organisations
   =========================================================================== */
UPDATE CONFIGURATION SET
    COMPANYNAME   = 'A.S.D. ETHEA',
    DX            = 'A.S.D. ETHEA',
    FISCAL_CODE   = '97123456789',
    VATNUM        = '01234567890',
    ADDRESS       = 'Via dei Tigli 1',
    SUPPORT_EMAIL = 'support@example.com',
    INFO_EMAIL    = 'info@example.com',
    SITO_INTERNET = 'https://www.example.com',
    TELEFONO      = '02 1000000',
    FAX           = '02 1000001',
    LOGO_SOC      = NULL;

UPDATE s SET
    DX = 'Societa Sportiva Demo ' + CAST(x.N AS varchar(3)),
    LOGO_FEDERAZIONE = NULL
FROM SOCIETA s
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM SOCIETA) x ON x.ID = s.ID;

UPDATE s SET
    DX              = 'Sponsor Demo ' + CAST(x.N AS varchar(3)),
    CODICE_FISCALE  = CASE WHEN NULLIF(s.CODICE_FISCALE, '') IS NULL THEN s.CODICE_FISCALE ELSE '9712345678' + CAST(x.N % 10 AS varchar(1)) END,
    PARTITA_IVA     = CASE WHEN NULLIF(s.PARTITA_IVA, '') IS NULL THEN s.PARTITA_IVA ELSE '0123456789' + CAST(x.N % 10 AS varchar(1)) END,
    INDIRIZZO       = CASE WHEN NULLIF(s.INDIRIZZO, '') IS NULL THEN s.INDIRIZZO ELSE 'Via delle Industrie ' + CAST(x.N AS varchar(3)) END,
    TELEFONO        = CASE WHEN NULLIF(s.TELEFONO, '') IS NULL THEN s.TELEFONO ELSE '02 200000' + CAST(x.N % 10 AS varchar(1)) END,
    LOGO            = NULL
FROM SPONSORS s
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM SPONSORS) x ON x.ID = s.ID;

UPDATE b SET
    DX        = 'Banca Demo ' + CAST(x.N AS varchar(3)),
    INDIRIZZO = 'Via dei Tigli ' + CAST(x.N AS varchar(3)),
    TELEFONO  = CASE WHEN NULLIF(b.TELEFONO, '') IS NULL THEN b.TELEFONO ELSE '02 300000' + CAST(x.N % 10 AS varchar(1)) END,
    EMAIL     = CASE WHEN NULLIF(b.EMAIL, '') IS NULL THEN b.EMAIL ELSE 'banca' + CAST(x.N AS varchar(3)) + '@example.com' END,
    IBAN      = CASE WHEN NULLIF(b.IBAN, '') IS NULL THEN b.IBAN ELSE 'IT60X05428111010000000000' + CAST(x.N % 100 AS varchar(2)) END
FROM BANCHE b
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM BANCHE) x ON x.ID = b.ID;

UPDATE a SET
    DX        = 'Ambulatorio Demo ' + CAST(x.N AS varchar(3)),
    INDIRIZZO = 'Via delle Betulle ' + CAST(x.N AS varchar(3)),
    TELEFONO  = CASE WHEN NULLIF(a.TELEFONO, '') IS NULL THEN a.TELEFONO ELSE '02 400000' + CAST(x.N % 10 AS varchar(1)) END,
    EMAIL     = CASE WHEN NULLIF(a.EMAIL, '') IS NULL THEN a.EMAIL ELSE 'ambulatorio' + CAST(x.N AS varchar(3)) + '@example.com' END
FROM AMBULATORI a
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM AMBULATORI) x ON x.ID = a.ID;

UPDATE i SET
    DX         = 'Impianto Sportivo ' + CAST(x.N AS varchar(3)),
    INDIRIZZO  = 'Via dello Sport ' + CAST(x.N AS varchar(3)),
    TELEFONO   = CASE WHEN NULLIF(i.TELEFONO, '') IS NULL THEN i.TELEFONO ELSE '02 500000' + CAST(x.N % 10 AS varchar(1)) END,
    FAX        = CASE WHEN NULLIF(i.FAX, '') IS NULL THEN i.FAX ELSE '02 510000' + CAST(x.N % 10 AS varchar(1)) END,
    FOTO       = NULL,
    CARTINA    = NULL,
    ITINERARIO = NULL
FROM IMPIANTI_SPORTIVI i
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM IMPIANTI_SPORTIVI) x ON x.ID = i.ID;

/* ===========================================================================
   7. Attachments, notes, file names and the mail queue
   =========================================================================== */
UPDATE SQUADRE SET LOGO = NULL, FOTO = NULL;

UPDATE ASSICURAZIONI        SET NOTE = NULL;
UPDATE DOCUMENTI            SET NOTE = NULL, NOME_FILE_ORIGINALE = NULL;
UPDATE FATTURECLIENTI       SET NOTE = NULL;
UPDATE MAGAZZINO            SET NOTE = NULL;
UPDATE MOVIMENTI_CONTABILI  SET NOTE = NULL, NOME_FATTURA_PDF = NULL, NOME_FATTURA_XML = NULL;
UPDATE PARTITE              SET NOTE = NULL;
UPDATE RATE_ISCRIZIONI      SET NOTE_ABBUONO = NULL;
UPDATE VERSAMENTI           SET ESTREMI = NULL;
UPDATE VISITEMEDICHE        SET NOTE = NULL, NOME_FILE_ORIGINALE = NULL;
UPDATE DETRAZIONI_FISCALI   SET NOME_FILE_ORIGINALE = NULL;

/*  The queue is a log of messages actually sent to actual people. */
DELETE FROM CODA_EMAIL;

/*  The templates stay -- they are what makes the demo show something -- but
    every address in them becomes a demo one. */
UPDATE TESTI_EMAIL SET
    EMAIL_FROM         = CASE WHEN NULLIF(EMAIL_FROM, '') IS NULL THEN EMAIL_FROM ELSE 'info@example.com' END,
    EMAIL_TO           = CASE WHEN NULLIF(EMAIL_TO, '') IS NULL THEN EMAIL_TO ELSE 'demo@example.com' END,
    EMAIL_CC           = CASE WHEN NULLIF(EMAIL_CC, '') IS NULL THEN EMAIL_CC ELSE 'demo@example.com' END,
    EMAIL_BCC          = CASE WHEN NULLIF(EMAIL_BCC, '') IS NULL THEN EMAIL_BCC ELSE 'demo@example.com' END,
    EMAIL_OPERATOR_TO  = CASE WHEN NULLIF(EMAIL_OPERATOR_TO, '') IS NULL THEN EMAIL_OPERATOR_TO ELSE 'demo@example.com' END,
    EMAIL_OPERATOR_CC  = CASE WHEN NULLIF(EMAIL_OPERATOR_CC, '') IS NULL THEN EMAIL_OPERATOR_CC ELSE 'demo@example.com' END,
    EMAIL_OPERATOR_BCC = CASE WHEN NULLIF(EMAIL_OPERATOR_BCC, '') IS NULL THEN EMAIL_OPERATOR_BCC ELSE 'demo@example.com' END,
    NO_EMAIL           = CASE WHEN NULLIF(NO_EMAIL, '') IS NULL THEN NO_EMAIL ELSE 'demo@example.com' END,
    EMAIL_ATTACH       = NULL;


/* ===========================================================================
   7b. Teams, companies and documents
   ===========================================================================
   What is left after the people: the names of the other clubs the archive
   played against, of the firms it bought from and sold to, and the numbers of
   the identity papers it filed. Every one of them names a real organisation or
   carries a real person's document number, and none of them is reachable from
   the person map.                                                           */
UPDATE s SET
    DX    = 'Squadra Demo ' + CAST(x.N AS varchar(3)),
    SIGLA = CASE WHEN NULLIF(s.SIGLA, '') IS NULL THEN s.SIGLA ELSE 'SQD' + CAST(x.N AS varchar(3)) END
FROM SQUADRE s
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM SQUADRE) x ON x.ID = s.ID;

UPDATE c SET
    DX          = 'Cliente Demo ' + CAST(x.N AS varchar(3)),
    PARTIVA     = CASE WHEN NULLIF(c.PARTIVA   , '') IS NULL THEN c.PARTIVA    ELSE '0123456789' + CAST(x.N % 10 AS varchar(1)) END,
    CODFISCALE  = CASE WHEN NULLIF(c.CODFISCALE, '') IS NULL THEN c.CODFISCALE ELSE '0123456789' + CAST(x.N % 10 AS varchar(1)) END,
    INDIRIZZO   = 'Via delle Industrie ' + CAST(x.N AS varchar(3)),
    EMAIL       = CASE WHEN NULLIF(c.EMAIL, '') IS NULL THEN c.EMAIL ELSE 'cliente' + CAST(x.N AS varchar(3)) + '@example.com' END,
    TELEFONO    = CASE WHEN NULLIF(c.TELEFONO, '') IS NULL THEN c.TELEFONO ELSE '02 600000' + CAST(x.N % 10 AS varchar(1)) END
FROM CLIENTI c
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM CLIENTI) x ON x.ID = c.ID
WHERE NULLIF(c.COGNOME, '') IS NULL;

UPDATE f SET
    DX          = 'Fornitore Demo ' + CAST(x.N AS varchar(3)),
    PARTIVA     = CASE WHEN NULLIF(f.PARTIVA   , '') IS NULL THEN f.PARTIVA    ELSE '0123456789' + CAST(x.N % 10 AS varchar(1)) END,
    CODFISCALE  = CASE WHEN NULLIF(f.CODFISCALE, '') IS NULL THEN f.CODFISCALE ELSE '0123456789' + CAST(x.N % 10 AS varchar(1)) END,
    INDIRIZZO   = 'Via delle Industrie ' + CAST(x.N AS varchar(3)),
    EMAIL       = CASE WHEN NULLIF(f.EMAIL, '') IS NULL THEN f.EMAIL ELSE 'fornitore' + CAST(x.N AS varchar(3)) + '@example.com' END,
    TELEFONO    = CASE WHEN NULLIF(f.TELEFONO, '') IS NULL THEN f.TELEFONO ELSE '02 700000' + CAST(x.N % 10 AS varchar(1)) END
FROM FORNITORI f
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM FORNITORI) x ON x.ID = f.ID
WHERE NULLIF(f.COGNOME, '') IS NULL;

/*  Identity cards, health cards, driving licences: the number is the person.
    The description keeps the kind of document and loses the number. */
UPDATE d SET
    NUMERO = CASE WHEN NULLIF(d.NUMERO, '') IS NULL THEN d.NUMERO
                  ELSE 'DEMO' + RIGHT('0000' + CAST(x.N AS varchar(4)), 4) END,
    DX     = CASE WHEN CHARINDEX(' N.', d.DX) > 0
                  THEN LEFT(d.DX, CHARINDEX(' N.', d.DX)) + 'N.DEMO' + RIGHT('0000' + CAST(x.N AS varchar(4)), 4)
                  ELSE d.DX END
FROM DOCUMENTI d
JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM DOCUMENTI) x ON x.ID = d.ID;

/*  The administrative address of a firm, its brand, the body that issued a
    document and the meeting point of a team: each of them names a real place
    or a real company. */
UPDATE c SET INDIRIZZO_AMM = 'Via delle Industrie ' + CAST(x.N AS varchar(3))
FROM CLIENTI c JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM CLIENTI) x ON x.ID = c.ID
WHERE NULLIF(c.INDIRIZZO_AMM, '') IS NOT NULL;

UPDATE f SET INDIRIZZO_AMM = 'Via delle Industrie ' + CAST(x.N AS varchar(3))
FROM FORNITORI f JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM FORNITORI) x ON x.ID = f.ID
WHERE NULLIF(f.INDIRIZZO_AMM, '') IS NOT NULL;

UPDATE s SET MARCHIO = 'Marchio Demo ' + CAST(x.N AS varchar(3))
FROM SPONSORS s JOIN (SELECT ID, ROW_NUMBER() OVER (ORDER BY ID) AS N FROM SPONSORS) x ON x.ID = s.ID
WHERE NULLIF(s.MARCHIO, '') IS NOT NULL;

UPDATE DOCUMENTI SET ENTE = 'Comune di Milano'
WHERE ENTE LIKE 'Comune%';

UPDATE SQUADRE SET RITROVO = 'Via dello Sport 1'
WHERE NULLIF(RITROVO, '') IS NOT NULL AND RITROVO LIKE '%Via%';

/*  A tournament named after the club's own town names the club. */
UPDATE CAMPIONATI SET DX = 'Torneo Demo'
WHERE DX LIKE '%Torneo%';

/*  The club's address, which Config.yaml calls A.S.D. ETHEA. */
UPDATE CONFIGURATION SET CITY = 'Milano', ZIP = '20100', PROVINCE = 'MI';

PRINT 'Campi strutturati riscritti.';
GO

/*  Safety net: whatever is left of the real names, tax codes or club strings in
    any text column -- descriptions, accounting entries, e-mail bodies, file
    names -- is replaced here. The targeted rewrites came first; this catches
    what they could not know about.

    Order matters: full names before single words, longer tokens before
    shorter, so that "Rossi Mario" is not half-replaced by the surname rule. */
SET NOCOUNT ON;

IF OBJECT_ID('dbo.AnonToken') IS NOT NULL DROP TABLE dbo.AnonToken;
CREATE TABLE dbo.AnonToken (
    Id     int IDENTITY PRIMARY KEY,
    Ord    int          NOT NULL,   -- 1 pairs, 2 tax codes, 3 surnames, 4 first names
    Tok    varchar(200) NOT NULL,
    NewTok varchar(200) NOT NULL
);
GO

SET NOCOUNT ON;

/* 1. "Surname Firstname" and "Firstname Surname", per person */
INSERT INTO dbo.AnonToken (Ord, Tok, NewTok)
SELECT 1, OldLast + ' ' + OldFirst, NewLast + ' ' + NewFirst
FROM dbo.AnonPerson WHERE OldFirst <> '' AND NewFirst IS NOT NULL
UNION
SELECT 1, OldFirst + ' ' + OldLast, NewFirst + ' ' + NewLast
FROM dbo.AnonPerson WHERE OldFirst <> '' AND NewFirst IS NOT NULL;

/* 2. tax codes: unique by construction */
INSERT INTO dbo.AnonToken (Ord, Tok, NewTok)
SELECT 2, OldCF, NewCF FROM dbo.AnonPerson
WHERE OldCF IS NOT NULL AND NewCF IS NOT NULL;

/* 3. surnames: one family, one new surname */
INSERT INTO dbo.AnonToken (Ord, Tok, NewTok)
SELECT 3, OldLast, NewLast FROM dbo.AnonLastMap
WHERE LEN(OldLast) >= 4 AND NewLast IS NOT NULL;

/* 4. first names: several people share one, so the choice is arbitrary but
      fixed. In free text it only has to stop being a real person's name. */
INSERT INTO dbo.AnonToken (Ord, Tok, NewTok)
SELECT 4, OldFirst, MIN(NewFirst) FROM dbo.AnonPerson
WHERE OldFirst <> '' AND LEN(OldFirst) >= 4 AND NewFirst IS NOT NULL
GROUP BY OldFirst;

/*  A first name that is really an ordinary word never becomes a token: the
    archive holds a junk registry row whose first name is "Figlio", and with it
    among the tokens the sweep turned the relationship "Figlio/a" of the
    PARENTELE vocabulary into a person's name. The pair token "Surname Figlio"
    stays, so that junk row is still anonymised where it appears. */
DELETE FROM dbo.AnonToken
WHERE Ord = 4
  AND Tok IN ('Figlio', 'Figlia', 'Padre', 'Madre', 'Nonno', 'Nonna',
              'Fratello', 'Sorella', 'Tutore', 'Affidato', 'Genitore');

/* 5. the club's own town: in the accounting descriptions it names the club as
      surely as its name would. Birthplaces keep their real town, which says
      nothing about a synthetic person. */
INSERT INTO dbo.AnonToken (Ord, Tok, NewTok) VALUES
 (3, 'Cernusco sul Naviglio', 'Milano'),
 (3, 'Cernusco', 'Milano');

DECLARE @nTok int = (SELECT COUNT(*) FROM dbo.AnonToken);
PRINT 'Token: ' + CAST(@nTok AS varchar(10));

/* --------------------------------------------------------------------------
   The sweep itself, over every text column of every table but the geographic
   reference data (where a surname can also be the name of a town).
   -------------------------------------------------------------------------- */
IF OBJECT_ID('tempdb..#Excluded') IS NOT NULL DROP TABLE #Excluded;
CREATE TABLE #Excluded (name sysname PRIMARY KEY);
INSERT INTO #Excluded (name) VALUES
 ('COMUNI'), ('PROVINCE'), ('REGIONI'), ('NAZIONI'), ('AREEGEO'),
 ('AnonToken'), ('AnonPerson'), ('AnonSurname'), ('AnonFirstName'),
 ('AnonStreet'), ('AnonUser'), ('AnonCharValue'), ('AnonLastMap');

IF OBJECT_ID('tempdb..#Changed') IS NOT NULL DROP TABLE #Changed;
CREATE TABLE #Changed (Tabella sysname, Colonna sysname, Righe int);

DECLARE @t sysname, @c sysname, @ty sysname, @sql nvarchar(max), @n int, @tot int = 0;

DECLARE cur CURSOR FAST_FORWARD FOR
    SELECT t.name, c.name, ty.name
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
    WHERE p.rows > 0
      AND ty.name IN ('varchar', 'nvarchar', 'char', 'nchar', 'text', 'ntext')
      AND t.name NOT IN (SELECT name FROM #Excluded)
      /*  Columns that hold the name of a town: an Italian surname is often a
          place name too, and replacing it there would corrupt reference data
          rather than protect anybody. */
      AND c.name NOT LIKE '%COMUNE%'
      AND c.name NOT LIKE 'LUOGO%'
      AND c.name NOT LIKE 'PROVINC%'
      AND c.name NOT LIKE '%CITY%'
      AND c.name NOT LIKE '%NASC%'
    ORDER BY t.name, c.column_id;

OPEN cur;
FETCH NEXT FROM cur INTO @t, @c, @ty;
WHILE @@FETCH_STATUS = 0
BEGIN
    /*  One statement per token, and only where the token stands as a WORD of
        its own. A substring match would be a disaster here: Italian surnames
        are also ordinary words and place names -- Stella is inside
        CASTELLAMMARE, Lombardi inside Lombardia, Ivan inside "derivanti" --
        and every one of those would be quietly mangled. The padding with a
        space plus the [^A-Za-z] classes is how a word boundary is expressed
        with LIKE. */
    DECLARE @tok varchar(200), @new varchar(200);
    DECLARE tcur CURSOR FAST_FORWARD FOR
        SELECT Tok, NewTok FROM dbo.AnonToken ORDER BY Ord, LEN(Tok) DESC;
    OPEN tcur;
    FETCH NEXT FROM tcur INTO @tok, @new;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'UPDATE dbo.' + QUOTENAME(@t)
                 + N' SET ' + QUOTENAME(@c) + N' = REPLACE(CAST(' + QUOTENAME(@c)
                 + N' AS varchar(max)), @tok, @new)'
                 + N' WHERE '' '' + CAST(' + QUOTENAME(@c) + N' AS varchar(max)) + '' '''
                 + N' LIKE ''%[^A-Za-z]'' + @tok + ''[^A-Za-z]%''';
        BEGIN TRY
            EXEC sp_executesql @sql, N'@tok varchar(200), @new varchar(200)', @tok = @tok, @new = @new;
            SET @n = @@ROWCOUNT;
            IF @n > 0
            BEGIN
                SET @tot = @tot + @n;
                INSERT INTO #Changed (Tabella, Colonna, Righe) VALUES (@t, @c, @n);
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Changed (Tabella, Colonna, Righe) VALUES (@t, @c, -1);
        END CATCH;
        FETCH NEXT FROM tcur INTO @tok, @new;
    END;
    CLOSE tcur; DEALLOCATE tcur;
    FETCH NEXT FROM cur INTO @t, @c, @ty;
END;
CLOSE cur; DEALLOCATE cur;

PRINT 'Sostituzioni: ' + CAST(@tot AS varchar(10));

SELECT Tabella + '.' + Colonna + ' -> ' + CAST(SUM(Righe) AS varchar(10)) + ' sostituzioni' AS Sweep
FROM #Changed GROUP BY Tabella, Colonna ORDER BY SUM(Righe) DESC;

GO

/* ===========================================================================
   8. Verification: what is left of the real data, and does the result hold
      together (tax codes valid and matching their names, families sharing a
      surname, no address outside example.com, every account on the demo
      password).
   =========================================================================== */
SET NOCOUNT ON;

/* --- 1. residui: qualunque token vecchio in qualunque colonna testuale ---- */
DECLARE @t sysname, @c sysname, @sql nvarchar(max), @n int;
DECLARE @found TABLE (Tabella sysname, Colonna sysname, Righe int, Esempio varchar(200));

DECLARE cur CURSOR FAST_FORWARD FOR
    SELECT t.name, c.name
    FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
    WHERE p.rows > 0
      AND ty.name IN ('varchar', 'nvarchar', 'char', 'nchar', 'text', 'ntext')
      AND t.name NOT LIKE 'Anon%'
    ORDER BY t.name, c.column_id;

OPEN cur;
FETCH NEXT FROM cur INTO @t, @c;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'SELECT @n = COUNT(*) FROM dbo.' + QUOTENAME(@t) + N' x WHERE EXISTS ('
             + N'SELECT 1 FROM dbo.AnonToken k WHERE '' '' + CAST(x.' + QUOTENAME(@c)
             + N' AS varchar(max)) + '' '' LIKE ''%[^A-Za-z]'' + k.Tok + ''[^A-Za-z]%'')';
    BEGIN TRY
        EXEC sp_executesql @sql, N'@n int OUTPUT', @n = @n OUTPUT;
        IF @n > 0
        BEGIN
            DECLARE @e varchar(200);
            SET @sql = N'SELECT TOP 1 @e = LEFT(CAST(x.' + QUOTENAME(@c) + N' AS varchar(max)), 100) FROM dbo.'
                     + QUOTENAME(@t) + N' x WHERE EXISTS (SELECT 1 FROM dbo.AnonToken k WHERE '' '' + CAST(x.'
                     + QUOTENAME(@c) + N' AS varchar(max)) + '' '' LIKE ''%[^A-Za-z]'' + k.Tok + ''[^A-Za-z]%'')';
            EXEC sp_executesql @sql, N'@e varchar(200) OUTPUT', @e = @e OUTPUT;
            INSERT INTO @found VALUES (@t, @c, @n, @e);
        END;
    END TRY
    BEGIN CATCH
        INSERT INTO @found VALUES (@t, @c, -1, ERROR_MESSAGE());
    END CATCH;
    FETCH NEXT FROM cur INTO @t, @c;
END;
CLOSE cur; DEALLOCATE cur;

SELECT 'RESIDUO ' + Tabella + '.' + Colonna + ' (' + CAST(Righe AS varchar(10)) + ') ' + ISNULL(Esempio, '') AS R
FROM @found ORDER BY Righe DESC;

IF NOT EXISTS (SELECT 1 FROM @found)
    SELECT 'RESIDUI: nessuno' AS R;

/* --- 2. coerenza ---------------------------------------------------------- */
SELECT 'CF non validi in NOMINATIVI: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM NOMINATIVI
WHERE NULLIF(CODFISC, '') IS NOT NULL
  AND (LEN(CODFISC) <> 16 OR dbo.fn_AnonCheckChar(LEFT(CODFISC, 15)) <> RIGHT(CODFISC, 1));

SELECT 'CF le cui lettere non corrispondono al nome: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM NOMINATIVI
WHERE LEN(ISNULL(CODFISC, '')) = 16
  AND LEFT(CODFISC, 6) <> UPPER(dbo.fn_AnonNameCode(COGNOME, 0) + dbo.fn_AnonNameCode(NOME, 1));

SELECT 'Iscrizioni il cui nominativo non combacia con NOMINATIVI: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM ISCRIZIONI i
WHERE LEN(ISNULL(i.CODFISC, '')) = 16
  AND NOT EXISTS (SELECT 1 FROM NOMINATIVI n
                  WHERE n.CODFISC = i.CODFISC AND n.COGNOME = i.COGNOME AND n.NOME = i.NOME);

SELECT 'Famiglie i cui membri hanno cognomi diversi: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM (SELECT m.FAMIGLIAID FROM MEMBRI_FAMIGLIE m
      JOIN NOMINATIVI n ON n.ID = m.NOMINATIVOID
      GROUP BY m.FAMIGLIAID HAVING COUNT(DISTINCT n.COGNOME) > 1) x;

SELECT 'Indirizzi e-mail fuori da example.com: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM (SELECT EMAIL AS E FROM NOMINATIVI WHERE EMAIL LIKE '%@%'
      UNION ALL SELECT EMAIL FROM ISCRIZIONI WHERE EMAIL LIKE '%@%'
      UNION ALL SELECT EMAIL_GENITORE FROM ISCRIZIONI WHERE EMAIL_GENITORE LIKE '%@%'
      UNION ALL SELECT EMAIL_ADDRESS FROM APPUSER WHERE EMAIL_ADDRESS LIKE '%@%'
      UNION ALL SELECT EMAIL FROM CLIENTI WHERE EMAIL LIKE '%@%'
      UNION ALL SELECT EMAIL FROM FORNITORI WHERE EMAIL LIKE '%@%') e
WHERE E NOT LIKE '%@example.com';

SELECT 'Utenti senza la password demo: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM APPUSER
WHERE PASSWD <> LOWER(CONVERT(varchar(32), HASHBYTES('MD5', CAST('demo1234' AS varchar(30))), 2));

SELECT 'Utenti che devono cambiare password o bloccati: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM APPUSER WHERE ISNULL(MUST_CHANGE_PASSWORD, 0) = 1 OR ISNULL(ACCESS_DENIED, 0) = 1;

SELECT 'Utenti USER il cui ID non e'' il proprio codice fiscale: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM APPUSER WHERE PROFILEID = 'USER' AND ISNULL(FISCAL_ID, '') <> '' AND ID <> FISCAL_ID;

SELECT 'Righe orfane in UTENTE_INSERIMENTOID: ' + CAST(COUNT(*) AS varchar(10)) AS R
FROM (SELECT UTENTE_INSERIMENTOID AS U FROM ISCRIZIONI
      UNION ALL SELECT UTENTE_INSERIMENTOID FROM MOVIMENTI_CONTABILI
      UNION ALL SELECT UTENTE_INSERIMENTOID FROM RIGHE_CONTABILI) x
WHERE NULLIF(U, '') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM APPUSER u WHERE u.ID = x.U);

SELECT 'Allegati binari rimasti: ' + CAST(
      (SELECT COUNT(*) FROM NOMINATIVI WHERE FOTO IS NOT NULL)
    + (SELECT COUNT(*) FROM APPUSER WHERE PHOTO IS NOT NULL)
    + (SELECT COUNT(*) FROM CONFIGURATION WHERE LOGO_SOC IS NOT NULL)
    + (SELECT COUNT(*) FROM SPONSORS WHERE LOGO IS NOT NULL)
    + (SELECT COUNT(*) FROM SQUADRE WHERE LOGO IS NOT NULL OR FOTO IS NOT NULL)
    + (SELECT COUNT(*) FROM SOCIETA WHERE LOGO_FEDERAZIONE IS NOT NULL) AS varchar(10)) AS R;

SELECT 'Righe in CODA_EMAIL: ' + CAST(COUNT(*) AS varchar(10)) AS R FROM CODA_EMAIL;

/* ===========================================================================
   9. The helpers go away
   ===========================================================================
   The map is the only thing that could take the anonymisation back, so it must
   not survive in the database the data script is generated from -- and neither
   should the pools and the two functions.                                   */
IF OBJECT_ID('dbo.AnonToken')     IS NOT NULL DROP TABLE dbo.AnonToken;
IF OBJECT_ID('dbo.AnonPerson')    IS NOT NULL DROP TABLE dbo.AnonPerson;
IF OBJECT_ID('dbo.AnonLastMap')   IS NOT NULL DROP TABLE dbo.AnonLastMap;
IF OBJECT_ID('dbo.AnonUser')      IS NOT NULL DROP TABLE dbo.AnonUser;
IF OBJECT_ID('dbo.AnonSurname')   IS NOT NULL DROP TABLE dbo.AnonSurname;
IF OBJECT_ID('dbo.AnonFirstName') IS NOT NULL DROP TABLE dbo.AnonFirstName;
IF OBJECT_ID('dbo.AnonStreet')    IS NOT NULL DROP TABLE dbo.AnonStreet;
IF OBJECT_ID('dbo.AnonCharValue') IS NOT NULL DROP TABLE dbo.AnonCharValue;
GO

IF OBJECT_ID('dbo.fn_AnonNameCode')  IS NOT NULL DROP FUNCTION dbo.fn_AnonNameCode;
IF OBJECT_ID('dbo.fn_AnonCheckChar') IS NOT NULL DROP FUNCTION dbo.fn_AnonCheckChar;
GO

PRINT 'Anonimizzazione completata: la mappa non esiste piu''.';
GO
