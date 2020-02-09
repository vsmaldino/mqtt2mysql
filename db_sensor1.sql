USE db_sensor1;
# sensor1 / sensorp1

DROP TABLE IF EXISTS t_BoardSignal;
DROP TABLE IF EXISTS t_SensorValue;
DROP TABLE IF EXISTS t_CommandSignal;
DROP TABLE IF EXISTS t_Sensor;
DROP TABLE IF EXISTS t_Board;
DROP TABLE IF EXISTS t_Broker;
DROP TABLE IF EXISTS t_BoardType;
DROP TABLE IF EXISTS t_SensorType;

CREATE TABLE t_SensorType (
  CodSensorType CHAR(15),
  UnitaMisura   CHAR(20) NOT NULL,
  Simbolo       CHAR(10) NOT NULL,
  Descrizione   CHAR(200),
  PRIMARY KEY (CodSensorType)
)
COMMENT 'Tipi di sensori'
;

CREATE TABLE t_BoardType (
  TypBoard    CHAR(20),
  Descrizione CHAR(200),
  PRIMARY KEY (TypBoard)
)
COMMENT 'Tipi di board'
;

CREATE TABLE t_Broker (
  CodMQTTBroker CHAR(10),
  IpHost        CHAR(30) NOT NULL COMMENT 'Indirizzo IP o Hostname',
  PlainPort     DEC(5) COMMENT 'Plain Port number',
  SSLPort       DEC(5) COMMENT 'SSL Port number',
  Descrizione   CHAR(200),
  PRIMARY KEY (CodMQTTBroker)
)
COMMENT 'I broker MQTT'
;

CREATE TABLE t_Board (
  CodBoard    CHAR(25)
   COMMENT 'Coincide con il ClientId se collegato a MQTT',
  TypBoard    CHAR(20) NOT NULL,
  IPv4        CHAR(15) COMMENT 'xxx.xxx.xxx.xxx',
  IPv6        CHAR(39)
   COMMENT 'xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx',
  MAC_Addr    CHAR(17) COMMENT 'xx:xx:xx:xx:xx:xx',
  Latitude    DECIMAL(9,6),
  Longitude   DECIMAL(9,6),
  Descrizione CHAR(200),
  CodMQTTBroker CHAR(10) COMMENT 'Can be null',
  PRIMARY KEY (CodBoard),
  FOREIGN KEY (TypBoard) REFERENCES t_BoardType(TypBoard),
  FOREIGN KEY (CodMQTTBroker) REFERENCES t_Broker(CodMQTTBroker)
)
COMMENT 'Le board cui sono collegati i sensori'
;

CREATE TABLE t_Sensor (
  Topic         CHAR(100),
  CodBoard      CHAR(25) NOT NULL,
  CodSensorType CHAR(15) NOT NULL,
  ExtInter      CHAR(3)  NOT NULL 
    COMMENT 'Internal/External'
    CHECK (ExtInter IN ('INT', 'int', 'EXT', 'ext')),
  Descrizione   CHAR(200),
  PRIMARY KEY (Topic),
  FOREIGN KEY (CodSensorType) REFERENCES t_SensorType(CodSensorType),
  FOREIGN KEY (CodBoard)      REFERENCES t_Board(CodBoard)
)
COMMENT 'Sensori'
;

CREATE TABLE t_CommandSignal (
  Topic         CHAR(100),
  CodBoard      CHAR(25),
  CommandSignal CHAR(3)  NOT NULL 
    COMMENT 'Command o Signal'
    CHECK (CommandSignal IN ('CMD', 'cmd', 'SIG', 'sig')),
  Payload       CHAR(100) NOT NULL
    COMMENT 'Payload specifico',
  Descrizione   CHAR(200),
  PRIMARY KEY (Topic, CodBoard, CommandSignal, Payload),
  FOREIGN KEY (CodBoard) REFERENCES t_Board(CodBoard)
)
COMMENT 'Comandi ricevibili e segnali inviati'
;


CREATE TABLE t_SensorValue (
  ReadTime    TIMESTAMP,
  SensorTopic CHAR(100),
  DataValType CHAR (3)
    COMMENT 'Numeric o Text'
    CHECK (DataValType IN ('TXT','txt','NUM', 'num')),
  NumVal      DEC(13,5) COMMENT 'only for numeric values', 
  TextVal     CHAR(50)  COMMENT 'only for text values',
  PRIMARY KEY (ReadTime, SensorTopic),
  FOREIGN KEY (SensorTopic) REFERENCES t_Sensor(Topic)
)
COMMENT 'Readings'
;


CREATE TABLE t_BoardSignal (
  ReadTime    TIMESTAMP,
  SignalTopic CHAR(100),
  DataValType CHAR (3)
    COMMENT 'Numeric o Text'
    CHECK (DataValType IN ('TXT','txt','NUM', 'num')),
  NumVal      DEC(13,5) COMMENT 'only for numeric values', 
  TextVal     CHAR(50)  COMMENT 'only for text values',
  PRIMARY KEY (ReadTime, SignalTopic)
)
COMMENT 'Segnali ricevuti. Impossibile creare una FK perche servirebbero troppe info'
;


INSERT INTO t_SensorType(CodSensorType, UnitaMisura, Simbolo, Descrizione)
VALUES
('TEMPERAT', 'Celsius', '°C', 'Sensore di temperatura'),
('ATMPRESS', 'Hectopascal', 'hPa', 'Sensore di pressione atmosferica'),
('HUMID', 'Relative Humidity', 'RH%', 'Sensore di umidità relativa'),
('LIGHT', 'Luminous flux', 'Lux', 'Sensore di illuminazione'),
('VOLTAGE', 'Electric Tension', 'V', 'Sensore di tensione'),
('ALTITUDE', 'Sea Level Altitude', 'm', 'Sensore altezza sul mare')
; 

INSERT INTO t_BoardType(TypBoard, Descrizione)
VALUES
('RASPI2B', 'Raspberry PI 2 B'),
('RASPI3B', 'Raspberry PI 3 B'),
('RASPI3B+', 'Raspberry PI 3 B+'),
('RASPI4B1G', 'Raspberry PI 4 B 1G'),
('RASPI4B2G', 'Raspberry PI 4 B 2G'),
('RASPI4B4G', 'Raspberry PI 4 B 4G'),
('ARD1R3', 'Arduino UNO R3'),
('WEMD1R1', 'Wemos D1 R1'),
('WEMD1R2', 'Wemos D1 R2'),
('WEMD1MIN', 'Wemos D1 Mini')
;

INSERT INTO t_Broker(CodMQTTBroker, IpHost, PlainPort, SSLPort, Descrizione)
VALUES
('SMALD1', 'mqtt.myhost.it', 1883, 8883, 'mqtt broker')
;

INSERT INTO t_Board(CodBoard, TypBoard, Descrizione, CodMQTTBroker, MAC_Addr, IPv4)
VALUES
('smaldinoHomeTerrace', 'WEMD1R1', 'Monitoraggio ambientale terrazzo',
 'SMALD1','84:F3:EB:B7:4F:BF', '172.30.2.212'),
('smaldinoHomeBoiler' , 'WEMD1R1', 'Monitoraggio temperature I/O caldaia',
 'SMALD1',NULL,NULL)
;


INSERT INTO t_CommandSignal(Topic, CodBoard, CommandSignal, Descrizione, Payload)
VALUES
('announcement/clientid', 'smaldinoHomeTerrace', 'SIG',
 'Annuncio al momento dell avvio', 'Hello, here smaldinoHomeTerrace'),
('announcement/clientid', 'smaldinoHomeBoiler', 'SIG',
 'Annuncio al momento dell avvio', 'Hello, here smaldinoHomeBoiler'),
('it/smaldino/home/terrace/wemosd1/out/reading', 'smaldinoHomeTerrace', 'SIG',
 'Feedback di avvio della sequenza di lettura e/o ricezione del comando di lettura ',
 'READINGON'),
('it/smaldino/home/terrace/wemosd1/out/reading', 'smaldinoHomeTerrace', 'SIG',
 'Feedback di fine della sequenza di lettura', 'READINGOFF'),
('it/smaldino/home/terrace/wemosd1/cmds', 'smaldinoHomeTerrace', 'CMD',
 'Comandi avvio della sequenza di lettura', 'READNOW'),
('it/smaldino/home/boiler/wemosd1/out/reading', 'smaldinoHomeBoiler', 'SIG',
 'Feedback di avvio della sequenza di lettura e/o ricezione del comando di lettura ',
 'READINGON'),
('it/smaldino/home/boiler/wemosd1/out/reading', 'smaldinoHomeBoiler', 'SIG',
 'Feedback di fine della sequenza di lettura', 'READINGOFF'),
('it/smaldino/home/boiler/wemosd1/cmds', 'smaldinoHomeBoiler', 'CMD',
 'Comandi avvio della sequenza di lettura', 'READNOW')
;


INSERT INTO t_Sensor(Topic, CodBoard, CodSensorType, ExtInter, Descrizione)
VALUES
('it/smaldino/home/boiler/wemosd1/out/tempdallas1', 'smaldinoHomeBoiler',
 'TEMPERAT', 'EXT', 'Sensore temperatura mandata'),
('it/smaldino/home/boiler/wemosd1/out/tempdallas2', 'smaldinoHomeBoiler',
 'TEMPERAT', 'EXT', 'Sensore temperatura ritorno'),
('it/smaldino/home/terrace/wemosd1/out/sens/light', 'smaldinoHomeTerrace',
 'LIGHT', 'EXT', 'Sensore Illuminazione'),
('it/smaldino/home/terrace/wemosd1/out/sens/humbme', 'smaldinoHomeTerrace',
 'HUMID', 'EXT', 'Sensore umidità BME280'),
('it/smaldino/home/terrace/wemosd1/out/sens/pressbme', 'smaldinoHomeTerrace',
 'ATMPRESS', 'EXT', 'Sensore pressione atmosferica BME280'),
('it/smaldino/home/terrace/wemosd1/out/sens/altitbme', 'smaldinoHomeTerrace',
 'ALTITUDE', 'EXT',
 'Sensore altitudine sul mare BME280, calcolata da pressione a 0 metri 1013,24 hPa'),
('it/smaldino/home/terrace/wemosd1/out/sens/bat', 'smaldinoHomeTerrace',
 'VOLTAGE', 'EXT', 'Sensore Tensione Batteria'),
('it/smaldino/home/terrace/wemosd1/out/sens/tempdallas', 'smaldinoHomeTerrace',
 'TEMPERAT', 'EXT', 'Sensore Temperatura Dallas'),
('it/smaldino/home/terrace/wemosd1/out/sens/tempbme', 'smaldinoHomeTerrace',
 'TEMPERAT', 'EXT', 'Sensore Temperatura BME280')
;
