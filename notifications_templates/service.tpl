##
## By kali
## Template for standard service notifications
## To be included (sourced) from send notification script
##

## Build message

# subject

MESSAGE_SUBJECT="** SERVICE ALERT: ${MACRO_HOSTNAME}/${MACRO_SERVICEDESC} ${MACRO_NOTIFICATIONTYPE} - ${MACRO_SERVICESTATE} **"

# header

MESSAGE_BODY="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">
	<html><head><title></title></head>
	<body style=\"font-family: verdana\">
	<br /><span style=\"background-color: ${COLORS_NOTIFICATION[$MACRO_SERVICESTATE]}; padding: 1px 5px; border: 1px solid black;\">${MACRO_SERVICESTATE}</span> -
	<strong>${MACRO_HOSTNAME} ${MACRO_SERVICEDESC}</strong><br />
	<br />"

# include comment

if [ -n "$MACRO_NOTIFICATIONAUTHOR" -a -n "$MACRO_NOTIFICATIONCOMMENT" ] ; then
	MESSAGE_BODY+="<strong>"
	if [ "$MACRO_NOTIFICATIONTYPE" == 'ACKNOWLEDGEMENT' ] ; then
		MESSAGE_BODY+="acknowledgement "
	else
		MESSAGE_BODY+="comment "
	fi
	MESSAGE_BODY+="(${MACRO_NOTIFICATIONAUTHOR}) :</strong> ${MACRO_NOTIFICATIONCOMMENT}
		<br />
		<br />"
fi

# notification table

MESSAGE_BODY+="<table cellpadding=\"2px\" style=\"width: 100%; \">
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Notification Type</td><td>${MACRO_NOTIFICATIONTYPE}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Service</td><td>${MACRO_SERVICEDESC}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Host</td><td>${MACRO_HOSTALIAS}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Address</td><td>${MACRO_HOSTADDRESS}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>State</td><td>${MACRO_SERVICESTATE}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Date/Time</td><td>${MACRO_LONGDATETIME}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Duration</td><td>${MACRO_SERVICEDURATION}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Notification number</td><td>${MACRO_SERVICENOTIFICATIONNUMBER}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Check command</td><td><pre style=\"font-size: 9pt\">${MACRO_SERVICECHECKCOMMAND}</pre></td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Check output:</td><td><pre style=\"font-size: 9pt\">${MACRO_SERVICEOUTPUT}<br />${MACRO_LONGSERVICEOUTPUT}</pre></td> </tr>
	</table>
	<br />"

# include graph

if [[ $MACRO_SERVICECHECKCOMMAND == check_graphite_metric* ]] ; then
	# if alert comes from a graphite-monitored service, insert the graph and links
	HAS_GRAPHITE_METRIC="check"
	GRAPHITE_METRIC=`sed -r "s/^.*-m '(.*)'.*/\1/" <<< ${MACRO_SERVICECHECKCOMMAND} | sed "s/%HOST%/$MACRO_HOSTNAME/g"`
	EMBED_TIME=`sed -rn "s/^.*-t ([0-9]+).*/\1/p" <<< ${MACRO_SERVICECHECKCOMMAND}`
else
	# else insert the service trend from nagios
	GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_NAGIOS} "${PROGRAM_BASEURL}/cgi-bin/trends.cgi?createimage&host=${MACRO_HOSTNAME}&service=${MACRO_SERVICEDESC}" | /usr/bin/base64)
	((ATTACHMENT_ID++))
	IMG_ATTACHMENTS[$ATTACHMENT_ID]="$GRAPH_BASE64"
	MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">
		Have a look at the state history for the service:<br />
		<!-- curl ${CURL_OPTIONS_NAGIOS} \"${PROGRAM_BASEURL}/cgi-bin/trends.cgi?createimage&host=${MACRO_HOSTNAME}&service=${MACRO_SERVICEDESC}\" -->
		<img src=\"cid:embedded_img_${ATTACHMENT_ID}\">
		<br />
		</div><br />"
	# check for custom macro defining associated graphite metric
	if [ ! -z ${MACRO__SERVICEASSOCIATED_GRAPHITE+x} ] ; then
		HAS_GRAPHITE_METRIC="associated"
		GRAPHITE_METRIC=`sed "s/%HOST%/$MACRO_HOSTNAME/g" <<< ${MACRO__SERVICEASSOCIATED_GRAPHITE}`
	fi
fi

# insert graphite graph and links when there is a graphite metric refered, either by the service check directly or by custom macro
if [ ! -z ${HAS_GRAPHITE_METRIC+x} ]; then
	[ "$EMBED_TIME" == "" ] && EMBED_TIME="360"
	GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_GRAPHITE} "${GRAPHITE_BASEURL_EMBED}${GRAPHITE_METRIC}&from=-${EMBED_TIME}minutes&preventCache="`date +"%s"` | /usr/bin/base64)
	((ATTACHMENT_ID++))
	IMG_ATTACHMENTS[$ATTACHMENT_ID]="$GRAPH_BASE64"
	GRAPH_PLAIN=$(echo $GRAPH_BASE64 | /usr/bin/base64 -d -i | strings | head -1)
	MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">
		Have a look at the graph for the service in the last ${EMBED_TIME} minutes:<br />
		<!-- following graph obtained via curl \"${GRAPHITE_BASEURL_EMBED}${GRAPHITE_METRIC}&from=-${EMBED_TIME}minutes\" -->"
	if [ "${GRAPH_PLAIN:0:1}" == "<" ] || [ "${GRAPH_PLAIN:0:1}" == "{" ] ; then
		# graphite returned an error, include it here
		MESSAGE_BODY+="Graphite returned the following error:<br />
			${GRAPH_PLAIN}<br />
			</div><br />"
	else
		# from - to format on graphite: "HH:MM_YYYYMMDD"
		GDATE_NOW=`date +%H:%M_%Y%m%d -ud "now"`
		GDATE_AGO=`date +%H:%M_%Y%m%d -ud "${EMBED_TIME} minutes ago"`
		BIG_SIZE='&width=900&height=500'
		MESSAGE_BODY+="<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=${GDATE_AGO}&until=${GDATE_NOW}'>
			<img src=\"cid:embedded_img_${ATTACHMENT_ID}\" width=\"${IMG_WIDTH}\" height=\"${IMG_HEIGHT}\"></a>
			<br />
			Click the image or <a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=${GDATE_AGO}&until=${GDATE_NOW}'>this link</a> to see the graph for the service at the time of this alert.
			<br />
			<br />
			Check service graphs for the last: <br />
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1hour'>1 hour</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2hours'>2 hours</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3hours'>3 hours</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4hours'>4 hours</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-5hours'>5 hours</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-6hours'>6 hours</a> 
			<br />
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1day'>1 day</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2days'>2 days</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3days'>3 days</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4days'>4 days</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-5days'>5 days</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-6days'>6 days</a> 
			<br />
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1week'>1 week</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2weeks'>2 weeks</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3weeks'>3 weeks</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-4weeks'>4 weeks</a> 
			<br />
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1month'>1 month</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2month'>2 months</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-3month'>3 months</a> 
			<br />
			<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-1year'>1 year</a> | 
				<a href='${GRAPHITE_BASEURL_LINK}${GRAPHITE_METRIC}${BIG_SIZE}&from=-2year'>2 years</a> 
			<br />
			</div><br />"
	fi
fi

# include useful links

MESSAGE_BODY+="<div style=\"font-size: 9pt; font-family: monospace;\">
	<ul>"

# check for custom macro defining associated graphitus dashboard
if [ ! -z ${MACRO__SERVICEASSOCIATED_DASHBOARD+x} ] ; then
	GRAPHITUS_DASHBOARD_ID=`sed "s/%HOST%/$MACRO_HOSTNAME/g" <<< ${MACRO__SERVICEASSOCIATED_DASHBOARD}`
	MESSAGE_BODY+="<li><a href=\"${GRAPHITUS_BASEURL}${GRAPHITUS_DASHBOARD_ID}\">Associated graphitus dashboard</a> - graphitus dashboard with extra information on this alert</li>"
fi

MESSAGE_BODY+="<li><a href=\"${PROGRAM_BASEURL}/cgi-bin/extinfo.cgi?type=2&host=${MACRO_HOSTNAME}&service=${MACRO_SERVICEDESC}\">Extended Service Info Page</a> - nagios extended info for service ${MACRO_SERVICEDESC} on ${MACRO_HOSTNAME}</li>
	<li><a href=\"${PROGRAM_BASEURL}/cgi-bin/cmd.cgi?cmd_typ=34&host=${MACRO_HOSTNAME}&service=${MACRO_SERVICEDESC}\">Acknowledge Alert</a> - acknowledge this service alert</li>
	<li><a href=\"${PROGRAM_BASEURL}/cgi-bin/status.cgi?host=all&sorttype=2&sortoption=3\">Alert Status Page</a> - all nagios alerts panel</li>"

# footer

MESSAGE_BODY+="	</ul>
	${MACRO_LONGDATETIME}
	</div>
	</body>
	</html>"
