--
-- File generated with SQLiteStudio v3.4.13 on Sun Jun 1 21:55:07 2025
--
-- Text encoding used: UTF-8
--
PRAGMA foreign_keys = off;
BEGIN TRANSACTION;

-- Table: anamnesi_prossima
CREATE TABLE IF NOT EXISTS [anamnesi_prossima] (
	[ID_consulto]	integer,
	[ID_paziente]	integer,
	[prima_volta]	nvarchar(50) COLLATE NOCASE,
	[tipologia]	nvarchar(50) COLLATE NOCASE,
	[localizzazione]	nvarchar(50) COLLATE NOCASE,
	[irradiazione]	nvarchar(50) COLLATE NOCASE,
	[periodo_insorgenza]	nvarchar(50) COLLATE NOCASE,
	[durata]	nvarchar(50) COLLATE NOCASE,
	[familiarita]	nvarchar(50) COLLATE NOCASE,
	[altre_terapie]	nvarchar(50) COLLATE NOCASE,
	[varie]	nvarchar COLLATE NOCASE

);

-- Table: anamnesi_remota
CREATE TABLE IF NOT EXISTS "anamnesi_remota" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`ID_paziente`	integer,
	`data`	datetime,
	`tipo`	integer,
	`descrizione`	nvarchar
);

-- Table: consulto
CREATE TABLE IF NOT EXISTS "consulto" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`ID_paziente`	integer,
	`data`	datetime,
	`problema_iniziale`	nvarchar
);

-- Table: esame
CREATE TABLE IF NOT EXISTS "esame" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`ID_consulto`	integer,
	`ID_paziente`	integer,
	`data`	datetime,
	`descrizione`	nvarchar,
	`tipo`	integer
);

-- Table: lkp_anamnesi
CREATE TABLE IF NOT EXISTS "lkp_anamnesi" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`descrizione`	nvarchar(50)
);
INSERT INTO lkp_anamnesi (ID, descrizione) VALUES (1, 'incidente');
INSERT INTO lkp_anamnesi (ID, descrizione) VALUES (2, 'trauma');
INSERT INTO lkp_anamnesi (ID, descrizione) VALUES (3, 'operazione chirugica');
INSERT INTO lkp_anamnesi (ID, descrizione) VALUES (4, 'problemi viscerali');
INSERT INTO lkp_anamnesi (ID, descrizione) VALUES (5, 'cicatrice');
INSERT INTO lkp_anamnesi (ID, descrizione) VALUES (6, 'gravidanza');
INSERT INTO lkp_anamnesi (ID, descrizione) VALUES (7, 'varie');

-- Table: lkp_esame
CREATE TABLE IF NOT EXISTS "lkp_esame" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`descrizione`	nvarchar(50)
);
INSERT INTO lkp_esame (ID, descrizione) VALUES (1, 'visita specialistica');
INSERT INTO lkp_esame (ID, descrizione) VALUES (2, 'rx');
INSERT INTO lkp_esame (ID, descrizione) VALUES (3, 'tac');
INSERT INTO lkp_esame (ID, descrizione) VALUES (4, 'rmn');
INSERT INTO lkp_esame (ID, descrizione) VALUES (5, 'ecografia');
INSERT INTO lkp_esame (ID, descrizione) VALUES (6, 'varie');

-- Table: lkp_provincia
CREATE TABLE IF NOT EXISTS [lkp_provincia] (
	[sigla]	nvarchar(2) COLLATE NOCASE,
	[descrizione]	nvarchar(50) COLLATE NOCASE

);
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AG', 'AGRIGENTO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AL', 'ALESSANDRIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AN', 'ANCONA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AO', 'AOSTA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AP', 'ASCOLI PICENO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AQ', 'L''AQUILA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AR', 'AREZZO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AT', 'ASTI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('AV', 'AVELLINO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BA', 'BARI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BG', 'BERGAMO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BI', 'BIELLA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BL', 'BELLUNO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BN', 'BENEVENTO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BO', 'BOLOGNA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BR', 'BRINDISI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BS', 'BRESCIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('BZ', 'BOLZANO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CA', 'CAGLIARI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CB', 'CAMPOBASSO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CE', 'CASERTA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CH', 'CHIETI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CL', 'CALTANISETTA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CN', 'CUNEO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CO', 'COMO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CR', 'CREMONA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CS', 'COSENZA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CT', 'CATANIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('CZ', 'CATANZARO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('EE', 'STATO ESTERO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('EN', 'ENNA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('FE', 'FERRARA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('FG', 'FOGGIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('FI', 'FIRENZE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('FO', 'FORLI''');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('FR', 'FROSINONE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('GE', 'GENOVA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('GO', 'GORIZIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('GR', 'GROSSETO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('IM', 'IMPERIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('IS', 'ISERNIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('KR', 'CROTONE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('LC', 'LECCO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('LE', 'LECCE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('LI', 'LIVORNO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('LO', 'LODI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('LT', 'LATINA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('LU', 'LUCCA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('MC', 'MACERATA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('ME', 'MESSINA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('MI', 'MILANO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('MN', 'MANTOVA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('MO', 'MODENA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('MS', 'MASSA CARRARA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('MT', 'MATERA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('NA', 'NAPOLI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('NO', 'NOVARA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('NU', 'NUORO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('OR', 'ORISTANO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PA', 'PALERMO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PC', 'PIACENZA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PD', 'PADOVA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PE', 'PESCARA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PG', 'PERUGIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PI', 'PISA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PN', 'PORDENONE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PO', 'PRATO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PR', 'PARMA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PS', 'PESARO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PT', 'PISTOIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PV', 'PAVIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('PZ', 'POTENZA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RA', 'RAVENNA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RC', 'REGGIO CALABRIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RE', 'REGGIO EMILIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RG', 'RAGUSA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RI', 'RIETI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RM', 'ROMA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RN', 'RIMINI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('RO', 'ROVIGO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('SA', 'SALERNO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('SI', 'SIENA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('SO', 'SONDRIO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('SP', 'LA SPEZIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('SR', 'SIRACUSA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('SS', 'SASSARI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('SV', 'SAVONA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TA', 'TARANTO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TE', 'TERAMO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TN', 'TRENTO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TO', 'TORINO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TP', 'TRAPANI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TR', 'TERNI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TS', 'TRIESTE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('TV', 'TREVISO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('UD', 'UDINE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VA', 'VARESE');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VB', 'VERBANIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VC', 'VERCELLI');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VE', 'VENEZIA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VI', 'VICENZA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VR', 'VERONA');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VT', 'VITERBO');
INSERT INTO lkp_provincia (sigla, descrizione) VALUES ('VV', 'VIBO VALENZIA');

-- Table: paziente
CREATE TABLE IF NOT EXISTS "paziente" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`cognome`	nvarchar(50),
	`nome`	nvarchar(50),
	`professione`	nvarchar(50),
	`indirizzo`	nvarchar(50),
	`citta`	nvarchar(50),
	`telefono`	nvarchar(50),
	`cellulare`	nvarchar(50),
	`prov`	nvarchar(2),
	`cap`	nvarchar(5),
	`email`	nvarchar(100),
	`data_nascita`	datetime
);

-- Table: trattamento
CREATE TABLE IF NOT EXISTS "trattamento" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`ID_consulto`	integer,
	`ID_paziente`	integer,
	`data`	datetime,
	`descrizione`	nvarchar
);

-- Table: valutazione
CREATE TABLE IF NOT EXISTS "valutazione" (
	`ID`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`ID_consulto`	integer,
	`ID_paziente`	integer,
	`strutturale`	nvarchar,
	`cranio_sacrale`	nvarchar,
	`ak_ortodontica`	nvarchar
);

COMMIT TRANSACTION;
PRAGMA foreign_keys = on;
