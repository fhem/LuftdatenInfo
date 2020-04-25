# Id ##########################################################################
# $Id: 59_LuftdatenInfo.pm 17548 2018-10-16 19:33:15Z igami $

# copyright ###################################################################
#
# 59_LuftdatenInfo.pm
#
# Copyright by igami
#
# This file is part of FHEM.
#
# FHEM is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# FHEM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FHEM.  If not, see <http://www.gnu.org/licenses/>.

# packages ####################################################################
package main;
use Encode;
use strict;
use warnings;

use HttpUtils;

# initialize ##################################################################
sub LuftdatenInfo_Initialize {
    my $hash = shift;

    $hash->{DefFn}   = \&LuftdatenInfo_Define;
    $hash->{UndefFn} = \&LuftdatenInfo_Undefine;
    $hash->{SetFn}   = \&LuftdatenInfo_Set;
    $hash->{GetFn}   = \&LuftdatenInfo_Get;
    $hash->{AttrFn}  = \&LuftdatenInfo_Attr;

    $hash->{AttrList} = join q{ }, qw{
      disable:1,0
      disabledForIntervals
      interval
      rawReading:0,1
      timeout
      }, $readingFnAttributes;

    return;
}

# regular Fn ##################################################################
sub LuftdatenInfo_Define {
    my $hash = shift;
    my ( $SELF, $TYPE, $MODE, $DEF ) = split m{[\s]+}xms, shift, 4;
    my $rc = eval {
        require JSON;
        JSON->import();
        1;
    };

    return (q{Error loading JSON. Maybe this module is not installed? }
          . q{\nUnder debian (based) system it can be installed using }
          . q{"apt-get install libjson-perl} )
      if ( !$rc );

    delete( $hash->{SENSORIDS} );
    delete( $hash->{ADDRESS} );
    delete( $hash->{INTERVAL} );
    delete( $hash->{TIMEOUT} );
    delete( $hash->{MASTER} );
    delete( $hash->{SENSORS} );

    my $hadTemperature = ReadingsVal( $SELF, q{temperature}, undef ) ? 1 : 0;

    delete( $hash->{READINGS} );

    if ( $MODE eq q{remote} ) {
        return (
            qq{Usage: define <name> $TYPE $MODE <SENSORID1> [<SENSORID2> ...]})
          if ( $DEF !~ m{^[\s\d]+$}xms );

        $hash->{SENSORIDS} = $DEF;
    }
    elsif ( $MODE eq q{local} ) {
        return (qq{Usage: define <name> $TYPE $MODE <IP>})
          if ( $DEF =~ m{\s}xms );

        $hash->{ADDRESS} = $DEF;
    }
    elsif ( $MODE eq q{slave} ) {
        return (
            q{Usage: define <name> $TYPE $MODE <master-name> <reading regexps>})
          if ( $DEF !~ m{\s}xms );

        ( $hash->{MASTER}, $hash->{SENSORS} ) = split m{[\s]+}xms, $DEF, 2;

        delete( $defs{ $hash->{MASTER} }->{READINGS} )
          if ( IsDevice( $hash->{MASTER}, $TYPE ) );
    }
    else {
        if ( looks_like_number($MODE) ) {
            $hash->{SENSORIDS} = $MODE;
            $hash->{SENSORIDS} .= q{ } . ( $MODE + 1 ) if ($hadTemperature);
            $hash->{SENSORIDS} .= qq{ $DEF}
              if ( $DEF && looks_like_number($DEF) );

            $MODE = q{remote};

            $hash->{DEF} = qq{$MODE $hash->{SENSORIDS}};
        }
        elsif ( !$DEF ) {
            $hash->{ADDRESS} = $MODE;

            $MODE = q{local};

            $hash->{DEF} = qq{$MODE $hash->{ADDRESS}};
        }
        else {
            return (
qq{Usage: define <name> $TYPE remote <SENSORID1> [<SENSORID2> ...]}
                  . qq{       define <name> $TYPE local <IP>}
                  . qq{       define <name> $TYPE slave <master-name> <sensor1 sensor2 ...>}
            );
        }
    }

    $hash->{MODE} = $MODE;

    if ( $MODE ne q{slave} ) {
        my $minInterval = $hash->{MODE} eq q{local} ? 30 : 300;
        my $interval = AttrVal( $SELF, q{interval}, $minInterval );
        $interval = $minInterval if ( !looks_like_number($interval) );
        $interval = $minInterval if ( $interval < $minInterval );
        my $minTimeout = 5;
        my $timeout = AttrVal( $SELF, q{timeout}, $minTimeout );
        $timeout = $minTimeout if ( !looks_like_number($timeout) );
        $timeout = $minTimeout if ( $timeout < $minTimeout );

        $hash->{INTERVAL} = $interval;
        $hash->{TIMEOUT}  = $timeout;
    }

    readingsSingleUpdate( $hash, q{state}, q{active}, 1 );

    LuftdatenInfo_statusRequest($hash);

    return;
}

sub LuftdatenInfo_Undefine {
    my $hash = shift;

    HttpUtils_Close($hash);
    RemoveInternalTimer($hash);

    return;
}

sub LuftdatenInfo_Set {
    my $hash     = shift;
    my $TYPE     = $hash->{TYPE};
    my $SELF     = shift;
    my $argument = shift // return qq{"set $TYPE" needs at least one argument};
    my $value    = qq{@_};

    my %LuftdatenInfo_sets = ( q{statusRequest} => q{statusRequest:noArg}, );

    return ( qq{Unknown argument $argument, choose one of }
          . join( q{ }, values %LuftdatenInfo_sets ) )
      if ( !exists( $LuftdatenInfo_sets{$argument} ) );

    if ( !IsDisabled($SELF) ) {
        if ( $argument eq q{statusRequest} ) {
            LuftdatenInfo_statusRequest($hash);
        }
    }

    return;
}

sub LuftdatenInfo_Get {
    my $hash     = shift;
    my $TYPE     = $hash->{TYPE};
    my $SELF     = shift;
    my $argument = shift // return qq{"get $TYPE" needs at least one argument};
    my $value    = qq{@_};

    my %LuftdatenInfo_gets = ( q{sensors} => q{sensors:noArg}, );

    return ( qq{Unknown argument $argument, choose one of }
          . join( q{ }, values %LuftdatenInfo_gets ) )
      if ( !exists( $LuftdatenInfo_gets{$argument} ) );

    if ( $argument eq q{sensors} ) {
        return (
            join(
                q{\n},
                split(
                    q{ },
                    ReadingsVal(
                        InternalVal( $SELF, q{MASTER}, $SELF ),
                        q{.sensors},
                        q{No sensors found.}
                    )
                )
            )
        );
    }

    return;
}

sub LuftdatenInfo_Attr {
    my $cmd       = shift;
    my $SELF      = shift;
    my $hash      = $defs{$SELF};
    my $TYPE      = $hash->{TYPE};
    my $attribute = shift;
    my $value     = qq{@_};

    Log3( $SELF, 5, qq{$TYPE ($SELF) - entering LuftdatenInfo_Attr} );

    if ( $attribute eq q{disable} ) {
        if ( $value && $value == 1 ) {
            readingsSingleUpdate( $hash, q{state}, q{disabled}, 1 );
        }
        elsif ( $cmd eq q{del} || !$value ) {
            LuftdatenInfo_statusRequest($hash);

            readingsSingleUpdate( $hash, q{state}, q{active}, 1 );
        }
    }
    elsif ( $attribute eq q{interval} ) {
        my $minInterval = $hash->{CONNECTION} eq q{local} ? 30 : 300;
        my $interval = $cmd eq q{set} ? $value : $minInterval;
        $interval = $minInterval if ( !looks_like_number($interval) );
        $interval = $minInterval if ( $interval < $minInterval );

        $hash->{INTERVAL} = $interval;
    }
    elsif ( $attribute eq q{timeout} ) {
        my $minTimeout = 5;
        my $timeout = $cmd eq q{set} ? $value : $minTimeout;
        $timeout = $minTimeout if ( !looks_like_number($timeout) );
        $timeout = $minTimeout if ( $timeout < $minTimeout );

        $hash->{TIMEOUT} = $timeout;
    }

    return;
}

# HttpUtils Fn ################################################################
sub LuftdatenInfo_GetHttpResponse {
    my $hash    = shift;
    my $arg     = shift;
    my $SELF    = $hash->{NAME};
    my $TYPE    = $hash->{TYPE};
    my $MODE    = $hash->{MODE};
    my $timeout = $hash->{TIMEOUT};

    Log3( $SELF, 5,
        qq{$TYPE ($SELF) - entering LuftdatenInfo_GetHttpResponse} );

    my $param = {
        timeout  => $timeout,
        hash     => $hash,
        method   => q{GET},
        header   => q{Accept: application/json},
        callback => \&LuftdatenInfo_ParseHttpResponse,
    };
    $param->{url} = qq{http://api.luftdaten.info/v1/sensor/$arg/}
      if ( $MODE eq q{remote} );
    $param->{url} = qq{http://$arg/data.json}
      if ( $MODE eq q{local} );

    return HttpUtils_NonblockingGet($param);
}

sub LuftdatenInfo_ParseHttpResponse {
    my $param = shift;
    my $err   = shift;
    my $data  = shift;
    my $hash  = $param->{hash};
    my $SELF  = $hash->{NAME};
    my $TYPE  = $hash->{TYPE};

    Log3( $SELF, 5,
        qq{$TYPE ($SELF) - entering LuftdatenInfo_ParseHttpResponse} );

    if ( $err ne q{} ) {
        Log3( $SELF, 2, qq{$TYPE ($SELF) - error while request: $err} );

        readingsSingleUpdate( $hash, q{state}, q{error}, 1 );
    }
    elsif ( $data eq q{[]} ) {
        Log3( $SELF, 2,
            qq{$TYPE ($SELF) - error while request: no data returned} );

        readingsSingleUpdate( $hash, q{state}, q{error}, 1 );
    }
    elsif ( $data ne q{} ) {
        Log3 $SELF, 4, qq{$TYPE ($SELF) - returned data: $data};

        $data = encode( q{UTF-8}, $data );
        $data = eval { decode_json($data) };

        if ($@) {
            Log3( $SELF, 2, qq{$TYPE ($SELF) - error while request: $@} );

            readingsSingleUpdate( $hash, q{state}, q{error}, 1 );

            return;
        }

        my $MODE = $hash->{MODE};
        my $rawReading = AttrVal( $SELF, q{rawReading}, 0 );

        if ( $param->{url} =~ m{openstreetmap}xms ) {
            my $address = $data->{address};

            readingsSingleUpdate(
                $hash,
                q{location},
                qq{$address->{postcode} }
                  . ( $address->{city} ? $address->{city} : $address->{town} ),
                1
            );
        }
        elsif ( $MODE eq q{remote} ) {
            my $sensor      = @{$data}[-1];
            my $sensor_type = $sensor->{sensor}{sensor_type}{name};

            Log3 $SELF, 5, qq{$TYPE ($SELF) - parsing $sensor_type data};

            my $latitude  = $sensor->{location}{latitude};
            my $longitude = $sensor->{location}{longitude};

            if (   $latitude ne ReadingsVal( $SELF, q{latitude}, $latitude )
                || $longitude ne ReadingsVal( $SELF, q{longitude}, $longitude )
              )
            {
                Log3( $SELF, 2,
                        qq{$TYPE ($SELF) - }
                      . qq{$sensor->{sensor}{sensor_type}{name} position differs from }
                      . q{other sensor position} );

                return;
            }

            if ( !ReadingsVal( $SELF, q{location}, undef ) ) {
                $param = {
                    url => q{http://nominatim.openstreetmap.org/reverse?}
                      . qq{format=json&lat=$latitude&lon=$longitude},
                    timeout  => $hash->{TIMEOUT},
                    hash     => $hash,
                    method   => q{GET},
                    header   => q{Accept: application/json},
                    callback => \&LuftdatenInfo_ParseHttpResponse,
                };

                HttpUtils_NonblockingGet($param);
            }

            readingsBeginUpdate($hash);

            for my $sensordatavalue ( @{ $sensor->{sensordatavalues} } ) {
                $sensordatavalue->{value} =~ m{^(\S+)(\s|$)}xms;
                $sensordatavalue->{value} = $1;
                my $knownReading = 1;

                if ( $sensordatavalue->{value_type} eq q{P1} ) {
                    $sensordatavalue->{value_type} = q{PM10};
                }
                elsif ( $sensordatavalue->{value_type} eq q{P2} ) {
                    $sensordatavalue->{value_type} = q{PM2.5};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{temperature$}xms ) {
                    $sensordatavalue->{value_type} = q{temperature};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{humidity$}xms ) {
                    $sensordatavalue->{value_type} = q{humidity};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{pressure$}xms ) {
                    $sensordatavalue->{value} = (
                          $sensordatavalue->{value} > 10000
                        ? $sensordatavalue->{value} / 100
                        : $sensordatavalue->{value}
                    );
                    $sensordatavalue->{value_type} = q{pressure};
                }
                else {
                    $knownReading = 0;
                }

                readingsBulkUpdate(
                    $hash,
                    $sensordatavalue->{value_type},
                    $sensordatavalue->{value}
                ) if ( $knownReading || $rawReading );
            }

            readingsBulkUpdateIfChanged( $hash, q{latitude},  $latitude );
            readingsBulkUpdateIfChanged( $hash, q{longitude}, $longitude );
            readingsBulkUpdate( $hash, q{state}, q{active} );
            readingsEndUpdate( $hash, 1 );
        }
        elsif ( $MODE eq q{local} ) {
            my @slaves = devspec2array(qq{TYPE=$TYPE:FILTER=MASTER=$SELF});
            my @sensors;

            for my $sensordatavalue ( @{ $data->{sensordatavalues} } ) {
                push( @sensors, $sensordatavalue->{value_type} );
            }

            for my $device ( $SELF, @slaves ) {
                readingsBeginUpdate( $defs{$device} );
            }

            readingsBulkUpdateIfChanged( $hash, q{softwareVersion},
                $data->{software_version} );
            readingsBulkUpdateIfChanged( $hash, q{.sensors},
                join( q{ }, sort (@sensors) ) );

            for my $sensordatavalue ( @{ $data->{sensordatavalues} } ) {
                my $knownReading = 1;
                $sensordatavalue->{value} =~ m{^(\S+)(\s|$)}xms;
                $sensordatavalue->{value} = $1;

                my $device = (
                    devspec2array(
qq{MASTER=$SELF:FILTER=SENSORS=(.+ )?$sensordatavalue->{value_type}( .+)?}
                    )
                )[0];
                $device = IsDevice( $device, $TYPE ) ? $defs{$device} : $hash;

                if ( $sensordatavalue->{value_type} =~ m{P0$}xms ) {
                    $sensordatavalue->{value_type} = q{PM1};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{P1$}xms ) {
                    $sensordatavalue->{value_type} = q{PM10};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{P2$}xms ) {
                    $sensordatavalue->{value_type} = q{PM2.5};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_air_quality$}xms )
                {
                    $sensordatavalue->{value_type} = q{airQuality};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_height$}xms ) {
                    $sensordatavalue->{value_type} = q{altitude};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_date$}xms ) {
                    $sensordatavalue->{value_type} = q{date};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{humidity$}xms ) {
                    $sensordatavalue->{value_type} = q{humidity};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_Full$}xms ) {
                    $sensordatavalue->{value_type} = q{illuminanceFull};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_UV$}xms ) {
                    $sensordatavalue->{value_type} = q{illuminanceUV};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_IR$}xms ) {
                    $sensordatavalue->{value_type} = q{illuminanceIR};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_Visible$}xms ) {
                    $sensordatavalue->{value_type} = q{illuminanceVisible};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_lat$}xms ) {
                    $sensordatavalue->{value_type} = q{latitude};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_lon$}xms ) {
                    $sensordatavalue->{value_type} = q{longitude};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{pressure$}xms ) {
                    $sensordatavalue->{value} = (
                          $sensordatavalue->{value} > 10000
                        ? $sensordatavalue->{value} / 100
                        : $sensordatavalue->{value}
                    );
                    $sensordatavalue->{value_type} = q{pressure};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{pressure_nn$}xms ) {
                    $sensordatavalue->{value} = (
                          $sensordatavalue->{value} > 10000
                        ? $sensordatavalue->{value} / 100
                        : $sensordatavalue->{value}
                    );
                    $sensordatavalue->{value_type} = q{pressureNN};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_risk}xms ) {
                    $sensordatavalue->{value_type} = q{UVRisk};
                }
                elsif ( $sensordatavalue->{value_type} eq q{signal} ) {
                    $sensordatavalue->{value_type} = q{signal};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{temperature$}xms ) {
                    $sensordatavalue->{value_type} = q{temperature};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_watt}xms ) {
                    $sensordatavalue->{value_type} = q{UVIntensity};
                }
                elsif ( $sensordatavalue->{value_type} =~ m{_time$}xms ) {
                    $sensordatavalue->{value_type} = q{time};
                }
                else {
                    $knownReading = 0;
                }

                readingsBulkUpdate(
                    $device,
                    $sensordatavalue->{value_type},
                    $sensordatavalue->{value}
                ) if ( $knownReading || $rawReading );
            }

            for my $device ( $SELF, @slaves ) {
                readingsBulkUpdate( $defs{$device}, q{state}, q{active} );
                readingsEndUpdate( $defs{$device}, 1 );
            }
        }
    }

    return;
}

# module Fn ###################################################################
sub LuftdatenInfo_statusRequest {
    my $hash     = shift;
    my $SELF     = $hash->{NAME};
    my $TYPE     = $hash->{TYPE};
    my $MODE     = $hash->{MODE};
    my $interval = InternalVal( $SELF, q{INTERVAL}, undef );

    Log3( $SELF, 5, qq{$TYPE ($SELF) - entering LuftdatenInfo_statusRequest} );

    if ($interval) {
        RemoveInternalTimer($hash);
        InternalTimer( gettimeofday() + $interval,
            q{LuftdatenInfo_statusRequest}, $hash );
    }

    return if ( IsDisabled($SELF) );

    if ( $MODE eq q{remote} ) {
        for my $SensorID ( split m{[\s]+}xms, $hash->{SENSORIDS} ) {
            LuftdatenInfo_GetHttpResponse( $hash, $SensorID );
        }
    }
    elsif ( $MODE eq q{local} ) {
        LuftdatenInfo_GetHttpResponse( $hash, $hash->{ADDRESS} );
    }
    elsif ( $MODE eq q{slave} ) {
        if (   IsDevice( $hash->{MASTER}, $TYPE )
            && InternalVal( $hash->{MASTER}, q{MODE}, q{} ) eq q{local} )
        {
            readingsSingleUpdate( $hash, q{state}, q{active}, 1 );

            LuftdatenInfo_statusRequest( $defs{ $hash->{MASTER} } );
        }
        else {
            readingsSingleUpdate( $hash, q{state}, q{master not defined}, 1 );
        }
    }

    return;
}

1;

# commandref ##################################################################

=pod
=item summary    provides data from Luftdaten.info
=item summary_DE stellt Daten von Luftdaten.info bereit

=begin html

<p><span id="LuftdatenInfo"></span></p>
<h1 id="luftdateninfo">LuftdatenInfo</h1>
<p>LuftdatenInfo is the FHEM module to read particulate matter, temperature and humidity values ​​from the self-assembly particulate matter sensors from <a href="Luftdaten.info" class="uri">Luftdaten.info</a>.<br>
The values ​​can be queried directly from the server or locally. There is an <a href="forum.fhem.de/index.php/topic,73879">alternative Firmware</a> to support more sensors.</p>
<h3 id="prerequisites">Prerequisites</h3>
<p>The Perl module "JSON" is required.<br>
Under Debian (based) system, this can be installed using<br>
<code>apt-get install libjson-perl</code>.</p>
<p><span id="LuftdatenInfodefine"></span></p>
<h2 id="define">Define</h2>
<p>Query of Luftdaten.info:<br>
<code>define &lt;name&gt; LuftdatenInfo remote &lt;SENSORID1&gt; [&lt;SENSORID2&gt; ..]</code><br>
Local query:<br>
<code>define &lt;name&gt; LuftdatenInfo local &lt;IP&gt;</code><br>
Redirecting readings:<br>
<code>define &lt;name&gt; LuftdatenInfo slave &lt;master-name&gt; &lt;sensor1 sensor2 ...&gt;</code></p>
<p>To query the data from the server, all affected SensorIDs must be specified. The IDs of the SDS01 are on the right side of the page <a href="maps.Luftdaten.info" class="uri">maps.Luftdaten.info</a>. The DHT22 SensorID normally corresponds to the SDS011 SensorID + 1.<br>
While parsing the data the location values from all sensors will be compared and a message will be written into the log if they differ.</p>
<p>For a local query of the data, the IP address or hostname must be specified.</p>
<p>If several similar sensors are operated locally, the double values (e.g. temperature) can be redirected to a slave device.</p>
<p><span id="LuftdatenInfoset"></span></p>
<h2 id="set">Set</h2>
<ul>
  <li><code>statusRequest</code><br>
  Starts a status request.</li>
</ul>
<p><span id="LuftdatenInfoget"></span></p>
<h2 id="get">Get</h2>
<ul>
  <li><code>sensors</code><br>
  Lists all senors.</li>
</ul>
<p><span id="LuftdatenInforeadings"></span></p>
<h2 id="readings">Readings</h2>
<ul>
  <li><code>airQuality</code><br>
  1 =&gt; good<br>
  2 =&gt; moderate<br>
  3 =&gt; unhealthy for sensitive groups<br>
  4 =&gt; unhealthy<br>
  5 =&gt; very unhealthy<br>
  6 =&gt; hazardous</li>
  <li><code>altitude</code></li>
  <li><code>humidity</code><br>
  Relative humidity in %</li>
  <li><code>illuminanceFull</code><br>
  Illuminace of the full spectrum in lux</li>
  <li><code>illuminanceIR</code><br>
  Iilluminace of the IR spectrum in lux</li>
  <li><code>illuminanceUV</code><br>
  Iilluminace of the UV spectrum in lux</li>
  <li><code>illuminanceVisible</code><br>
  Iilluminace of the visible spectrum in lux</li>
  <li><code>latitude</code></li>
  <li><code>location</code><br>
  location as "postcode city"<br>
  Only available with remote query.</li>
  <li><code>longitude</code></li>
  <li><code>PM1</code><br>
  Quantity of particles with a diameter of less than 1 μm in μg/m³</li>
  <li><code>PM2.5</code><br>
  Quantity of particles with a diameter of less than 2.5 μm in μg/m³</li>
  <li><code>PM10</code><br>
  Quantity of particles with a diameter of less than 10 μm in μg/m³</li>
  <li><code>pressure</code><br>
  Pressure in hPa</li>
  <li><code>pressureNN</code><br>
  Pressure at sea level in hPa. Is calculated if pressure and temperature sensor are active and the sensor is not at sea level.<br>
  The height, can be determined by maps or SmartPhone, needs to be specified at the configuration page.</li>
  <li><code>signal</code><br>
  WLAN signal strength in dBm<br>
  Only available with local query.</li>
  <li><code>temperature</code><br>
  Temperature in °C</li>
  <li><code>UVIntensity</code><br>
  UV intensity in W</li>
  <li><code>UVRisk</code><br>
  UV risk from 1 to 5</li>
</ul>
<p><span id="LuftdatenInfoattr"></span></p>
<h2 id="attribute">Attribute</h2>
<ul>
  <li><code>disable 1</code><br>
  No queries are started.</li>
  <li>
    <a href="#disabledForIntervals"><code>disabledForIntervals HH:MM-HH:MM HH:MM-HH-MM ...</code></a>
  </li>
  <li><code>interval &lt;seconds&gt;</code><br>
  Interval in seconds in which queries are performed.<br>
  The default and minimum value is 300 seconds.</li>
  <li><code>rawReading 1</code><br>
  The readings names used are those specified in the firmware. This can be useful if new sensors are connected to the NodeMCU for which no mapping exists yet.</li>
  <li><code>timeout &lt;seconds&gt;</code><br>
  Timeout in seconds for the queries.<br>
  The default and minimum value is 5 seconds.</li>
</ul>

=end html

=begin html_DE

<p><span id="LuftdatenInfo"></span></p>
<h1 id="luftdateninfo">LuftdatenInfo</h1>
<p>LuftdatenInfo ist das FHEM Modul um Feinstaub-, Temperatur- und Luftfeuchtichkeitswerte von den selbstbau Feinstaub Sensoren von <a href="Luftdaten.info" class="uri">Luftdaten.info</a> auszulesen.<br>
Dabei können die Werte direkt vom Server oder auch lokal abgefragt werden.<br>
Bei einer lokalen Abfrage werden durch eine <a href="forum.fhem.de/index.php/topic,73879">alternative Firmware</a> noch weitere Sensoren unterstützt.</p>
<h3 id="vorraussetzungen">Vorraussetzungen</h3>
<p>Das Perl-Modul "JSON" wird benötigt.<br>
Unter Debian (basierten) System, kann dies mittels<br>
<code>apt-get install libjson-perl</code><br>
installiert werden.</p>
<p><span id="LuftdatenInfodefine"></span></p>
<h2 id="define">Define</h2>
<p>Abfrage von Luftdaten.info:<br>
<code>define &lt;name&gt; LuftdatenInfo remote &lt;SENSORID1&gt; [&lt;SENSORID2&gt; ..]</code><br>
Lokale Abfrage:<br>
<code>define &lt;name&gt; LuftdatenInfo local &lt;IP&gt;</code><br>
Umleiten von Readings:<br>
<code>define &lt;name&gt; LuftdatenInfo slave &lt;master-name&gt; &lt;sensor1 sensor2 ...&gt;</code></p>
<p>Für eine Abfrage der Daten vom Server müssem alle betroffenenen SensorIDs angegeben werden. Die IDs vom SDS01 stehen rechts auf der Seite <a href="maps.Luftdaten.info" class="uri">maps.Luftdaten.info</a>. Die DHT22 SensorID entspricht normalerweise der SDS011 SensorID + 1.<br>
Bei einer Abfrage werden die die Positionsangaben verglichen und bei einer Abweichung eine Meldung ins Log geschrieben.</p>
<p>Für eine lokale Abfrage der Daten muss die IP Addresse oder der Hostname angegeben werden.</p>
<p>Werden mehrere ähnliche Sensoren lokal betrieben lassen sich die doppelten Werte (z.B. temperature) auf ein slave Gerät umleiten.</p>
<p><span id="LuftdatenInfoset"></span></p>
<h2 id="set">Set</h2>
<ul>
  <li><code>statusRequest</code><br>
  Startet eine Abfrage der Daten.</li>
</ul>
<p><span id="LuftdatenInfoget"></span></p>
<h2 id="get">Get</h2>
<ul>
  <li><code>sensors</code><br>
  Listet alle konfigurierten Sensoren auf.</li>
</ul>
<p><span id="LuftdatenInforeadings"></span></p>
<h2 id="readings">Readings</h2>
<ul>
  <li><code>airQuality</code><br>
  1 =&gt; gut<br>
  2 =&gt; mittelmäßig<br>
  3 =&gt; ungesund für empfindliche Menschen<br>
  4 =&gt; ungesund<br>
  5 =&gt; sehr ungesund<br>
  6 =&gt; katastrophal</li>
  <li><code>altitude</code><br>
  Höhe über NN</li>
  <li><code>humidity</code><br>
  Relative Luftfeuchtgkeit in %</li>
  <li><code>illuminanceFull</code><br>
  Helligkeit des vollen Bereich in lux</li>
  <li><code>illuminanceIR</code><br>
  Helligkeit des IR Bereich in lux</li>
  <li><code>illuminanceUV</code><br>
  Helligkeit des UV Bereich in lux</li>
  <li><code>illuminanceVisible</code><br>
  Helligkeit des sichtbaren Bereich in lux</li>
  <li><code>latitude</code><br>
  Längengrad</li>
  <li><code>location</code><br>
  Standort als "Postleitzahl Ort"<br>
  Nur bei remote Abfrage verfügbar.</li>
  <li><code>longitude</code><br>
  Breitengrad</li>
  <li><code>PM1</code><br>
  Menge der Partikel mit einem Durchmesser von weniger als 1 µm in µg/m³</li>
  <li><code>PM2.5</code><br>
  Menge der Partikel mit einem Durchmesser von weniger als 2.5 µm in µg/m³</li>
  <li><code>PM10</code><br>
  Menge der Partikel mit einem Durchmesser von weniger als 10 µm in µg/m³</li>
  <li><code>pressure</code><br>
  Luftdruck in hPa</li>
  <li><code>pressureNN</code><br>
  Luftdruck für Normal Null in hPa.<br>
  Wird bei aktivem Luftdruck- und Temperatursensor berechnet, sofern sich der Sensor nicht auf Normal Null befindet. Hierzu ist die Höhe, kann über Kartendienste oder SmartPhone ermittelt werden, auf der Konfigurationsseite anzugeben.</li>
  <li><code>signal</code><br>
  WLAN Signalstärke in dBm<br>
  Nur bei local Abfrage verfügbar.</li>
  <li><code>temperature</code><br>
  Temperatur in °C</li>
  <li><code>UVIntensity</code><br>
  UV Intensität in W</li>
  <li><code>UVRisk</code><br>
  UV Risiko von 1 bis 5</li>
</ul>
<p><span id="LuftdatenInfoattr"></span></p>
<h2 id="attribute">Attribute</h2>
<ul>
  <li><code>disable 1</code><br>
  Es werden keine Abfragen mehr gestartet.</li>
  <li>
    <a href="#disabledForIntervals"><code>disabledForIntervals HH:MM-HH:MM HH:MM-HH-MM ...</code></a>
  </li>
  <li><code>interval &lt;seconds&gt;</code><br>
  Intervall in Sekunden in dem Abfragen durchgeführt werden.<br>
  Der Vorgabe- und Mindestwert beträgt 300 Sekunden.</li>
  <li><code>rawReading 1</code><br>
  Als Readingsnamen werden die Bezeichnungen verwendet, die in der Firmware angegeben sind. Dies kann sinnvoll sein, wenn neue Sensoren an den NodeMCU angeschlossen werden für die noch kein Mapping vorhanden ist.</li>
  <li><code>timeout &lt;seconds&gt;</code><br>
  Timeout in Sekunden für die Abfragen. Der Vorgabe- und Mindestwert beträgt 5 Sekunden.</li>
</ul>

=end html_DE
=cut
