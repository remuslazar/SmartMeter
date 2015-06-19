Hacking the EnBW intelligent power meter
========================================

UPnP SSDP
---------

The SmartMeter is using the SSDP
([Service Discovery Protocol](https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol))
to advertise its presence on the local network:

```
NOTIFY * HTTP/1.1
CACHE-CONTROL: max-age=120
HOST: 239.255.255.250:1900
LOCATION: http://192.168.37.20:80/wikidesc.xml
NT: urn:schemas-upnp-org:device:InternetGatewayDevice:1
NTS: ssdp:alive
SERVER: Linux/2.6.28.10 UPnP/1.0 AppliedInformatics_UPnP/1.0
USN: uuid:6472e454-dc38-11e3-95c4-000000000000::urn:schemas-upnp-org:device:InternetGatewayDevice:1
```

In the example above the smartmeter having the local ip address 192.168.37.20.

XML REST API
------------

The current wattage and also historical data can be fetched using a XML based
REST API:

```
GET http://192.168.37.20/InstantView/request/getPowerProfile.html?ts=0&n=1&param=Wirkleistung&format=1
```

Will respond with:

```
<?xml version="1.0" encoding="UTF-8"?>
<values
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="/InstantView/request/powerProfile.xsd">
    <header>
        <name>Wirkleistung</name>
        <obis>1.25.0</obis>
        <startts>150615224320s</startts>
        <endts>150615224320s</endts>
        <samplerate>1</samplerate>
        <no>1</no>
        <error>false</error>
    </header>
    <v>994</v>
</values>
```

Fetching the XSD schema will uncover more details about the API:

### header

Element name | Description | Example
-------------|-------------|---------------------
name         | currently only "Wirkleistung" available | Wirkleistung
obi          | Some Version info | 1.25.0
startts      | Start Timestamp pattern \d{12}[nws] | 150615224320s
endts        | End Timestamp pattern \d{12}[nws] | 150615224320s
samplerate   | Samplerate, pattern \d+ | 1
no           | Record count | 10
error        | true/false | false

### Error state

When requesting data for a timestamp which is out of range, an error will be
reported:

```
<?xml version="1.0" encoding="UTF-8"?>
<values
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="/InstantView/request/powerProfile.xsd">
    <header>
        <name>Wirkleistung</name>
        <obis>1.25.0</obis>
        <startts>150615225543s</startts>
        <endts>150615225543s</endts>
        <samplerate>1</samplerate>
        <no>0</no>
        <error>true</error>
    </header>
    <error>
        <id>8100</id>
        <text>Value ts out of range</text>
    </error>
</values>
```

Timings
-------

```
$ time curl 'http://192.168.37.20/InstantView/request/getPowerProfile.html?ts=150615111958&n=100'
>/dev/null

real	0m2.943s
```

### Timestamps

The Timestamps are *not* UNIX Timestamps:

```
$ curl -s  'http://192.168.37.20/InstantView/request/getPowerProfile.html?ts=0&n=1&param=Wirkleistung&format=1' | grep startts | tr -cd '[0-9]' && echo && python -c 'import time; print int(time.time())'
150615230959
1434402630
```

They are using the following DateTime Format: `YYMMDDHHMMSS`:

```
$ curl -s  'http://192.168.37.20/InstantView/request/getPowerProfile.html?ts=0&n=1&param=Wirkleistung&format=1' | grep startts | tr -cd '[0-9]' && echo && date +%y%m%d%H%M%S
150615231140
150615231212
```

The RTC of the smart-meter is not very accurate, in the above example the drift
being -32 seconds.

### Historical Values

The device can hold the samples for the past 12 hours (total of 12 * 3600 =
43.200 samples.

To fetch historical values, just do a regular API call using the start
timestamp:

```
GET /InstantView/request/getPowerProfile.html?ts=150615111958&n=1
```

You can fetch multiple historical values at once using n=100 e.g. (100 being the
max. value, btw.). To fetch the whole buffer, you need 432 http requests and
this process will take about 432 * 3 seconds = 21,6 minutes.


References
==========

XSD Schema
----------


```
<?xml version="1.0" encoding="UTF-8"?>
<xs:schema
    xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified" attributeFormDefault="unqualified">
    <xs:annotation>
        <xs:documentation>
    		Antwort des ComModuls auf getPowerProfile-Requests
    	</xs:documentation>
    </xs:annotation>
    <xs:element name="values" type="t_values"/>
    <xs:complexType name="t_values">
        <xs:sequence>
            <xs:element name="header" type="t_header"/>
            <xs:choice>
                <xs:element name="v" type="xs:string" nillable="true" minOccurs="0" maxOccurs="unbounded"/>
                <xs:element name="error" type="t_error" minOccurs="0"/>
            </xs:choice>
        </xs:sequence>
    </xs:complexType>
    <xs:complexType name="t_header">
        <xs:sequence>
            <xs:element name="name">
                <xs:simpleType>
                    <xs:restriction base="xs:string">
                        <xs:enumeration value="Wirkleistung"/>
                        <xs:enumeration value="ERR"/>
                    </xs:restriction>
                </xs:simpleType>
            </xs:element>
            <xs:element name="obis">
                <xs:simpleType>
                    <xs:restriction base="xs:string">
                        <xs:enumeration value="1-1:16.7.0"/>
                        <xs:enumeration value="ERR"/>
                    </xs:restriction>
                </xs:simpleType>
            </xs:element>
            <xs:element name="startts">
                <xs:simpleType>
                    <xs:restriction base="xs:string">
                        <xs:pattern value="[0-9]{12}[nws]?"/>
                        <xs:pattern value="ERR"/>
                    </xs:restriction>
                </xs:simpleType>
            </xs:element>
            <xs:element name="endts">
                <xs:simpleType>
                    <xs:restriction base="xs:string">
                        <xs:pattern value="[0-9]{12}[nws]?"/>
                        <xs:pattern value="ERR"/>
                    </xs:restriction>
                </xs:simpleType>
            </xs:element>
            <xs:element name="samplerate">
                <xs:simpleType>
                    <xs:restriction base="xs:string">
                        <xs:pattern value="[1-9]{1}[0-9]*"/>
                        <xs:pattern value="ERR"/>
                    </xs:restriction>
                </xs:simpleType>
            </xs:element>
            <xs:element name="no">
                <xs:simpleType>
                    <xs:restriction base="xs:string">
                        <xs:pattern value="[0-9]+"/>
                        <xs:pattern value="ERR"/>
                    </xs:restriction>
                </xs:simpleType>
            </xs:element>
            <xs:element name="error" type="xs:boolean"/>
        </xs:sequence>
    </xs:complexType>
    <xs:complexType name="t_error">
        <xs:sequence>
            <xs:element name="id">
                <xs:simpleType>
                    <xs:restriction base="xs:nonNegativeInteger">
                        <xs:minInclusive value="0"/>
                        <xs:maxInclusive value="9999"/>
                    </xs:restriction>
                </xs:simpleType>
            </xs:element>
            <xs:element name="text" type="xs:string"/>
        </xs:sequence>
    </xs:complexType>
</xs:schema>
```
