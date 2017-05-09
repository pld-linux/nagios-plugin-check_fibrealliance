#!/bin/sh

# Version 0.0.5 2013-07-09
# Ramón Román Castro <ramonromancastro@gmail.com>
# Minor changes on event, sensors check

# Version 0.0.4 2013-07-05
# Ramón Román Castro <ramonromancastro@gmail.com>
# Add event check

# Version 0.0.3 2010-08-18
# Verify that the sensors check returns data. If not, return unknown to nagios.

# Version 0.0.2 2010-05-11
# Ulric Eriksson <ulric.eriksson@dgc.se>

BASEOID=.1.3.6.1.3.94
SYSTEMOID=$BASEOID.1.6
connUnitStateOID=$SYSTEMOID.1.5
# 1 = unknown, 2 = online, 3 = diag/offline
connUnitStatusOID=$SYSTEMOID.1.6
# 3 = OK, 4 = warning, 5 = failed
connUnitProductOID=$SYSTEMOID.1.7
# e.g. "QLogic SANbox2 FC Switch"
connUnitSnOID=$SYSTEMOID.1.8
# chassis serial number
connUnitNumSensorsOID=$SYSTEMOID.1.14
# number of sensors in connUnitSensorTable
connUnitNameOID=$SYSTEMOID.1.20
# symbolic name
connUnitContactOID=$SYSTEMOID.1.23
connUnitLocationOID=$SYSTEMOID.1.24

SENSOROID=$BASEOID.1.8
connUnitSensorIndexOID=$SENSOROID.1.2
connUnitSensorNameOID=$SENSOROID.1.3
# textual id of sensor
connUnitSensorStatusOID=$SENSOROID.1.4
# 1 = unknown, 2 = other, 3 = ok, 4 = warning, 5 = failed
connUnitSensorMessageOID=$SENSOROID.1.6
# textual status message

PORTOID=$BASEOID.1.10
connUnitPortUnitIdOID=$PORTOID.1.1
connUnitPortIndexOID=$PORTOID.1.2
connUnitPortTypeOID=$PORTOID.1.3
connUnitPortStateOID=$PORTOID.1.6
# user selected state
# 1 = unknown, 2 = online, 3 = offline, 4 = bypassed, 5 = diagnostics
connUnitPortStatusOID=$PORTOID.1.7
# actual status
# 1 = unknown, 2 = unused, 3 = ready, 4 = warning, 5 = failure
# 6 = notparticipating, 7 = initializing, 8 = bypass, 9 = ols, 10 = other
# Always returns 2, so this is utterly useless
connUnitPortSpeedOID=$PORTOID.1.15
# port speed in kilobytes per second

EVENTOID=$BASEOID.1.11
connUnitEventIndexOID=$EVENTOID.1.2
connUnitREventTimeOID=$EVENTOID.1.4
connUnitEventSeverityOID=$EVENTOID.1.6
connUnitEventDescrOID=$EVENTOID.1.9
# user selected state
# unknown	(1)
# emergency	(2)
# alert		(3)
# critical	(4)
# error		(5)
# warning	(6)
# notify	(7)
# info		(8)
# debug		(9)
# mark		(10)

COMMUNITY=public
HOST=127.0.0.1
TEST=status
VERBOSE=0

verb(){
	if [ "$VERBOSE" == "1" ]; then echo "[debug] - $1"; fi
}

usage()
{
	echo "Usage: $0 -H host -C community -T events|status|sensors (-V)"
	exit 0
}


get_system()
{
        echo "$SYSTEM"|grep "^$1."|head -1|sed -e 's,^.*: ,,'
}

get_sensor()
{
        echo "$SENSOR"|grep "^$2.*$1 = "|head -1|sed -e 's,^.*: ,,'|sed 's/^[ \"]*//g'|sed 's/[ \"]*$//g'
}

get_port()
{
        echo "$PORT"|grep "^$2.*$1 = "|head -1|sed -e 's,^.*: ,,'
}

if test "$1" = -h; then
	usage
fi

while getopts "H:C:T:V" o; do
	case "$o" in
	H )
		HOST="$OPTARG"
		;;
	C )
		COMMUNITY="$OPTARG"
		;;
	T )
		TEST="$OPTARG"
		;;
	V )
		VERBOSE=1
		;;
	* )
		usage
		;;
	esac
done

TIMEOUT=10
RESULT=
STATUS=0	# OK

case "$TEST" in

events )
	TODAY=`date +%d,%m,%Y`
	RESULT=OK
	NCRIT=0
	NWARN=0
	NUNKN=0
	index=0
	verb "Get SNMP OID $connUnitEventSeverityOID"
	connUnitEventIndex=($(snmpwalk -v 1 -c $COMMUNITY -t $TIMEOUT -Ovq $HOST $connUnitEventSeverityOID))
	verb "Get SNMP OID $connUnitREventTimeOID"
	connUnitEventIndex2=($(snmpwalk -v 1 -c $COMMUNITY -t $TIMEOUT -Ovq $HOST $connUnitREventTimeOID | awk '{print $1}' | sed 's/[^,0-9]//g'))
	for i in ${connUnitEventIndex2[@]}; do
		if [ "$TODAY" == "$i" ]; then
			case "${connUnitEventIndex[$index]}" in
				1 )
					verb "Event [$i]: UNKNOWN"
					NUNKN=$((NUNKN+1))
					RESULT="UNKNOWN"
				;;
				2|3|4|5 )
					verb "Event [$i]: CRITICAL"
					NCRIT=$((NCRIT+1))
					RESULT="CRITICAL"
				;;
				6 )
					verb "Event [$i]: WARNING"
					NWARN=$((NWARN+1))
					RESULT="WARNING"
				;;
				*)
					verb "Event [$i]: OK"
					RESULT="OK"
				;;
			esac
		else
			verb "Skip event [$i]"
		fi
		let "index++"
	done
	
	if [ "$NCRIT" -gt 0 ]; then
		RESULT="CRITICAL: $NCRIT events found today|critical=$NCRIT warning=$NWARN unknown=$NUNKN"
		STATUS=2
	elif [ "$NWARN" -gt 0 ]; then
		RESULT="WARNING: $NWARN events found today|critical=$NCRIT warning=$NWARN unknown=$NUNKN"
		STATUS=1
	else
		RESULT="OK: No events found today|critical=$NCRIT warning=$NWARN unknown=$NUNKN"
		STATUS=0
	fi
	;;

sensors )
        RESULT=
        NCRIT=0
        NWARN=0
	SENSOR=`snmpwalk -v 1 -c $COMMUNITY -t $TIMEOUT -On $HOST $SENSOROID`
	connUnitSensorIndex=`echo "$SENSOR" | grep -F "$connUnitSensorIndexOID." | sed -e 's,^.*: ,,'`
	for i in $connUnitSensorIndex; do
		connUnitSensorName=`get_sensor $i $connUnitSensorNameOID`
		connUnitSensorStatus=`get_sensor $i $connUnitSensorStatusOID`
		connUnitSensorMessage=`get_sensor $i $connUnitSensorMessageOID`
		case "$connUnitSensorStatus" in
			1 )
				RESULT="$RESULT$connUnitSensorName = $connUnitSensorMessage\n"
			;;
			2 )
				NWARN=$((NWARN+1))
				RESULT="${RESULT}WARNING: $connUnitSensorName = $connUnitSensorMessage\n"
			;;
			3 )
				RESULT="$RESULT$connUnitSensorName = $connUnitSensorMessage\n"
			;;
			4 )
				NWARN=$((NWARN+1))
				RESULT="${RESULT}WARNING: $connUnitSensorName = $connUnitSensorMessage\n"

			;;
			5 )
				NCRIT=$((NCRIT+1))
				RESULT="${RESULT}CRITICAL: $connUnitSensorName = $connUnitSensorMessage\n"
			;;
			*)
				NWARN=$((NWARN+1))
				RESULT="${RESULT}WARNING: $connUnitSensorName = $connUnitSensorMessage\n"
			;;
		esac
	done
        if test -z "$RESULT"; then
                RESULT="Sensors: UNKNOWN\n$RESULT"
                STATUS=3
        elif [ "$NCRIT" -gt 0 ]; then
                RESULT="Sensors: $NCRIT sensors are in CRITICAL state\n$RESULT"
                STATUS=2
        elif [ "$NWARN" -gt 0 ]; then
                RESULT="Sensors: $NWARN sensors are in WARNING state\n$RESULT"
                STATUS=1
        else
                RESULT="Sensors: OK\n$RESULT"
                STATUS=0
        fi
        ;;
status )
	SYSTEM=`snmpwalk -v 1 -c $COMMUNITY -t $TIMEOUT -On $HOST $SYSTEMOID`
	connUnitStatus=`get_system $connUnitStatusOID`
	connUnitProduct=`get_system $connUnitProductOID`
	connUnitSn=`get_system $connUnitSnOID`
	case "$connUnitStatus" in
	3 )
		RESULT="Overall unit status: OK"
		;;
	4 )
		RESULT="Overall unit status: Warning"
		STATUS=1
		;;
	5 )
		RESULT="Overall unit status: Failed"
		STATUS=2
		;;
	* )
		RESULT="Overall unit status: Unknown"
		STATUS=3
		;;
	esac
	if test ! -z "$connUnitProduct"; then
		RESULT="$RESULT\nProduct: $connUnitProduct"
	fi
	if test ! -z "$connUnitSn"; then
		RESULT="$RESULT\nSerial number: $connUnitSn"
	fi
	;;
* )
	usage
	;;
esac

echo -e "$RESULT"
exit $STATUS
