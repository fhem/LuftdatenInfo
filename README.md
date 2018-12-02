<span id="LuftdatenInfo"></span>
# LuftdatenInfo
  LuftdatenInfo is the FHEM module to read particulate matter, temperature and humidity values ​​from the self-assembly particulate matter sensors from [Luftdaten.info](Luftdaten.info).  
  The values ​​can be queried directly from the server or locally.
  There is an [alternative Firmware](forum.fhem.de/index.php/topic,73879) to support more sensors.

### Prerequisites
  The Perl module "JSON" is required.
  Under Debian (based) system, this can be installed using  
  `apt-get install libjson-perl`.

<span id="LuftdatenInfodefine"></span>
## Define
  Query of Luftdaten.info:  
  `define <name> air data info remote <SENSORID1> [<SENSORID2> ..]`  
  Local query:  
  `define <name> Air DataInfo local <IP>`  
  Redirecting readings:  
  `define <name> LuftdatenInfo slave <master-name> <sensor1 sensor2 ...>`

  To query the data from the server, all affected SensorIDs must be specified. The IDs of the SDS01 are on the right side of the page [maps.Luftdaten.info](maps.Luftdaten.info). The DHT22 SensorID normally corresponds to the SDS011 SensorID + 1.  
  While parsing the data the location values from all sensors will be compared and a message will be written into the log if they differ.  

  For a local query of the data, the IP address or hostname must be specified.

  If several similar sensors are operated locally, the double values (e.g. temperature) can be redirected to a slave device.

<span id="LuftdatenInfoset"></span>
## Set
  - `statusRequest`  
    Starts a status request.

<span id="LuftdatenInfoget"></span>
## Get
  - `sensors`  
    Lists all senors.

<span id="LuftdatenInforeadings"></span>
## Readings
  - `airQuality`  
    1 =\> good  
    2 =\> moderate  
    3 =\> unhealthy for sensitive groups  
    4 =\> unhealthy  
    5 =\> very unhealthy  
    6 =\> hazardous  
  - `altitude`  
  - `humidity`  
    Relative humidity in %
  - `illuminanceFull`  
    Illuminace of the full spectrum in lux
  - `illuminanceIR`  
    Iilluminace of the IR spectrum in lux
  - `illuminanceUV`  
    Iilluminace of the UV spectrum in lux
  - `illuminanceVisible`  
    Iilluminace of the visible spectrum in lux
  - `latitude`  
  - `location`  
    location as "postcode city"  
    Only available with remote query.
  - `longitude`  
  - `PM1`  
    Quantity of particles with a diameter of less than 1 μm in μg/m³
  - `PM2.5`  
    Quantity of particles with a diameter of less than 2.5 μm in μg/m³
  - `PM10`  
    Quantity of particles with a diameter of less than 10 μm in μg/m³
  - `pressure`  
    Pressure in hPa
  - `pressureNN`  
    Pressure at sea level in hPa.
    Is calculated if pressure and temperature sensor are active and the sensor is not at sea level.  
    The height, can be determined by maps or SmartPhone, needs to be specified at the configuration page.
  - `signal`  
    WLAN signal strength in dBm  
    Only available with local query.
  - `temperature`  
    Temperature in °C
  - `UVIntensity`  
    UV intensity in W
  - `UVRisk`  
    UV risk from 1 to 5

<span id="LuftdatenInfoattr"></span>
## Attribute
  - `disable 1`  
    No queries are started.
  - [<span class="underline">`disabledForIntervals HH:MM-HH:MM
    HH:MM-HH-MM ...`</span>](#disabledForIntervals)
  - `interval <seconds>`  
    Interval in seconds in which queries are performed.  
    The default and minimum value is 300 seconds.
  - `rawReading 1`  
    The readings names used are those specified in the firmware. This can be useful if new sensors are connected to the NodeMCU for which no mapping exists yet.
  - `timeout <seconds>`  
    Timeout in seconds for the queries.  
    The default and minimum value is 5 seconds.
