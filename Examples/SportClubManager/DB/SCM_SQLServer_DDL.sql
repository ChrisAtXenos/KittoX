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

/*  Sport Club Manager - SQL Server schema.
    Generated with SQL Server Management Studio (Generate Scripts, schema only).
    Select the target database before running it: the script carries no USE.
    Data: SCM_SQLServer_Data.sql  */

/****** Oggetto: UserDefinedFunction [dbo].[DataFineAnno]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataFineAnno]
(@dayReference DateTime) returns DateTime
AS
BEGIN
  declare @theDay DateTime, @theYear NVarChar(4)
  set @theYear = Cast(DatePart(year,@dayReference) as NVarChar)
  set @theDay = Convert(DateTime,@theYear+'1231',112) 
  return @theDay
END;
GO
/****** Oggetto: UserDefinedFunction [dbo].[DataFineMese]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataFineMese]
(@dayReference datetime) returns datetime
AS
BEGIN
  declare @theDay datetime
  set @theDay = DATEADD(dd, -1, DATEADD(mm, 1, dbo.DataInizioMese(@dayReference)))
  return @theDay
END
GO
/****** Oggetto: UserDefinedFunction [dbo].[DataFineMeseSuccessivo]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataFineMeseSuccessivo]
(@dayReference datetime) returns datetime
AS
BEGIN
  declare @theDay datetime
  set @theDay = DATEADD(dd, -1, DATEADD(mm, 1, dbo.DataInizioMeseSuccessivo(@dayReference)))

  return @theDay
END
GO
/****** Oggetto: UserDefinedFunction [dbo].[DataFineSettimana]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataFineSettimana]
(@dayReference DateTime) returns DateTime
AS
BEGIN
  declare @theDay DateTime
  set @theDay = Cast(Left(Convert(NVarChar,DateAdd(day,1-DatePart(dw,@dayReference),@dayReference),112),8) as DateTime)
  set @theDay = DateAdd(day,6,@theDay)
  return @theDay
END;
GO
/****** Oggetto: UserDefinedFunction [dbo].[DataInizioAnno]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataInizioAnno]
(@dayReference DateTime) returns DateTime
AS
BEGIN
  declare @theDay DateTime, @theYear NVarChar(4)
  set @theYear = Cast(DatePart(year,@dayReference) as NVarChar)
  set @theDay = Convert(DateTime,@theYear+'0101',112) 
  return @theDay
END;
GO
/****** Oggetto: UserDefinedFunction [dbo].[DataInizioMese]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataInizioMese]
(@dayReference datetime) returns datetime
AS
BEGIN
  declare @theDay datetime
  set @theDay = DATEADD(mm, DATEDIFF(mm, 0, @dayReference), 0) 
  return @theDay
END
GO
/****** Oggetto: UserDefinedFunction [dbo].[DataInizioMeseSuccessivo]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataInizioMeseSuccessivo]
(@dayReference datetime) returns datetime
AS
BEGIN
  declare @theDay datetime
  set @theDay = DATEADD(dd, 1, dbo.DataFineMese(@dayReference))
  return @theDay
END
GO
/****** Oggetto: UserDefinedFunction [dbo].[DataInizioSettimana]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[DataInizioSettimana]
(@dayReference DateTime) returns DateTime
AS
BEGIN
  declare @theDay DateTime
  set @theDay = Cast(Left(Convert(NVarChar,DateAdd(day,1-DatePart(dw,@dayReference),@dayReference),112),8) as DateTime)
  return @theDay
END;
GO
/****** Oggetto: UserDefinedFunction [dbo].[nextNworkingDay]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[nextNworkingDay]
(@dayReference datetime, @delay int) returns datetime
AS
BEGIN
  declare @theDay datetime
  set @theDay = (SELECT data_giorno from
                    (select data_giorno, xRank from
                       (SELECT data_giorno, RANK() OVER (ORDER BY data_giorno) AS xRank
                          FROM (select data_giorno from PGM_TRRIPA_CALENDARIO
                                   where festivo=0 and giorno_sett_num<6 and cast(data_giorno-cast(@dayReference as datetime) as int) between 1 and 10) x) y
                     where xRank=@delay) z )
  return @theDay
END
GO
/****** Oggetto: UserDefinedFunction [dbo].[previousNworkingDay]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[previousNworkingDay]
(@dayReference datetime, @delay int) returns datetime
AS
BEGIN
  declare @theDay datetime
  set @theDay = (SELECT data_giorno from
                    (select data_giorno, xRank from
                       (SELECT data_giorno, RANK() OVER (ORDER BY data_giorno desc) AS xRank
                          FROM (select data_giorno from PGM_TRRIPA_CALENDARIO
                                   where festivo=0 and giorno_sett_num<6 and cast(data_giorno-cast(@dayReference as datetime) as int) between -10 and -1) x) y
                     where xRank=@delay) z )
  return @theDay
END
GO
/****** Oggetto: UserDefinedFunction [dbo].[splitstring]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[splitstring] ( @stringToSplit VARCHAR(MAX) )
RETURNS
 @returnList TABLE ([Name] [nvarchar] (500))
AS
BEGIN
 DECLARE @name NVARCHAR(255)
 DECLARE @pos INT
 WHILE CHARINDEX(',', @stringToSplit) > 0
 BEGIN
  SELECT @pos  = CHARINDEX(',', @stringToSplit)  
  SELECT @name = SUBSTRING(@stringToSplit, 1, @pos-1)
  INSERT INTO @returnList 
  SELECT @name
  SELECT @stringToSplit = SUBSTRING(@stringToSplit, @pos+1, LEN(@stringToSplit)-@pos)
 END
 INSERT INTO @returnList
 SELECT @stringToSplit
 RETURN
END
GO
/****** Oggetto: Table [dbo].[MOVIMENTI_CONTABILI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MOVIMENTI_CONTABILI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[ESERCCLASS] [varchar](32) NOT NULL,
	[ESERCID] [varchar](32) NOT NULL,
	[NR_MOV] [int] NOT NULL,
	[UTENTE_INSERIMENTOCLASS] [varchar](32) NULL,
	[UTENTE_INSERIMENTOID] [varchar](32) NULL,
	[DATA_REG] [datetime] NOT NULL,
	[TIPO_MOV] [varchar](2) NOT NULL,
	[DATA_DOC] [datetime] NULL,
	[NR_DOC] [varchar](50) NULL,
	[MOD_PAGAMENTOCLASS] [varchar](32) NULL,
	[MOD_PAGAMENTOID] [varchar](32) NULL,
	[REG_IVACLASS] [varchar](32) NULL,
	[REG_IVAID] [varchar](32) NULL,
	[NR_IVA] [int] NULL,
	[CAUSALECLASS] [varchar](32) NULL,
	[CAUSALEID] [varchar](32) NULL,
	[IMPORTO] [money] NULL,
	[NOTE] [text] NULL,
	[CLIENTECLASS] [varchar](32) NULL,
	[CLIENTEID] [varchar](32) NULL,
	[FORNITORECLASS] [varchar](32) NULL,
	[FORNITOREID] [varchar](32) NULL,
	[BANCACLASS] [varchar](32) NULL,
	[BANCAID] [varchar](32) NULL,
	[FATTURA_PDF] [varchar](50) NULL,
	[NOME_FATTURA_PDF] [varchar](200) NULL,
	[FATTURA_XML] [varchar](50) NULL,
	[NOME_FATTURA_XML] [varchar](200) NULL,
 CONSTRAINT [MOVIMENTI_CONTABILI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[RIGHE_CONTABILI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RIGHE_CONTABILI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[MOVIMENTOCLASS] [varchar](32) NULL,
	[MOVIMENTOID] [varchar](32) NULL,
	[NR_RIGA] [smallint] NULL,
	[UTENTE_INSERIMENTOCLASS] [varchar](32) NULL,
	[UTENTE_INSERIMENTOID] [varchar](32) NULL,
	[CONTOCLASS] [varchar](32) NULL,
	[CONTOID] [varchar](32) NULL,
	[DATASCADENZA] [datetime] NULL,
	[PARTITA] [varchar](30) NULL,
	[IMPORTO] [money] NULL,
	[SEGNO] [varchar](1) NULL,
	[COD_IVACLASS] [varchar](32) NULL,
	[COD_IVAID] [varchar](32) NULL,
	[CENTRO_COSTOCLASS] [varchar](32) NULL,
	[CENTRO_COSTOID] [varchar](32) NULL,
	[CLIENTECLASS] [varchar](32) NULL,
	[CLIENTEID] [varchar](32) NULL,
	[FORNITORECLASS] [varchar](32) NULL,
	[FORNITOREID] [varchar](32) NULL,
	[BANCACLASS] [varchar](32) NULL,
	[BANCAID] [varchar](32) NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
 CONSTRAINT [RIGHE_CONTABILI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[NOMINATIVI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NOMINATIVI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[COGNOME] [varchar](100) NOT NULL,
	[NOME] [varchar](100) NOT NULL,
	[CODFISC] [varchar](16) NULL,
	[SESSO] [varchar](1) NOT NULL,
	[INDIRIZZO] [varchar](50) NULL,
	[CAP] [varchar](5) NULL,
	[PROVINCIACLASS] [varchar](32) NULL,
	[PROVINCIAID] [varchar](32) NULL,
	[TELEFONO] [varchar](30) NULL,
	[EMAIL] [varchar](50) NULL,
	[PROVNASCCLASS] [varchar](32) NULL,
	[PROVNASCID] [varchar](32) NULL,
	[DATANASC] [datetime] NULL,
	[NAZIONALITACLASS] [varchar](32) NULL,
	[NAZIONALITAID] [varchar](32) NULL,
	[TESSERA] [varchar](20) NULL,
	[PRESTITO] [bit] NULL,
	[BANCACLASS] [varchar](32) NULL,
	[BANCAID] [varchar](32) NULL,
	[C_C] [varchar](20) NULL,
	[IBAN] [varchar](30) NULL,
	[FOTO] [image] NULL,
	[TAGLIACLASS] [varchar](32) NULL,
	[TAGLIAID] [varchar](32) NULL,
	[DOCUMENTOCLASS] [varchar](32) NULL,
	[DOCUMENTOID] [varchar](32) NULL,
	[ANNO_NASCITA] [varchar](4) NULL,
	[ALTEZZA] [smallint] NULL,
	[PESO] [smallint] NULL,
	[TESSERASANCLASS] [varchar](32) NULL,
	[TESSERASANID] [varchar](32) NULL,
	[ATLETA] [bit] NULL,
	[DIRIGENTE] [bit] NULL,
	[ALLENATORE] [bit] NULL,
	[STORICO] [bit] NULL,
	[ETA] [smallint] NULL,
	[CELLULARE] [varchar](30) NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
	[LUOGONASCCLASS] [varchar](32) NULL,
	[LUOGONASCID] [varchar](32) NULL,
 CONSTRAINT [NOMINATIVI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CONTICONTABILI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONTICONTABILI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CODCONTO] [varchar](10) NOT NULL,
	[SEZIONE] [varchar](3) NOT NULL,
	[LIVELLO] [varchar](1) NOT NULL,
	[CODPADRE] [varchar](10) NULL,
	[RIF_CLIENTE] [bit] NOT NULL,
	[RIF_FORNITORE] [bit] NOT NULL,
	[RIF_CONTO_CORRENTE] [bit] NOT NULL,
	[RIF_SOCIO] [bit] NULL,
	[ERARIO_IVA] [bit] NULL,
	[IMPOSTE_TRIBUTI] [bit] NULL,
	[DISATTIVATO] [bit] NULL,
 CONSTRAINT [CONTICONTABILI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CLIENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CLIENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[COGNOME] [varchar](100) NULL,
	[NOME] [varchar](100) NULL,
	[CODFISCALE] [varchar](16) NULL,
	[PARTIVA] [varchar](11) NULL,
	[INDIRIZZO] [varchar](50) NULL,
	[CAP] [varchar](5) NULL,
	[PROVINCIACLASS] [varchar](32) NULL,
	[PROVINCIAID] [varchar](32) NULL,
	[IBAN] [varchar](27) NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
	[CODICE_FATT_ELE] [varchar](7) NULL,
	[EMAIL] [varchar](50) NULL,
	[EMAIL_PEC] [varchar](50) NULL,
	[INDIRIZZO_AMM] [varchar](50) NULL,
	[CAP_AMM] [varchar](5) NULL,
	[COMUNE_AMMCLASS] [varchar](32) NULL,
	[COMUNE_AMMID] [varchar](32) NULL,
	[PROVINCIA_AMMCLASS] [varchar](32) NULL,
	[PROVINCIA_AMMID] [varchar](32) NULL,
	[FORMA_GIURICLASS] [varchar](32) NULL,
	[FORMA_GIURIID] [varchar](32) NULL,
	[FLAG_INDI_AMM] [bit] NULL,
	[TELEFONO] [varchar](30) NULL,
	[CELLULARE] [varchar](30) NULL,
	[PERSONA_RIF] [varchar](200) NULL,
	[BANCA] [varchar](50) NULL,
 CONSTRAINT [CLIENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[FORNITORI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FORNITORI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[COGNOME] [varchar](100) NULL,
	[NOME] [varchar](100) NULL,
	[CODFISCALE] [varchar](16) NULL,
	[PARTIVA] [varchar](11) NULL,
	[INDIRIZZO] [varchar](50) NULL,
	[CAP] [varchar](5) NULL,
	[PROVINCIACLASS] [varchar](32) NULL,
	[PROVINCIAID] [varchar](32) NULL,
	[IBAN] [varchar](27) NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
	[PERCIP] [bit] NULL,
	[CODRA] [varchar](6) NULL,
	[PCASSA] [bit] NULL,
	[PINPS] [bit] NULL,
	[PCAPE] [bit] NULL,
	[CODICE_FATT_ELE] [varchar](7) NULL,
	[EMAIL] [varchar](100) NULL,
	[EMAIL_PEC] [varchar](100) NULL,
	[INDIRIZZO_AMM] [varchar](50) NULL,
	[CAP_AMM] [varchar](5) NULL,
	[COMUNE_AMMCLASS] [varchar](32) NULL,
	[COMUNE_AMMID] [varchar](32) NULL,
	[PROVINCIA_AMMCLASS] [varchar](32) NULL,
	[PROVINCIA_AMMID] [varchar](32) NULL,
	[FORMA_GIURICLASS] [varchar](32) NULL,
	[FORMA_GIURIID] [varchar](32) NULL,
	[FLAG_INDI_AMM] [bit] NULL,
	[TELEFONO] [varchar](30) NULL,
	[CELLULARE] [varchar](30) NULL,
	[PERSONA_RIF] [varchar](200) NULL,
	[BANCA] [varchar](50) NULL,
 CONSTRAINT [FORNITORI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[BANCHE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BANCHE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[INDIRIZZO] [varchar](40) NULL,
	[CAP] [varchar](5) NULL,
	[CODCOMUNECLASS] [varchar](32) NULL,
	[CODCOMUNEID] [varchar](32) NULL,
	[PROVINCIACLASS] [varchar](32) NULL,
	[PROVINCIAID] [varchar](32) NULL,
	[TELEFONO] [varchar](40) NULL,
	[EMAIL] [varchar](50) NULL,
	[IBAN] [varchar](30) NULL,
 CONSTRAINT [BANCHE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_SALDOCONTI_DETT]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SALDOCONTI_DETT]
    ( ID,
     CODCONTO,
     DX,
     SEZIONE,
	 LIVELLO,
	 CODPADRE,
	 DX_CONTO,
     ESERCID,	 
	 DETTAGLIO,
	 TOT_DARE,
	 TOT_AVERE,
	 SEGNO_SALDO,
     SALDO,
	 SALDOABS   ) AS
SELECT 
     C.ID,
     C.CODCONTO,
	 C.CODCONTO + ' - ' +  C.DX,
     C.SEZIONE,
	 C.LIVELLO,
	 C.CODPADRE,
	 C.DX,
     M.ESERCID,
	 CASE 
	   WHEN C.RIF_CLIENTE = 1 THEN CL.DX
	   WHEN C.RIF_SOCIO = 1 THEN N.DX
	   WHEN C.RIF_FORNITORE = 1 THEN F.DX
	   WHEN C.RIF_CONTO_CORRENTE = 1 THEN B.DX
	 END, 
	 COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE 0 END),0) TOT_DARE,
     COALESCE(SUM(CASE WHEN SEGNO='A' THEN R.IMPORTO ELSE 0 END),0) TOT_AVERE,
	 CASE
	   WHEN COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE 0 END),0) > COALESCE(SUM(CASE WHEN SEGNO='A' THEN R.IMPORTO ELSE 0 END),0) THEN 'D'
	   ELSE 'A'
	 END SEGNO_SALDO, 
     COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE -R.IMPORTO END),0) SALDO, 
     COALESCE(ABS(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE -R.IMPORTO END)),0) SALDOABS
FROM 
     CONTICONTABILI C
INNER JOIN
     RIGHE_CONTABILI R 
ON
     C.ID = R.CONTOID 
INNER JOIN
     MOVIMENTI_CONTABILI M 
ON
     M.ID = R.MOVIMENTOID
LEFT OUTER JOIN
  NOMINATIVI N
ON
  N.ID = R.NOMINATIVOID
LEFT OUTER JOIN
  BANCHE B
ON
  B.ID = R.BANCAID
LEFT OUTER JOIN
  CLIENTI CL
ON
  CL.ID = R.CLIENTEID
LEFT OUTER JOIN
  FORNITORI F
ON
  F.ID = R.NOMINATIVOID
WHERE
  M.TIPO_MOV NOT IN ('MC') --escludo i movimenti di chiusura esercizio
GROUP BY
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
	 C.LIVELLO,
	 C.CODPADRE,
     M.ESERCID,
	 CASE 
	   WHEN C.RIF_CLIENTE = 1 THEN CL.DX
	   WHEN C.RIF_SOCIO = 1 THEN N.DX
	   WHEN C.RIF_FORNITORE = 1 THEN F.DX
	   WHEN C.RIF_CONTO_CORRENTE = 1 THEN B.DX
	 END
GO
/****** Oggetto: Table [dbo].[ISCRIZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ISCRIZIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DATA_ISCRIZIONE] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[CAMPAGNACLASS] [varchar](32) NOT NULL,
	[CAMPAGNAID] [varchar](32) NOT NULL,
	[QUOTA_ISCRIZIONECLASS] [varchar](32) NOT NULL,
	[QUOTA_ISCRIZIONEID] [varchar](32) NOT NULL,
	[COGNOME] [varchar](100) NOT NULL,
	[NOME] [varchar](100) NOT NULL,
	[SESSO] [varchar](1) NOT NULL,
	[CODFISC] [varchar](16) NULL,
	[DATANASC] [datetime] NULL,
	[INDIRIZZO] [varchar](50) NULL,
	[CAP] [varchar](5) NULL,
	[PROVINCIACLASS] [varchar](32) NULL,
	[PROVINCIAID] [varchar](32) NULL,
	[CELLULARE] [varchar](30) NULL,
	[EMAIL] [varchar](50) NULL,
	[COGNOME_GENITORE] [varchar](100) NULL,
	[NOME_GENITORE] [varchar](100) NULL,
	[TELEFONO_GENITORE] [varchar](30) NULL,
	[CELLULARE_GENITORE] [varchar](30) NULL,
	[COD_FISCALE_GENITORE] [varchar](16) NULL,
	[DATA_ACCETTAZIONE] [datetime] NULL,
	[DATA_RIFIUTO] [datetime] NULL,
	[NOTE] [text] NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[EMAIL_GENITORE] [varchar](50) NULL,
	[PROVNASCCLASS] [varchar](32) NULL,
	[PROVNASCID] [varchar](32) NULL,
	[NAZIONALITACLASS] [varchar](32) NULL,
	[NAZIONALITAID] [varchar](32) NULL,
	[LUOGONASCCLASS] [varchar](32) NULL,
	[LUOGONASCID] [varchar](32) NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
	[SC_FRATELLI] [bit] NULL,
	[IMP_SC_FRATELLI] [money] NULL,
	[SC_RATA_UNICA] [bit] NULL,
	[IMP_SC_RATA_UNICA] [money] NULL,
	[TOTALE_IMPORTO] [money] NULL,
	[IMPORTO_QUOTA] [money] NULL,
	[UTENTE_INSERIMENTOCLASS] [varchar](32) NULL,
	[UTENTE_INSERIMENTOID] [varchar](32) NULL,
	[INDIRIZZO_IP] [varchar](30) NULL,
	[STATUS] [varchar](3) NULL,
	[NOTE_ADMIN] [text] NULL,
	[SC_ABBUONO_RATE] [money] NULL,
 CONSTRAINT [ISCRIZIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[VISITEMEDICHE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VISITEMEDICHE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TPVISITACLASS] [varchar](32) NOT NULL,
	[TPVISITAID] [varchar](32) NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[TESSERASANIT] [varchar](8) NULL,
	[AMBULATORIOCLASS] [varchar](32) NULL,
	[AMBULATORIOID] [varchar](32) NULL,
	[SCADENZA] [datetime] NULL,
	[EFFETTUATA] [bit] NULL,
	[PESO] [smallint] NULL,
	[ALTEZZA] [smallint] NULL,
	[NOTE] [text] NULL,
	[IDEONEITA] [bit] NULL,
	[FILE_DOCUMENTO] [varchar](50) NULL,
	[NOME_FILE_ORIGINALE] [varchar](200) NULL,
	[ORA_VISITA] [datetime] NULL,
	[DATA_NOTIFICA] [datetime] NULL,
	[DATA_RICHIESTA] [datetime] NOT NULL,
	[DATA_VISITA] [datetime] NULL,
 CONSTRAINT [VISITEMEDICHE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_ISCRIZIONI_VISITE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_ISCRIZIONI_VISITE] 
   (
	NOMINATIVOID
	,CLASS
	,ID
	,UPDATECOUNT
	,DX
	,UPDTIMESTAMP
	,TPVISITACLASS
	,TPVISITAID
	,TESSERASANIT
	,DATA_RICHIESTA
	,DATA_VISITA
	,ORA_VISITA
	,AMBULATORIOCLASS
	,AMBULATORIOID
	,SCADENZA
	,DATA_NOTIFICA
	,EFFETTUATA
	,PESO
	,ALTEZZA
	,NOTE
	,IDEONEITA
	,FILE_DOCUMENTO
	,NOME_FILE_ORIGINALE
	,STATUS_VISITA   ) AS
SELECT
	DISTINCT 
	NOM.ID NOMINATIVOID
	,VME.CLASS
	,VME.ID
	,VME.UPDATECOUNT
	,VME.DX
	,VME.UPDTIMESTAMP
	,VME.TPVISITACLASS
	,VME.TPVISITAID
	,VME.TESSERASANIT
	,VME.DATA_RICHIESTA
	,VME.DATA_VISITA
	,VME.ORA_VISITA
	,VME.AMBULATORIOCLASS
	,VME.AMBULATORIOID
	,VME.SCADENZA
	,VME.DATA_NOTIFICA
	,VME.EFFETTUATA
	,VME.PESO
	,VME.ALTEZZA
	,CAST(VME.NOTE AS VARCHAR(1000))
	,VME.IDEONEITA
	,VME.FILE_DOCUMENTO
	,VME.NOME_FILE_ORIGINALE
	, CASE 
                        WHEN VME.ID IS NULL THEN 'VMN'
                        WHEN VME.SCADENZA IS NULL OR EFFETTUATA = 0 THEN 'VMD'
                        WHEN VME.SCADENZA < GETDATE() THEN 'VMS'
                        WHEN VME.SCADENZA >= GETDATE() THEN 'VMO'
                   END  STATUS_VISITA   
FROM
  ISCRIZIONI ISC
LEFT OUTER JOIN
  NOMINATIVI NOM
ON
  ISC.NOMINATIVOCLASS = NOM.CLASS AND
  ISC.NOMINATIVOID = NOM.ID
LEFT OUTER JOIN
(SELECT
  NOMINATIVOCLASS,
  NOMINATIVOID,
  MAX(DATA_VISITA) LAST_DATA
 FROM
   VISITEMEDICHE
 GROUP BY
   NOMINATIVOCLASS,
   NOMINATIVOID ) VME_MAX
ON
  VME_MAX.NOMINATIVOCLASS = NOM.CLASS AND
  VME_MAX.NOMINATIVOID = NOM.ID
LEFT OUTER JOIN
  VISITEMEDICHE VME
ON
  VME.NOMINATIVOCLASS = VME_MAX.NOMINATIVOCLASS AND
  VME.NOMINATIVOID = VME_MAX.NOMINATIVOID AND
  VME.DATA_VISITA = VME_MAX.LAST_DATA
GO
/****** Oggetto: Table [dbo].[APPUSER]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[APPUSER](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[PASSWD] [varchar](40) NULL,
	[PROFILECLASS] [varchar](32) NOT NULL,
	[PROFILEID] [varchar](32) NOT NULL,
	[LANGUAGECLASS] [varchar](32) NULL,
	[LANGUAGEID] [varchar](32) NULL,
	[ADMINISTRATOR] [bit] NULL,
	[FIRST_NAME] [varchar](40) NULL,
	[LAST_NAME] [varchar](40) NULL,
	[IS_SYSTEM] [bit] NULL,
	[EMAIL_ADDRESS] [varchar](100) NULL,
	[MUST_CHANGE_PASSWORD] [bit] NULL,
	[ACCESS_DENIED] [bit] NULL,
	[PRIVACY_CONFIRM] [bit] NULL,
	[CREATION_DATE] [datetime] NULL,
	[IP_ADDRESS] [varchar](50) NULL,
	[PHONE_NUMBER] [varchar](15) NULL,
	[PHOTO] [image] NULL,
	[FISCAL_ID] [varchar](50) NULL,
 CONSTRAINT [APPUSER_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TESTI_EMAIL]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TESTI_EMAIL](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[EMAIL_FROM] [varchar](50) NULL,
	[EMAIL_TO] [varchar](2000) NULL,
	[EMAIL_CC] [varchar](2000) NULL,
	[EMAIL_BCC] [varchar](2000) NULL,
	[EMAIL_SUBJECT] [varchar](1000) NULL,
	[EMAIL_BODY] [text] NULL,
	[EMAIL_BODYHTML] [text] NULL,
	[EMAIL_ATTACH] [varchar](200) NULL,
	[ATTIVO] [bit] NULL,
	[NOTE] [text] NULL,
	[EMAIL_PROFILE_TO] [varchar](2000) NULL,
	[NO_EMAIL] [varchar](2000) NULL,
	[EMAIL_OPERATOR_TO] [varchar](2000) NULL,
	[EMAIL_OPERATOR_CC] [varchar](2000) NULL,
	[EMAIL_OPERATOR_BCC] [varchar](2000) NULL,
 CONSTRAINT [TESTI_EMAIL_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_INDIRIZZI_TESTI_EMAIL]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_INDIRIZZI_TESTI_EMAIL] (ID, EMAIL_FROM, EMAILTO, EMAILCC, EMAILBCC, EMAIL_SUBJECT, EMAIL_BODY, EMAIL_ATTACH, ATTIVO) 
AS
--- esplode gli indirizzi mail da testi mail in base al profilo e all'id dell'operatore

SELECT   
      t.ID,
      t.EMAIL_FROM,
      replace(
      case when t.EMAIL_TO is not null then t.EMAIL_TO + ';' else ' ' end + 
      case when t.EMAIL_PROFILE_TO is not null then
         case when    replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND PROFILEID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_PROFILE_TO,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','') is not null then 
                              replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND PROFILEID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_PROFILE_TO,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','') 
         else ' ' end                               
      else ' ' end +                                                                                                     
      case when t.EMAIL_OPERATOR_TO is not null then
          case when   replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND ID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_OPERATOR_TO,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','') is not null then
                   replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND ID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_OPERATOR_TO,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','')
          else ' ' end                              
      else ' ' end, ' ', '') as EMAILTO ,           
           
      replace(
      case when t.EMAIL_CC is not null then t.EMAIL_CC + ';' else ' ' end + 
      case when t.EMAIL_OPERATOR_CC is not null then
           case when  replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND ID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_OPERATOR_CC,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','') is not null then
                              replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND ID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_OPERATOR_CC,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','')
           else ' ' end                   
      else ' ' end, ' ', '') as EMAILCC , 
      
      replace(
      case when t.EMAIL_BCC is not null then t.EMAIL_BCC + ';' else ' ' end + 
      case when t.EMAIL_OPERATOR_BCC is not null then
          case when  replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND ID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_OPERATOR_BCC,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','') is not null then 
                              replace(replace((select APPUSER.EMAIL_ADDRESS from APPUSER 
                              where ATTIVO = 1 AND ID in  ( SELECT * FROM dbo.splitstring(replace(t.EMAIL_OPERATOR_BCC,';',',')))   
                                   and (t.NO_EMAIL IS NULL OR t.NO_EMAIL NOT LIKE '%' + APPUSER.EMAIL_ADDRESS  + '%')                                
                              AND EMAIL_ADDRESS IS NOT NULL for XML auto), '"/>', ';'),'<APPUSER EMAIL="','')
          else ' ' end
      else ' ' end, ' ', '') as EMAILBCC,
                              t.EMAIL_SUBJECT,
                              t.EMAIL_BODY,  
                              t.EMAIL_ATTACH,
                              t.ATTIVO 

       FROM TESTI_EMAIL t
GO
/****** Oggetto: Table [dbo].[RATE_ISCRIZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RATE_ISCRIZIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[IMPORTO] [money] NULL,
	[DATA_SCADENZA] [datetime] NULL,
	[ISCRIZIONECLASS] [varchar](32) NULL,
	[ISCRIZIONEID] [varchar](32) NULL,
	[SCONTO_ABBUONO] [money] NULL,
	[IMPORTO_TOT] [money] NULL,
	[NOTE_ABBUONO] [text] NULL,
 CONSTRAINT [RATE_ISCRIZIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[MEZZI_PAGAMENTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MEZZI_PAGAMENTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[PAGANTECLASS] [varchar](32) NOT NULL,
	[PAGANTEID] [varchar](32) NOT NULL,
	[MOD_PAGAMENTOCLASS] [varchar](32) NOT NULL,
	[MOD_PAGAMENTOID] [varchar](32) NOT NULL,
	[DATA_PAGAMENTO] [datetime] NOT NULL,
	[RIFERIMENTO_BANCACLASS] [varchar](32) NULL,
	[RIFERIMENTO_BANCAID] [varchar](32) NULL,
	[ASSEGNO_NUMERO] [varchar](30) NULL,
	[CRO_BONIFICO] [varchar](30) NULL,
	[IMPORTO] [money] NULL,
	[DATA_REGISTRAZIONE] [datetime] NULL,
	[DATA_VALUTA] [datetime] NULL,
	[ASSEGNO_BANCA] [varchar](100) NULL,
	[STATUS] [varchar](3) NULL,
	[DATA_APPROVAZIONE] [datetime] NULL,
	[DATA_RIFIUTO] [datetime] NULL,
 CONSTRAINT [MEZZI_PAGAMENTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[DETTAGLI_PAGAMENTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DETTAGLI_PAGAMENTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[MEZZO_PAGAMENTOCLASS] [varchar](32) NULL,
	[MEZZO_PAGAMENTOID] [varchar](32) NULL,
	[RATA_ISCRIZIONECLASS] [varchar](32) NULL,
	[RATA_ISCRIZIONEID] [varchar](32) NULL,
	[IMPORTO_PAGATO] [money] NOT NULL,
	[RATA_ISCRIZIONE_IMPORTO] [money] NULL,
	[RATA_ISCRIZIONE_IMPORTO_PAGATO] [money] NULL,
	[RATA_ISCRIZIONE_IMPORTO_RESIDU] [money] NULL,
 CONSTRAINT [DETTAGLI_PAGAMENTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_RATE_ISCRIZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_RATE_ISCRIZIONI] (ID, IMPORTO, IMPORTO_PAGATO, IMPORTO_RESIDUO, IMPORTO_NONAPPROVATO, STATUS) 
AS
/*
Calcola importo pagato e status di ogni rata
*/
select r.ID, r.IMPORTO_TOT, 
case when p.IMPORTO_PAGATO is not null then p.IMPORTO_PAGATO
     else 0 
end  as IMPORTO_PAGATO,      
case when p.IMPORTO_PAGATO is not null then r.IMPORTO_TOT - p.IMPORTO_PAGATO
     else r.IMPORTO_TOT 
end     as IMPORTO_RESIDUO,
COALESCE(IMPORTO_NONAPPROVATO, 0) as IMPORTO_NONAPPROVATO,
case when p.IMPORTO_PAGATO is null or p.IMPORTO_PAGATO = '' then 'inserita' 
     when r.IMPORTO_TOT = p.IMPORTO_PAGATO then 'pagata'
     when r.IMPORTO_TOT  > p.IMPORTO_PAGATO  then 'parziale'
end as STATUS             
from RATE_ISCRIZIONI r
left join (SELECT RATA_ISCRIZIONEID, 
	  SUM(CASE WHEN MP.STATUS = 'ATT' THEN DP.IMPORTO_PAGATO ELSE 0 END) as IMPORTO_PAGATO, 
	  SUM(CASE WHEN MP.STATUS <> 'ATT' THEN DP.IMPORTO_PAGATO ELSE 0 END) as IMPORTO_NONAPPROVATO
	FROM DETTAGLI_PAGAMENTO DP
	inner join MEZZI_PAGAMENTO MP on MP.CLASS = DP.MEZZO_PAGAMENTOCLASS AND DP.MEZZO_PAGAMENTOID = MP.ID 
	group by RATA_ISCRIZIONEID) p on r.ID = p.RATA_ISCRIZIONEID
GO
/****** Oggetto: View [dbo].[V_RIGHE_CONTABILI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_RIGHE_CONTABILI]
   ( 
     DX
	,MOV_ID
    ,MOV_DX
    ,MOV_ESERCID
    ,MOV_NR_MOV
    ,MOV_UTENTE_INSERIMENTOID
    ,MOV_DATA_REG
    ,MOV_TIPO_MOV
    ,MOV_DATA_DOC
    ,MOV_NR_DOC
    ,MOV_MOD_PAGAMENTOID
    ,MOV_REG_IVAID
    ,MOV_NR_IVA
    ,MOV_CAUSALEID
    ,MOV_IMPORTO
    ,MOV_NOTE
    ,MOV_CLIENTEID
    ,MOV_FORNITOREID
    ,MOV_BANCAID
    ,MOV_FATTURA_PDF
    ,MOV_NOME_FATTURA_PDF
    ,MOV_FATTURA_XML
    ,MOV_NOME_FATTURA_XML
    ,RIG_ID
    ,RIG_DX
    ,RIG_NR_RIGA
    ,RIG_UTENTE_INSERIMENTOID
    ,RIG_CONTOID
    ,RIG_DATASCADENZA
    ,RIG_PARTITA
    ,RIG_IMPORTO
    ,RIG_SEGNO
    ,RIG_COD_IVAID
    ,RIG_CENTRO_COSTOID
    ,RIG_CLIENTEID
    ,RIG_FORNITOREID
    ,RIG_BANCAID
    ,RIG_NOMINATIVOID
	,RIG_IMPORTO_DARE
	,RIG_IMPORTO_AVERE  ) AS
SELECT 
     'Esercizio: '+M.ESERCID+' Nr.Mov.:'+CAST(M.NR_MOV AS VARCHAR(10))+' - '+ M.DX+' - Totale €: '+ REPLACE(CAST(M.IMPORTO AS VARCHAR(20)), '.', ',')
    ,M.ID
    ,M.DX
    ,M.ESERCID
    ,M.NR_MOV
    ,M.UTENTE_INSERIMENTOID
    ,M.DATA_REG
    ,M.TIPO_MOV
    ,M.DATA_DOC
    ,M.NR_DOC
    ,M.MOD_PAGAMENTOID
    ,M.REG_IVAID
    ,M.NR_IVA
    ,M.CAUSALEID
    ,M.IMPORTO
    ,M.NOTE
    ,M.CLIENTEID
    ,M.FORNITOREID
    ,M.BANCAID
    ,M.FATTURA_PDF
    ,M.NOME_FATTURA_PDF
    ,M.FATTURA_XML
    ,M.NOME_FATTURA_XML
    ,R.ID
    ,R.DX
    ,R.NR_RIGA
    ,R.UTENTE_INSERIMENTOID
    ,R.CONTOID
    ,R.DATASCADENZA
    ,R.PARTITA
    ,R.IMPORTO
    ,R.SEGNO
    ,R.COD_IVAID
    ,R.CENTRO_COSTOID
    ,R.CLIENTEID
    ,R.FORNITOREID
    ,R.BANCAID
    ,R.NOMINATIVOID 
	,CASE WHEN R.SEGNO = 'D' THEN R.IMPORTO ELSE 0 END
	,CASE WHEN R.SEGNO = 'A' THEN R.IMPORTO ELSE 0 END
FROM 
     RIGHE_CONTABILI R 
INNER JOIN
     MOVIMENTI_CONTABILI M 
ON
     M.ID = R.MOVIMENTOID


GO
/****** Oggetto: View [dbo].[V_SALDOCONTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SALDOCONTI]
      ( ID,
     CODCONTO,
     DX,
     SEZIONE,
     LIVELLO,
     CODPADRE,
     ESERCID,
	 TOT_DARE,
	 TOT_AVERE,
	 SEGNO_SALDO,
     SALDO   ) AS
SELECT 
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
     C.LIVELLO,
     C.CODPADRE,
     M.ESERCID,
	 COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE 0 END),0) TOT_DARE,
     COALESCE(SUM(CASE WHEN SEGNO='A' THEN R.IMPORTO ELSE 0 END),0) TOT_AVERE,
	 CASE
	   WHEN COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE 0 END),0) > COALESCE(SUM(CASE WHEN SEGNO='A' THEN R.IMPORTO ELSE 0 END),0) THEN 'D'
	   ELSE 'A'
	 END SEGNO_SALDO, 
     COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE -R.IMPORTO END),0) SALDO
FROM 
     CONTICONTABILI C
INNER JOIN
     RIGHE_CONTABILI R 
ON
     C.ID = R.CONTOID 
INNER JOIN
     MOVIMENTI_CONTABILI M 
ON
     M.ID = R.MOVIMENTOID
LEFT OUTER JOIN
  NOMINATIVI N
ON
  N.ID = R.NOMINATIVOID
LEFT OUTER JOIN
  BANCHE B
ON
  B.ID = R.BANCAID
LEFT OUTER JOIN
  CLIENTI CL
ON
  CL.ID = R.CLIENTEID
LEFT OUTER JOIN
  FORNITORI F
ON
  F.ID = R.NOMINATIVOID
WHERE
  M.TIPO_MOV NOT IN ('MC') --escludo i movimenti di chiusura esercizio
GROUP BY
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
     C.LIVELLO,
     C.CODPADRE,
     M.ESERCID

GO
/****** Oggetto: Table [dbo].[DETTAGLI_IVA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DETTAGLI_IVA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[MOVIMENTOCLASS] [varchar](32) NULL,
	[MOVIMENTOID] [varchar](32) NULL,
	[CODICE_IVACLASS] [varchar](32) NULL,
	[CODICE_IVAID] [varchar](32) NULL,
	[IMPONIBILE] [money] NULL,
	[IMPOSTA] [money] NULL,
	[IMP_DETR] [money] NULL,
	[IMP_INDETR] [money] NULL,
 CONSTRAINT [DETTAGLI_IVA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_REGISTRO_IVA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_REGISTRO_IVA]
   ( ESERCID,
     DATA_DOC,
     DATA_REG,
     TIPO_MOV,
     REG_IVAID,
     FORNITOREID,
     CLIENTEID,
     IMPONIBILE,
     CODICE_IVAID,
     IMPOSTA,
     IMP_DETR,
     IMP_INDETR,
     TRIMESTRE,
     ANNO   ) AS
SELECT
  MC.ESERCID,
  MC.DATA_DOC,
  MC.DATA_REG,
  MC.TIPO_MOV,
  MC.REG_IVAID,
  MC.FORNITOREID,
  MC.CLIENTEID,
  DI.IMPONIBILE,
  DI.CODICE_IVAID,
  DI.IMPOSTA,
  DI.IMP_DETR,
  DI.IMP_INDETR,
  CASE WHEN MONTH(MC.DATA_DOC) <= 3 THEN 'I trimestre'
            WHEN MONTH(MC.DATA_DOC) <= 6 THEN 'II trimestre'
            WHEN MONTH(MC.DATA_DOC) <= 9 THEN 'III trimestre'
            ELSE 'IV trimestre'
   END,
   YEAR(MC.DATA_DOC)
FROM
  MOVIMENTI_CONTABILI MC
INNER JOIN
  DETTAGLI_IVA DI
ON
  DI.MOVIMENTOID = MC.ID
GO
/****** Oggetto: Table [dbo].[CONFIGURATION]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONFIGURATION](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NULL,
	[DBVERSION] [varchar](10) NOT NULL,
	[DOCPATH] [varchar](200) NULL,
	[IMGPATH] [varchar](200) NULL,
	[SNDPATH] [varchar](200) NULL,
	[TPLPATH] [varchar](200) NULL,
	[TPLXSLPATH] [varchar](200) NULL,
	[TPLHTMLPATH] [varchar](200) NULL,
	[IMPORTPATH] [varchar](200) NULL,
	[EXPORTPATH] [varchar](200) NULL,
	[COMPANYNAME] [varchar](50) NULL,
	[ADDRESS] [varchar](50) NULL,
	[CITY] [varchar](40) NULL,
	[ZIP] [varchar](5) NULL,
	[PROVINCE] [varchar](2) NULL,
	[FISCAL_CODE] [varchar](16) NULL,
	[VATNUM] [varchar](11) NULL,
	[LICENSE_N] [varchar](20) NULL,
	[OPERATING_LEV] [smallint] NULL,
	[SUPPORT_EMAIL] [varchar](50) NULL,
	[INFO_EMAIL] [varchar](50) NULL,
	[SITO_INTERNET] [varchar](100) NULL,
	[LOGO_SOC] [image] NULL,
	[TELEFONO] [varchar](20) NULL,
	[FAX] [varchar](20) NULL,
	[COLORI_SOCIALI] [varchar](30) NULL,
	[REGIME_FISCALE] [varchar](4) NULL,
 CONSTRAINT [CONFIGURATION_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[KITTO_PERMISSIONS]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[KITTO_PERMISSIONS]
(RESOURCE_URI_PATTERN, ACCESS_MODES, GRANT_VALUE, GRANTEE_NAME, NOTES) AS
SELECT '*', 'ALL', 1, '*', 'Accesso a tutto per tutti in lettura e scrittura'
UNION ALL SELECT 'metadata://Model/*', 'ALL', 1, '*', 'Accesso a tutti i modelli e i campi per tutti in lettura e scrittura'
UNION ALL SELECT 'metadata://View/*', 'ALL', 1, '*', 'Accesso a tutte le view i campi per tutti in lettura e scrittura'
UNION ALL SELECT 'metadata://View/ADMIN_*', 'ALL', 0, 'USER_ROLE', 'ADMIN_ROLE può lanciare ed editare tutte le view che iniziano per ADMIN_'
UNION ALL SELECT 'metadata://View/USER_*', 'ALL', 0, 'ADMIN_ROLE', 'USER_ROLE può lanciare ed editare tutte le view che iniziano per USER_'
UNION ALL SELECT 'metadata://Model/Nominativo/CodiceFiscale', 'MODIFY', 0, 'USER_ROLE', 'USER_ROLE non può modificare il CodiceFiscale di un nominativo'
UNION ALL SELECT 'metadata://Model/Configurazione/*', 'ADD,DELETE,MODIFY', 0, 'ADMIN_ROLE', 'ADMIN_ROLE non può modificare i campi della tabella di configurazione'
UNION ALL SELECT 'metadata://Model/Utente', 'ADD,DELETE,MODIFY', 0, 'ADMIN_ROLE', 'ADMIN_ROLE non può modificare la tabella di configurazione'
FROM CONFIGURATION
WHERE CONFIGURATION.ID = 'CONFIG000'
GO
/****** Oggetto: Table [dbo].[DETRAZIONI_FISCALI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DETRAZIONI_FISCALI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[COGNOME] [varchar](100) NULL,
	[NOME] [varchar](100) NULL,
	[CODFISC] [varchar](16) NULL,
	[INDIRIZZO] [varchar](50) NULL,
	[CAP] [varchar](5) NULL,
	[COMUNE] [varchar](200) NULL,
	[PROVINCIAID] [varchar](2) NULL,
	[PROVINCIA] [varchar](200) NULL,
	[PERC_DETRAZIONI] [smallint] NULL,
	[ISCR_COGNOME] [varchar](100) NULL,
	[ISCR_NOME] [varchar](100) NULL,
	[ISCR_DATANASC] [datetime] NULL,
	[ISCR_COMUNENASC] [varchar](200) NULL,
	[ISCR_PROVNASCID] [varchar](2) NULL,
	[ISCR_PROVNASC] [varchar](200) NULL,
	[ISCR_CODFISC] [varchar](16) NULL,
	[IMPORTOPAGATO] [money] NULL,
	[IMPORTO_PERC] [money] NULL,
	[ANNO] [int] NULL,
	[DATA_STAMPA] [datetime] NULL,
	[FILE_DOCUMENTO] [varchar](50) NULL,
	[NOME_FILE_ORIGINALE] [varchar](200) NULL,
	[DESC_CAMPAGNA] [varchar](200) NULL,
	[MOD_PAGAMENTO] [varchar](200) NULL,
	[NUMERO] [int] NULL,
	[PRES_COGNOME] [varchar](100) NULL,
	[PRES_NOME] [varchar](100) NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[DATA_PAGAMENTO] [datetime] NULL,
 CONSTRAINT [DETRAZIONI_FISCALI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[DOCUMENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DOCUMENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TIPODOCCLASS] [varchar](32) NOT NULL,
	[TIPODOCID] [varchar](32) NOT NULL,
	[DATARIL] [datetime] NOT NULL,
	[ENTE] [varchar](100) NOT NULL,
	[DATASCAD] [datetime] NULL,
	[NUMERO] [varchar](40) NOT NULL,
	[NOTE] [text] NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[FILE_DOCUMENTO] [varchar](50) NULL,
	[NOME_FILE_ORIGINALE] [varchar](200) NULL,
 CONSTRAINT [DOCUMENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[VIEW_DOC_NOMINATIVI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[VIEW_DOC_NOMINATIVI]
(ID
    ,DX
    ,TIPODOCID
    ,NOMINATIVOID      
    ,FILE_DOCUMENTO
    ,NOME_FILE_ORIGINALE)
AS
SELECT 
    ID
     ,'Certificato Medico' DX
    ,'VM' TIPODOCID
    ,NOMINATIVOID      
    ,'VisiteMediche\'+FILE_DOCUMENTO
    ,NOME_FILE_ORIGINALE
FROM VISITEMEDICHE
WHERE
  FILE_DOCUMENTO IS NOT NULL
UNION ALL
SELECT 
     ID
    ,DX
    ,TIPODOCID
    ,NOMINATIVOID
    ,'Documenti\'+FILE_DOCUMENTO
    ,NOME_FILE_ORIGINALE
FROM DOCUMENTI
WHERE
   FILE_DOCUMENTO IS NOT NULL
UNION ALL
SELECT 
     ID
    ,DX
    ,'DF'
    ,NOMINATIVOID
    ,'DetrazioniFiscali\'+FILE_DOCUMENTO
    ,NOME_FILE_ORIGINALE
FROM DETRAZIONI_FISCALI
WHERE
   FILE_DOCUMENTO IS NOT NULL
GO
/****** Oggetto: Table [dbo].[COMUNI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[COMUNI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[PROVCLASS] [varchar](32) NULL,
	[PROVID] [varchar](32) NULL,
	[CAP] [varchar](5) NULL,
	[ESTINTO] [varchar](1) NULL,
 CONSTRAINT [COMUNI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[IMPIANTI_SPORTIVI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IMPIANTI_SPORTIVI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[INDIRIZZO] [varchar](50) NOT NULL,
	[CAP] [varchar](5) NOT NULL,
	[PROVINCIACLASS] [varchar](32) NOT NULL,
	[PROVINCIAID] [varchar](32) NOT NULL,
	[CAMPOSCOPERTO] [bit] NULL,
	[ILLUMINATO] [bit] NULL,
	[FONDO_CAMPO] [varchar](20) NULL,
	[TIPO_IMPIANTOCLASS] [varchar](32) NULL,
	[TIPO_IMPIANTOID] [varchar](32) NULL,
	[ALTRO] [varchar](20) NULL,
	[TELEFONO] [varchar](20) NULL,
	[FAX] [varchar](20) NULL,
	[FOTO] [image] NULL,
	[ITINERARIO] [text] NULL,
	[CARTINA] [image] NULL,
	[PROPRIO] [bit] NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
 CONSTRAINT [IMPIANTI_SPORTIVI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[SQUADRE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SQUADRE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SIGLA] [varchar](30) NOT NULL,
	[TIPOSPORTCLASS] [varchar](32) NOT NULL,
	[TIPOSPORTID] [varchar](32) NOT NULL,
	[COD_FEDER] [varchar](15) NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[CATEGORIACLASS] [varchar](32) NOT NULL,
	[CATEGORIAID] [varchar](32) NOT NULL,
	[MINISIGLA] [varchar](3) NULL,
	[PROPRIA] [bit] NOT NULL,
	[SOCIETACLASS] [varchar](32) NULL,
	[SOCIETAID] [varchar](32) NULL,
	[SPONSORCLASS] [varchar](32) NULL,
	[SPONSORID] [varchar](32) NULL,
	[CAMPOCLASS] [varchar](32) NULL,
	[CAMPOID] [varchar](32) NULL,
	[PRIMOCOLORE] [varchar](20) NULL,
	[SECONDOCOLORE] [varchar](20) NULL,
	[PALLONE] [varchar](30) NULL,
	[DAY_GARACLASS] [varchar](32) NULL,
	[DAY_GARAID] [varchar](32) NULL,
	[ORARIO] [datetime] NULL,
	[RITROVO] [varchar](100) NULL,
	[ALLENATORECLASS] [varchar](32) NULL,
	[ALLENATOREID] [varchar](32) NULL,
	[ACCOMPAGNATORECLASS] [varchar](32) NULL,
	[ACCOMPAGNATOREID] [varchar](32) NULL,
	[FOTO] [image] NULL,
	[LOGO] [image] NULL,
	[NUMERO] [int] NOT NULL,
 CONSTRAINT [SQUADRE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CALENDARIO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CALENDARIO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DATA] [datetime] NOT NULL,
	[ORA] [datetime] NULL,
	[TIPOEVENTOCLASS] [varchar](32) NOT NULL,
	[TIPOEVENTOID] [varchar](32) NOT NULL,
	[PERSRIFCLASS] [varchar](32) NULL,
	[PERSRIFID] [varchar](32) NULL,
	[NOTE] [varchar](200) NULL,
	[DATAORAINIZIO] [datetime] NULL,
	[DATAORAFINE] [datetime] NULL,
 CONSTRAINT [CALENDARIO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[ACCOPPIAMENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ACCOPPIAMENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[OWNERGIORNATACLASS] [varchar](32) NOT NULL,
	[OWNERGIORNATAID] [varchar](32) NOT NULL,
	[CASACLASS] [varchar](32) NOT NULL,
	[CASAID] [varchar](32) NOT NULL,
	[PUNTI_CASA] [smallint] NULL,
	[SET_CASA] [smallint] NULL,
	[OSPITICLASS] [varchar](32) NOT NULL,
	[OSPITIID] [varchar](32) NOT NULL,
	[PUNTI_OSPITI] [smallint] NULL,
	[SET_OSPITI] [smallint] NULL,
	[STATUSCLASS] [varchar](32) NOT NULL,
	[STATUSID] [varchar](32) NOT NULL,
	[NUMPARTITA] [varchar](20) NULL,
	[DATAPARTITA] [smalldatetime] NULL,
	[ORAPARTITA] [smalldatetime] NULL,
	[LUOGOCLASS] [varchar](32) NULL,
	[LUOGOID] [varchar](32) NULL,
	[PARZIALI] [varchar](50) NULL,
	[SET1_CASA] [smallint] NULL,
	[SET1_OSPITI] [smallint] NULL,
	[SET2_CASA] [smallint] NULL,
	[SET2_OSPITI] [smallint] NULL,
	[SET3_CASA] [smallint] NULL,
	[SET3_OSPITI] [smallint] NULL,
	[SET4_CASA] [smallint] NULL,
	[SET4_OSPITI] [smallint] NULL,
	[SET5_CASA] [smallint] NULL,
	[SET5_OSPITI] [smallint] NULL,
 CONSTRAINT [ACCOPPIAMENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[VCALENDARIO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[VCALENDARIO](
    CLASS,
    ID,
    UPDATECOUNT,
    UPDTIMESTAMP,
    DX,
    DATA,
    ORA,
    TIPOEVENTOCLASS,
    TIPOEVENTOID,
    PERSRIFCLASS,
    PERSRIFID,
    OWNEROBJCLASS,
    OWNEROBJID,
    NOTE,
    CATEGORIA,
    GIORNOSETT,
    DATAORAINIZIO,
    DATAORAFINE)
AS
SELECT
  CAST('TISViewCalendario' AS VARCHAR(32)),
  CAST(CALENDARIO.ID AS VARCHAR(32)),
  CAST(1 AS INTEGER),
  CAST(NULL AS TIMESTAMP),
  CALENDARIO.DX,
  CALENDARIO.DATA,
  CALENDARIO.ORA,
  CALENDARIO.TIPOEVENTOCLASS,
  CALENDARIO.TIPOEVENTOID,
  CALENDARIO.PERSRIFCLASS,
  CALENDARIO.PERSRIFID,
  CAST('TISCalendario' AS VARCHAR(32)),
  CALENDARIO.ID,
  CALENDARIO.NOTE,
  CAST(NULL AS VARCHAR(20)),
  CAST(NULL AS VARCHAR(3)),
  CALENDARIO.DATAORAINIZIO,
  CALENDARIO.DATAORAFINE  
FROM CALENDARIO

UNION ALL

SELECT
  CAST('TISViewCalendario' AS VARCHAR(32)),
    ACCOPPIAMENTI.ID,
    CAST(1 AS INTEGER),
    CAST(NULL AS TIMESTAMP), 
    ACCOPPIAMENTI.DX,
    ACCOPPIAMENTI.DATAPARTITA,
    ACCOPPIAMENTI.ORAPARTITA,
    CAST('TISTipoEvento' AS VARCHAR(32)),
    CAST('PC' AS VARCHAR(32)),
    CAST(NULL AS VARCHAR(32)),
    CAST(NULL AS VARCHAR(32)),
    ACCOPPIAMENTI.CASACLASS,
    ACCOPPIAMENTI.CASAID,
    CAST(IMPIANTI_SPORTIVI.DX+' '+IMPIANTI_SPORTIVI.INDIRIZZO+' '+CI.DX AS VARCHAR(200)),
    CAST(NULL AS VARCHAR(20)),
    CAST(NULL AS VARCHAR(3)),
    CAST(NULL AS TIMESTAMP),
    CAST(NULL AS TIMESTAMP)
FROM
  ACCOPPIAMENTI
LEFT OUTER JOIN
  SQUADRE ON (SQUADRE.CLASS = ACCOPPIAMENTI.CASACLASS AND SQUADRE.ID = ACCOPPIAMENTI.CASAID)
LEFT OUTER JOIN
  IMPIANTI_SPORTIVI ON (ACCOPPIAMENTI.LUOGOCLASS = IMPIANTI_SPORTIVI.CLASS AND ACCOPPIAMENTI.LUOGOID = IMPIANTI_SPORTIVI.ID) 
LEFT OUTER JOIN
  COMUNI CI ON IMPIANTI_SPORTIVI.COMUNECLASS = CI.CLASS AND IMPIANTI_SPORTIVI.COMUNEID = CI.ID
WHERE
  SQUADRE.PROPRIA = 1

UNION ALL

SELECT
  CAST('TISViewCalendario' AS VARCHAR(32)),
    ACCOPPIAMENTI.ID,
    CAST(1 AS INTEGER),
    CAST(NULL AS TIMESTAMP), 
    ACCOPPIAMENTI.DX,
    ACCOPPIAMENTI.DATAPARTITA,
    ACCOPPIAMENTI.ORAPARTITA,
    CAST('TISTipoEvento' AS VARCHAR(32)),
    CAST('PF' AS VARCHAR(32)),
    CAST(NULL AS VARCHAR(32)),
    CAST(NULL AS VARCHAR(32)),
    ACCOPPIAMENTI.OSPITICLASS,
    ACCOPPIAMENTI.OSPITIID,
    CAST(IMPIANTI_SPORTIVI.DX+' '+IMPIANTI_SPORTIVI.INDIRIZZO+' '+CI2.DX AS VARCHAR(200)),
    CAST(NULL AS VARCHAR(20)),
    CAST(NULL AS VARCHAR(3)),
    CAST(NULL AS TIMESTAMP),
    CAST(NULL AS TIMESTAMP)
FROM
  ACCOPPIAMENTI
LEFT OUTER JOIN
  SQUADRE ON (SQUADRE.CLASS = ACCOPPIAMENTI.OSPITICLASS AND SQUADRE.ID = ACCOPPIAMENTI.OSPITIID)
LEFT OUTER JOIN
  IMPIANTI_SPORTIVI ON (ACCOPPIAMENTI.LUOGOCLASS = IMPIANTI_SPORTIVI.CLASS AND ACCOPPIAMENTI.LUOGOID = IMPIANTI_SPORTIVI.ID)
LEFT OUTER JOIN
  COMUNI CI2 ON IMPIANTI_SPORTIVI.COMUNECLASS = CI2.CLASS AND IMPIANTI_SPORTIVI.COMUNEID = CI2.ID
WHERE
  SQUADRE.PROPRIA = 1;
GO
/****** Oggetto: Table [dbo].[PARENTELE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PARENTELE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[FLAGGENITORE] [bit] NULL,
	[FLAGFIGLIO] [bit] NULL,
 CONSTRAINT [PARENTELE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[MEMBRI_FAMIGLIE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MEMBRI_FAMIGLIE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[PARENTELACLASS] [varchar](32) NULL,
	[PARENTELAID] [varchar](32) NULL,
	[FAMIGLIACLASS] [varchar](32) NULL,
	[FAMIGLIAID] [varchar](32) NULL,
	[PERC_DETRAZIONI] [smallint] NULL,
 CONSTRAINT [MEMBRI_FAMIGLIE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_GENITORI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_GENITORI] AS
SELECT 
MF.FAMIGLIAID FAMIGLIA_ID, 
MF.ID MEMBRO_ID, 
MF.NOMINATIVOID NOMINATIVO_ID, 
M.COGNOME COGNOME,
M.NOME NOME,
M.CODFISC
FROM 
MEMBRI_FAMIGLIE MF 
INNER JOIN NOMINATIVI M ON MF.NOMINATIVOID = M.ID
LEFT OUTER JOIN PARENTELE P ON MF.PARENTELAID = P.ID
WHERE 
P.FLAGGENITORE = 1
GO
/****** Oggetto: Table [dbo].[CAMPAGNE_ISCRIZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CAMPAGNE_ISCRIZIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[NOTE_ISCRIZIONE] [text] NULL,
	[SCONTO_FRATELLI] [money] NULL,
	[SCADENZA_SCONTO] [smallint] NULL,
	[INIZIO] [datetime] NOT NULL,
	[FINE] [datetime] NOT NULL,
	[QUOTA_ASSOCIATIVA] [money] NULL,
	[SCONTO_RATA_UNICA] [money] NULL,
	[FLAG_ATT_SPORTIVA] [bit] NULL,
	[PERC_SCONTO_FRATELLI] [smallint] NULL,
 CONSTRAINT [CAMPAGNE_ISCRIZIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[PROVINCE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PROVINCE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[REGIONECLASS] [varchar](32) NULL,
	[REGIONEID] [varchar](32) NULL,
 CONSTRAINT [PROVINCE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[MODPAGAMENTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MODPAGAMENTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[RIFBANCARI] [bit] NOT NULL,
	[COD_CONTOCLASS] [varchar](32) NULL,
	[COD_CONTOID] [varchar](32) NULL,
 CONSTRAINT [MODPAGAMENTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CONSIGLIO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONSIGLIO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[QUALIFICACLASS] [varchar](32) NOT NULL,
	[QUALIFICAID] [varchar](32) NOT NULL,
	[DATA_INI] [datetime] NULL,
	[DATA_FINE] [datetime] NULL,
 CONSTRAINT [CONSIGLIO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_DETRAZIONI_FAMIGLIA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW  [dbo].[V_DETRAZIONI_FAMIGLIA]
(
NOMINATIVOID,
COGNOME,
NOME, 
CODFISC,
INDIRIZZO,
CAP,
COMUNE,
PROVINCIAID,
PROVINCIA,
PERC_DETRAZIONI,
ISCR_COGNOME,
ISCR_NOME,
ISCR_DATANASC,
ISCR_COMUNENASC,
ISCR_PROVNASCID,
ISCR_PROVNASC,
ISCR_CODFISC,
DESC_CAMPAGNA,
MOD_PAGAMENTO, 
IMPORTO_PAGATO,
IMPORTO_PERC,
NUMERO,
ANNO_PAGAMENTO,
PRES_COGNOME,
PRES_NOME,
DATA_PAGAMENTO) AS
SELECT
NG.ID,
NG.COGNOME,
NG.NOME,
NG.CODFISC,
NG.INDIRIZZO,
NG.CAP,
C.DX COMUNE,
NG.PROVINCIAID,
PR.DX PROVINCIA,
MFG.PERC_DETRAZIONI,
I.COGNOME ISCR_COGNOME,
I.NOME ISCR_NOME,
I.DATANASC ISCR_DATANASC,
CNI.DX ISCR_COMUNENASC,
I.PROVNASCID ISCR_PROVNASCID,
PRNI.DX ISCR_PROVNASC,
I.CODFISC ISCR_CODFISC,
CI.DX DESC_CAMPAGNA,
MPAG.DX MOD_PAGAMENTO, 
SUM(DP.IMPORTO_PAGATO) IMPORTO_PAGATO,
SUM(DP.IMPORTO_PAGATO)*MFG.PERC_DETRAZIONI/100 IMPORTO_PERC,
ROW_NUMBER() OVER(PARTITION BY YEAR(MP.DATA_PAGAMENTO) ORDER BY YEAR(MP.DATA_PAGAMENTO), NG.COGNOME, NG.NOME ) AS NUMERO,
YEAR(MP.DATA_PAGAMENTO) ANNO_PAGAMENTO,
(SELECT NC.COGNOME FROM CONSIGLIO C INNER JOIN NOMINATIVI NC ON C.NOMINATIVOID = NC.ID  
WHERE QUALIFICAID = 'PS' AND (COALESCE(C.DATA_INI,GETDATE()) <= GETDATE()) AND (COALESCE(C.DATA_FINE,GETDATE()) >= GETDATE())) AS PRES_COGNOME,
(SELECT NC.NOME FROM CONSIGLIO C INNER JOIN NOMINATIVI NC ON C.NOMINATIVOID = NC.ID  
WHERE QUALIFICAID = 'PS'  AND (COALESCE(C.DATA_INI,GETDATE()) <= GETDATE()) AND (COALESCE(C.DATA_FINE,GETDATE()) >= GETDATE())) AS PRES_NOME,
MAX(MP.DATA_PAGAMENTO)
FROM 
  DETTAGLI_PAGAMENTO DP
INNER JOIN
  MEZZI_PAGAMENTO MP
ON 
  MP.ID = DP.MEZZO_PAGAMENTOID
INNER JOIN
  RATE_ISCRIZIONI RI
ON
  DP.RATA_ISCRIZIONEID = RI.ID 
INNER JOIN
  ISCRIZIONI I
ON
  RI.ISCRIZIONEID = I.ID
INNER JOIN
  CAMPAGNE_ISCRIZIONI CI
ON
  CI.ID = I.CAMPAGNAID
INNER JOIN
  MODPAGAMENTO MPAG
ON
  MPAG.ID = MP.MOD_PAGAMENTOID
INNER JOIN
  MEMBRI_FAMIGLIE MF
ON
  MF.NOMINATIVOID = I.NOMINATIVOID
INNER JOIN
  MEMBRI_FAMIGLIE MFG
ON
  MFG.FAMIGLIAID = MF.FAMIGLIAID AND
  MFG.PARENTELAID IN (SELECT P.ID FROM PARENTELE P WHERE P.FLAGGENITORE = 1)
INNER JOIN
  NOMINATIVI NG
ON
  MFG.NOMINATIVOID = NG.ID 
LEFT OUTER JOIN
  COMUNI C
ON
  NG.COMUNEID = C.ID 
LEFT OUTER JOIN
  PROVINCE PR
ON
  NG.PROVINCIAID = PR.ID
LEFT OUTER JOIN
  COMUNI CNI
ON
  I.LUOGONASCID = CNI.ID 
LEFT OUTER JOIN
  PROVINCE PRNI
ON
  I.PROVNASCID = PRNI.ID
WHERE 
  MFG.PERC_DETRAZIONI <> 0
GROUP BY
NG.ID,
NG.COGNOME,
NG.NOME,
NG.CODFISC,
NG.INDIRIZZO,
NG.CAP,
C.DX ,
NG.PROVINCIAID,
PR.DX ,
MFG.PERC_DETRAZIONI,
I.COGNOME ,
I.NOME ,
I.DATANASC,
CNI.DX,
I.PROVNASCID,
PRNI.DX,
I.CODFISC,
CI.DX,
MPAG.DX,
YEAR(MP.DATA_PAGAMENTO)


GO
/****** Oggetto: View [dbo].[V_SALDOCONTI_DETT_RIGHE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SALDOCONTI_DETT_RIGHE]
     ( ID,
     CODCONTO,
     DX,
     SEZIONE,
     ESERCID,
	 DETTAGLIO,
     IMPORTO,
	 NR_MOV,
	 RIG_DX,
	 SEGNO,
	 MOV_DX,
	 MOV_DATA_REG   ) AS
SELECT 
     C.ID,
     C.CODCONTO,
	 C.CODCONTO + ' - ' +  C.DX,
     C.SEZIONE,
     M.ESERCID,
	 CASE 
	   WHEN C.RIF_CLIENTE = 1 THEN CL.DX
	   WHEN C.RIF_SOCIO = 1 THEN N.DX
	   WHEN C.RIF_FORNITORE = 1 THEN F.DX
	   WHEN C.RIF_CONTO_CORRENTE = 1 THEN B.DX
	 END, 
     R.IMPORTO,
	 M.NR_MOV,
	 R.DX,
	 R.SEGNO,
	 M.DX,
	 M.DATA_REG
FROM 
     CONTICONTABILI C
INNER JOIN
     RIGHE_CONTABILI R 
ON
     C.ID = R.CONTOID 
INNER JOIN
     MOVIMENTI_CONTABILI M 
ON
     M.ID = R.MOVIMENTOID
LEFT OUTER JOIN
  NOMINATIVI N
ON
  N.ID = R.NOMINATIVOID
LEFT OUTER JOIN
  BANCHE B
ON
  B.ID = R.BANCAID
LEFT OUTER JOIN
  CLIENTI CL
ON
  CL.ID = R.CLIENTEID
LEFT OUTER JOIN
  FORNITORI F
ON
  F.ID = R.NOMINATIVOID
WHERE
  M.TIPO_MOV NOT IN ('MC')
GO
/****** Oggetto: View [dbo].[V_SALDOCONTI_LIVELLOC]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SALDOCONTI_LIVELLOC]   
  ( ID,
     CODCONTO,
     DX,
     SEZIONE,
     LIVELLO,
     CODPADRE,
     ESERCID,
	 TOT_DARE,
	 TOT_AVERE,
	 SEGNO_SALDO,
     SALDO   ) AS
SELECT 
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
     C.LIVELLO,
     C.CODPADRE,
     SC.ESERCID,
	 COALESCE(SUM(SC.TOT_DARE),0) TOT_DARE,
     COALESCE(SUM(SC.TOT_AVERE),0) TOT_AVERE,
	 CASE
	   WHEN COALESCE(SUM(SC.SALDO),0) > 0 THEN 'D'
	   ELSE 'A'
	 END SEGNO_SALDO, 
     COALESCE(SUM(SC.SALDO), 0)
FROM 
  CONTICONTABILI C
INNER JOIN
  V_SALDOCONTI SC
ON
  C.CODCONTO = SC.CODPADRE
  AND C.SEZIONE = SC.SEZIONE 
WHERE
  C.LIVELLO = 'C'
GROUP BY
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
     C.LIVELLO,
     C.CODPADRE,
     SC.ESERCID
GO
/****** Oggetto: Table [dbo].[FAMIGLIE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FAMIGLIE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVO_CREATORECLASS] [varchar](32) NOT NULL,
	[NOMINATIVO_CREATOREID] [varchar](32) NOT NULL,
 CONSTRAINT [FAMIGLIE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_NUCLEO_FAMIGLIARE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_NUCLEO_FAMIGLIARE] AS
SELECT 
G.CODFISC CREATORE_CODFISC, 
MF.FAMIGLIAID FAMIGLIA_ID, 
MF.ID MEMBRO_ID, 
MF.NOMINATIVOID NOMINATIVO_ID, 
G.COGNOME COGNOME,
G.NOME NOME,
M.CODFISC CODFISC,
MF.PARENTELAID PARENTELA_ID,
P.DX PARENTELA_DX
FROM 
MEMBRI_FAMIGLIE MF 
INNER JOIN FAMIGLIE F ON MF.FAMIGLIAID = F.ID
INNER JOIN V_GENITORI G ON G.FAMIGLIA_ID = F.ID
INNER JOIN NOMINATIVI M ON MF.NOMINATIVOID = M.ID
LEFT OUTER JOIN PARENTELE P ON MF.PARENTELAID = P.ID
GO
/****** Oggetto: View [dbo].[V_RIEP_PAGAMENTO_ISCR]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_RIEP_PAGAMENTO_ISCR] 
(
  ID,
  DX,
  STAGIONEID,
  CAMPAGNAID,
  QUOTA_ISCRIZIONEID,
  COGNOME,
  NOME,
  CODFISC,
  DATANASC,
  COGNOME_GENITORE,
  NOME_GENITORE,
  COD_FISCALE_GENITORE,
  DATA_ISCRIZIONE,
  TOTALE_IMPORTO,
  IMP_PAGATO,
  IMP_RESIDUO
) AS
SELECT 
  I.ID,
  I.DX,
  I.STAGIONEID,
  I.CAMPAGNAID,
  I.QUOTA_ISCRIZIONEID,
  I.COGNOME,
  I.NOME,
  I.CODFISC, 
  I.DATANASC,
  I.COGNOME_GENITORE,
  I.NOME_GENITORE,
  I.COD_FISCALE_GENITORE,
  I.DATA_ISCRIZIONE,
  I.TOTALE_IMPORTO,
  SUM(VI.IMPORTO_PAGATO) IMP_PAGATO,
  SUM(VI.IMPORTO_RESIDUO) IMP_RESIDUO
FROM 
	ISCRIZIONI I
LEFT OUTER JOIN
	RATE_ISCRIZIONI RI
ON
	I.ID = RI.ISCRIZIONEID
LEFT OUTER JOIN
	V_RATE_ISCRIZIONI VI
ON
	VI.ID = RI.ID
WHERE
  I.STATUS = 'ATT'
GROUP BY
  I.ID,
  I.DX,
  I.STAGIONEID,
  I.CAMPAGNAID,
  I.QUOTA_ISCRIZIONEID,
  I.COGNOME,
  I.NOME,
  I.CODFISC,
  I.DATANASC,
  I.COGNOME_GENITORE,
  I.NOME_GENITORE,
  I.COD_FISCALE_GENITORE,
  I.DATA_ISCRIZIONE,  
  I.TOTALE_IMPORTO
GO
/****** Oggetto: View [dbo].[V_SALDOCONTI_LIVELLOM]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SALDOCONTI_LIVELLOM]   
 ( ID,
     CODCONTO,
     DX,
     SEZIONE,
     LIVELLO,
     CODPADRE,
     ESERCID,
	 TOT_DARE,
	 TOT_AVERE,
	 SEGNO_SALDO,
     SALDO   ) AS
SELECT 
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
     C.LIVELLO,
     C.CODPADRE,
     SC.ESERCID,
	 COALESCE(SUM(SC.TOT_DARE),0) TOT_DARE,
     COALESCE(SUM(SC.TOT_AVERE),0) TOT_AVERE,
	 CASE
	   WHEN COALESCE(SUM(SC.SALDO),0) > 0 THEN 'D'
	   ELSE 'A'
	 END SEGNO_SALDO, 
     COALESCE(SUM(SC.SALDO), 0)
FROM 
  CONTICONTABILI C
INNER JOIN
  V_SALDOCONTI_LIVELLOC SC
ON
  C.CODCONTO = SC.CODPADRE
  AND C.SEZIONE = SC.SEZIONE 
WHERE
  C.LIVELLO = 'M'
GROUP BY
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
     C.LIVELLO,
     C.CODPADRE,
     SC.ESERCID
GO
/****** Oggetto: View [dbo].[V_SALDOCONTI_SEZIONE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_SALDOCONTI_SEZIONE]
  ( 
     DX,
     SEZIONE,
     ESERCID,
	 TOT_DARE,
	 TOT_AVERE,
	 SEGNO_SALDO,
     SALDO   ) AS
SELECT 
  CASE   WHEN SC.SEZIONE = 'A' THEN 'Attivo' 
	WHEN SC.SEZIONE = 'P' THEN 'Passivo'
	WHEN SC.SEZIONE = 'R' THEN 'Ricavi' 
	WHEN SC.SEZIONE = 'C' THEN 'Costi'
  END,
     SC.SEZIONE,
     SC.ESERCID,
	 COALESCE(SUM(SC.TOT_DARE),0) TOT_DARE,
     COALESCE(SUM(SC.TOT_AVERE),0) TOT_AVERE,
	 CASE
	   WHEN COALESCE(SUM(SC.SALDO),0) > 0 THEN 'D'
	   ELSE 'A'
	 END SEGNO_SALDO, 
     COALESCE(SUM(SC.SALDO), 0)
FROM 
  V_SALDOCONTI_LIVELLOM SC
GROUP BY
  CASE   WHEN SC.SEZIONE = 'A' THEN 'Attivo' 
	WHEN SC.SEZIONE = 'P' THEN 'Passivo'
	WHEN SC.SEZIONE = 'R' THEN 'Ricavi' 
	WHEN SC.SEZIONE = 'C' THEN 'Costi'
  END,
     SC.SEZIONE,
     SC.ESERCID
GO
/****** Oggetto: Table [dbo].[ESERCIZICONTABILI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ESERCIZICONTABILI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DATAINIZIO] [datetime] NOT NULL,
	[DATAFINE] [datetime] NOT NULL,
	[STATO] [varchar](1) NOT NULL,
	[NRMOV] [smallint] NULL,
 CONSTRAINT [ESERCIZICONTABILI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[V_BILANCIO_DETT]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_BILANCIO_DETT]
   ( ESERCID,
      ESERCDX,
      SEZIONE,
      CODPADRE,
     CODCONTO,    
     LIVELLO,
     DX,
	 TOT_DARE,
	 TOT_AVERE,
	 SEGNO_SALDO,
     SALDO,
     ORD,
	 DETTAGLIO  ) AS
SELECT
	E.ID,  
	E.DX,  
    C.SEZIONE,
	C.CODPADRE,
	C.CODCONTO,
	C.LIVELLO,
	CASE 
        WHEN C.LIVELLO = 'M' THEN C.DX
        WHEN C.LIVELLO = 'C' THEN '&emsp;'+C.DX
      ELSE '' END  DX,
    CASE 
		WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT TOT_DARE FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
		WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT TOT_DARE FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
    END TOT_DARE,
	CASE 
		WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT TOT_AVERE FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
		WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT TOT_AVERE FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
    END TOT_AVERE,
	CASE 
		WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT SEGNO_SALDO FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), '0')
		WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT SEGNO_SALDO FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), '0')
    END SEGNO_SALDO,
	CASE 
		    WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT ABS(SALDO) FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
			WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT ABS(SALDO) FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
          END SALDO
	,CASE 
	    WHEN C.SEZIONE = 'A' THEN  
		  CASE 
		    WHEN C.LIVELLO = 'M' THEN 'A'+C.CODCONTO
		    WHEN C.LIVELLO = 'C' THEN 'A'+C.CODPADRE+C.CODCONTO
          END 
		WHEN C.SEZIONE = 'P' THEN 
		  CASE 
		      WHEN C.LIVELLO = 'M' THEN 'B'+C.CODCONTO
		      WHEN C.LIVELLO = 'C' THEN 'B'+C.CODPADRE+C.CODCONTO
           END 
		WHEN C.SEZIONE = 'R' THEN 
		  CASE 
		      WHEN C.LIVELLO = 'M' THEN 'C'+C.CODCONTO
		      WHEN C.LIVELLO = 'C' THEN 'C'+C.CODPADRE+C.CODCONTO
           END
		WHEN C.SEZIONE = 'C' THEN
		  CASE 
		      WHEN C.LIVELLO = 'M' THEN 'D'+C.CODCONTO
		      WHEN C.LIVELLO = 'C' THEN 'D'+C.CODPADRE+C.CODCONTO
          END
		END ORD,
		NULL
  FROM
    CONTICONTABILI C, ESERCIZICONTABILI E
  WHERE
    C.DISATTIVATO = 0 AND C.LIVELLO IN ('M', 'C')
  UNION
SELECT
	E.ID,  
	E.DX,  
    C.SEZIONE,
	C.CODPADRE,
	C.CODCONTO,
	C.LIVELLO,
	'&emsp;&emsp;'+C.DX DX,
	COALESCE(TOT_DARE, 0) TOT_DARE,
	COALESCE(TOT_AVERE, 0) TOT_AVERE,
	COALESCE(SEGNO_SALDO, '0') SEGNO_SALDO,
	 COALESCE( ABS(SALDO) , 0) SALDO
	,CASE 
	    WHEN C.SEZIONE = 'A' THEN 'A'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO
		WHEN C.SEZIONE = 'P' THEN 'B'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO                              
		WHEN C.SEZIONE = 'R' THEN 'C'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO
		WHEN C.SEZIONE = 'C' THEN 'D'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO
	END ORD,
	DETTAGLIO
  FROM
    CONTICONTABILI C
	FULL OUTER JOIN
	  ESERCIZICONTABILI E
	ON
	  1 = 1
	LEFT OUTER JOIN 
	  V_SALDOCONTI_DETT V
	ON
	  V.ID = C.ID AND E.ID = V.ESERCID
  WHERE
    C.DISATTIVATO = 0 AND C.LIVELLO = 'S'
  UNION
SELECT
	E.ID,  
	E.DX,  
                  C.SEZIONE,
	NULL,
	NULL,
	'A',
	CASE 
	    WHEN SEZIONE = 'A' THEN 'Attivo' 
		WHEN SEZIONE = 'P' THEN 'Passivo'
		WHEN SEZIONE = 'R' THEN 'Ricavi' 
		WHEN SEZIONE = 'C' THEN 'Costi'
	END,
	COALESCE((SELECT TOT_DARE FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), 0) TOT_DARE,
	COALESCE((SELECT TOT_AVERE FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), 0) TOT_AVERE,
	COALESCE((SELECT SEGNO_SALDO FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), '0') SEGNO_SALDO,
	COALESCE((SELECT ABS(SALDO) FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), 0) SALDO
	,CASE 
	    WHEN SEZIONE = 'A' THEN 'XXXXA'
		WHEN SEZIONE = 'P' THEN 'XXXXB'
		WHEN SEZIONE = 'R' THEN 'XXXXC'
		WHEN SEZIONE = 'C' THEN 'XXXXD'
		END ORD
	, NULL
  FROM
    CONTICONTABILI C, ESERCIZICONTABILI E
  WHERE
    C.LIVELLO = 'M'
  GROUP BY
    E.ID,  
    E.DX,  
    C.SEZIONE
GO
/****** Oggetto: View [dbo].[V_BILANCIO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[V_BILANCIO]
     ( ESERCID,
      ESERCDX,
      SEZIONE,
      CODPADRE,
     CODCONTO,
	 CONTO_ID,    
     LIVELLO,
     DX,
	 TOT_DARE,
	 TOT_AVERE,
	 SEGNO_SALDO,
     SALDO,
     ORD   ) AS
SELECT
	E.ID,  
	E.DX,  
    C.SEZIONE,
	C.CODPADRE,
	C.CODCONTO,
	C.ID,
	C.LIVELLO,
	CASE 
        WHEN C.LIVELLO = 'M' THEN C.DX
        WHEN C.LIVELLO = 'C' THEN '&emsp;'+C.DX
        WHEN C.LIVELLO = 'S' THEN '&emsp;&emsp;'+C.DX
      ELSE '' END  DX,
	CASE 
		WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT TOT_DARE FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
		WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT TOT_DARE FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
		WHEN C.LIVELLO = 'S' THEN COALESCE((SELECT TOT_DARE FROM V_SALDOCONTI V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
    END TOT_DARE,
	CASE 
		WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT TOT_AVERE FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
		WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT TOT_AVERE FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
		WHEN C.LIVELLO = 'S' THEN COALESCE((SELECT TOT_AVERE FROM V_SALDOCONTI V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
    END TOT_AVERE,
	CASE 
		WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT SEGNO_SALDO FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), '0')
		WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT SEGNO_SALDO FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), '0')
		WHEN C.LIVELLO = 'S' THEN COALESCE((SELECT SEGNO_SALDO FROM V_SALDOCONTI V WHERE V.ID = C.ID AND E.ID = V.ESERCID), '0')
    END SEGNO_SALDO,
	CASE 
		    WHEN C.LIVELLO = 'M' THEN COALESCE((SELECT ABS(SALDO) FROM V_SALDOCONTI_LIVELLOM V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
			WHEN C.LIVELLO = 'C' THEN COALESCE((SELECT ABS(SALDO) FROM V_SALDOCONTI_LIVELLOC V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
			WHEN C.LIVELLO = 'S' THEN COALESCE((SELECT ABS(SALDO) FROM V_SALDOCONTI V WHERE V.ID = C.ID AND E.ID = V.ESERCID), 0)
          END SALDO
	,CASE 
	    WHEN C.SEZIONE = 'A' THEN  
		  CASE 
		    WHEN C.LIVELLO = 'M' THEN 'A'+C.CODCONTO
		    WHEN C.LIVELLO = 'C' THEN 'A'+C.CODPADRE+C.CODCONTO
		    WHEN C.LIVELLO = 'S' THEN 'A'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO
                                       END 
		WHEN C.SEZIONE = 'P' THEN 
		  CASE 
		      WHEN C.LIVELLO = 'M' THEN 'B'+C.CODCONTO
		      WHEN C.LIVELLO = 'C' THEN 'B'+C.CODPADRE+C.CODCONTO
		       WHEN C.LIVELLO = 'S' THEN 'B'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO
                                       END 
		WHEN C.SEZIONE = 'R' THEN 
		  CASE 
		      WHEN C.LIVELLO = 'M' THEN 'C'+C.CODCONTO
		      WHEN C.LIVELLO = 'C' THEN 'C'+C.CODPADRE+C.CODCONTO
		      WHEN C.LIVELLO = 'S' THEN 'C'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO
                                       END
		WHEN C.SEZIONE = 'C' THEN
		  CASE 
		      WHEN C.LIVELLO = 'M' THEN 'D'+C.CODCONTO
		      WHEN C.LIVELLO = 'C' THEN 'D'+C.CODPADRE+C.CODCONTO
		      WHEN C.LIVELLO = 'S' THEN 'D'+(SELECT C1.CODPADRE FROM CONTICONTABILI C1 WHERE C1.SEZIONE = C.SEZIONE AND C1.CODCONTO = C.CODPADRE)+C.CODPADRE+C.CODCONTO
                                         END
		END ORD
  FROM
    CONTICONTABILI C, ESERCIZICONTABILI E
  WHERE
    C.DISATTIVATO = 0
  UNION
SELECT
	E.ID,  
	E.DX,  
    C.SEZIONE,
	NULL,
	NULL,
	NULL,
	'A',
	CASE 
	    WHEN SEZIONE = 'A' THEN 'Attivo' 
		WHEN SEZIONE = 'P' THEN 'Passivo'
		WHEN SEZIONE = 'R' THEN 'Ricavi' 
		WHEN SEZIONE = 'C' THEN 'Costi'
	END,
    COALESCE((SELECT TOT_DARE FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), 0) TOT_DARE,
	COALESCE((SELECT TOT_AVERE FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), 0) TOT_AVERE,
	COALESCE((SELECT SEGNO_SALDO FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), '0') SEGNO_SALDO,
	COALESCE((SELECT ABS(SALDO) FROM V_SALDOCONTI_SEZIONE V WHERE V.SEZIONE = C.SEZIONE AND E.ID = V.ESERCID), 0) SALDO
	
	,CASE 
	    WHEN SEZIONE = 'A' THEN 'XXXXA'
		WHEN SEZIONE = 'P' THEN 'XXXXB'
		WHEN SEZIONE = 'R' THEN 'XXXXC'
		WHEN SEZIONE = 'C' THEN 'XXXXD'
		END ORD
  FROM
    CONTICONTABILI C, ESERCIZICONTABILI E
  WHERE
    C.LIVELLO = 'M'
  GROUP BY
    E.ID,  
    E.DX,  
    C.SEZIONE
GO
/****** Oggetto: View [dbo].[V_SALDOCONTI_DETT_BIL]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE VIEW [dbo].[V_SALDOCONTI_DETT_BIL]
   ( ID,
     CODCONTO,
     DX,
     SEZIONE,
	 LIVELLO,
	 CODPADRE,
	 DX_CONTO,
     ESERCID,	 
	 NOMINATIVOID,
     CLIENTEID,
     FORNITOREID,
	 IMPORTO_AVERE,
	 IMPORTO_DARE,
	 SEGNO_SALDO,
     SALDO   ) AS
SELECT 
     C.ID,
     C.CODCONTO,
	 C.CODCONTO + ' - ' +  C.DX,
     C.SEZIONE,
	 C.LIVELLO,
	 C.CODPADRE,
	 C.DX,
     M.ESERCID,
	 R.NOMINATIVOID,
     R.CLIENTEID,
     R.FORNITOREID, 
	 COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE 0 END),0) TOT_DARE,
     COALESCE(SUM(CASE WHEN SEGNO='A' THEN R.IMPORTO ELSE 0 END),0) TOT_AVERE,
	 CASE
	   WHEN COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE 0 END),0) > COALESCE(SUM(CASE WHEN SEGNO='A' THEN R.IMPORTO ELSE 0 END),0) THEN 'D'
	   ELSE 'A'
	 END SEGNO_SALDO, 
     COALESCE(SUM(CASE WHEN SEGNO='D' THEN R.IMPORTO ELSE -R.IMPORTO END),0) SALDO 
FROM 
     CONTICONTABILI C
INNER JOIN
     RIGHE_CONTABILI R 
ON
     C.ID = R.CONTOID 
INNER JOIN
     MOVIMENTI_CONTABILI M 
ON
     M.ID = R.MOVIMENTOID
GROUP BY
     C.ID,
     C.CODCONTO,
     C.DX,
     C.SEZIONE,
	 C.LIVELLO,
	 C.CODPADRE,
     M.ESERCID,
	 R.NOMINATIVOID,
     R.CLIENTEID,
     R.FORNITOREID






GO
/****** Oggetto: Table [dbo].[CODA_EMAIL]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CODA_EMAIL](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TESTO_EMAILCLASS] [varchar](32) NULL,
	[TESTO_EMAILID] [varchar](32) NULL,
	[EMAIL_FROM] [varchar](50) NULL,
	[EMAIL_TO] [varchar](2000) NULL,
	[EMAIL_CC] [varchar](2000) NULL,
	[EMAIL_BCC] [varchar](2000) NULL,
	[EMAIL_SUBJECT] [varchar](1000) NULL,
	[EMAIL_BODY] [text] NULL,
	[EMAIL_ATTACH] [varchar](200) NULL,
	[DATA_ORA_INSERIMENTO] [datetime] NULL,
	[OPERATORE_INSERIMENTOCLASS] [varchar](32) NULL,
	[OPERATORE_INSERIMENTOID] [varchar](32) NULL,
	[MINIMA_DATA_ORA_TRASMISSIONE] [datetime] NULL,
	[DATA_ORA_TRASMISSIONE] [datetime] NULL,
	[TABELLA_ORIGINE] [varchar](100) NULL,
	[OGGETTO_ORIGINE] [varchar](32) NULL,
	[EMAIL_BODYHTML] [text] NULL,
 CONSTRAINT [CODA_EMAIL_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TESSERAMENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TESSERAMENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[SOC_TITOLARECLASS] [varchar](32) NULL,
	[SOC_TITOLAREID] [varchar](32) NULL,
	[NOMINATIVOCLASS] [varchar](32) NOT NULL,
	[NOMINATIVOID] [varchar](32) NOT NULL,
	[CAMPIONATOCLASS] [varchar](32) NOT NULL,
	[CAMPIONATOID] [varchar](32) NOT NULL,
	[ABBUONO] [money] NULL,
	[QUOTA_TOT] [money] NULL,
	[COD_CONTRATTO] [varchar](20) NULL,
	[DATA_DEP_CONTRATTO] [datetime] NULL,
	[DATA_INIZIO] [datetime] NULL,
	[DATA_SCADENZA] [datetime] NULL,
	[TESSERA] [varchar](20) NULL,
	[PRESTITO] [bit] NULL,
 CONSTRAINT [TESSERAMENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[STAGIONE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[STAGIONE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DATAINI] [datetime] NOT NULL,
	[DATAFINE] [datetime] NOT NULL,
 CONSTRAINT [STAGIONE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[VW_KPI_SCM]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[VW_KPI_SCM] AS
WITH StagAttiva AS (
  SELECT TOP 1 ID, DX, DATAINI FROM dbo.STAGIONE
   WHERE DATAINI <= GETDATE() AND DATAFINE >= GETDATE()
   ORDER BY DATAINI DESC
),
StagPrec AS (
  SELECT TOP 1 ID FROM dbo.STAGIONE
   WHERE DATAINI < (SELECT DATAINI FROM StagAttiva)
   ORDER BY DATAINI DESC
)
SELECT
  CAST(1 AS INT) AS KPI_ID,
  ISNULL((SELECT ID FROM StagAttiva), '') AS STAGIONE_ID,
  ISNULL((SELECT DX FROM StagAttiva), '(nessuna)') AS STAGIONE_DESC,
  (SELECT COUNT(*) FROM dbo.ISCRIZIONI
    WHERE STATUS='ATT' AND STAGIONEID=(SELECT ID FROM StagAttiva)) AS NUM_ISCRITTI,
  (SELECT COUNT(*) FROM dbo.ISCRIZIONI
    WHERE STATUS='INS' AND STAGIONEID=(SELECT ID FROM StagAttiva)) AS ISCRIZIONI_IN_ATTESA,
  (SELECT COUNT(*) FROM dbo.V_RATE_ISCRIZIONI VR
     JOIN dbo.RATE_ISCRIZIONI R ON R.ID = VR.ID
     JOIN dbo.ISCRIZIONI I ON I.ID = R.ISCRIZIONEID
    WHERE I.STAGIONEID=(SELECT ID FROM StagAttiva) AND VR.STATUS='pagata') AS RATE_VERSATE,
  (SELECT COUNT(*) FROM dbo.V_RATE_ISCRIZIONI VR
     JOIN dbo.RATE_ISCRIZIONI R ON R.ID = VR.ID
     JOIN dbo.ISCRIZIONI I ON I.ID = R.ISCRIZIONEID
    WHERE I.STAGIONEID=(SELECT ID FROM StagAttiva) AND VR.STATUS IN ('inserita','parziale')) AS RATE_DA_VERSARE,
  (SELECT COUNT(*) FROM dbo.SQUADRE
    WHERE STAGIONEID=(SELECT ID FROM StagAttiva) AND ISNULL(PROPRIA,1)=1) AS SQUADRE_ATTIVE,
  (SELECT COUNT(*) FROM dbo.MEZZI_PAGAMENTO WHERE STATUS='INS') AS PAGAMENTI_DA_VERIFICARE,
  (SELECT COUNT(*) FROM dbo.CODA_EMAIL WHERE DATA_ORA_TRASMISSIONE IS NULL) AS EMAIL_IN_CODA,
  (SELECT COUNT(*) FROM dbo.DETRAZIONI_FISCALI WHERE DATA_STAMPA IS NULL) AS DETRAZIONI_DA_STAMPARE,
  (SELECT COUNT(DISTINCT I.NOMINATIVOID)
     FROM dbo.ISCRIZIONI I
    WHERE I.STATUS='ATT'
      AND I.STAGIONEID IN (
        ISNULL((SELECT ID FROM StagAttiva), ''),
        ISNULL((SELECT ID FROM StagPrec), '')
      )
      AND EXISTS (
        SELECT 1 FROM dbo.VISITEMEDICHE V1
        WHERE V1.NOMINATIVOID = I.NOMINATIVOID
          AND V1.UPDTIMESTAMP = (SELECT MAX(UPDTIMESTAMP) FROM dbo.VISITEMEDICHE V2 WHERE V2.NOMINATIVOID = V1.NOMINATIVOID)
          AND (V1.SCADENZA < GETDATE() OR ISNULL(V1.IDEONEITA,0) = 0)
      )
  ) AS CERTIFICATI_SCADUTI,
  (SELECT COUNT(DISTINCT I.NOMINATIVOID)
     FROM dbo.ISCRIZIONI I
    WHERE I.STATUS='ATT'
      AND I.STAGIONEID IN (
        ISNULL((SELECT ID FROM StagAttiva), ''),
        ISNULL((SELECT ID FROM StagPrec), '')
      )
      AND NOT EXISTS (SELECT 1 FROM dbo.VISITEMEDICHE V1 WHERE V1.NOMINATIVOID = I.NOMINATIVOID)
  ) AS SENZA_CERTIFICATO,
  (SELECT COUNT(*) FROM dbo.VISITEMEDICHE
    WHERE DATA_VISITA >= CAST(GETDATE() AS DATE) AND ISNULL(EFFETTUATA,0)=0) AS VISITE_PRENOTATE,
  (SELECT COUNT(*) FROM dbo.TESSERAMENTI
    WHERE STAGIONEID=(SELECT ID FROM StagAttiva)
      AND DATA_SCADENZA BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE))) AS TESSERAMENTI_IN_SCADENZA;

GO
/****** Oggetto: Table [dbo].[TIPOSPORT]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TIPOSPORT](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[GESTPAREGGIO] [bit] NULL,
	[GESTSETS] [bit] NULL,
	[GESTMEDIAING] [bit] NULL,
 CONSTRAINT [TIPOSPORT_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[ROSE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ROSE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[RUOLO_GIOCCLASS] [varchar](32) NULL,
	[RUOLO_GIOCID] [varchar](32) NULL,
	[NUMERO_MAGLIA] [varchar](3) NULL,
	[SQUADRACLASS] [varchar](32) NOT NULL,
	[SQUADRAID] [varchar](32) NOT NULL,
 CONSTRAINT [ROSE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[VW_ISCRITTI_PER_DISCIPLINA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[VW_ISCRITTI_PER_DISCIPLINA] AS
WITH StagAttiva AS (
  SELECT TOP 1 ID FROM dbo.STAGIONE WHERE DATAINI <= GETDATE() AND DATAFINE >= GETDATE() ORDER BY DATAINI DESC
)
SELECT
  ISNULL(TS.DX, '(senza disciplina)') AS DISCIPLINA,
  COUNT(DISTINCT I.NOMINATIVOID) AS NUM_ISCRITTI
FROM dbo.ISCRIZIONI I
LEFT JOIN dbo.ROSE R ON R.NOMINATIVOID = I.NOMINATIVOID
LEFT JOIN dbo.SQUADRE S ON S.ID = R.SQUADRAID AND S.STAGIONEID = (SELECT ID FROM StagAttiva)
LEFT JOIN dbo.TIPOSPORT TS ON TS.ID = S.TIPOSPORTID
WHERE I.STATUS='ATT' AND I.STAGIONEID = (SELECT ID FROM StagAttiva)
GROUP BY ISNULL(TS.DX, '(senza disciplina)');

GO
/****** Oggetto: Table [dbo].[CAUSALICONTABILI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CAUSALICONTABILI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TIPOREG] [varchar](2) NOT NULL,
	[TIPOCAUSALE] [varchar](3) NOT NULL,
	[RIFDTDOC] [bit] NOT NULL,
	[RIFNRDOC] [bit] NOT NULL,
	[RIFDTSCAD] [bit] NOT NULL,
 CONSTRAINT [CAUSALICONTABILI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: View [dbo].[VW_FLUSSO_ECONOMICO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[VW_FLUSSO_ECONOMICO] AS
WITH StagAttiva AS (
  SELECT TOP 1 ID, DATAINI, DATAFINE FROM dbo.STAGIONE
   WHERE DATAINI <= GETDATE() AND DATAFINE >= GETDATE()
   ORDER BY DATAINI DESC
),
Tot AS (
  SELECT
    ISNULL(SUM(CASE WHEN C.TIPOCAUSALE IN ('CLI','INC') THEN M.IMPORTO ELSE 0 END), 0) AS TOTENTRATE,
    ISNULL(SUM(CASE WHEN C.TIPOCAUSALE = 'FOR' THEN M.IMPORTO ELSE 0 END), 0) AS TOTUSCITE
  FROM dbo.MOVIMENTI_CONTABILI M
  JOIN dbo.CAUSALICONTABILI C ON C.ID = M.CAUSALEID
  WHERE M.DATA_REG BETWEEN (SELECT DATAINI FROM StagAttiva) AND (SELECT DATAFINE FROM StagAttiva)
)
SELECT 'Entrate' AS TIPO, TOTENTRATE AS IMPORTO FROM Tot
UNION ALL
SELECT 'Uscite',  TOTUSCITE FROM Tot;

GO
/****** Oggetto: View [dbo].[VW_ANDAMENTO_ISCRIZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[VW_ANDAMENTO_ISCRIZIONI] AS
WITH StagAttiva AS (
  SELECT TOP 1 ID FROM dbo.STAGIONE WHERE DATAINI <= GETDATE() AND DATAFINE >= GETDATE() ORDER BY DATAINI DESC
)
SELECT
  FORMAT(I.DATA_ISCRIZIONE, 'yyyy-MM') AS PERIODO,
  COUNT(*) AS NUM_ISCRIZIONI
FROM dbo.ISCRIZIONI I
WHERE I.STAGIONEID = (SELECT ID FROM StagAttiva)
GROUP BY FORMAT(I.DATA_ISCRIZIONE, 'yyyy-MM');

GO
/****** Oggetto: Table [dbo].[ACCESSPRIVILEGE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ACCESSPRIVILEGE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[RESOURCEURI] [varchar](500) NOT NULL,
	[GRANTMODES] [varchar](20) NOT NULL,
	[ACCESSDENIED] [bit] NULL,
	[ACCESSROLECLASS] [varchar](32) NOT NULL,
	[ACCESSROLEID] [varchar](32) NOT NULL,
 CONSTRAINT [ACCESSPRIVILEGE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[ACCESSROLE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ACCESSROLE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[ACCESSPRIVILEGES] [image] NULL,
 CONSTRAINT [ACCESSROLE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[ADDETTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ADDETTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[MANSIONECLASS] [varchar](32) NOT NULL,
	[MANSIONEID] [varchar](32) NOT NULL,
	[SQUADRACLASS] [varchar](32) NOT NULL,
	[SQUADRAID] [varchar](32) NOT NULL,
 CONSTRAINT [ADDETTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[AMBULATORI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AMBULATORI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[INDIRIZZO] [varchar](50) NULL,
	[CAP] [varchar](5) NULL,
	[PROVINCIACLASS] [varchar](32) NULL,
	[PROVINCIAID] [varchar](32) NULL,
	[ASL] [varchar](30) NULL,
	[PERSRIF] [varchar](40) NULL,
	[TELEFONO] [varchar](40) NULL,
	[EMAIL] [varchar](50) NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
 CONSTRAINT [AMBULATORI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[ARBITRI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ARBITRI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TPARBITROCLASS] [varchar](32) NOT NULL,
	[TPARBITROID] [varchar](32) NOT NULL,
	[SOGGETTOCLASS] [varchar](32) NULL,
	[SOGGETTOID] [varchar](32) NULL,
 CONSTRAINT [ARBITRI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[AREEGEO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AREEGEO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [AREEGEO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[ARTICOLI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ARTICOLI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[UMCLASS] [varchar](32) NOT NULL,
	[UMID] [varchar](32) NOT NULL,
	[MATRICOLA] [bit] NULL,
	[RIFNOMINATIVO] [bit] NULL,
	[RIFSQUADRA] [bit] NULL,
	[RIFUBICAZIONE] [bit] NULL,
	[CATEGORIACLASS] [varchar](32) NOT NULL,
	[CATEGORIAID] [varchar](32) NOT NULL,
 CONSTRAINT [ARTICOLI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[ASSICURAZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ASSICURAZIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[POLIZZACLASS] [varchar](32) NOT NULL,
	[POLIZZAID] [varchar](32) NOT NULL,
	[NOTE] [text] NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
 CONSTRAINT [ASSICURAZIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[BASKET_SCOUTING]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BASKET_SCOUTING](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[GAMECLASS] [varchar](32) NOT NULL,
	[GAMEID] [varchar](32) NOT NULL,
	[NUMBER] [varchar](3) NULL,
	[PLAYER_POSITION] [varchar](20) NULL,
	[PLAYERCLASS] [varchar](32) NOT NULL,
	[PLAYERID] [varchar](32) NOT NULL,
	[TOTAL_POINTS] [smallint] NULL,
	[SCORE] [smallint] NULL,
	[OK_T1] [smallint] NULL,
	[KO_T1] [smallint] NULL,
	[PERC_T1] [varchar](6) NULL,
	[OK_T2] [smallint] NULL,
	[KO_T2] [smallint] NULL,
	[PERC_T2] [varchar](6) NULL,
	[OK_T3] [smallint] NULL,
	[KO_T3] [smallint] NULL,
	[PERC_T3] [varchar](6) NULL,
	[OK_OFF] [smallint] NULL,
	[OK_DEF] [smallint] NULL,
	[RT] [smallint] NULL,
	[OK_BS] [smallint] NULL,
	[KO_BA] [smallint] NULL,
	[OK_ST] [smallint] NULL,
	[KO_TO] [smallint] NULL,
	[KO_PF] [smallint] NULL,
	[OK_FA] [smallint] NULL,
	[KO_TF] [smallint] NULL,
	[OK_AST] [smallint] NULL,
	[PLAYED_TIME] [datetime] NULL,
 CONSTRAINT [BASKET_SCOUTING_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CALCIO_SCORING]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CALCIO_SCORING](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[PARTITACLASS] [varchar](32) NOT NULL,
	[PARTITAID] [varchar](32) NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[GF] [smallint] NULL,
	[AU] [smallint] NULL,
	[FF] [smallint] NULL,
	[FS] [smallint] NULL,
	[MINUTI] [smallint] NULL,
	[AMM] [smallint] NULL,
	[ESP] [smallint] NULL,
	[VAL] [smallint] NULL,
 CONSTRAINT [CALCIO_SCORING_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CAMPIONATI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CAMPIONATI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[SOCIETACLASS] [varchar](32) NOT NULL,
	[SOCIETAID] [varchar](32) NOT NULL,
	[CATEGORIACLASS] [varchar](32) NOT NULL,
	[CATEGORIAID] [varchar](32) NOT NULL,
	[GIRONE] [varchar](20) NULL,
	[TIPOSPORTCLASS] [varchar](32) NOT NULL,
	[TIPOSPORTID] [varchar](32) NOT NULL,
	[SEZ_FEDE] [varchar](40) NULL,
	[ETA_MIN] [smallint] NOT NULL,
	[ETA_MAX] [smallint] NOT NULL,
	[AGONISTICO] [bit] NULL,
	[QUOTA] [money] NULL,
 CONSTRAINT [CAMPIONATI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CATARTICOLO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CATARTICOLO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [CATARTICOLO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CATEGORIE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CATEGORIE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SESSO] [varchar](1) NOT NULL,
	[ETA_MIN] [smallint] NOT NULL,
	[ETA_MAX] [smallint] NOT NULL,
 CONSTRAINT [CATEGORIE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CAUSALEINCASSO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CAUSALEINCASSO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [CAUSALEINCASSO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CAUSALI_AUTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CAUSALI_AUTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CAUSALECLASS] [varchar](32) NULL,
	[CAUSALEID] [varchar](32) NULL,
 CONSTRAINT [CAUSALI_AUTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CBOBJECT_LOCKER]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CBOBJECT_LOCKER](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[LOCKEDCLASS] [varchar](32) NOT NULL,
	[LOCKEDID] [varchar](32) NOT NULL,
	[OWNER_USER_NAMECLASS] [varchar](32) NOT NULL,
	[OWNER_USER_NAMEID] [varchar](32) NOT NULL,
	[LOCK_EXPIRATION] [datetime] NOT NULL,
	[EXCLUSIVE_LOCK] [bit] NOT NULL,
 CONSTRAINT [CBOBJECT_LOCKER_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CENTRIDICOSTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CENTRIDICOSTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [CENTRIDICOSTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CLASSIFICA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CLASSIFICA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[POSIZIONE] [smallint] NULL,
	[SQUADRACLASS] [varchar](32) NOT NULL,
	[SQUADRAID] [varchar](32) NOT NULL,
	[PUNTI] [smallint] NULL,
	[GIOCATE] [smallint] NULL,
	[VINTE] [smallint] NULL,
	[NEUTRE] [smallint] NULL,
	[PERSE] [smallint] NULL,
	[FATTI] [smallint] NULL,
	[SUBITI] [smallint] NULL,
	[DIFFERENZA] [smallint] NULL,
	[CASAGIOCATE] [smallint] NULL,
	[CASAPV] [smallint] NULL,
	[CASAPN] [smallint] NULL,
	[CASAPP] [smallint] NULL,
	[CASAPF] [smallint] NULL,
	[CASAPS] [smallint] NULL,
	[CASADIFF] [smallint] NULL,
	[FUORIGIOCATE] [smallint] NULL,
	[FUORIPV] [smallint] NULL,
	[FUORIPN] [smallint] NULL,
	[FUORIPP] [smallint] NULL,
	[FUORIPF] [smallint] NULL,
	[FUORIPS] [smallint] NULL,
	[FUORIDIFF] [smallint] NULL,
	[MEDIA_INGLESE] [smallint] NULL,
	[PENALTY] [smallint] NULL,
	[NOTE] [varchar](30) NULL,
	[PESO] [float] NULL,
	[DIFFDIRETTI] [smallint] NULL,
	[VINTE3_0] [smallint] NULL,
	[VINTE3_1] [smallint] NULL,
	[VINTE3_2] [smallint] NULL,
	[PERSE2_3] [smallint] NULL,
	[PERSE1_3] [smallint] NULL,
	[PERSE0_3] [smallint] NULL,
	[SET_VINTI] [smallint] NULL,
	[SET_PERSI] [smallint] NULL,
	[QUOZIENTE_SET] [float] NULL,
	[QUOZIENTE_PUNTI] [float] NULL,
 CONSTRAINT [CLASSIFICA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CLASSMARCATORI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CLASSMARCATORI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SQUADRACLASS] [varchar](32) NULL,
	[SQUADRAID] [varchar](32) NULL,
	[MARCATORE] [varchar](40) NOT NULL,
	[PUNTI] [smallint] NOT NULL,
 CONSTRAINT [CLASSMARCATORI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CODICIIVA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CODICIIVA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[ALIQUOTA] [smallint] NULL,
	[PERC_INDETR] [smallint] NULL,
	[COD_DETR] [varchar](4) NULL,
	[COD_INDETR] [varchar](4) NULL,
	[IMP_BOLLO] [money] NULL,
	[LIMITE_SCAGLIONE] [money] NULL,
	[TITOLO] [varchar](50) NULL,
	[NATURA] [varchar](2) NULL,
	[ESCLUDIDACOMLIQIVA] [bit] NULL,
	[DISATTIVATO] [bit] NULL,
 CONSTRAINT [CODICIIVA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CONTI_AUTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONTI_AUTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CAUSALEAUTOCLASS] [varchar](32) NULL,
	[CAUSALEAUTOID] [varchar](32) NULL,
	[SEGNO] [varchar](1) NULL,
	[CONTOCLASS] [varchar](32) NULL,
	[CONTOID] [varchar](32) NULL,
	[MODPAGAMENTOCLASS] [varchar](32) NULL,
	[MODPAGAMENTOID] [varchar](32) NULL,
	[BANCACLASS] [varchar](32) NULL,
	[BANCAID] [varchar](32) NULL,
 CONSTRAINT [CONTI_AUTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CONTICORRENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONTICORRENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[BANCACLASS] [varchar](32) NOT NULL,
	[BANCAID] [varchar](32) NOT NULL,
	[IBAN] [varchar](27) NOT NULL,
 CONSTRAINT [CONTICORRENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[CONVOCATI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CONVOCATI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[RUOLOCLASS] [varchar](32) NULL,
	[RUOLOID] [varchar](32) NULL,
	[NUMERO] [varchar](3) NULL,
	[TITOLARE] [bit] NULL,
	[TIPODOC] [varchar](2) NULL,
	[TIPOENUMDOC] [varchar](20) NULL,
	[PRESTITO] [varchar](1) NULL,
 CONSTRAINT [CONVOCATI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[DEFCALENDARIO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DEFCALENDARIO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CAMPIONATOCLASS] [varchar](32) NOT NULL,
	[CAMPIONATOID] [varchar](32) NOT NULL,
	[FASECLASS] [varchar](32) NOT NULL,
	[FASEID] [varchar](32) NOT NULL,
	[NUMGARE] [smallint] NULL,
	[GG_GARA] [smallint] NULL,
	[DATA_INIZIO] [datetime] NOT NULL,
	[ORA_INIZIO] [datetime] NOT NULL,
 CONSTRAINT [DEFCALENDARIO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[DEFCAMPIONATO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DEFCAMPIONATO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CAMPIONATOCLASS] [varchar](32) NOT NULL,
	[CAMPIONATOID] [varchar](32) NOT NULL,
 CONSTRAINT [DEFCAMPIONATO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[DETTAGLI_RITENUTE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DETTAGLI_RITENUTE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[MOVIMENTOCLASS] [varchar](32) NULL,
	[MOVIMENTOID] [varchar](32) NULL,
	[DT_REG] [datetime] NULL,
	[DT_COMP] [datetime] NULL,
	[COD_TRIBUTO] [varchar](6) NULL,
	[IMP_COMPENSO] [money] NULL,
	[IMPONIBILE] [money] NULL,
	[IMP_NON_SOGG_RA] [money] NULL,
	[IMP_SOGG_RA] [money] NULL,
	[DT_SCAD] [datetime] NULL,
	[DT_VERS] [datetime] NULL,
	[BANCA_VERSAMENTOCLASS] [varchar](32) NULL,
	[BANCA_VERSAMENTOID] [varchar](32) NULL,
	[COD_ATT_INPS] [varchar](2) NULL,
	[TIPO_RITENUTA] [varchar](5) NULL,
	[MOD_LIQUIDAZIONECLASS] [varchar](32) NULL,
	[MOD_LIQUIDAZIONEID] [varchar](32) NULL,
	[STATUS] [varchar](1) NULL,
	[FORNITORECLASS] [varchar](32) NULL,
	[FORNITOREID] [varchar](32) NULL,
 CONSTRAINT [DETTAGLI_RITENUTE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[EXPORTDATA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EXPORTDATA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[EXPORTCLASS] [varchar](50) NULL,
 CONSTRAINT [EXPORTDATA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[FASICAMP]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FASICAMP](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NUMERO] [smallint] NOT NULL,
	[TIPOFASECLASS] [varchar](32) NOT NULL,
	[TIPOFASEID] [varchar](32) NOT NULL,
	[OWNERCAMPCLASS] [varchar](32) NULL,
	[OWNERCAMPID] [varchar](32) NULL,
	[DXSTAGIONE] [varchar](40) NULL,
	[DXCATEGORIA] [varchar](20) NULL,
	[AGGCLASSIFICA] [datetime] NULL,
	[AGGCLMARCATORI] [datetime] NULL,
	[CLASSAVULSA] [bit] NOT NULL,
 CONSTRAINT [FASICAMP_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[FATTURECLIENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FATTURECLIENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[ESERCIZIOCLASS] [varchar](32) NOT NULL,
	[ESERCIZIOID] [varchar](32) NOT NULL,
	[NUMFATT] [varchar](10) NOT NULL,
	[DATAFATT] [datetime] NOT NULL,
	[CAUSALECLASS] [varchar](32) NOT NULL,
	[CAUSALEID] [varchar](32) NOT NULL,
	[IMPONIBILE] [money] NOT NULL,
	[TOTIVA] [money] NOT NULL,
	[TOTALEFATT] [money] NOT NULL,
	[MODPAGCLICLASS] [varchar](32) NOT NULL,
	[MODPAGCLIID] [varchar](32) NOT NULL,
	[CONTOCORRENTECLASS] [varchar](32) NULL,
	[CONTOCORRENTEID] [varchar](32) NULL,
	[NOTE] [text] NULL,
 CONSTRAINT [FATTURECLIENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[FEDERAZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FEDERAZIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[INDIRIZZO] [varchar](50) NULL,
	[CAP] [varchar](5) NULL,
	[PROVINCIACLASS] [varchar](32) NULL,
	[PROVINCIAID] [varchar](32) NULL,
	[EMAIL] [varchar](50) NULL,
	[LOGO] [varchar](100) NULL,
	[SPORTCLASS] [varchar](32) NULL,
	[SPORTID] [varchar](32) NULL,
	[TELEFONO] [varchar](40) NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
	[LOGO_FEDERAZIONE] [varchar](255) NULL,
 CONSTRAINT [FEDERAZIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[FORMA_GIURIDICA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FORMA_GIURIDICA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[FLAGCF] [bit] NULL,
	[FLAGPI] [bit] NULL,
	[FLAGPF] [bit] NULL,
 CONSTRAINT [FORMA_GIURIDICA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[GESTVISITE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GESTVISITE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[AMBULATORIOCLASS] [varchar](32) NOT NULL,
	[AMBULATORIOID] [varchar](32) NOT NULL,
	[SOCIETACLASS] [varchar](32) NULL,
	[SOCIETAID] [varchar](32) NULL,
	[DATARICHIESTA] [datetime] NOT NULL,
	[TIPOVISITACLASS] [varchar](32) NOT NULL,
	[TIPOVISITAID] [varchar](32) NOT NULL,
	[DATAVISITA] [datetime] NOT NULL,
	[NUMPERSONE] [smallint] NOT NULL,
 CONSTRAINT [GESTVISITE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[GIORNATE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GIORNATE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TIPOGIORNATACLASS] [varchar](32) NOT NULL,
	[TIPOGIORNATAID] [varchar](32) NOT NULL,
	[NUMERO] [smallint] NULL,
	[DATA_STD] [datetime] NOT NULL,
	[ORA_STD] [datetime] NULL,
	[DESCGIORNO] [varchar](10) NULL,
	[SUBNUMERO] [smallint] NULL,
	[OWNERFASECLASS] [varchar](32) NULL,
	[OWNERFASEID] [varchar](32) NULL,
 CONSTRAINT [GIORNATE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[GIORNI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GIORNI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [GIORNI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[IDGENERATOR]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[IDGENERATOR](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[GENERATEDID] [int] NULL,
	[CHARSNUM] [smallint] NOT NULL,
 CONSTRAINT [IDGENERATOR_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[LANGUAGE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LANGUAGE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SEQ_NUMBER] [int] NULL,
 CONSTRAINT [LANGUAGE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[LIBRO_SOCI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LIBRO_SOCI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DATA_RICHIESTA] [datetime] NULL,
	[DATA_ACCETTAZIONE] [datetime] NULL,
	[NOME] [varchar](100) NULL,
	[COGNOME] [varchar](100) NULL,
	[DATA_NASCITA] [datetime] NULL,
	[LUOGO_NASCITA] [varchar](100) NULL,
	[CODICE_FISCALE] [varchar](16) NULL,
	[INDIRIZZO] [varchar](100) NULL,
	[RUOLO] [varchar](50) NULL,
	[DATA_RIFIUTO] [datetime] NULL,
	[MOTIVAZIONE] [text] NULL,
	[DATA_PRESENTAZIONE] [datetime] NULL,
 CONSTRAINT [LIBRO_SOCI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[LIBRO_SOCI_QUOTE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LIBRO_SOCI_QUOTE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SOCIOCLASS] [varchar](32) NULL,
	[SOCIOID] [varchar](32) NULL,
	[QUOTA] [money] NULL,
	[NUMERO_TESSERA] [varchar](20) NULL,
	[ANNO] [int] NULL,
 CONSTRAINT [LIBRO_SOCI_QUOTE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[MAGAZZINO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MAGAZZINO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[ARTICOLOCLASS] [varchar](32) NOT NULL,
	[ARTICOLOID] [varchar](32) NOT NULL,
	[UMCLASS] [varchar](32) NOT NULL,
	[UMID] [varchar](32) NOT NULL,
	[MATRICOLA] [varchar](40) NULL,
	[MISURA] [varchar](10) NULL,
	[QTA] [smallint] NOT NULL,
	[PREZZO] [money] NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[SQUADRACLASS] [varchar](32) NULL,
	[SQUADRAID] [varchar](32) NULL,
	[IMPIANTOCLASS] [varchar](32) NULL,
	[IMPIANTOID] [varchar](32) NULL,
	[UBICAZIONESEDE] [bit] NULL,
	[UBICAZIONE] [varchar](100) NULL,
	[DATACONSEGNA] [datetime] NULL,
	[NOTE] [text] NULL,
 CONSTRAINT [MAGAZZINO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[MANSIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MANSIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TIPORUOLOCLASS] [varchar](32) NOT NULL,
	[TIPORUOLOID] [varchar](32) NOT NULL,
	[DAL] [datetime] NOT NULL,
	[AL] [datetime] NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
 CONSTRAINT [MANSIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[MARCATORI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MARCATORI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[ACCOPPIAMENTOCLASS] [varchar](32) NOT NULL,
	[ACCOPPIAMENTOID] [varchar](32) NOT NULL,
	[SQUADRACLASS] [varchar](32) NULL,
	[SQUADRAID] [varchar](32) NULL,
	[MINUTO] [smallint] NULL,
	[TIPOMARCATURACLASS] [varchar](32) NOT NULL,
	[TIPOMARCATURAID] [varchar](32) NOT NULL,
	[MARCATORE] [varchar](40) NOT NULL,
 CONSTRAINT [MARCATORI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[MODPAGAM]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MODPAGAM](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[RIFBANCA] [bit] NOT NULL,
 CONSTRAINT [MODPAGAM_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[NAZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NAZIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SIGLA] [varchar](3) NOT NULL,
	[LINGUACLASS] [varchar](32) NULL,
	[LINGUAID] [varchar](32) NULL,
	[FLCEE] [bit] NULL,
	[CODICEISTAT] [varchar](3) NULL,
	[CODICEAT] [varchar](4) NULL,
	[CONTINENTE] [varchar](20) NULL,
	[CODICEAREA] [smallint] NULL,
 CONSTRAINT [NAZIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[PARTITE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PARTITE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[CAMPIONATOCLASS] [varchar](32) NOT NULL,
	[CAMPIONATOID] [varchar](32) NOT NULL,
	[FASECAMPCLASS] [varchar](32) NULL,
	[FASECAMPID] [varchar](32) NULL,
	[GIORNATACLASS] [varchar](32) NULL,
	[GIORNATAID] [varchar](32) NULL,
	[NUMGARA] [varchar](10) NULL,
	[DESGIORNATA] [varchar](30) NULL,
	[ACCOPPIAMENTOCLASS] [varchar](32) NULL,
	[ACCOPPIAMENTOID] [varchar](32) NULL,
	[DATA_PARTITA] [datetime] NOT NULL,
	[ORA_PARTITA] [datetime] NOT NULL,
	[CASALINGA] [bit] NOT NULL,
	[SQUADRACLASS] [varchar](32) NOT NULL,
	[SQUADRAID] [varchar](32) NOT NULL,
	[PUNTI] [smallint] NULL,
	[SETSPROPRI] [smallint] NULL,
	[AVVERSARIOCLASS] [varchar](32) NOT NULL,
	[AVVERSARIOID] [varchar](32) NOT NULL,
	[AVV_PUNTI] [smallint] NULL,
	[AVV_SET] [smallint] NULL,
	[CAMPOCLASS] [varchar](32) NULL,
	[CAMPOID] [varchar](32) NULL,
	[RITROVO] [datetime] NULL,
	[LUOGO_RITROVO] [varchar](100) NULL,
	[NOTE] [text] NULL,
	[STATUSCLASS] [varchar](32) NULL,
	[STATUSID] [varchar](32) NULL,
	[ALLENATORECLASS] [varchar](32) NULL,
	[ALLENATOREID] [varchar](32) NULL,
	[ACCOMPAGNATORECLASS] [varchar](32) NULL,
	[ACCOMPAGNATOREID] [varchar](32) NULL,
	[MEDICOCLASS] [varchar](32) NULL,
	[MEDICOID] [varchar](32) NULL,
	[VICE_ALLENATORECLASS] [varchar](32) NULL,
	[VICE_ALLENATOREID] [varchar](32) NULL,
	[FISIOTERAPISTACLASS] [varchar](32) NULL,
	[FISIOTERAPISTAID] [varchar](32) NULL,
	[ADDETTO_ARBITRICLASS] [varchar](32) NULL,
	[ADDETTO_ARBITRIID] [varchar](32) NULL,
	[ADDETTO_STATCLASS] [varchar](32) NULL,
	[ADDETTO_STATID] [varchar](32) NULL,
 CONSTRAINT [PARTITE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[POLIZZE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[POLIZZE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[COMPAGNIA] [varchar](30) NOT NULL,
	[NUMERO_POLIZZA] [varchar](20) NOT NULL,
	[DATA_STIPULA] [datetime] NOT NULL,
	[COSTO] [money] NULL,
	[DATA_EFFETTO] [datetime] NOT NULL,
	[DURATACLASS] [varchar](32) NOT NULL,
	[DURATAID] [varchar](32) NOT NULL,
	[DATA_SCADENZA] [datetime] NOT NULL,
	[NOTE] [varchar](200) NULL,
 CONSTRAINT [POLIZZE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[PROFILE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PROFILE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DXEXT] [text] NULL,
	[ACCESSROLES] [image] NULL,
 CONSTRAINT [PROFILE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[PROFUN]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PROFUN](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[IOCLASS] [varchar](50) NULL,
	[PROFILEIDCLASS] [varchar](32) NULL,
	[PROFILEIDID] [varchar](32) NULL,
	[ACCESSDENIED] [bit] NULL,
	[PERMISSIONS] [varchar](20) NULL,
	[DXPERMISSIONS] [text] NULL,
 CONSTRAINT [PROFUN_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[QUOTE_ISCRIZIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[QUOTE_ISCRIZIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DATASCADENZA1] [datetime] NULL,
	[QUOTA1] [money] NULL,
	[DATASCADENZA2] [datetime] NULL,
	[QUOTA2] [money] NULL,
	[DATASCADENZA3] [datetime] NULL,
	[QUOTA3] [money] NULL,
	[DATASCADENZA4] [datetime] NULL,
	[QUOTA4] [money] NULL,
	[DATASCADENZA5] [datetime] NULL,
	[QUOTA5] [money] NULL,
	[CAMPAGNACLASS] [varchar](32) NOT NULL,
	[CAMPAGNAID] [varchar](32) NOT NULL,
	[ANNO_DAL] [int] NULL,
	[ANNO_AL] [int] NULL,
	[TOTALE_QUOTA] [money] NULL,
	[GIORNO1CLASS] [varchar](32) NULL,
	[GIORNO1ID] [varchar](32) NULL,
	[ORA_INIZIO1] [datetime] NULL,
	[ORA_FINE1] [datetime] NULL,
	[GIORNO2CLASS] [varchar](32) NULL,
	[GIORNO2ID] [varchar](32) NULL,
	[ORA_INIZIO2] [datetime] NULL,
	[ORA_FINE2] [datetime] NULL,
	[GIORNO3CLASS] [varchar](32) NULL,
	[GIORNO3ID] [varchar](32) NULL,
	[ORA_INIZIO3] [datetime] NULL,
	[ORA_FINE3] [datetime] NULL,
	[LUOGO] [varchar](200) NULL,
	[CORSO_COMPLETO] [bit] NULL,
	[SC_RATA_UNICA] [money] NULL,
 CONSTRAINT [QUOTE_ISCRIZIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[REGIONI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[REGIONI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[AREAGEOCLASS] [varchar](32) NULL,
	[AREAGEOID] [varchar](32) NULL,
 CONSTRAINT [REGIONI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[REGISTRI_IVA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[REGISTRI_IVA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TIPO_REG] [varchar](1) NULL,
	[DATA_ULT_PROT] [datetime] NULL,
	[DATA_ULT_PROT_PREC] [datetime] NULL,
	[NR_PROT] [int] NULL,
	[NR_PROT_PREC] [int] NULL,
 CONSTRAINT [REGISTRI_IVA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[RIGHEFATTURECLIENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RIGHEFATTURECLIENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[FATTCLICLASS] [varchar](32) NOT NULL,
	[FATTCLIID] [varchar](32) NOT NULL,
	[IMPONIBILE] [money] NOT NULL,
	[ASSOGIVACLASS] [varchar](32) NOT NULL,
	[ASSOGIVAID] [varchar](32) NOT NULL,
	[IMPORTO] [money] NOT NULL,
	[CODRICAVOCLASS] [varchar](32) NOT NULL,
	[CODRICAVOID] [varchar](32) NOT NULL,
	[CENTROCOSTOCLASS] [varchar](32) NULL,
	[CENTROCOSTOID] [varchar](32) NULL,
 CONSTRAINT [RIGHEFATTURECLIENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[RISPARZIALI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RISPARZIALI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TEMPO] [varchar](30) NOT NULL,
	[PUNTISQUADRA] [smallint] NULL,
	[PUNTIAVVERSARIO] [smallint] NULL,
 CONSTRAINT [RISPARZIALI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[RUOLI_GIOC]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RUOLI_GIOC](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [RUOLI_GIOC_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[RUOLI_STAFF]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RUOLI_STAFF](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DIRIGENZA] [bit] NOT NULL,
	[SIGLA] [varchar](10) NULL,
 CONSTRAINT [RUOLI_STAFF_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_FASCE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_FASCE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SESSO] [varchar](1) NULL,
	[DATA_MIN] [datetime] NULL,
	[DATA_MAX] [datetime] NULL,
 CONSTRAINT [S_FASCE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_INDIRIZZI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_INDIRIZZI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[INDIRIZZO] [varchar](35) NOT NULL,
 CONSTRAINT [S_INDIRIZZI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_LOCALITA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_LOCALITA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CAP] [varchar](5) NULL,
	[COMUNE] [varchar](35) NULL,
	[PROVCLASS] [varchar](32) NULL,
	[PROVID] [varchar](32) NULL,
 CONSTRAINT [S_LOCALITA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_MESENASC]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_MESENASC](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[MESE] [smallint] NOT NULL,
 CONSTRAINT [S_MESENASC_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_NOMINATIVI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_NOMINATIVI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CODFISC] [varchar](16) NULL,
	[COGNOME] [varchar](40) NULL,
	[NOME] [varchar](40) NULL,
	[CODICE] [varchar](32) NULL,
 CONSTRAINT [S_NOMINATIVI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_SETTORE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_SETTORE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SETTORE] [varchar](1) NOT NULL,
 CONSTRAINT [S_SETTORE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_SOCIETA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_SOCIETA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SOCIETACLASS] [varchar](32) NOT NULL,
	[SOCIETAID] [varchar](32) NOT NULL,
 CONSTRAINT [S_SOCIETA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_STAGCAT]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_STAGCAT](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[CATEGORIACLASS] [varchar](32) NULL,
	[CATEGORIAID] [varchar](32) NULL,
 CONSTRAINT [S_STAGCAT_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_TESSERAMENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_TESSERAMENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NOT NULL,
	[STAGIONEID] [varchar](32) NOT NULL,
	[CAMPIONATOCLASS] [varchar](32) NULL,
	[CAMPIONATOID] [varchar](32) NULL,
	[CATEGORIACLASS] [varchar](32) NULL,
	[CATEGORIAID] [varchar](32) NULL,
 CONSTRAINT [S_TESSERAMENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[S_TIME]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[S_TIME](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DAYSPAST] [smallint] NULL,
	[WEEKSPAST] [smallint] NULL,
	[MONTHSPAST] [datetime] NULL,
	[FROMDATE] [datetime] NULL,
	[TODATE] [datetime] NULL,
 CONSTRAINT [S_TIME_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[SCONTRIDIR]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SCONTRIDIR](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DATA] [datetime] NULL,
	[CASALINGA] [bit] NOT NULL,
	[AVVERSARIOCLASS] [varchar](32) NULL,
	[AVVERSARIOID] [varchar](32) NULL,
	[PUNTIPROPRI] [smallint] NULL,
	[PUNTIAVVERSARIO] [smallint] NULL,
	[DIFFERENZA] [smallint] NULL,
	[SETPROPRI] [smallint] NULL,
	[SETAVVERSARIO] [smallint] NULL,
 CONSTRAINT [SCONTRIDIR_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[SELECTIDDX]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SELECTIDDX](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SID] [varchar](32) NULL,
	[SDESCRIPTION] [varchar](100) NULL,
 CONSTRAINT [SELECTIDDX_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[SELGENERIC]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SELGENERIC](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[CUSTOMWHERE] [text] NULL,
	[TARGETCLASS] [varchar](50) NOT NULL,
	[DETAILCONDITIONS] [image] NULL,
 CONSTRAINT [SELGENERIC_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[SOCI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SOCI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[ADESIONE] [datetime] NULL,
	[CESSAZIONE] [datetime] NULL,
 CONSTRAINT [SOCI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[SOCIETA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SOCIETA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[FEDERAZIONECLASS] [varchar](32) NOT NULL,
	[FEDERAZIONEID] [varchar](32) NOT NULL,
	[TIPOSPORTCLASS] [varchar](32) NULL,
	[TIPOSPORTID] [varchar](32) NULL,
	[DATA_AFFILIAZIONE] [datetime] NULL,
	[COD_SOC] [varchar](20) NULL,
	[COLORI_SOCIALI] [varchar](30) NULL,
	[MAIN_SPONSORCLASS] [varchar](32) NULL,
	[MAIN_SPONSORID] [varchar](32) NULL,
	[ALTRO_SPONSORCLASS] [varchar](32) NULL,
	[ALTRO_SPONSORID] [varchar](32) NULL,
	[MAIN_CAMPOCLASS] [varchar](32) NULL,
	[MAIN_CAMPOID] [varchar](32) NULL,
	[LOGO_FEDERAZIONE] [image] NULL,
	[ANNO_AFF] [varchar](4) NULL,
 CONSTRAINT [SOCIETA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[SPONSORS]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SPONSORS](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[STAGIONECLASS] [varchar](32) NULL,
	[STAGIONEID] [varchar](32) NULL,
	[CODICE_FISCALE] [varchar](16) NULL,
	[PARTITA_IVA] [varchar](11) NULL,
	[INDIRIZZO] [varchar](50) NOT NULL,
	[CAP] [varchar](5) NOT NULL,
	[PROVINCIACLASS] [varchar](32) NOT NULL,
	[PROVINCIAID] [varchar](32) NOT NULL,
	[LOGO] [image] NULL,
	[LEG_RAPPCLASS] [varchar](32) NULL,
	[LEG_RAPPID] [varchar](32) NULL,
	[MARCHIO] [varchar](50) NULL,
	[INIZIO_ABB] [datetime] NULL,
	[FINE_ABB] [datetime] NULL,
	[QUALIFICA] [varchar](30) NULL,
	[LINK] [varchar](100) NULL,
	[TELEFONO] [varchar](40) NULL,
	[COMUNECLASS] [varchar](32) NULL,
	[COMUNEID] [varchar](32) NULL,
 CONSTRAINT [SPONSORS_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[STAFF_PARTITA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[STAFF_PARTITA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[NOMINATIVOCLASS] [varchar](32) NULL,
	[NOMINATIVOID] [varchar](32) NULL,
	[MANSIONECLASS] [varchar](32) NULL,
	[MANSIONEID] [varchar](32) NULL,
	[TIPOENUMDOC] [varchar](20) NULL,
	[TESSERA] [varchar](20) NULL,
 CONSTRAINT [STAFF_PARTITA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[STATUS]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[STATUS](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [STATUS_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TAGLIA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TAGLIA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [TAGLIA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TIPOARBITRO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TIPOARBITRO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [TIPOARBITRO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TIPOEVENTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TIPOEVENTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[DURATAORE] [smallint] NOT NULL,
 CONSTRAINT [TIPOEVENTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TIPOFASE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TIPOFASE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[ISELIMINAZIONE] [bit] NULL,
	[NUMGARE] [smallint] NULL,
	[AND_RIT] [bit] NOT NULL,
	[PUNTI_VINTE] [smallint] NULL,
	[PUNTI_NEUTRE] [smallint] NULL,
	[PUNTI_PERSE] [smallint] NULL,
	[PENALITA_TAVOLINO] [smallint] NULL,
	[PUNTI_VIN_MIS] [smallint] NULL,
	[PUNTI_PER_MIS] [smallint] NULL,
 CONSTRAINT [TIPOFASE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TIPOGIORNATA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TIPOGIORNATA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [TIPOGIORNATA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TIPOMARCATURA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TIPOMARCATURA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[TIPOSPORTCLASS] [varchar](32) NOT NULL,
	[TIPOSPORTID] [varchar](32) NOT NULL,
	[PUNTEGGIO] [smallint] NOT NULL,
 CONSTRAINT [TIPOMARCATURA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TPDOC]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TPDOC](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [TPDOC_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TPDURATE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TPDURATE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [TPDURATE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TPIMPIANTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TPIMPIANTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [TPIMPIANTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TPSANZIONE]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TPSANZIONE](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[GIORNATE] [smallint] NULL,
 CONSTRAINT [TPSANZIONE_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TPTESSERAMENTO]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TPTESSERAMENTO](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[PROF] [bit] NOT NULL,
	[EXTRACOMUN] [bit] NULL,
 CONSTRAINT [TPTESSERAMENTO_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[TPVISITAMED]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TPVISITAMED](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[SCADENZACLASS] [varchar](32) NULL,
	[SCADENZAID] [varchar](32) NULL,
	[COSTO] [money] NOT NULL,
 CONSTRAINT [TPVISITAMED_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[UNITAMISURA]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UNITAMISURA](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
 CONSTRAINT [UNITAMISURA_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Oggetto: Table [dbo].[VERSAMENTI]    Data dello script 07/09/2026 17:28:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VERSAMENTI](
	[CLASS] [varchar](32) NOT NULL,
	[ID] [varchar](32) NOT NULL,
	[UPDATECOUNT] [int] NULL,
	[DX] [varchar](200) NOT NULL,
	[UPDTIMESTAMP] [datetime] NOT NULL,
	[QUOTAVERS] [money] NOT NULL,
	[DATAVERS] [datetime] NOT NULL,
	[ESTREMI] [text] NULL,
	[TESSERAMENTOCLASS] [varchar](32) NULL,
	[TESSERAMENTOID] [varchar](32) NULL,
 CONSTRAINT [VERSAMENTI_ID] PRIMARY KEY CLUSTERED 
(
	[CLASS] ASC,
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[ACCESSPRIVILEGE] ADD  CONSTRAINT [DF_ACCESSPRIVILEGE_CLASS]  DEFAULT ('TISAccessPrivilege') FOR [CLASS]
GO
ALTER TABLE [dbo].[ACCESSPRIVILEGE] ADD  CONSTRAINT [DF_ACCESSPRIVILEGE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ACCESSPRIVILEGE] ADD  CONSTRAINT [DF_ACCESSPRIVILEGE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ACCESSPRIVILEGE] ADD  CONSTRAINT [DF_ACCESSPRIVILEGE_ACCESSROLECLASS]  DEFAULT ('TISAccessRole') FOR [ACCESSROLECLASS]
GO
ALTER TABLE [dbo].[ACCESSROLE] ADD  CONSTRAINT [DF_ACCESSROLE_CLASS]  DEFAULT ('TISAccessRole') FOR [CLASS]
GO
ALTER TABLE [dbo].[ACCESSROLE] ADD  CONSTRAINT [DF_ACCESSROLE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ACCESSROLE] ADD  CONSTRAINT [DF_ACCESSROLE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_CLASS]  DEFAULT ('TISAccoppiamento') FOR [CLASS]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_OWNERGIORNATACLASS]  DEFAULT ('TISGiornata') FOR [OWNERGIORNATACLASS]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_CASACLASS]  DEFAULT ('TISSquadra') FOR [CASACLASS]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_OSPITICLASS]  DEFAULT ('TISSquadra') FOR [OSPITICLASS]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_STATUSCLASS]  DEFAULT ('TISStatus') FOR [STATUSCLASS]
GO
ALTER TABLE [dbo].[ACCOPPIAMENTI] ADD  CONSTRAINT [DF_ACCOPPIAMENTI_LUOGOCLASS]  DEFAULT ('TISImpiantoSportivo') FOR [LUOGOCLASS]
GO
ALTER TABLE [dbo].[ADDETTI] ADD  CONSTRAINT [DF_ADDETTI_CLASS]  DEFAULT ('TISAddetto') FOR [CLASS]
GO
ALTER TABLE [dbo].[ADDETTI] ADD  CONSTRAINT [DF_ADDETTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ADDETTI] ADD  CONSTRAINT [DF_ADDETTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ADDETTI] ADD  CONSTRAINT [DF_ADDETTI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[ADDETTI] ADD  CONSTRAINT [DF_ADDETTI_MANSIONECLASS]  DEFAULT ('TISRuoloStaff') FOR [MANSIONECLASS]
GO
ALTER TABLE [dbo].[ADDETTI] ADD  CONSTRAINT [DF_ADDETTI_SQUADRACLASS]  DEFAULT ('TISSquadra') FOR [SQUADRACLASS]
GO
ALTER TABLE [dbo].[AMBULATORI] ADD  CONSTRAINT [DF_AMBULATORI_CLASS]  DEFAULT ('TISAmbulatorio') FOR [CLASS]
GO
ALTER TABLE [dbo].[AMBULATORI] ADD  CONSTRAINT [DF_AMBULATORI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[AMBULATORI] ADD  CONSTRAINT [DF_AMBULATORI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[AMBULATORI] ADD  CONSTRAINT [DF_AMBULATORI_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[AMBULATORI] ADD  CONSTRAINT [DF_AMBULATORI_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[APPUSER] ADD  CONSTRAINT [DF_APPUSER_CLASS]  DEFAULT ('TISUser') FOR [CLASS]
GO
ALTER TABLE [dbo].[APPUSER] ADD  CONSTRAINT [DF_APPUSER_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[APPUSER] ADD  CONSTRAINT [DF_APPUSER_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[APPUSER] ADD  CONSTRAINT [DF_APPUSER_PROFILECLASS]  DEFAULT ('TISProfile') FOR [PROFILECLASS]
GO
ALTER TABLE [dbo].[APPUSER] ADD  CONSTRAINT [DF_APPUSER_LANGUAGECLASS]  DEFAULT ('TISLanguage') FOR [LANGUAGECLASS]
GO
ALTER TABLE [dbo].[ARBITRI] ADD  CONSTRAINT [DF_ARBITRI_CLASS]  DEFAULT ('TISArbitro') FOR [CLASS]
GO
ALTER TABLE [dbo].[ARBITRI] ADD  CONSTRAINT [DF_ARBITRI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ARBITRI] ADD  CONSTRAINT [DF_ARBITRI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ARBITRI] ADD  CONSTRAINT [DF_ARBITRI_TPARBITROCLASS]  DEFAULT ('TISTipoArbitro') FOR [TPARBITROCLASS]
GO
ALTER TABLE [dbo].[ARBITRI] ADD  CONSTRAINT [DF_ARBITRI_TPARBITROID]  DEFAULT ('P') FOR [TPARBITROID]
GO
ALTER TABLE [dbo].[ARBITRI] ADD  CONSTRAINT [DF_ARBITRI_SOGGETTOCLASS]  DEFAULT ('TISNominativo') FOR [SOGGETTOCLASS]
GO
ALTER TABLE [dbo].[AREEGEO] ADD  CONSTRAINT [DF_AREEGEO_CLASS]  DEFAULT ('TISAreaGeografica') FOR [CLASS]
GO
ALTER TABLE [dbo].[AREEGEO] ADD  CONSTRAINT [DF_AREEGEO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[AREEGEO] ADD  CONSTRAINT [DF_AREEGEO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ARTICOLI] ADD  CONSTRAINT [DF_ARTICOLI_CLASS]  DEFAULT ('TISArticolo') FOR [CLASS]
GO
ALTER TABLE [dbo].[ARTICOLI] ADD  CONSTRAINT [DF_ARTICOLI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ARTICOLI] ADD  CONSTRAINT [DF_ARTICOLI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ARTICOLI] ADD  CONSTRAINT [DF_ARTICOLI_UMCLASS]  DEFAULT ('TISUnitaMisura') FOR [UMCLASS]
GO
ALTER TABLE [dbo].[ARTICOLI] ADD  CONSTRAINT [DF_ARTICOLI_CATEGORIACLASS]  DEFAULT ('TISCategoriaArticolo') FOR [CATEGORIACLASS]
GO
ALTER TABLE [dbo].[ASSICURAZIONI] ADD  CONSTRAINT [DF_ASSICURAZIONI_CLASS]  DEFAULT ('TISAssicurazione') FOR [CLASS]
GO
ALTER TABLE [dbo].[ASSICURAZIONI] ADD  CONSTRAINT [DF_ASSICURAZIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ASSICURAZIONI] ADD  CONSTRAINT [DF_ASSICURAZIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ASSICURAZIONI] ADD  CONSTRAINT [DF_ASSICURAZIONI_POLIZZACLASS]  DEFAULT ('TISPolizza') FOR [POLIZZACLASS]
GO
ALTER TABLE [dbo].[ASSICURAZIONI] ADD  CONSTRAINT [DF_ASSICURAZIONI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[BANCHE] ADD  CONSTRAINT [DF_BANCHE_CLASS]  DEFAULT ('TISBanca') FOR [CLASS]
GO
ALTER TABLE [dbo].[BANCHE] ADD  CONSTRAINT [DF_BANCHE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[BANCHE] ADD  CONSTRAINT [DF_BANCHE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[BANCHE] ADD  CONSTRAINT [DF_BANCHE_CODCOMUNECLASS]  DEFAULT ('TISComune') FOR [CODCOMUNECLASS]
GO
ALTER TABLE [dbo].[BANCHE] ADD  CONSTRAINT [DF_BANCHE_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[BASKET_SCOUTING] ADD  CONSTRAINT [DF_BASKET_SCOUTING_CLASS]  DEFAULT ('TISBasketScouting') FOR [CLASS]
GO
ALTER TABLE [dbo].[BASKET_SCOUTING] ADD  CONSTRAINT [DF_BASKET_SCOUTING_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[BASKET_SCOUTING] ADD  CONSTRAINT [DF_BASKET_SCOUTING_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[BASKET_SCOUTING] ADD  CONSTRAINT [DF_BASKET_SCOUTING_GAMECLASS]  DEFAULT ('TISPartita') FOR [GAMECLASS]
GO
ALTER TABLE [dbo].[BASKET_SCOUTING] ADD  CONSTRAINT [DF_BASKET_SCOUTING_PLAYERCLASS]  DEFAULT ('TISNominativo') FOR [PLAYERCLASS]
GO
ALTER TABLE [dbo].[CALCIO_SCORING] ADD  CONSTRAINT [DF_CALCIO_SCORING_CLASS]  DEFAULT ('TISCalcioScoring') FOR [CLASS]
GO
ALTER TABLE [dbo].[CALCIO_SCORING] ADD  CONSTRAINT [DF_CALCIO_SCORING_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CALCIO_SCORING] ADD  CONSTRAINT [DF_CALCIO_SCORING_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CALCIO_SCORING] ADD  CONSTRAINT [DF_CALCIO_SCORING_PARTITACLASS]  DEFAULT ('TISPartita') FOR [PARTITACLASS]
GO
ALTER TABLE [dbo].[CALCIO_SCORING] ADD  CONSTRAINT [DF_CALCIO_SCORING_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[CALENDARIO] ADD  CONSTRAINT [DF_CALENDARIO_CLASS]  DEFAULT ('TISCalendario') FOR [CLASS]
GO
ALTER TABLE [dbo].[CALENDARIO] ADD  CONSTRAINT [DF_CALENDARIO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CALENDARIO] ADD  CONSTRAINT [DF_CALENDARIO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CALENDARIO] ADD  CONSTRAINT [DF_CALENDARIO_TIPOEVENTOCLASS]  DEFAULT ('TISTipoEvento') FOR [TIPOEVENTOCLASS]
GO
ALTER TABLE [dbo].[CALENDARIO] ADD  CONSTRAINT [DF_CALENDARIO_PERSRIFCLASS]  DEFAULT ('TISNominativo') FOR [PERSRIFCLASS]
GO
ALTER TABLE [dbo].[CAMPAGNE_ISCRIZIONI] ADD  CONSTRAINT [DF_CAMPAGNE_ISCRIZIONI_CLASS]  DEFAULT ('TISCampagnaIscrizione') FOR [CLASS]
GO
ALTER TABLE [dbo].[CAMPAGNE_ISCRIZIONI] ADD  CONSTRAINT [DF_CAMPAGNE_ISCRIZIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CAMPAGNE_ISCRIZIONI] ADD  CONSTRAINT [DF_CAMPAGNE_ISCRIZIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CAMPAGNE_ISCRIZIONI] ADD  CONSTRAINT [DF_CAMPAGNE_ISCRIZIONI_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[CAMPAGNE_ISCRIZIONI] ADD  CONSTRAINT [DF_CAMPAGNE_ISCRIZIONI_SCADENZA_SCONTO]  DEFAULT ((0)) FOR [SCADENZA_SCONTO]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_CLASS]  DEFAULT ('TISCampionato') FOR [CLASS]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_SOCIETACLASS]  DEFAULT ('TISSocieta') FOR [SOCIETACLASS]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_SOCIETAID]  DEFAULT ('0000000001') FOR [SOCIETAID]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_CATEGORIACLASS]  DEFAULT ('TISCategoria') FOR [CATEGORIACLASS]
GO
ALTER TABLE [dbo].[CAMPIONATI] ADD  CONSTRAINT [DF_CAMPIONATI_TIPOSPORTCLASS]  DEFAULT ('TISTipoSport') FOR [TIPOSPORTCLASS]
GO
ALTER TABLE [dbo].[CATARTICOLO] ADD  CONSTRAINT [DF_CATARTICOLO_CLASS]  DEFAULT ('TISCategoriaArticolo') FOR [CLASS]
GO
ALTER TABLE [dbo].[CATARTICOLO] ADD  CONSTRAINT [DF_CATARTICOLO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CATARTICOLO] ADD  CONSTRAINT [DF_CATARTICOLO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CATEGORIE] ADD  CONSTRAINT [DF_CATEGORIE_CLASS]  DEFAULT ('TISCategoria') FOR [CLASS]
GO
ALTER TABLE [dbo].[CATEGORIE] ADD  CONSTRAINT [DF_CATEGORIE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CATEGORIE] ADD  CONSTRAINT [DF_CATEGORIE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CAUSALEINCASSO] ADD  CONSTRAINT [DF_CAUSALEINCASSO_CLASS]  DEFAULT ('TISCausaleIncasso') FOR [CLASS]
GO
ALTER TABLE [dbo].[CAUSALEINCASSO] ADD  CONSTRAINT [DF_CAUSALEINCASSO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CAUSALEINCASSO] ADD  CONSTRAINT [DF_CAUSALEINCASSO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CAUSALI_AUTO] ADD  CONSTRAINT [DF_CAUSALI_AUTO_CLASS]  DEFAULT ('TISCausaleAuto') FOR [CLASS]
GO
ALTER TABLE [dbo].[CAUSALI_AUTO] ADD  CONSTRAINT [DF_CAUSALI_AUTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CAUSALI_AUTO] ADD  CONSTRAINT [DF_CAUSALI_AUTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CAUSALI_AUTO] ADD  CONSTRAINT [DF_CAUSALI_AUTO_CAUSALECLASS]  DEFAULT ('TISCausaleContabile') FOR [CAUSALECLASS]
GO
ALTER TABLE [dbo].[CAUSALICONTABILI] ADD  CONSTRAINT [DF_CAUSALICONTABILI_CLASS]  DEFAULT ('TISCausaleContabile') FOR [CLASS]
GO
ALTER TABLE [dbo].[CAUSALICONTABILI] ADD  CONSTRAINT [DF_CAUSALICONTABILI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CAUSALICONTABILI] ADD  CONSTRAINT [DF_CAUSALICONTABILI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CAUSALICONTABILI] ADD  CONSTRAINT [DF_CAUSALICONTABILI_RIFDTDOC]  DEFAULT ((0)) FOR [RIFDTDOC]
GO
ALTER TABLE [dbo].[CAUSALICONTABILI] ADD  CONSTRAINT [DF_CAUSALICONTABILI_RIFNRDOC]  DEFAULT ((0)) FOR [RIFNRDOC]
GO
ALTER TABLE [dbo].[CAUSALICONTABILI] ADD  CONSTRAINT [DF_CAUSALICONTABILI_RIFDTSCAD]  DEFAULT ((0)) FOR [RIFDTSCAD]
GO
ALTER TABLE [dbo].[CBOBJECT_LOCKER] ADD  CONSTRAINT [DF_CBOBJECT_LOCKER_CLASS]  DEFAULT ('TISCBObjectLocker') FOR [CLASS]
GO
ALTER TABLE [dbo].[CBOBJECT_LOCKER] ADD  CONSTRAINT [DF_CBOBJECT_LOCKER_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CBOBJECT_LOCKER] ADD  CONSTRAINT [DF_CBOBJECT_LOCKER_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CBOBJECT_LOCKER] ADD  CONSTRAINT [DF_CBOBJECT_LOCKER_OWNER_USER_NAMECLASS]  DEFAULT ('TISUser') FOR [OWNER_USER_NAMECLASS]
GO
ALTER TABLE [dbo].[CENTRIDICOSTO] ADD  CONSTRAINT [DF_CENTRIDICOSTO_CLASS]  DEFAULT ('TISCentroDiCosto') FOR [CLASS]
GO
ALTER TABLE [dbo].[CENTRIDICOSTO] ADD  CONSTRAINT [DF_CENTRIDICOSTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CENTRIDICOSTO] ADD  CONSTRAINT [DF_CENTRIDICOSTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CLASSIFICA] ADD  CONSTRAINT [DF_CLASSIFICA_CLASS]  DEFAULT ('TISClassifica') FOR [CLASS]
GO
ALTER TABLE [dbo].[CLASSIFICA] ADD  CONSTRAINT [DF_CLASSIFICA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CLASSIFICA] ADD  CONSTRAINT [DF_CLASSIFICA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CLASSIFICA] ADD  CONSTRAINT [DF_CLASSIFICA_SQUADRACLASS]  DEFAULT ('TISSquadra') FOR [SQUADRACLASS]
GO
ALTER TABLE [dbo].[CLASSMARCATORI] ADD  CONSTRAINT [DF_CLASSMARCATORI_CLASS]  DEFAULT ('TISClassificaMarcatore') FOR [CLASS]
GO
ALTER TABLE [dbo].[CLASSMARCATORI] ADD  CONSTRAINT [DF_CLASSMARCATORI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CLASSMARCATORI] ADD  CONSTRAINT [DF_CLASSMARCATORI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CLASSMARCATORI] ADD  CONSTRAINT [DF_CLASSMARCATORI_SQUADRACLASS]  DEFAULT ('TISSquadra') FOR [SQUADRACLASS]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_CLASS]  DEFAULT ('TISCliente') FOR [CLASS]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_CODICE_FATT_ELE]  DEFAULT ('0000000') FOR [CODICE_FATT_ELE]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_COMUNE_AMMCLASS]  DEFAULT ('TISComune') FOR [COMUNE_AMMCLASS]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_PROVINCIA_AMMCLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIA_AMMCLASS]
GO
ALTER TABLE [dbo].[CLIENTI] ADD  CONSTRAINT [DF_CLIENTI_FORMA_GIURICLASS]  DEFAULT ('TISFormaGiuridica') FOR [FORMA_GIURICLASS]
GO
ALTER TABLE [dbo].[CODA_EMAIL] ADD  CONSTRAINT [DF_CODA_EMAIL_CLASS]  DEFAULT ('TISCodaMail') FOR [CLASS]
GO
ALTER TABLE [dbo].[CODA_EMAIL] ADD  CONSTRAINT [DF_CODA_EMAIL_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CODA_EMAIL] ADD  CONSTRAINT [DF_CODA_EMAIL_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CODA_EMAIL] ADD  CONSTRAINT [DF_CODA_EMAIL_TESTO_EMAILCLASS]  DEFAULT ('TISTestoEmail') FOR [TESTO_EMAILCLASS]
GO
ALTER TABLE [dbo].[CODA_EMAIL] ADD  CONSTRAINT [DF_CODA_EMAIL_OPERATORE_INSERIMENTOCLASS]  DEFAULT ('TISUser') FOR [OPERATORE_INSERIMENTOCLASS]
GO
ALTER TABLE [dbo].[CODICIIVA] ADD  CONSTRAINT [DF_CODICIIVA_CLASS]  DEFAULT ('TISCodiceIVA') FOR [CLASS]
GO
ALTER TABLE [dbo].[CODICIIVA] ADD  CONSTRAINT [DF_CODICIIVA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CODICIIVA] ADD  CONSTRAINT [DF_CODICIIVA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CODICIIVA] ADD  CONSTRAINT [DF_CODICIIVA_IMP_BOLLO]  DEFAULT ((0)) FOR [IMP_BOLLO]
GO
ALTER TABLE [dbo].[COMUNI] ADD  CONSTRAINT [DF_COMUNI_CLASS]  DEFAULT ('TISComune') FOR [CLASS]
GO
ALTER TABLE [dbo].[COMUNI] ADD  CONSTRAINT [DF_COMUNI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[COMUNI] ADD  CONSTRAINT [DF_COMUNI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[COMUNI] ADD  CONSTRAINT [DF_COMUNI_PROVCLASS]  DEFAULT ('TISProvincia') FOR [PROVCLASS]
GO
ALTER TABLE [dbo].[CONFIGURATION] ADD  CONSTRAINT [DF_CONFIGURATION_CLASS]  DEFAULT ('TISConfiguration') FOR [CLASS]
GO
ALTER TABLE [dbo].[CONFIGURATION] ADD  CONSTRAINT [DF_CONFIGURATION_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CONFIGURATION] ADD  CONSTRAINT [DF_CONFIGURATION_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CONSIGLIO] ADD  CONSTRAINT [DF_CONSIGLIO_CLASS]  DEFAULT ('TISConsiglio') FOR [CLASS]
GO
ALTER TABLE [dbo].[CONSIGLIO] ADD  CONSTRAINT [DF_CONSIGLIO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CONSIGLIO] ADD  CONSTRAINT [DF_CONSIGLIO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CONSIGLIO] ADD  CONSTRAINT [DF_CONSIGLIO_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[CONSIGLIO] ADD  CONSTRAINT [DF_CONSIGLIO_QUALIFICACLASS]  DEFAULT ('TISRuoloStaff') FOR [QUALIFICACLASS]
GO
ALTER TABLE [dbo].[CONTI_AUTO] ADD  CONSTRAINT [DF_CONTI_AUTO_CLASS]  DEFAULT ('TISContoAuto') FOR [CLASS]
GO
ALTER TABLE [dbo].[CONTI_AUTO] ADD  CONSTRAINT [DF_CONTI_AUTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CONTI_AUTO] ADD  CONSTRAINT [DF_CONTI_AUTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CONTI_AUTO] ADD  CONSTRAINT [DF_CONTI_AUTO_CAUSALEAUTOCLASS]  DEFAULT ('TISCausaleAuto') FOR [CAUSALEAUTOCLASS]
GO
ALTER TABLE [dbo].[CONTI_AUTO] ADD  CONSTRAINT [DF_CONTI_AUTO_CONTOCLASS]  DEFAULT ('TISContoContabile') FOR [CONTOCLASS]
GO
ALTER TABLE [dbo].[CONTI_AUTO] ADD  CONSTRAINT [DF_CONTI_AUTO_MODPAGAMENTOCLASS]  DEFAULT ('TISModPagamento') FOR [MODPAGAMENTOCLASS]
GO
ALTER TABLE [dbo].[CONTI_AUTO] ADD  CONSTRAINT [DF_CONTI_AUTO_BANCACLASS]  DEFAULT ('TISBanca') FOR [BANCACLASS]
GO
ALTER TABLE [dbo].[CONTICONTABILI] ADD  CONSTRAINT [DF_CONTICONTABILI_CLASS]  DEFAULT ('TISContoContabile') FOR [CLASS]
GO
ALTER TABLE [dbo].[CONTICONTABILI] ADD  CONSTRAINT [DF_CONTICONTABILI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CONTICONTABILI] ADD  CONSTRAINT [DF_CONTICONTABILI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CONTICORRENTI] ADD  CONSTRAINT [DF_CONTICORRENTI_CLASS]  DEFAULT ('TISContoCorrente') FOR [CLASS]
GO
ALTER TABLE [dbo].[CONTICORRENTI] ADD  CONSTRAINT [DF_CONTICORRENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CONTICORRENTI] ADD  CONSTRAINT [DF_CONTICORRENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CONTICORRENTI] ADD  CONSTRAINT [DF_CONTICORRENTI_BANCACLASS]  DEFAULT ('TISBanca') FOR [BANCACLASS]
GO
ALTER TABLE [dbo].[CONVOCATI] ADD  CONSTRAINT [DF_CONVOCATI_CLASS]  DEFAULT ('TISConvocato') FOR [CLASS]
GO
ALTER TABLE [dbo].[CONVOCATI] ADD  CONSTRAINT [DF_CONVOCATI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[CONVOCATI] ADD  CONSTRAINT [DF_CONVOCATI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[CONVOCATI] ADD  CONSTRAINT [DF_CONVOCATI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[CONVOCATI] ADD  CONSTRAINT [DF_CONVOCATI_RUOLOCLASS]  DEFAULT ('TISRuoloGioc') FOR [RUOLOCLASS]
GO
ALTER TABLE [dbo].[DEFCALENDARIO] ADD  CONSTRAINT [DF_DEFCALENDARIO_CLASS]  DEFAULT ('TISDefCalendario') FOR [CLASS]
GO
ALTER TABLE [dbo].[DEFCALENDARIO] ADD  CONSTRAINT [DF_DEFCALENDARIO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[DEFCALENDARIO] ADD  CONSTRAINT [DF_DEFCALENDARIO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[DEFCALENDARIO] ADD  CONSTRAINT [DF_DEFCALENDARIO_CAMPIONATOCLASS]  DEFAULT ('TISCampionato') FOR [CAMPIONATOCLASS]
GO
ALTER TABLE [dbo].[DEFCALENDARIO] ADD  CONSTRAINT [DF_DEFCALENDARIO_FASECLASS]  DEFAULT ('TISFaseCampionato') FOR [FASECLASS]
GO
ALTER TABLE [dbo].[DEFCALENDARIO] ADD  CONSTRAINT [DF_DEFCALENDARIO_GG_GARA]  DEFAULT ((7)) FOR [GG_GARA]
GO
ALTER TABLE [dbo].[DEFCAMPIONATO] ADD  CONSTRAINT [DF_DEFCAMPIONATO_CLASS]  DEFAULT ('TISDefCampionato') FOR [CLASS]
GO
ALTER TABLE [dbo].[DEFCAMPIONATO] ADD  CONSTRAINT [DF_DEFCAMPIONATO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[DEFCAMPIONATO] ADD  CONSTRAINT [DF_DEFCAMPIONATO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[DEFCAMPIONATO] ADD  CONSTRAINT [DF_DEFCAMPIONATO_CAMPIONATOCLASS]  DEFAULT ('TISCampionato') FOR [CAMPIONATOCLASS]
GO
ALTER TABLE [dbo].[DETRAZIONI_FISCALI] ADD  CONSTRAINT [DF_DETRAZIONI_FISCALI_CLASS]  DEFAULT ('TISDetrazioneFiscale') FOR [CLASS]
GO
ALTER TABLE [dbo].[DETRAZIONI_FISCALI] ADD  CONSTRAINT [DF_DETRAZIONI_FISCALI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[DETRAZIONI_FISCALI] ADD  CONSTRAINT [DF_DETRAZIONI_FISCALI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[DETRAZIONI_FISCALI] ADD  CONSTRAINT [DF_DETRAZIONI_FISCALI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_IVA] ADD  CONSTRAINT [DF_DETTAGLI_IVA_CLASS]  DEFAULT ('TISDettaglioIva') FOR [CLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_IVA] ADD  CONSTRAINT [DF_DETTAGLI_IVA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[DETTAGLI_IVA] ADD  CONSTRAINT [DF_DETTAGLI_IVA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[DETTAGLI_IVA] ADD  CONSTRAINT [DF_DETTAGLI_IVA_MOVIMENTOCLASS]  DEFAULT ('TISMovimentoContabile') FOR [MOVIMENTOCLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_IVA] ADD  CONSTRAINT [DF_DETTAGLI_IVA_CODICE_IVACLASS]  DEFAULT ('TISCodiceIVA') FOR [CODICE_IVACLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_PAGAMENTO] ADD  CONSTRAINT [DF_DETTAGLI_PAGAMENTO_CLASS]  DEFAULT ('TISDettaglioPagamento') FOR [CLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_PAGAMENTO] ADD  CONSTRAINT [DF_DETTAGLI_PAGAMENTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[DETTAGLI_PAGAMENTO] ADD  CONSTRAINT [DF_DETTAGLI_PAGAMENTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[DETTAGLI_PAGAMENTO] ADD  CONSTRAINT [DF_DETTAGLI_PAGAMENTO_MEZZO_PAGAMENTOCLASS]  DEFAULT ('TISMezzoPagamento') FOR [MEZZO_PAGAMENTOCLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_PAGAMENTO] ADD  CONSTRAINT [DF_DETTAGLI_PAGAMENTO_RATA_ISCRIZIONECLASS]  DEFAULT ('TISRataIscrizione') FOR [RATA_ISCRIZIONECLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_RITENUTE] ADD  CONSTRAINT [DF_DETTAGLI_RITENUTE_CLASS]  DEFAULT ('TISDettaglioRitenute') FOR [CLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_RITENUTE] ADD  CONSTRAINT [DF_DETTAGLI_RITENUTE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[DETTAGLI_RITENUTE] ADD  CONSTRAINT [DF_DETTAGLI_RITENUTE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[DETTAGLI_RITENUTE] ADD  CONSTRAINT [DF_DETTAGLI_RITENUTE_MOVIMENTOCLASS]  DEFAULT ('TISMovimentoContabile') FOR [MOVIMENTOCLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_RITENUTE] ADD  CONSTRAINT [DF_DETTAGLI_RITENUTE_BANCA_VERSAMENTOCLASS]  DEFAULT ('TISBanca') FOR [BANCA_VERSAMENTOCLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_RITENUTE] ADD  CONSTRAINT [DF_DETTAGLI_RITENUTE_MOD_LIQUIDAZIONECLASS]  DEFAULT ('TISModPagamento') FOR [MOD_LIQUIDAZIONECLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_RITENUTE] ADD  CONSTRAINT [DF_DETTAGLI_RITENUTE_FORNITORECLASS]  DEFAULT ('TISFornitore') FOR [FORNITORECLASS]
GO
ALTER TABLE [dbo].[DOCUMENTI] ADD  CONSTRAINT [DF_DOCUMENTI_CLASS]  DEFAULT ('TISDocumento') FOR [CLASS]
GO
ALTER TABLE [dbo].[DOCUMENTI] ADD  CONSTRAINT [DF_DOCUMENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[DOCUMENTI] ADD  CONSTRAINT [DF_DOCUMENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[DOCUMENTI] ADD  CONSTRAINT [DF_DOCUMENTI_TIPODOCCLASS]  DEFAULT ('TISTipoDoc') FOR [TIPODOCCLASS]
GO
ALTER TABLE [dbo].[DOCUMENTI] ADD  CONSTRAINT [DF_DOCUMENTI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[ESERCIZICONTABILI] ADD  CONSTRAINT [DF_ESERCIZICONTABILI_CLASS]  DEFAULT ('TISEsercizioContabile') FOR [CLASS]
GO
ALTER TABLE [dbo].[ESERCIZICONTABILI] ADD  CONSTRAINT [DF_ESERCIZICONTABILI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ESERCIZICONTABILI] ADD  CONSTRAINT [DF_ESERCIZICONTABILI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ESERCIZICONTABILI] ADD  CONSTRAINT [DF_ESERCIZICONTABILI_STATO]  DEFAULT ('A') FOR [STATO]
GO
ALTER TABLE [dbo].[EXPORTDATA] ADD  CONSTRAINT [DF_EXPORTDATA_CLASS]  DEFAULT ('TISExportData') FOR [CLASS]
GO
ALTER TABLE [dbo].[EXPORTDATA] ADD  CONSTRAINT [DF_EXPORTDATA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[EXPORTDATA] ADD  CONSTRAINT [DF_EXPORTDATA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[FAMIGLIE] ADD  CONSTRAINT [DF_FAMIGLIE_CLASS]  DEFAULT ('TISFamiglia') FOR [CLASS]
GO
ALTER TABLE [dbo].[FAMIGLIE] ADD  CONSTRAINT [DF_FAMIGLIE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[FAMIGLIE] ADD  CONSTRAINT [DF_FAMIGLIE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[FAMIGLIE] ADD  CONSTRAINT [DF_FAMIGLIE_NOMINATIVO_CREATORECLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVO_CREATORECLASS]
GO
ALTER TABLE [dbo].[FASICAMP] ADD  CONSTRAINT [DF_FASICAMP_CLASS]  DEFAULT ('TISFaseCampionato') FOR [CLASS]
GO
ALTER TABLE [dbo].[FASICAMP] ADD  CONSTRAINT [DF_FASICAMP_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[FASICAMP] ADD  CONSTRAINT [DF_FASICAMP_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[FASICAMP] ADD  CONSTRAINT [DF_FASICAMP_TIPOFASECLASS]  DEFAULT ('TISTipoFase') FOR [TIPOFASECLASS]
GO
ALTER TABLE [dbo].[FASICAMP] ADD  CONSTRAINT [DF_FASICAMP_OWNERCAMPCLASS]  DEFAULT ('TISCampionato') FOR [OWNERCAMPCLASS]
GO
ALTER TABLE [dbo].[FASICAMP] ADD  CONSTRAINT [DF_FASICAMP_CLASSAVULSA]  DEFAULT ((1)) FOR [CLASSAVULSA]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_CLASS]  DEFAULT ('TISFatturaCliente') FOR [CLASS]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_ESERCIZIOCLASS]  DEFAULT ('TISEsercizioContabile') FOR [ESERCIZIOCLASS]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_CAUSALECLASS]  DEFAULT ('TISCausaleContabile') FOR [CAUSALECLASS]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_TOTIVA]  DEFAULT ((0)) FOR [TOTIVA]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_MODPAGCLICLASS]  DEFAULT ('TISModPagamento') FOR [MODPAGCLICLASS]
GO
ALTER TABLE [dbo].[FATTURECLIENTI] ADD  CONSTRAINT [DF_FATTURECLIENTI_CONTOCORRENTECLASS]  DEFAULT ('TISContoCorrente') FOR [CONTOCORRENTECLASS]
GO
ALTER TABLE [dbo].[FEDERAZIONI] ADD  CONSTRAINT [DF_FEDERAZIONI_CLASS]  DEFAULT ('TISFederazione') FOR [CLASS]
GO
ALTER TABLE [dbo].[FEDERAZIONI] ADD  CONSTRAINT [DF_FEDERAZIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[FEDERAZIONI] ADD  CONSTRAINT [DF_FEDERAZIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[FEDERAZIONI] ADD  CONSTRAINT [DF_FEDERAZIONI_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[FEDERAZIONI] ADD  CONSTRAINT [DF_FEDERAZIONI_SPORTCLASS]  DEFAULT ('TISTipoSport') FOR [SPORTCLASS]
GO
ALTER TABLE [dbo].[FEDERAZIONI] ADD  CONSTRAINT [DF_FEDERAZIONI_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[FORMA_GIURIDICA] ADD  CONSTRAINT [DF_FORMA_GIURIDICA_CLASS]  DEFAULT ('TISFormaGiuridica') FOR [CLASS]
GO
ALTER TABLE [dbo].[FORMA_GIURIDICA] ADD  CONSTRAINT [DF_FORMA_GIURIDICA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[FORMA_GIURIDICA] ADD  CONSTRAINT [DF_FORMA_GIURIDICA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_CLASS]  DEFAULT ('TISFornitore') FOR [CLASS]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_CODICE_FATT_ELE]  DEFAULT ('0000000') FOR [CODICE_FATT_ELE]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_COMUNE_AMMCLASS]  DEFAULT ('TISComune') FOR [COMUNE_AMMCLASS]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_PROVINCIA_AMMCLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIA_AMMCLASS]
GO
ALTER TABLE [dbo].[FORNITORI] ADD  CONSTRAINT [DF_FORNITORI_FORMA_GIURICLASS]  DEFAULT ('TISFormaGiuridica') FOR [FORMA_GIURICLASS]
GO
ALTER TABLE [dbo].[GESTVISITE] ADD  CONSTRAINT [DF_GESTVISITE_CLASS]  DEFAULT ('TISGestioneVisite') FOR [CLASS]
GO
ALTER TABLE [dbo].[GESTVISITE] ADD  CONSTRAINT [DF_GESTVISITE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[GESTVISITE] ADD  CONSTRAINT [DF_GESTVISITE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[GESTVISITE] ADD  CONSTRAINT [DF_GESTVISITE_AMBULATORIOCLASS]  DEFAULT ('TISAmbulatorio') FOR [AMBULATORIOCLASS]
GO
ALTER TABLE [dbo].[GESTVISITE] ADD  CONSTRAINT [DF_GESTVISITE_SOCIETACLASS]  DEFAULT ('TISSocieta') FOR [SOCIETACLASS]
GO
ALTER TABLE [dbo].[GESTVISITE] ADD  CONSTRAINT [DF_GESTVISITE_TIPOVISITACLASS]  DEFAULT ('TISTipoVisitaMedica') FOR [TIPOVISITACLASS]
GO
ALTER TABLE [dbo].[GIORNATE] ADD  CONSTRAINT [DF_GIORNATE_CLASS]  DEFAULT ('TISGiornata') FOR [CLASS]
GO
ALTER TABLE [dbo].[GIORNATE] ADD  CONSTRAINT [DF_GIORNATE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[GIORNATE] ADD  CONSTRAINT [DF_GIORNATE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[GIORNATE] ADD  CONSTRAINT [DF_GIORNATE_TIPOGIORNATACLASS]  DEFAULT ('TISTipoGiornata') FOR [TIPOGIORNATACLASS]
GO
ALTER TABLE [dbo].[GIORNATE] ADD  CONSTRAINT [DF_GIORNATE_OWNERFASECLASS]  DEFAULT ('TISFaseCampionato') FOR [OWNERFASECLASS]
GO
ALTER TABLE [dbo].[GIORNI] ADD  CONSTRAINT [DF_GIORNI_CLASS]  DEFAULT ('TISGiorni') FOR [CLASS]
GO
ALTER TABLE [dbo].[GIORNI] ADD  CONSTRAINT [DF_GIORNI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[GIORNI] ADD  CONSTRAINT [DF_GIORNI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[IDGENERATOR] ADD  CONSTRAINT [DF_IDGENERATOR_CLASS]  DEFAULT ('TISIdGenerator') FOR [CLASS]
GO
ALTER TABLE [dbo].[IDGENERATOR] ADD  CONSTRAINT [DF_IDGENERATOR_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[IDGENERATOR] ADD  CONSTRAINT [DF_IDGENERATOR_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[IMPIANTI_SPORTIVI] ADD  CONSTRAINT [DF_IMPIANTI_SPORTIVI_CLASS]  DEFAULT ('TISImpiantoSportivo') FOR [CLASS]
GO
ALTER TABLE [dbo].[IMPIANTI_SPORTIVI] ADD  CONSTRAINT [DF_IMPIANTI_SPORTIVI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[IMPIANTI_SPORTIVI] ADD  CONSTRAINT [DF_IMPIANTI_SPORTIVI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[IMPIANTI_SPORTIVI] ADD  CONSTRAINT [DF_IMPIANTI_SPORTIVI_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[IMPIANTI_SPORTIVI] ADD  CONSTRAINT [DF_IMPIANTI_SPORTIVI_TIPO_IMPIANTOCLASS]  DEFAULT ('TISTipoImpianto') FOR [TIPO_IMPIANTOCLASS]
GO
ALTER TABLE [dbo].[IMPIANTI_SPORTIVI] ADD  CONSTRAINT [DF_IMPIANTI_SPORTIVI_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_CLASS]  DEFAULT ('TISIscrizione') FOR [CLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_CAMPAGNACLASS]  DEFAULT ('TISCampagnaIscrizione') FOR [CAMPAGNACLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_QUOTA_ISCRIZIONECLASS]  DEFAULT ('TISQuotaIscrizione') FOR [QUOTA_ISCRIZIONECLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_PROVNASCCLASS]  DEFAULT ('TISProvincia') FOR [PROVNASCCLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_NAZIONALITACLASS]  DEFAULT ('TISNazione') FOR [NAZIONALITACLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_LUOGONASCCLASS]  DEFAULT ('TISComune') FOR [LUOGONASCCLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[ISCRIZIONI] ADD  CONSTRAINT [DF_ISCRIZIONI_UTENTE_INSERIMENTOCLASS]  DEFAULT ('TISUser') FOR [UTENTE_INSERIMENTOCLASS]
GO
ALTER TABLE [dbo].[LANGUAGE] ADD  CONSTRAINT [DF_LANGUAGE_CLASS]  DEFAULT ('TISLanguage') FOR [CLASS]
GO
ALTER TABLE [dbo].[LANGUAGE] ADD  CONSTRAINT [DF_LANGUAGE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[LANGUAGE] ADD  CONSTRAINT [DF_LANGUAGE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[LIBRO_SOCI] ADD  CONSTRAINT [DF_LIBRO_SOCI_CLASS]  DEFAULT ('TISLibroSoci') FOR [CLASS]
GO
ALTER TABLE [dbo].[LIBRO_SOCI] ADD  CONSTRAINT [DF_LIBRO_SOCI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[LIBRO_SOCI] ADD  CONSTRAINT [DF_LIBRO_SOCI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[LIBRO_SOCI_QUOTE] ADD  CONSTRAINT [DF_LIBRO_SOCI_QUOTE_CLASS]  DEFAULT ('TISLibroSociQuote') FOR [CLASS]
GO
ALTER TABLE [dbo].[LIBRO_SOCI_QUOTE] ADD  CONSTRAINT [DF_LIBRO_SOCI_QUOTE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[LIBRO_SOCI_QUOTE] ADD  CONSTRAINT [DF_LIBRO_SOCI_QUOTE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[LIBRO_SOCI_QUOTE] ADD  CONSTRAINT [DF_LIBRO_SOCI_QUOTE_SOCIOCLASS]  DEFAULT ('TISLibroSoci') FOR [SOCIOCLASS]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_CLASS]  DEFAULT ('TISMagazzino') FOR [CLASS]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_ARTICOLOCLASS]  DEFAULT ('TISArticolo') FOR [ARTICOLOCLASS]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_UMCLASS]  DEFAULT ('TISUnitaMisura') FOR [UMCLASS]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_SQUADRACLASS]  DEFAULT ('TISSquadra') FOR [SQUADRACLASS]
GO
ALTER TABLE [dbo].[MAGAZZINO] ADD  CONSTRAINT [DF_MAGAZZINO_IMPIANTOCLASS]  DEFAULT ('TISImpiantoSportivo') FOR [IMPIANTOCLASS]
GO
ALTER TABLE [dbo].[MANSIONI] ADD  CONSTRAINT [DF_MANSIONI_CLASS]  DEFAULT ('TISMansione') FOR [CLASS]
GO
ALTER TABLE [dbo].[MANSIONI] ADD  CONSTRAINT [DF_MANSIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MANSIONI] ADD  CONSTRAINT [DF_MANSIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MANSIONI] ADD  CONSTRAINT [DF_MANSIONI_TIPORUOLOCLASS]  DEFAULT ('TISRuoloStaff') FOR [TIPORUOLOCLASS]
GO
ALTER TABLE [dbo].[MANSIONI] ADD  CONSTRAINT [DF_MANSIONI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[MARCATORI] ADD  CONSTRAINT [DF_MARCATORI_CLASS]  DEFAULT ('TISMarcatore') FOR [CLASS]
GO
ALTER TABLE [dbo].[MARCATORI] ADD  CONSTRAINT [DF_MARCATORI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MARCATORI] ADD  CONSTRAINT [DF_MARCATORI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MARCATORI] ADD  CONSTRAINT [DF_MARCATORI_ACCOPPIAMENTOCLASS]  DEFAULT ('TISAccoppiamento') FOR [ACCOPPIAMENTOCLASS]
GO
ALTER TABLE [dbo].[MARCATORI] ADD  CONSTRAINT [DF_MARCATORI_SQUADRACLASS]  DEFAULT ('TISSquadra') FOR [SQUADRACLASS]
GO
ALTER TABLE [dbo].[MARCATORI] ADD  CONSTRAINT [DF_MARCATORI_TIPOMARCATURACLASS]  DEFAULT ('TISTipoMarcatura') FOR [TIPOMARCATURACLASS]
GO
ALTER TABLE [dbo].[MEMBRI_FAMIGLIE] ADD  CONSTRAINT [DF_MEMBRI_FAMIGLIE_CLASS]  DEFAULT ('TISMembroFamiglia') FOR [CLASS]
GO
ALTER TABLE [dbo].[MEMBRI_FAMIGLIE] ADD  CONSTRAINT [DF_MEMBRI_FAMIGLIE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MEMBRI_FAMIGLIE] ADD  CONSTRAINT [DF_MEMBRI_FAMIGLIE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MEMBRI_FAMIGLIE] ADD  CONSTRAINT [DF_MEMBRI_FAMIGLIE_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[MEMBRI_FAMIGLIE] ADD  CONSTRAINT [DF_MEMBRI_FAMIGLIE_PARENTELACLASS]  DEFAULT ('TISParentela') FOR [PARENTELACLASS]
GO
ALTER TABLE [dbo].[MEMBRI_FAMIGLIE] ADD  CONSTRAINT [DF_MEMBRI_FAMIGLIE_FAMIGLIACLASS]  DEFAULT ('TISFamiglia') FOR [FAMIGLIACLASS]
GO
ALTER TABLE [dbo].[MEMBRI_FAMIGLIE] ADD  DEFAULT ((100)) FOR [PERC_DETRAZIONI]
GO
ALTER TABLE [dbo].[MEZZI_PAGAMENTO] ADD  CONSTRAINT [DF_MEZZI_PAGAMENTO_CLASS]  DEFAULT ('TISMezzoPagamento') FOR [CLASS]
GO
ALTER TABLE [dbo].[MEZZI_PAGAMENTO] ADD  CONSTRAINT [DF_MEZZI_PAGAMENTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MEZZI_PAGAMENTO] ADD  CONSTRAINT [DF_MEZZI_PAGAMENTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MEZZI_PAGAMENTO] ADD  CONSTRAINT [DF_MEZZI_PAGAMENTO_PAGANTECLASS]  DEFAULT ('TISNominativo') FOR [PAGANTECLASS]
GO
ALTER TABLE [dbo].[MEZZI_PAGAMENTO] ADD  CONSTRAINT [DF_MEZZI_PAGAMENTO_MOD_PAGAMENTOCLASS]  DEFAULT ('TISModPagamento') FOR [MOD_PAGAMENTOCLASS]
GO
ALTER TABLE [dbo].[MEZZI_PAGAMENTO] ADD  CONSTRAINT [DF_MEZZI_PAGAMENTO_RIFERIMENTO_BANCACLASS]  DEFAULT ('TISBanca') FOR [RIFERIMENTO_BANCACLASS]
GO
ALTER TABLE [dbo].[MODPAGAM] ADD  CONSTRAINT [DF_MODPAGAM_CLASS]  DEFAULT ('TISModPagam') FOR [CLASS]
GO
ALTER TABLE [dbo].[MODPAGAM] ADD  CONSTRAINT [DF_MODPAGAM_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MODPAGAM] ADD  CONSTRAINT [DF_MODPAGAM_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MODPAGAM] ADD  CONSTRAINT [DF_MODPAGAM_RIFBANCA]  DEFAULT ((0)) FOR [RIFBANCA]
GO
ALTER TABLE [dbo].[MODPAGAMENTO] ADD  CONSTRAINT [DF_MODPAGAMENTO_CLASS]  DEFAULT ('TISModPagamento') FOR [CLASS]
GO
ALTER TABLE [dbo].[MODPAGAMENTO] ADD  CONSTRAINT [DF_MODPAGAMENTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MODPAGAMENTO] ADD  CONSTRAINT [DF_MODPAGAMENTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MODPAGAMENTO] ADD  CONSTRAINT [DF_MODPAGAMENTO_COD_CONTOCLASS]  DEFAULT ('TISContoContabile') FOR [COD_CONTOCLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_CLASS]  DEFAULT ('TISMovimentoContabile') FOR [CLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_ESERCCLASS]  DEFAULT ('TISEsercizioContabile') FOR [ESERCCLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_UTENTE_INSERIMENTOCLASS]  DEFAULT ('TISUser') FOR [UTENTE_INSERIMENTOCLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_MOD_PAGAMENTOCLASS]  DEFAULT ('TISModPagamento') FOR [MOD_PAGAMENTOCLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_REG_IVACLASS]  DEFAULT ('TISRegistroIva') FOR [REG_IVACLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_CAUSALECLASS]  DEFAULT ('TISCausaleContabile') FOR [CAUSALECLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_CLIENTECLASS]  DEFAULT ('TISCliente') FOR [CLIENTECLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_FORNITORECLASS]  DEFAULT ('TISFornitore') FOR [FORNITORECLASS]
GO
ALTER TABLE [dbo].[MOVIMENTI_CONTABILI] ADD  CONSTRAINT [DF_MOVIMENTI_CONTABILI_BANCACLASS]  DEFAULT ('TISBanca') FOR [BANCACLASS]
GO
ALTER TABLE [dbo].[NAZIONI] ADD  CONSTRAINT [DF_NAZIONI_CLASS]  DEFAULT ('TISNazione') FOR [CLASS]
GO
ALTER TABLE [dbo].[NAZIONI] ADD  CONSTRAINT [DF_NAZIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[NAZIONI] ADD  CONSTRAINT [DF_NAZIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[NAZIONI] ADD  CONSTRAINT [DF_NAZIONI_LINGUACLASS]  DEFAULT ('TISLanguage') FOR [LINGUACLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_CLASS]  DEFAULT ('TISNominativo') FOR [CLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_PROVNASCCLASS]  DEFAULT ('TISProvincia') FOR [PROVNASCCLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_NAZIONALITACLASS]  DEFAULT ('TISNazione') FOR [NAZIONALITACLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_NAZIONALITAID]  DEFAULT ('IT') FOR [NAZIONALITAID]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_BANCACLASS]  DEFAULT ('TISBanca') FOR [BANCACLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_TAGLIACLASS]  DEFAULT ('TISTaglia') FOR [TAGLIACLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_DOCUMENTOCLASS]  DEFAULT ('TISDocumento') FOR [DOCUMENTOCLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_TESSERASANCLASS]  DEFAULT ('TISDocumento') FOR [TESSERASANCLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[NOMINATIVI] ADD  CONSTRAINT [DF_NOMINATIVI_LUOGONASCCLASS]  DEFAULT ('TISComune') FOR [LUOGONASCCLASS]
GO
ALTER TABLE [dbo].[PARENTELE] ADD  CONSTRAINT [DF_PARENTELE_CLASS]  DEFAULT ('TISParentela') FOR [CLASS]
GO
ALTER TABLE [dbo].[PARENTELE] ADD  CONSTRAINT [DF_PARENTELE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[PARENTELE] ADD  CONSTRAINT [DF_PARENTELE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_CLASS]  DEFAULT ('TISPartita') FOR [CLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_CAMPIONATOCLASS]  DEFAULT ('TISCampionato') FOR [CAMPIONATOCLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_FASECAMPCLASS]  DEFAULT ('TISFaseCampionato') FOR [FASECAMPCLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_GIORNATACLASS]  DEFAULT ('TISGiornata') FOR [GIORNATACLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_ACCOPPIAMENTOCLASS]  DEFAULT ('TISAccoppiamento') FOR [ACCOPPIAMENTOCLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_SQUADRACLASS]  DEFAULT ('TISSquadra') FOR [SQUADRACLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_AVVERSARIOCLASS]  DEFAULT ('TISSquadra') FOR [AVVERSARIOCLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_CAMPOCLASS]  DEFAULT ('TISImpiantoSportivo') FOR [CAMPOCLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_STATUSCLASS]  DEFAULT ('TISStatus') FOR [STATUSCLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_ALLENATORECLASS]  DEFAULT ('TISNominativo') FOR [ALLENATORECLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_ACCOMPAGNATORECLASS]  DEFAULT ('TISNominativo') FOR [ACCOMPAGNATORECLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_MEDICOCLASS]  DEFAULT ('TISNominativo') FOR [MEDICOCLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_VICE_ALLENATORECLASS]  DEFAULT ('TISNominativo') FOR [VICE_ALLENATORECLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_FISIOTERAPISTACLASS]  DEFAULT ('TISNominativo') FOR [FISIOTERAPISTACLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_ADDETTO_ARBITRICLASS]  DEFAULT ('TISNominativo') FOR [ADDETTO_ARBITRICLASS]
GO
ALTER TABLE [dbo].[PARTITE] ADD  CONSTRAINT [DF_PARTITE_ADDETTO_STATCLASS]  DEFAULT ('TISNominativo') FOR [ADDETTO_STATCLASS]
GO
ALTER TABLE [dbo].[POLIZZE] ADD  CONSTRAINT [DF_POLIZZE_CLASS]  DEFAULT ('TISPolizza') FOR [CLASS]
GO
ALTER TABLE [dbo].[POLIZZE] ADD  CONSTRAINT [DF_POLIZZE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[POLIZZE] ADD  CONSTRAINT [DF_POLIZZE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[POLIZZE] ADD  CONSTRAINT [DF_POLIZZE_DURATACLASS]  DEFAULT ('TISTipoDurata') FOR [DURATACLASS]
GO
ALTER TABLE [dbo].[PROFILE] ADD  CONSTRAINT [DF_PROFILE_CLASS]  DEFAULT ('TISProfile') FOR [CLASS]
GO
ALTER TABLE [dbo].[PROFILE] ADD  CONSTRAINT [DF_PROFILE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[PROFILE] ADD  CONSTRAINT [DF_PROFILE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[PROFUN] ADD  CONSTRAINT [DF_PROFUN_CLASS]  DEFAULT ('TISProfun') FOR [CLASS]
GO
ALTER TABLE [dbo].[PROFUN] ADD  CONSTRAINT [DF_PROFUN_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[PROFUN] ADD  CONSTRAINT [DF_PROFUN_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[PROFUN] ADD  CONSTRAINT [DF_PROFUN_PROFILEIDCLASS]  DEFAULT ('TISProfile') FOR [PROFILEIDCLASS]
GO
ALTER TABLE [dbo].[PROVINCE] ADD  CONSTRAINT [DF_PROVINCE_CLASS]  DEFAULT ('TISProvincia') FOR [CLASS]
GO
ALTER TABLE [dbo].[PROVINCE] ADD  CONSTRAINT [DF_PROVINCE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[PROVINCE] ADD  CONSTRAINT [DF_PROVINCE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[PROVINCE] ADD  CONSTRAINT [DF_PROVINCE_REGIONECLASS]  DEFAULT ('TISRegione') FOR [REGIONECLASS]
GO
ALTER TABLE [dbo].[QUOTE_ISCRIZIONI] ADD  CONSTRAINT [DF_QUOTE_ISCRIZIONI_CLASS]  DEFAULT ('TISQuotaIscrizione') FOR [CLASS]
GO
ALTER TABLE [dbo].[QUOTE_ISCRIZIONI] ADD  CONSTRAINT [DF_QUOTE_ISCRIZIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[QUOTE_ISCRIZIONI] ADD  CONSTRAINT [DF_QUOTE_ISCRIZIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[QUOTE_ISCRIZIONI] ADD  CONSTRAINT [DF_QUOTE_ISCRIZIONI_CAMPAGNACLASS]  DEFAULT ('TISCampagnaIscrizione') FOR [CAMPAGNACLASS]
GO
ALTER TABLE [dbo].[QUOTE_ISCRIZIONI] ADD  CONSTRAINT [DF_QUOTE_ISCRIZIONI_GIORNO1CLASS]  DEFAULT ('TISGiorni') FOR [GIORNO1CLASS]
GO
ALTER TABLE [dbo].[QUOTE_ISCRIZIONI] ADD  CONSTRAINT [DF_QUOTE_ISCRIZIONI_GIORNO2CLASS]  DEFAULT ('TISGiorni') FOR [GIORNO2CLASS]
GO
ALTER TABLE [dbo].[QUOTE_ISCRIZIONI] ADD  CONSTRAINT [DF_QUOTE_ISCRIZIONI_GIORNO3CLASS]  DEFAULT ('TISGiorni') FOR [GIORNO3CLASS]
GO
ALTER TABLE [dbo].[RATE_ISCRIZIONI] ADD  CONSTRAINT [DF_RATE_ISCRIZIONI_CLASS]  DEFAULT ('TISRataIscrizione') FOR [CLASS]
GO
ALTER TABLE [dbo].[RATE_ISCRIZIONI] ADD  CONSTRAINT [DF_RATE_ISCRIZIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[RATE_ISCRIZIONI] ADD  CONSTRAINT [DF_RATE_ISCRIZIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[RATE_ISCRIZIONI] ADD  CONSTRAINT [DF_RATE_ISCRIZIONI_ISCRIZIONECLASS]  DEFAULT ('TISIscrizione') FOR [ISCRIZIONECLASS]
GO
ALTER TABLE [dbo].[REGIONI] ADD  CONSTRAINT [DF_REGIONI_CLASS]  DEFAULT ('TISRegione') FOR [CLASS]
GO
ALTER TABLE [dbo].[REGIONI] ADD  CONSTRAINT [DF_REGIONI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[REGIONI] ADD  CONSTRAINT [DF_REGIONI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[REGIONI] ADD  CONSTRAINT [DF_REGIONI_AREAGEOCLASS]  DEFAULT ('TISAreaGeografica') FOR [AREAGEOCLASS]
GO
ALTER TABLE [dbo].[REGISTRI_IVA] ADD  CONSTRAINT [DF_REGISTRI_IVA_CLASS]  DEFAULT ('TISRegistroIva') FOR [CLASS]
GO
ALTER TABLE [dbo].[REGISTRI_IVA] ADD  CONSTRAINT [DF_REGISTRI_IVA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[REGISTRI_IVA] ADD  CONSTRAINT [DF_REGISTRI_IVA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_CLASS]  DEFAULT ('TISRigaContabile') FOR [CLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_MOVIMENTOCLASS]  DEFAULT ('TISMovimentoContabile') FOR [MOVIMENTOCLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_UTENTE_INSERIMENTOCLASS]  DEFAULT ('TISUser') FOR [UTENTE_INSERIMENTOCLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_CONTOCLASS]  DEFAULT ('TISContoContabile') FOR [CONTOCLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_COD_IVACLASS]  DEFAULT ('TISCodiceIVA') FOR [COD_IVACLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_CENTRO_COSTOCLASS]  DEFAULT ('TISCentroDiCosto') FOR [CENTRO_COSTOCLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_CLIENTECLASS]  DEFAULT ('TISCliente') FOR [CLIENTECLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_FORNITORECLASS]  DEFAULT ('TISFornitore') FOR [FORNITORECLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_BANCACLASS]  DEFAULT ('TISBanca') FOR [BANCACLASS]
GO
ALTER TABLE [dbo].[RIGHE_CONTABILI] ADD  CONSTRAINT [DF_RIGHE_CONTABILI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[RIGHEFATTURECLIENTI] ADD  CONSTRAINT [DF_RIGHEFATTURECLIENTI_CLASS]  DEFAULT ('TISRigaFatturaCliente') FOR [CLASS]
GO
ALTER TABLE [dbo].[RIGHEFATTURECLIENTI] ADD  CONSTRAINT [DF_RIGHEFATTURECLIENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[RIGHEFATTURECLIENTI] ADD  CONSTRAINT [DF_RIGHEFATTURECLIENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[RIGHEFATTURECLIENTI] ADD  CONSTRAINT [DF_RIGHEFATTURECLIENTI_FATTCLICLASS]  DEFAULT ('TISFatturaCliente') FOR [FATTCLICLASS]
GO
ALTER TABLE [dbo].[RIGHEFATTURECLIENTI] ADD  CONSTRAINT [DF_RIGHEFATTURECLIENTI_ASSOGIVACLASS]  DEFAULT ('TISCodiceIVA') FOR [ASSOGIVACLASS]
GO
ALTER TABLE [dbo].[RIGHEFATTURECLIENTI] ADD  CONSTRAINT [DF_RIGHEFATTURECLIENTI_CODRICAVOCLASS]  DEFAULT ('TISContoContabile') FOR [CODRICAVOCLASS]
GO
ALTER TABLE [dbo].[RIGHEFATTURECLIENTI] ADD  CONSTRAINT [DF_RIGHEFATTURECLIENTI_CENTROCOSTOCLASS]  DEFAULT ('TISCentroDiCosto') FOR [CENTROCOSTOCLASS]
GO
ALTER TABLE [dbo].[RISPARZIALI] ADD  CONSTRAINT [DF_RISPARZIALI_CLASS]  DEFAULT ('TISRisparziale') FOR [CLASS]
GO
ALTER TABLE [dbo].[RISPARZIALI] ADD  CONSTRAINT [DF_RISPARZIALI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[RISPARZIALI] ADD  CONSTRAINT [DF_RISPARZIALI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ROSE] ADD  CONSTRAINT [DF_ROSE_CLASS]  DEFAULT ('TISRosa') FOR [CLASS]
GO
ALTER TABLE [dbo].[ROSE] ADD  CONSTRAINT [DF_ROSE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[ROSE] ADD  CONSTRAINT [DF_ROSE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[ROSE] ADD  CONSTRAINT [DF_ROSE_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[ROSE] ADD  CONSTRAINT [DF_ROSE_RUOLO_GIOCCLASS]  DEFAULT ('TISRuoloGioc') FOR [RUOLO_GIOCCLASS]
GO
ALTER TABLE [dbo].[ROSE] ADD  CONSTRAINT [DF_ROSE_SQUADRACLASS]  DEFAULT ('TISSquadra') FOR [SQUADRACLASS]
GO
ALTER TABLE [dbo].[RUOLI_GIOC] ADD  CONSTRAINT [DF_RUOLI_GIOC_CLASS]  DEFAULT ('TISRuoloGioc') FOR [CLASS]
GO
ALTER TABLE [dbo].[RUOLI_GIOC] ADD  CONSTRAINT [DF_RUOLI_GIOC_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[RUOLI_GIOC] ADD  CONSTRAINT [DF_RUOLI_GIOC_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[RUOLI_STAFF] ADD  CONSTRAINT [DF_RUOLI_STAFF_CLASS]  DEFAULT ('TISRuoloStaff') FOR [CLASS]
GO
ALTER TABLE [dbo].[RUOLI_STAFF] ADD  CONSTRAINT [DF_RUOLI_STAFF_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[RUOLI_STAFF] ADD  CONSTRAINT [DF_RUOLI_STAFF_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_FASCE] ADD  CONSTRAINT [DF_S_FASCE_CLASS]  DEFAULT ('TISSelNomFasce') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_FASCE] ADD  CONSTRAINT [DF_S_FASCE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_FASCE] ADD  CONSTRAINT [DF_S_FASCE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_INDIRIZZI] ADD  CONSTRAINT [DF_S_INDIRIZZI_CLASS]  DEFAULT ('TISSelIndirizzi') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_INDIRIZZI] ADD  CONSTRAINT [DF_S_INDIRIZZI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_INDIRIZZI] ADD  CONSTRAINT [DF_S_INDIRIZZI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_LOCALITA] ADD  CONSTRAINT [DF_S_LOCALITA_CLASS]  DEFAULT ('TISSelLocalita') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_LOCALITA] ADD  CONSTRAINT [DF_S_LOCALITA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_LOCALITA] ADD  CONSTRAINT [DF_S_LOCALITA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_LOCALITA] ADD  CONSTRAINT [DF_S_LOCALITA_PROVCLASS]  DEFAULT ('TISProvincia') FOR [PROVCLASS]
GO
ALTER TABLE [dbo].[S_MESENASC] ADD  CONSTRAINT [DF_S_MESENASC_CLASS]  DEFAULT ('TISSelMeseNasc') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_MESENASC] ADD  CONSTRAINT [DF_S_MESENASC_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_MESENASC] ADD  CONSTRAINT [DF_S_MESENASC_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_NOMINATIVI] ADD  CONSTRAINT [DF_S_NOMINATIVI_CLASS]  DEFAULT ('TISSelNominativi') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_NOMINATIVI] ADD  CONSTRAINT [DF_S_NOMINATIVI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_NOMINATIVI] ADD  CONSTRAINT [DF_S_NOMINATIVI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_SETTORE] ADD  CONSTRAINT [DF_S_SETTORE_CLASS]  DEFAULT ('TISSelSettore') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_SETTORE] ADD  CONSTRAINT [DF_S_SETTORE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_SETTORE] ADD  CONSTRAINT [DF_S_SETTORE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_SOCIETA] ADD  CONSTRAINT [DF_S_SOCIETA_CLASS]  DEFAULT ('TISSelSocieta') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_SOCIETA] ADD  CONSTRAINT [DF_S_SOCIETA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_SOCIETA] ADD  CONSTRAINT [DF_S_SOCIETA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_SOCIETA] ADD  CONSTRAINT [DF_S_SOCIETA_SOCIETACLASS]  DEFAULT ('TISSocieta') FOR [SOCIETACLASS]
GO
ALTER TABLE [dbo].[S_STAGCAT] ADD  CONSTRAINT [DF_S_STAGCAT_CLASS]  DEFAULT ('TISSelStagCateg') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_STAGCAT] ADD  CONSTRAINT [DF_S_STAGCAT_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_STAGCAT] ADD  CONSTRAINT [DF_S_STAGCAT_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_STAGCAT] ADD  CONSTRAINT [DF_S_STAGCAT_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[S_STAGCAT] ADD  CONSTRAINT [DF_S_STAGCAT_CATEGORIACLASS]  DEFAULT ('TISCategoria') FOR [CATEGORIACLASS]
GO
ALTER TABLE [dbo].[S_TESSERAMENTI] ADD  CONSTRAINT [DF_S_TESSERAMENTI_CLASS]  DEFAULT ('TISSelTesseramenti') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_TESSERAMENTI] ADD  CONSTRAINT [DF_S_TESSERAMENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_TESSERAMENTI] ADD  CONSTRAINT [DF_S_TESSERAMENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[S_TESSERAMENTI] ADD  CONSTRAINT [DF_S_TESSERAMENTI_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[S_TESSERAMENTI] ADD  CONSTRAINT [DF_S_TESSERAMENTI_CAMPIONATOCLASS]  DEFAULT ('TISCampionato') FOR [CAMPIONATOCLASS]
GO
ALTER TABLE [dbo].[S_TESSERAMENTI] ADD  CONSTRAINT [DF_S_TESSERAMENTI_CATEGORIACLASS]  DEFAULT ('TISCategoria') FOR [CATEGORIACLASS]
GO
ALTER TABLE [dbo].[S_TIME] ADD  CONSTRAINT [DF_S_TIME_CLASS]  DEFAULT ('TISSelTime') FOR [CLASS]
GO
ALTER TABLE [dbo].[S_TIME] ADD  CONSTRAINT [DF_S_TIME_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[S_TIME] ADD  CONSTRAINT [DF_S_TIME_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SCONTRIDIR] ADD  CONSTRAINT [DF_SCONTRIDIR_CLASS]  DEFAULT ('TISScontroDiretto') FOR [CLASS]
GO
ALTER TABLE [dbo].[SCONTRIDIR] ADD  CONSTRAINT [DF_SCONTRIDIR_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[SCONTRIDIR] ADD  CONSTRAINT [DF_SCONTRIDIR_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SCONTRIDIR] ADD  CONSTRAINT [DF_SCONTRIDIR_AVVERSARIOCLASS]  DEFAULT ('TISSquadra') FOR [AVVERSARIOCLASS]
GO
ALTER TABLE [dbo].[SELECTIDDX] ADD  CONSTRAINT [DF_SELECTIDDX_CLASS]  DEFAULT ('TISSelectId_Desc') FOR [CLASS]
GO
ALTER TABLE [dbo].[SELECTIDDX] ADD  CONSTRAINT [DF_SELECTIDDX_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[SELECTIDDX] ADD  CONSTRAINT [DF_SELECTIDDX_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SELGENERIC] ADD  CONSTRAINT [DF_SELGENERIC_CLASS]  DEFAULT ('TISSelGeneric') FOR [CLASS]
GO
ALTER TABLE [dbo].[SELGENERIC] ADD  CONSTRAINT [DF_SELGENERIC_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[SELGENERIC] ADD  CONSTRAINT [DF_SELGENERIC_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SOCI] ADD  CONSTRAINT [DF_SOCI_CLASS]  DEFAULT ('TISSocio') FOR [CLASS]
GO
ALTER TABLE [dbo].[SOCI] ADD  CONSTRAINT [DF_SOCI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[SOCI] ADD  CONSTRAINT [DF_SOCI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SOCI] ADD  CONSTRAINT [DF_SOCI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_CLASS]  DEFAULT ('TISSocieta') FOR [CLASS]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_FEDERAZIONECLASS]  DEFAULT ('TISFederazione') FOR [FEDERAZIONECLASS]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_TIPOSPORTCLASS]  DEFAULT ('TISTipoSport') FOR [TIPOSPORTCLASS]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_MAIN_SPONSORCLASS]  DEFAULT ('TISSponsor') FOR [MAIN_SPONSORCLASS]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_ALTRO_SPONSORCLASS]  DEFAULT ('TISSponsor') FOR [ALTRO_SPONSORCLASS]
GO
ALTER TABLE [dbo].[SOCIETA] ADD  CONSTRAINT [DF_SOCIETA_MAIN_CAMPOCLASS]  DEFAULT ('TISImpiantoSportivo') FOR [MAIN_CAMPOCLASS]
GO
ALTER TABLE [dbo].[SPONSORS] ADD  CONSTRAINT [DF_SPONSORS_CLASS]  DEFAULT ('TISSponsor') FOR [CLASS]
GO
ALTER TABLE [dbo].[SPONSORS] ADD  CONSTRAINT [DF_SPONSORS_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[SPONSORS] ADD  CONSTRAINT [DF_SPONSORS_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SPONSORS] ADD  CONSTRAINT [DF_SPONSORS_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[SPONSORS] ADD  CONSTRAINT [DF_SPONSORS_PROVINCIACLASS]  DEFAULT ('TISProvincia') FOR [PROVINCIACLASS]
GO
ALTER TABLE [dbo].[SPONSORS] ADD  CONSTRAINT [DF_SPONSORS_LEG_RAPPCLASS]  DEFAULT ('TISNominativo') FOR [LEG_RAPPCLASS]
GO
ALTER TABLE [dbo].[SPONSORS] ADD  CONSTRAINT [DF_SPONSORS_COMUNECLASS]  DEFAULT ('TISComune') FOR [COMUNECLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_CLASS]  DEFAULT ('TISSquadra') FOR [CLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_TIPOSPORTCLASS]  DEFAULT ('TISTipoSport') FOR [TIPOSPORTCLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_CATEGORIACLASS]  DEFAULT ('TISCategoria') FOR [CATEGORIACLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_SOCIETACLASS]  DEFAULT ('TISSocieta') FOR [SOCIETACLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_SPONSORCLASS]  DEFAULT ('TISSponsor') FOR [SPONSORCLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_CAMPOCLASS]  DEFAULT ('TISImpiantoSportivo') FOR [CAMPOCLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_DAY_GARACLASS]  DEFAULT ('TISGiorni') FOR [DAY_GARACLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_ALLENATORECLASS]  DEFAULT ('TISNominativo') FOR [ALLENATORECLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_ACCOMPAGNATORECLASS]  DEFAULT ('TISNominativo') FOR [ACCOMPAGNATORECLASS]
GO
ALTER TABLE [dbo].[SQUADRE] ADD  CONSTRAINT [DF_SQUADRE_NUMERO]  DEFAULT ((0)) FOR [NUMERO]
GO
ALTER TABLE [dbo].[STAFF_PARTITA] ADD  CONSTRAINT [DF_STAFF_PARTITA_CLASS]  DEFAULT ('TISStaffPartita') FOR [CLASS]
GO
ALTER TABLE [dbo].[STAFF_PARTITA] ADD  CONSTRAINT [DF_STAFF_PARTITA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[STAFF_PARTITA] ADD  CONSTRAINT [DF_STAFF_PARTITA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[STAFF_PARTITA] ADD  CONSTRAINT [DF_STAFF_PARTITA_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[STAFF_PARTITA] ADD  CONSTRAINT [DF_STAFF_PARTITA_MANSIONECLASS]  DEFAULT ('TISRuoloStaff') FOR [MANSIONECLASS]
GO
ALTER TABLE [dbo].[STAGIONE] ADD  CONSTRAINT [DF_STAGIONE_CLASS]  DEFAULT ('TISStagione') FOR [CLASS]
GO
ALTER TABLE [dbo].[STAGIONE] ADD  CONSTRAINT [DF_STAGIONE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[STAGIONE] ADD  CONSTRAINT [DF_STAGIONE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[STATUS] ADD  CONSTRAINT [DF_STATUS_CLASS]  DEFAULT ('TISStatus') FOR [CLASS]
GO
ALTER TABLE [dbo].[STATUS] ADD  CONSTRAINT [DF_STATUS_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[STATUS] ADD  CONSTRAINT [DF_STATUS_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TAGLIA] ADD  CONSTRAINT [DF_TAGLIA_CLASS]  DEFAULT ('TISTaglia') FOR [CLASS]
GO
ALTER TABLE [dbo].[TAGLIA] ADD  CONSTRAINT [DF_TAGLIA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TAGLIA] ADD  CONSTRAINT [DF_TAGLIA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TESSERAMENTI] ADD  CONSTRAINT [DF_TESSERAMENTI_CLASS]  DEFAULT ('TISTesseramento') FOR [CLASS]
GO
ALTER TABLE [dbo].[TESSERAMENTI] ADD  CONSTRAINT [DF_TESSERAMENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TESSERAMENTI] ADD  CONSTRAINT [DF_TESSERAMENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TESSERAMENTI] ADD  CONSTRAINT [DF_TESSERAMENTI_STAGIONECLASS]  DEFAULT ('TISStagione') FOR [STAGIONECLASS]
GO
ALTER TABLE [dbo].[TESSERAMENTI] ADD  CONSTRAINT [DF_TESSERAMENTI_SOC_TITOLARECLASS]  DEFAULT ('TISSocieta') FOR [SOC_TITOLARECLASS]
GO
ALTER TABLE [dbo].[TESSERAMENTI] ADD  CONSTRAINT [DF_TESSERAMENTI_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[TESSERAMENTI] ADD  CONSTRAINT [DF_TESSERAMENTI_CAMPIONATOCLASS]  DEFAULT ('TISCampionato') FOR [CAMPIONATOCLASS]
GO
ALTER TABLE [dbo].[TESTI_EMAIL] ADD  CONSTRAINT [DF_TESTI_EMAIL_CLASS]  DEFAULT ('TISTestoEmail') FOR [CLASS]
GO
ALTER TABLE [dbo].[TESTI_EMAIL] ADD  CONSTRAINT [DF_TESTI_EMAIL_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TESTI_EMAIL] ADD  CONSTRAINT [DF_TESTI_EMAIL_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TIPOARBITRO] ADD  CONSTRAINT [DF_TIPOARBITRO_CLASS]  DEFAULT ('TISTipoArbitro') FOR [CLASS]
GO
ALTER TABLE [dbo].[TIPOARBITRO] ADD  CONSTRAINT [DF_TIPOARBITRO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TIPOARBITRO] ADD  CONSTRAINT [DF_TIPOARBITRO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TIPOEVENTO] ADD  CONSTRAINT [DF_TIPOEVENTO_CLASS]  DEFAULT ('TISTipoEvento') FOR [CLASS]
GO
ALTER TABLE [dbo].[TIPOEVENTO] ADD  CONSTRAINT [DF_TIPOEVENTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TIPOEVENTO] ADD  CONSTRAINT [DF_TIPOEVENTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TIPOEVENTO] ADD  CONSTRAINT [DF_TIPOEVENTO_DURATAORE]  DEFAULT ((2)) FOR [DURATAORE]
GO
ALTER TABLE [dbo].[TIPOFASE] ADD  CONSTRAINT [DF_TIPOFASE_CLASS]  DEFAULT ('TISTipoFase') FOR [CLASS]
GO
ALTER TABLE [dbo].[TIPOFASE] ADD  CONSTRAINT [DF_TIPOFASE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TIPOFASE] ADD  CONSTRAINT [DF_TIPOFASE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TIPOFASE] ADD  CONSTRAINT [DF_TIPOFASE_NUMGARE]  DEFAULT ((1)) FOR [NUMGARE]
GO
ALTER TABLE [dbo].[TIPOGIORNATA] ADD  CONSTRAINT [DF_TIPOGIORNATA_CLASS]  DEFAULT ('TISTipoGiornata') FOR [CLASS]
GO
ALTER TABLE [dbo].[TIPOGIORNATA] ADD  CONSTRAINT [DF_TIPOGIORNATA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TIPOGIORNATA] ADD  CONSTRAINT [DF_TIPOGIORNATA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TIPOMARCATURA] ADD  CONSTRAINT [DF_TIPOMARCATURA_CLASS]  DEFAULT ('TISTipoMarcatura') FOR [CLASS]
GO
ALTER TABLE [dbo].[TIPOMARCATURA] ADD  CONSTRAINT [DF_TIPOMARCATURA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TIPOMARCATURA] ADD  CONSTRAINT [DF_TIPOMARCATURA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TIPOMARCATURA] ADD  CONSTRAINT [DF_TIPOMARCATURA_TIPOSPORTCLASS]  DEFAULT ('TISTipoSport') FOR [TIPOSPORTCLASS]
GO
ALTER TABLE [dbo].[TIPOMARCATURA] ADD  CONSTRAINT [DF_TIPOMARCATURA_PUNTEGGIO]  DEFAULT ((1)) FOR [PUNTEGGIO]
GO
ALTER TABLE [dbo].[TIPOSPORT] ADD  CONSTRAINT [DF_TIPOSPORT_CLASS]  DEFAULT ('TISTipoSport') FOR [CLASS]
GO
ALTER TABLE [dbo].[TIPOSPORT] ADD  CONSTRAINT [DF_TIPOSPORT_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TIPOSPORT] ADD  CONSTRAINT [DF_TIPOSPORT_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TPDOC] ADD  CONSTRAINT [DF_TPDOC_CLASS]  DEFAULT ('TISTipoDoc') FOR [CLASS]
GO
ALTER TABLE [dbo].[TPDOC] ADD  CONSTRAINT [DF_TPDOC_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TPDOC] ADD  CONSTRAINT [DF_TPDOC_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TPDURATE] ADD  CONSTRAINT [DF_TPDURATE_CLASS]  DEFAULT ('TISTipoDurata') FOR [CLASS]
GO
ALTER TABLE [dbo].[TPDURATE] ADD  CONSTRAINT [DF_TPDURATE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TPDURATE] ADD  CONSTRAINT [DF_TPDURATE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TPIMPIANTO] ADD  CONSTRAINT [DF_TPIMPIANTO_CLASS]  DEFAULT ('TISTipoImpianto') FOR [CLASS]
GO
ALTER TABLE [dbo].[TPIMPIANTO] ADD  CONSTRAINT [DF_TPIMPIANTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TPIMPIANTO] ADD  CONSTRAINT [DF_TPIMPIANTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TPSANZIONE] ADD  CONSTRAINT [DF_TPSANZIONE_CLASS]  DEFAULT ('TISTipoSanzione') FOR [CLASS]
GO
ALTER TABLE [dbo].[TPSANZIONE] ADD  CONSTRAINT [DF_TPSANZIONE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TPSANZIONE] ADD  CONSTRAINT [DF_TPSANZIONE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TPTESSERAMENTO] ADD  CONSTRAINT [DF_TPTESSERAMENTO_CLASS]  DEFAULT ('TISTipoTesseramento') FOR [CLASS]
GO
ALTER TABLE [dbo].[TPTESSERAMENTO] ADD  CONSTRAINT [DF_TPTESSERAMENTO_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TPTESSERAMENTO] ADD  CONSTRAINT [DF_TPTESSERAMENTO_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TPVISITAMED] ADD  CONSTRAINT [DF_TPVISITAMED_CLASS]  DEFAULT ('TISTipoVisitaMedica') FOR [CLASS]
GO
ALTER TABLE [dbo].[TPVISITAMED] ADD  CONSTRAINT [DF_TPVISITAMED_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[TPVISITAMED] ADD  CONSTRAINT [DF_TPVISITAMED_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[TPVISITAMED] ADD  CONSTRAINT [DF_TPVISITAMED_SCADENZACLASS]  DEFAULT ('TISTipoDurata') FOR [SCADENZACLASS]
GO
ALTER TABLE [dbo].[UNITAMISURA] ADD  CONSTRAINT [DF_UNITAMISURA_CLASS]  DEFAULT ('TISUnitaMisura') FOR [CLASS]
GO
ALTER TABLE [dbo].[UNITAMISURA] ADD  CONSTRAINT [DF_UNITAMISURA_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[UNITAMISURA] ADD  CONSTRAINT [DF_UNITAMISURA_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[VERSAMENTI] ADD  CONSTRAINT [DF_VERSAMENTI_CLASS]  DEFAULT ('TISVersamento') FOR [CLASS]
GO
ALTER TABLE [dbo].[VERSAMENTI] ADD  CONSTRAINT [DF_VERSAMENTI_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[VERSAMENTI] ADD  CONSTRAINT [DF_VERSAMENTI_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[VERSAMENTI] ADD  CONSTRAINT [DF_VERSAMENTI_TESSERAMENTOCLASS]  DEFAULT ('TISTesseramento') FOR [TESSERAMENTOCLASS]
GO
ALTER TABLE [dbo].[VISITEMEDICHE] ADD  CONSTRAINT [DF_VISITEMEDICHE_CLASS]  DEFAULT ('TISVisitaMedica') FOR [CLASS]
GO
ALTER TABLE [dbo].[VISITEMEDICHE] ADD  CONSTRAINT [DF_VISITEMEDICHE_UPDATECOUNT]  DEFAULT ((0)) FOR [UPDATECOUNT]
GO
ALTER TABLE [dbo].[VISITEMEDICHE] ADD  CONSTRAINT [DF_VISITEMEDICHE_UPDTIMESTAMP]  DEFAULT (CONVERT([timestamp],getdate(),0)) FOR [UPDTIMESTAMP]
GO
ALTER TABLE [dbo].[VISITEMEDICHE] ADD  CONSTRAINT [DF_VISITEMEDICHE_TPVISITACLASS]  DEFAULT ('TISTipoVisitaMedica') FOR [TPVISITACLASS]
GO
ALTER TABLE [dbo].[VISITEMEDICHE] ADD  CONSTRAINT [DF_VISITEMEDICHE_NOMINATIVOCLASS]  DEFAULT ('TISNominativo') FOR [NOMINATIVOCLASS]
GO
ALTER TABLE [dbo].[VISITEMEDICHE] ADD  CONSTRAINT [DF_VISITEMEDICHE_AMBULATORIOCLASS]  DEFAULT ('TISAmbulatorio') FOR [AMBULATORIOCLASS]
GO
ALTER TABLE [dbo].[DETTAGLI_PAGAMENTO]  WITH CHECK ADD  CONSTRAINT [FK_DETTAGLI_PAGAMENTO_MEZZO_PAGAMENTO] FOREIGN KEY([MEZZO_PAGAMENTOCLASS], [MEZZO_PAGAMENTOID])
REFERENCES [dbo].[MEZZI_PAGAMENTO] ([CLASS], [ID])
GO
ALTER TABLE [dbo].[DETTAGLI_PAGAMENTO] CHECK CONSTRAINT [FK_DETTAGLI_PAGAMENTO_MEZZO_PAGAMENTO]
GO
ALTER TABLE [dbo].[PROVINCE]  WITH CHECK ADD  CONSTRAINT [FK_PROVINCE_REGIONE] FOREIGN KEY([REGIONECLASS], [REGIONEID])
REFERENCES [dbo].[REGIONI] ([CLASS], [ID])
GO
ALTER TABLE [dbo].[PROVINCE] CHECK CONSTRAINT [FK_PROVINCE_REGIONE]
GO
