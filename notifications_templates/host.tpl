##
## By kali
## Template for standard host notifications
## To be included (sourced) from send notification script
##

## Build message

# subject

MESSAGE_SUBJECT="** HOST ALERT: ${ICINGA_HOSTNAME} ${ICINGA_NOTIFICATIONTYPE} - ${ICINGA_HOSTSTATE} **"

# header

MESSAGE_BODY="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">\n
	<html><head><title></title></head>\n
	<body style=\"font-family: verdana\">\n
	<br />\n
	<span style=\"background-color: ${COLORS_NOTIFICATION[$ICINGA_HOSTSTATE]}; padding: 1px 5px; border: 1px solid black;\">${ICINGA_HOSTSTATE}</span> -\n
	<strong>${ICINGA_HOSTNAME}</strong>\n
	<br />\n
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
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Host</td><td>${ICINGA_HOSTALIAS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Address</td><td>${ICINGA_HOSTADDRESS}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>State</td><td>${ICINGA_HOSTSTATE}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Date/Time</td><td>${ICINGA_LONGDATETIME}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Duration</td><td>${ICINGA_HOSTDURATION}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Notification number</td><td>${ICINGA_HOSTNOTIFICATIONNUMBER}</td> </tr>\n
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Check output:</td><td><pre style=\"font-size: 9pt\">${ICINGA_HOSTOUTPUT}<br />${ICINGA_LONGHOSTOUTPUT}</pre></td> </tr>\n
	</table>\n
	<br />\n "

# include graph

GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_NAGIOS} "${ICINGA_BASEURL}/cgi-bin/trends.cgi?createimage&host=${ICINGA_HOSTNAME}" | /usr/bin/base64 -w0)
MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">\n
	Have a look at the state history for the host:<br />\n
	<!-- curl ${CURL_OPTIONS_NAGIOS} \"${ICINGA_BASEURL}/cgi-bin/trends.cgi?createimage&host=${ICINGA_HOSTNAME}\" -->\n
	<img src=\"data:image/png; base64,${GRAPH_BASE64}\">\n
	<br />\n
	</div><br />\n "

# include useful links

MESSAGE_BODY+="<div style=\"font-size: 9pt; font-family: monospace;\">\n
	<ul>\n
	<li><a href=\"${ICINGA_BASEURL}/cgi-bin/extinfo.cgi?type=1&host=${ICINGA_HOSTNAME}\">Extended Host Info Page</a> - nagios extended info for host ${ICINGA_HOSTNAME}</li>\n
	<li><a href=\"${ICINGA_BASEURL}/cgi-bin/cmd.cgi?cmd_typ=33&host=${ICINGA_HOSTNAME}\">Acknowledge Alert</a> - acknowledge this host alert</li>\n
	<li><a href=\"${ICINGA_BASEURL}/cgi-bin/status.cgi?host=all&sorttype=2&sortoption=3\">Alert Status Page</a> - all nagios alerts panel</li>\n "

# footer

MESSAGE_BODY+="	</ul>\n
	${ICINGA_LONGDATETIME}\n
	</div>
	</body>
	</html>"
