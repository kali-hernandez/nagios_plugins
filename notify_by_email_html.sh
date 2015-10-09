#!/bin/bash

##
## By kali
## Build html notification to be piped to mail command
##
##

## General variables

IMG_WIDTH=500
IMG_HEIGHT=200

NAGIOS_BASEURL="https://YOUR_NAGIOS_BASEURL/nagios"
GRAPHITE_BASEURL="https://YOUR_GRAPHITE_BASEURL/render/?width=${IMG_WIDTH}&height=${IMG_HEIGHT}&target="
CURL_OPTIONS_GRAPHITE="-s -u GRAPHITE_HTTP_USER:GRAPHITE_HTTP_PASSWORD --compress"
CURL_OPTIONS_NAGIOS="-k -s -u YOUR_NAGIOS_HTTP_USER:YOUR_NAGIOS_HTTP_PASSWORD"

declare -A COLORS_NOTIFICATION
COLORS_NOTIFICATION[OK]='#88d066'
COLORS_NOTIFICATION[WARNING]='#ffff00'
COLORS_NOTIFICATION[CRITICAL]='#f88888'
COLORS_NOTIFICATION[UNKNOWN]='#ffbb55'
COLORS_NOTIFICATION[UP]='#88d066'
COLORS_NOTIFICATION[DOWN]='#f88888'

declare -a COLORS_TABLE
COLORS_TABLE[0]='#f4f4f4'
COLORS_TABLE[1]='#e7e7e7'

## Get parameters

ARGS=$(getopt -o m:t: -l "mail:,type:" -n $0 -- "$@");
eval set -- "$ARGS";
while true; do
  case "$1" in
	-m|--mail)
	  shift;
	  if [ -n "$1" ]; then
		NAGIOS_CONTACTEMAIL="$1";
		shift;
	  fi
	;;
	-t|--type)
	  shift;
	  case ${1,,} in
		host|h)
		  NOTIFICATION_TYPE="HOST";
		  shift;
		;;
	  esac
	;;
	--)
	  shift;
	  break;
	;;
	*)
	  shift;
	;;
  esac
done
EMAIL_TARGET=${1:-$NAGIOS_CONTACTEMAIL}
NOTIFICATION_TYPE=${NOTIFICATION_TYPE:-"SERVICE"}

## Build message

# header

MESSAGE_BODY="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n
	<html><head><title></title></head>\n
	<body style=\"font-family: verdana\">\n
	<br />\n "

if [ $NOTIFICATION_TYPE == "SERVICE" ] ; then
	MESSAGE_BODY+="<span style=\"background-color: ${COLORS_NOTIFICATION[$NAGIOS_SERVICESTATE]}; padding: 1px 5px; border: 1px solid black;\">${NAGIOS_SERVICESTATE}</span> -\n
		<strong>${NAGIOS_HOSTNAME} ${NAGIOS_SERVICEDESC}</strong>\n "
else
echo debug $NAGIOS_HOSTSTATE and ${COLORS_NOTIFICATION[$NAGIOS_HOSTSTATE]}
	MESSAGE_BODY+="<span style=\"background-color: ${COLORS_NOTIFICATION[$NAGIOS_HOSTSTATE]}; padding: 1px 5px; border: 1px solid black;\">${NAGIOS_HOSTSTATE}</span> -\n
		<strong>${NAGIOS_HOSTNAME}</strong>\n "
fi

MESSAGE_BODY+="<br />\n
		<br />\n "

# include comment

if [ -n "$NAGIOS_NOTIFICATIONAUTHOR" -a -n "$NAGIOS_NOTIFICATIONCOMMENT" ] ; then
	MESSAGE_BODY+="<strong>"
	if [ "$NAGIOS_NOTIFICATIONTYPE" == 'ACKNOWLEDGEMENT' ] ; then
		MESSAGE_BODY+="acknowledgement "
	else
		MESSAGE_BODY+="comment "
	fi
	MESSAGE_BODY+="(${NAGIOS_NOTIFICATIONAUTHOR}) :</strong> ${NAGIOS_NOTIFICATIONCOMMENT}\n
		<br />\n
		<br />\n "
fi

# notification table

if [ $NOTIFICATION_TYPE == "SERVICE" ] ; then
	MESSAGE_BODY+="<table cellpadding=\"2px\" style=\"width: 100%; \">\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Notification Type</td><td>${NAGIOS_NOTIFICATIONTYPE}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Service</td><td>${NAGIOS_SERVICEDESC}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Host</td><td>${NAGIOS_HOSTALIAS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Address</td><td>${NAGIOS_HOSTADDRESS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>State</td><td>${NAGIOS_SERVICESTATE}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Date/Time</td><td>${NAGIOS_LONGDATETIME}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Duration</td><td>${NAGIOS_SERVICEDURATION}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Notification number</td><td>${NAGIOS_SERVICENOTIFICATIONNUMBER}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Check command</td><td><pre style=\"font-size: 9pt\">${NAGIOS_SERVICECHECKCOMMAND}</pre></td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Check output:</td><td><pre style=\"font-size: 9pt\">${NAGIOS_SERVICEOUTPUT}</pre></td> </tr>\n
	</table>\n
	<br />\n "
else
	MESSAGE_BODY+="<table cellpadding=\"2px\" style=\"width: 100%; \">\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Notification Type</td><td>${NAGIOS_NOTIFICATIONTYPE}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Host</td><td>${NAGIOS_HOSTALIAS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Address</td><td>${NAGIOS_HOSTADDRESS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>State</td><td>${NAGIOS_HOSTSTATE}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Date/Time</td><td>${NAGIOS_LONGDATETIME}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Duration</td><td>${NAGIOS_HOSTDURATION}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Notification number</td><td>${NAGIOS_HOSTNOTIFICATIONNUMBER}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Check output:</td><td><pre style=\"font-size: 9pt\">${NAGIOS_HOSTOUTPUT}</pre></td> </tr>\n
	</table>\n
	<br />\n "
fi

# include graph

if [ $NOTIFICATION_TYPE == "SERVICE" ] ; then
	if [[ $NAGIOS_SERVICECHECKCOMMAND == check_graphite_metric* ]] ; then
		# if alert comes from a graphite-monitored service, insert the graph and links
		GRAPHITE_METRIC=`sed -r "s/^.*-m '(.*)'.*/\1/" <<< ${NAGIOS_SERVICECHECKCOMMAND} | sed "s/%HOST%/$NAGIOS_HOSTNAME/g"`
		GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_GRAPHITE} "${GRAPHITE_BASEURL}${GRAPHITE_METRIC}&from=-6hours&preventCache="`date +"%s"` | /usr/bin/base64 -w0)
		GRAPH_PLAIN=$(echo $GRAPH_BASE64 | /usr/bin/base64 -d -i | strings | head -1)
		if [ "${GRAPH_PLAIN:0:1}" == "<" ] || [ "${GRAPH_PLAIN:0:1}" == "{" ] ; then
			# graphite returned an error, include it here
			MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">\n
				Graphite returned the following error:<br />\n
				${GRAPH_PLAIN}<br />\n
				</div><br />\n "
		else
			# from - to format on graphite: "HH:MM_YYYYMMDD"
			GDATE_NOW=`date +%H:%M_%Y%m%d -ud 'now'`
			GDATE_6H_AGO=`date +%H:%M_%Y%m%d -ud '6 hours ago'`
			BIG_SIZE='&width=900&height=500'
			MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">\n 
				Have a look at the graph for the service in the last 6 hours:<br />\n 
				<!-- curl ${CURL_OPTIONS_GRAPHITE} \"${GRAPHITE_BASEURL}${GRAPHITE_METRIC}&from=-6hours\" -->\n 
				<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=${GDATE_6H_AGO}&until=${GDATE_NOW}'>\n
				<img src=\"data:image/png; base64,${GRAPH_BASE64}\" \n
					width=\"${IMG_WIDTH}\" height=\"${IMG_HEIGHT}\"></a>\n
				<br />\n 
				Click the image or <a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=${GDATE_6H_AGO}&until=${GDATE_NOW}'>this link</a> to see the graph for the service at the time of this alert.
				<br />\n 
				<br />\n 
				Check service graphs for the last: <br />\n 
				<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1hour'>1 hour</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2hours'>2 hours</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3hours'>3 hours</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4hours'>4 hours</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-5hours'>5 hours</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-6hours'>6 hours</a> \n
				<br />\n 
				<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1day'>1 day</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2days'>2 days</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3days'>3 days</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4days'>4 days</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-5days'>5 days</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-6days'>6 days</a> \n
				<br />\n 
				<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1week'>1 week</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2weeks'>2 weeks</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3weeks'>3 weeks</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4weeks'>4 weeks</a> \n
				<br />\n 
				<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1month'>1 month</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2month'>2 months</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3month'>3 months</a> \n
				<br />\n 
				<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1year'>1 year</a> | \n
					<a href='${GRAPHITE_BASEURL}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2year'>2 years</a> \n 
				<br />\n 
				</div><br />\n "
		fi
	else
		# else insert the service trend from nagios
		GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_NAGIOS} "${NAGIOS_BASEURL}/cgi-bin/trends.cgi?createimage&host=${NAGIOS_HOSTNAME}&service=${NAGIOS_SERVICEDESC}" | /usr/bin/base64 -w0)
		MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">\n
			Have a look at the state history for the service:<br />\n
			<!-- curl ${CURL_OPTIONS_NAGIOS} \"${NAGIOS_BASEURL}/cgi-bin/trends.cgi?createimage&host=${NAGIOS_HOSTNAME}&service=${NAGIOS_SERVICEDESC}\" -->\n
			<img src=\"data:image/png; base64,${GRAPH_BASE64}\">\n
			<br />\n
			</div><br />\n "
	fi

else
	GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_NAGIOS} "${NAGIOS_BASEURL}/cgi-bin/trends.cgi?createimage&host=${NAGIOS_HOSTNAME}" | /usr/bin/base64 -w0)
	MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">\n
		Have a look at the state history for the host:<br />\n
		<!-- curl ${CURL_OPTIONS_NAGIOS} \"${NAGIOS_BASEURL}/cgi-bin/trends.cgi?createimage&host=${NAGIOS_HOSTNAME}\" -->\n
		<img src=\"data:image/png; base64,${GRAPH_BASE64}\">\n
		<br />\n
		</div><br />\n "
fi

# include useful links

MESSAGE_BODY+="<div style=\"font-size: 9pt; font-family: monospace;\">\n
	<ul>\n "

if [ $NOTIFICATION_TYPE == "SERVICE" ] ; then
	MESSAGE_BODY+="<li><a href=\"${NAGIOS_BASEURL}/cgi-bin/extinfo.cgi?type=2&host=${NAGIOS_HOSTNAME}&service=${NAGIOS_SERVICEDESC}\">Extended Service Info Page</a> - nagios extended info for service ${NAGIOS_SERVICEDESC} on ${NAGIOS_HOSTNAME}</li>\n
	<li><a href=\"${NAGIOS_BASEURL}/cgi-bin/cmd.cgi?cmd_typ=34&host=${NAGIOS_HOSTNAME}&service=${NAGIOS_SERVICEDESC}\">Acknowledge Alert</a> - acknowledge this service alert</li>\n
	<li><a href=\"${NAGIOS_BASEURL}/cgi-bin/status.cgi?host=all&sorttype=2&sortoption=3\">Alert Status Page</a> - all nagios alerts panel</li>\n "
else
	MESSAGE_BODY+="<li><a href=\"${NAGIOS_BASEURL}/cgi-bin/extinfo.cgi?type=1&host=${NAGIOS_HOSTNAME}\">Extended Host Info Page</a> - nagios extended info for host ${NAGIOS_HOSTNAME}</li>\n
	<li><a href=\"${NAGIOS_BASEURL}/cgi-bin/cmd.cgi?cmd_typ=33&host=${NAGIOS_HOSTNAME}\">Acknowledge Alert</a> - acknowledge this host alert</li>\n
	<li><a href=\"${NAGIOS_BASEURL}/cgi-bin/status.cgi?host=all&sorttype=2&sortoption=3\">Alert Status Page</a> - all nagios alerts panel</li>\n "
fi

MESSAGE_BODY+="	</ul>\n
	${NAGIOS_LONGDATETIME}\n
	</div>
	</body>
	</html>"

if [ $NOTIFICATION_TYPE == "SERVICE" ] ; then
	MESSAGE_SUBJECT="** SERVICE ALERT: ${NAGIOS_HOSTNAME}/${NAGIOS_SERVICEDESC} ${NAGIOS_NOTIFICATIONTYPE} - ${NAGIOS_SERVICESTATE} **"
else
	MESSAGE_SUBJECT="** HOST ALERT: ${NAGIOS_HOSTNAME} ${NAGIOS_NOTIFICATIONTYPE} - ${NAGIOS_HOSTSTATE} **"
fi

echo -e $MESSAGE_BODY | /usr/bin/mail.mailutils -a "Content-Type: text/html" -s "${MESSAGE_SUBJECT}" ${EMAIL_TARGET}
