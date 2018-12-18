<span id="LuftdatenInfo"></span>
# LuftdatenInfo
  LuftdatenInfo ist das FHEM-Modul um Feinstaub-, Temperatur- und Luftfeuchtichkeitswerte von den DIY-Feinstaub-Sensoren von [Luftdaten.info](Luftdaten.info) auszulesen.  
  Dabei können die Werte direkt vom Server oder auch lokal abgefragt werden.  
  Bei einer lokalen Abfrage werden durch eine [alternative Firmware](forum.fhem.de/index.php/topic,73879) noch weitere Sensoren unterstützt.  

### Vorraussetzungen
  Das Perl-Modul "JSON" wird benötigt.  
  Unter Debian (basierten) System, kann dies mittels  
  `apt-get install libjson-perl`  
  installiert werden.

<span id="LuftdatenInfodefine"></span>
## Define
  Abfrage von Luftdaten.info:  
  `define <name> LuftdatenInfo remote <SENSORID1> [<SENSORID2> ..]`  
  Lokale Abfrage:  
  `define <name> LuftdatenInfo local <IP>`  
  Umleiten von Readings:  
  `define <name> LuftdatenInfo slave <master-name> <sensor1 sensor2 ...>`

  Für eine Abfrage der Daten vom Server müssem alle betroffenenen SensorIDs angegeben werden. Die IDs vom SDS01 stehen rechts auf der Seite [maps.Luftdaten.info](maps.Luftdaten.info). Die DHT22 SensorID entspricht normalerweise der SDS011 SensorID + 1.  
  Bei einer Abfrage werden die die Positionsangaben verglichen und bei einer Abweichung eine Meldung ins Log geschrieben.  

  Für eine lokale Abfrage der Daten muss die IP Addresse oder der Hostname angegeben werden.

  Werden mehrere ähnliche Sensoren lokal betrieben lassen sich die doppelten Werte (z.B. temperature) auf ein slave Gerät umleiten.

<span id="LuftdatenInfoset"></span>
## Set
  - `statusRequest`  
    Startet eine Abfrage der Daten.

<span id="LuftdatenInfoget"></span>
## Get
  - `sensors`  
    Listet alle konfigurierten Sensoren auf.

<span id="LuftdatenInforeadings"></span>
## Readings
  - `airQuality`  
    1 =\> gut  
    2 =\> mittelmäßig  
    3 =\> ungesund für empfindliche Menschen  
    4 =\> ungesund  
    5 =\> sehr ungesund  
    6 =\> katastrophal  
  - `altitude`  
    Höhe über NN
  - `humidity`  
    Relative Luftfeuchtgkeit in %
  - `illuminanceFull`  
    Helligkeit des vollen Bereich in lux
  - `illuminanceIR`  
    Helligkeit des IR Bereich in lux
  - `illuminanceUV`  
    Helligkeit des UV Bereich in lux
  - `illuminanceVisible`  
    Helligkeit des sichtbaren Bereich in lux
  - `latitude`  
    Längengrad
  - `location`  
    Standort als "Postleitzahl Ort"  
    Nur bei Remote-Abfrage verfügbar.
  - `longitude`  
    Breitengrad
  - `PM1`  
    Menge der Partikel mit einem Durchmesser von weniger als 1 µm in µg/m³
  - `PM2.5`  
    Menge der Partikel mit einem Durchmesser von weniger als 2.5 µm in µg/m³
  - `PM10`  
    Menge der Partikel mit einem Durchmesser von weniger als 10 µm in µg/m³
  - `pressure`  
    Luftdruck in hPa
  - `pressureNN`  
    Luftdruck für Normalhöhennull (NHN) in hPa.  
    Wird bei aktivem Luftdruck- und Temperatursensor berechnet, sofern sich der Sensor nicht auf Normalhöhennull (NHN) befindet. Hierzu ist die Höhe, kann über Kartendienste oder SmartPhone ermittelt werden, auf der Konfigurationsseite anzugeben.
  - `signal`  
    WLAN Signalstärke in dBm  
    Nur bei local Abfrage verfügbar.
  - `temperature`  
    Temperatur in °C
  - `UVIntensity`  
    UV-Intensität in W
  - `UVRisk`  
    UV-Risiko von 1 bis 5

<span id="LuftdatenInfoattr"></span>
## Attribute
  - `disable 1`  
    Es werden keine Abfragen mehr gestartet.
  - [`disabledForIntervals HH:MM-HH:MM HH:MM-HH-MM ...`](#disabledForIntervals)
  - `interval <seconds>`  
    Intervall in Sekunden in dem Abfragen durchgeführt werden.  
    Der Vorgabe- und Mindestwert beträgt 300 Sekunden.
  - `rawReading 1`  
    Als Readingsnamen werden die Bezeichnungen verwendet, die in der Firmware angegeben sind. Dies kann sinnvoll sein, wenn neue Sensoren an den NodeMCU angeschlossen werden für die noch kein Mapping vorhanden ist.
  - `timeout <seconds>`  
    Timeout in Sekunden für die Abfragen.
    Der Vorgabe- und Mindestwert beträgt 5 Sekunden.
