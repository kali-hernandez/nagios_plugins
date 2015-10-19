##
## By kali
## Template for standard service notifications
## To be included (sourced) from send notification script
##

## Build message

# subject

MESSAGE_SUBJECT="** SERVICE ALERT: ${ICINGA_HOSTNAME}/${ICINGA_SERVICEDESC} ${ICINGA_NOTIFICATIONTYPE} - ${ICINGA_SERVICESTATE} **"

# header

MESSAGE_BODY="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n
	<html><head><title></title></head>\n
	<body style=\"font-family: verdana\">\n
	<br />\n <span style=\"background-color: ${COLORS_NOTIFICATION[$ICINGA_SERVICESTATE]}; padding: 1px 5px; border: 1px solid black;\">${ICINGA_SERVICESTATE}</span> -\n
	<strong>${ICINGA_HOSTNAME} ${ICINGA_SERVICEDESC}</strong>\n <br />\n
	<br />\n "

# include comment

if [ -n "$ICINGA_NOTIFICATIONAUTHOR" -a -n "$ICINGA_NOTIFICATIONCOMMENT" ] ; then
	MESSAGE_BODY+="<strong>"
	if [ "$ICINGA_NOTIFICATIONTYPE" == 'ACKNOWLEDGEMENT' ] ; then
		MESSAGE_BODY+="acknowledgement "
	else
		MESSAGE_BODY+="comment "
	fi
	MESSAGE_BODY+="(${ICINGA_NOTIFICATIONAUTHOR}) :</strong> ${ICINGA_NOTIFICATIONCOMMENT}\n
		<br />\n
		<br />\n "
fi

# notification table

MESSAGE_BODY+="<table cellpadding=\"2px\" style=\"width: 100%; \">\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Notification Type</td><td>${ICINGA_NOTIFICATIONTYPE}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Service</td><td>${ICINGA_SERVICEDESC}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Host</td><td>${ICINGA_HOSTALIAS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Address</td><td>${ICINGA_HOSTADDRESS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>State</td><td>${ICINGA_SERVICESTATE}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Date/Time</td><td>${ICINGA_LONGDATETIME}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Duration</td><td>${ICINGA_SERVICEDURATION}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Notification number</td><td>${ICINGA_SERVICENOTIFICATIONNUMBER}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Check command</td><td><pre style=\"font-size: 9pt\">${ICINGA_SERVICECHECKCOMMAND}</pre></td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Check output:</td><td><pre style=\"font-size: 9pt\">${ICINGA_SERVICEOUTPUT}<br />${ICINGA_LONGSERVICEOUTPUT}</pre></td> </tr>\n
	</table>\n
	<br />\n "

# include graph

if [[ $ICINGA_SERVICECHECKCOMMAND == check_graphite_metric* ]] ; then
	# if alert comes from a graphite-monitored service, insert the graph and links
	HAS_GRAPHITE_METRIC="check"
	GRAPHITE_METRIC=`sed -r "s/^.*-m '(.*)'.*/\1/" <<< ${ICINGA_SERVICECHECKCOMMAND} | sed "s/%HOST%/$ICINGA_HOSTNAME/g"`
	EMBED_TIME=`sed -rn "s/^.*-t ([0-9]+).*/\1/p" <<< ${ICINGA_SERVICECHECKCOMMAND}`
else
	# else insert the service trend from nagios
	GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_NAGIOS} "${ICINGA_BASEURL}/cgi-bin/trends.cgi?createimage&host=${ICINGA_HOSTNAME}&service=${ICINGA_SERVICEDESC}" | /usr/bin/base64 -w0)
	MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">\n
		Have a look at the state history for the service:<br />\n
		<!-- curl ${CURL_OPTIONS_NAGIOS} \"${ICINGA_BASEURL}/cgi-bin/trends.cgi?createimage&host=${ICINGA_HOSTNAME}&service=${ICINGA_SERVICEDESC}\" -->\n
		<img src=\"data:image/png; base64,${GRAPH_BASE64}\">\n
		<br />\n
		</div><br />\n"
	# check for custom macro defining associated graphite metric
	if [ ! -z ${ICINGA__SERVICEASSOCIATED_GRAPHITE+x} ] ; then
		HAS_GRAPHITE_METRIC="associated"
		GRAPHITE_METRIC=`sed "s/%HOST%/$ICINGA_HOSTNAME/g" <<< ${ICINGA__SERVICEASSOCIATED_GRAPHITE}`
	fi
fi

# insert graphite graph and links when there is a graphite metric refered, either by the service check directly or by custom macro
if [ ! -z ${HAS_GRAPHITE_METRIC+x} ]; then
	[ "$EMBED_TIME" == "" ] && EMBED_TIME="360"
	GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_GRAPHITE} "${GRAPHITE_BASEURL_EMBED}${GRAPHITE_METRIC}&from=-${EMBED_TIME}minutes&preventCache="`date +"%s"` | /usr/bin/base64 -w0)
	GRAPH_PLAIN=$(echo $GRAPH_BASE64 | /usr/bin/base64 -d -i | strings | head -1)
	MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">\n
		Have a look at the graph for the service in the last ${EMBED_TIME} minutes:<br />\n
		<!-- following graph obtained via curl \"${GRAPHITE_BASEURL_EMBED}${GRAPHITE_METRIC}&from=-${EMBED_TIME}minutes\" -->\n "
	if [ "${GRAPH_PLAIN:0:1}" == "<" ] || [ "${GRAPH_PLAIN:0:1}" == "{" ] ; then
		# graphite returned an error, include it here
		MESSAGE_BODY+="Graphite returned the following error:<br />\n
			${GRAPH_PLAIN}<br />\n
			</div><br />\n "
	else
		# from - to format on graphite: "HH:MM_YYYYMMDD"
		GDATE_NOW=`date +%H:%M_%Y%m%d -ud "now"`
		GDATE_AGO=`date +%H:%M_%Y%m%d -ud "${EMBED_TIME} minutes ago"`
		BIG_SIZE='&width=900&height=500'
		MESSAGE_BODY+="<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=${GDATE_AGO}&until=${GDATE_NOW}'>\n
			<img src=\"data:image/png; base64,${GRAPH_BASE64}\" \n
				width=\"${IMG_WIDTH}\" height=\"${IMG_HEIGHT}\"></a>\n
			<br />\n
			Click the image or <a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=${GDATE_AGO}&until=${GDATE_NOW}'>this link</a> to see the graph for the service at the time of this alert.
			<br />\n
			<br />\n
			Check service graphs for the last: <br />\n
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1hour'>1 hour</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2hours'>2 hours</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3hours'>3 hours</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4hours'>4 hours</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-5hours'>5 hours</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-6hours'>6 hours</a> \n
			<br />\n
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1day'>1 day</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2days'>2 days</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3days'>3 days</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4days'>4 days</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-5days'>5 days</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-6days'>6 days</a> \n
			<br />\n
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1week'>1 week</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2weeks'>2 weeks</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3weeks'>3 weeks</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4weeks'>4 weeks</a> \n
			<br />\n
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1month'>1 month</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2month'>2 months</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3month'>3 months</a> \n
			<br />\n
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1year'>1 year</a> | \n
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2year'>2 years</a> \n
			<br />\n
			</div><br />\n "
	fi
fi

# include useful links

MESSAGE_BODY+="<div style=\"font-size: 9pt; font-family: monospace;\">\n
	<ul>\n "

# check for custom macro defining associated graphitus dashboard
if [ ! -z ${ICINGA__SERVICEASSOCIATED_DASHBOARD+x} ] ; then
	GRAPHITUS_DASHBOARD_ID=`sed "s/%HOST%/$ICINGA_HOSTNAME/g" <<< ${ICINGA__SERVICEASSOCIATED_DASHBOARD}`
	MESSAGE_BODY+="<li><a href=\"${GRAPHITUS_BASEURL}${GRAPHITUS_DASHBOARD_ID}\">Associated graphitus dashboard</a> - graphitus dashboard with extra information on this alert</li>\n "
fi

MESSAGE_BODY+="<li><a href=\"${ICINGA_BASEURL}/cgi-bin/extinfo.cgi?type=2&host=${ICINGA_HOSTNAME}&service=${ICINGA_SERVICEDESC}\">Extended Service Info Page</a> - nagios extended info for service ${ICINGA_SERVICEDESC} on ${ICINGA_HOSTNAME}</li>\n
	<li><a href=\"${ICINGA_BASEURL}/cgi-bin/cmd.cgi?cmd_typ=34&host=${ICINGA_HOSTNAME}&service=${ICINGA_SERVICEDESC}\">Acknowledge Alert</a> - acknowledge this service alert</li>\n
	<li><a href=\"${ICINGA_BASEURL}/cgi-bin/status.cgi?host=all&sorttype=2&sortoption=3\">Alert Status Page</a> - all nagios alerts panel</li>\n "

# footer

MESSAGE_BODY+="	</ul>\n
	${ICINGA_LONGDATETIME}\n
	</div>
	</body>
	</html>"
