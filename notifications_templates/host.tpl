##
## By kali
## Template for standard host notifications
## To be included (sourced) from send notification script
##

## Build message

# subject

MESSAGE_SUBJECT="** HOST ALERT: ${MACRO_HOSTNAME} ${MACRO_NOTIFICATIONTYPE} - ${MACRO_HOSTSTATE} **"

# header

MESSAGE_BODY="<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">
	<html><head><title></title></head>
	<body style=\"font-family: verdana\">
	<br />
	<span style=\"background-color: ${COLORS_NOTIFICATION[$MACRO_HOSTSTATE]}; padding: 1px 5px; border: 1px solid black;\">${MACRO_HOSTSTATE}</span> -
	<strong>${MACRO_HOSTNAME}</strong>
	<br />
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
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Host</td><td>${MACRO_HOSTALIAS}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Address</td><td>${MACRO_HOSTADDRESS}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>State</td><td>${MACRO_HOSTSTATE}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Date/Time</td><td>${MACRO_LONGDATETIME}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[0]};\"> <td>Duration</td><td>${MACRO_HOSTDURATION}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Notification number</td><td>${MACRO_HOSTNOTIFICATIONNUMBER}</td> </tr>
	<tr style=\"background-color: ${COLORS_TABLE[1]};\"> <td>Check output:</td><td><pre style=\"font-size: 9pt\">${MACRO_HOSTOUTPUT}<br />${MACRO_LONGHOSTOUTPUT}</pre></td> </tr>
	</table>
	<br />"

# include graph

GRAPH_BASE64=$(/usr/bin/curl ${CURL_OPTIONS_NAGIOS} "${PROGRAM_BASEURL}/cgi-bin/trends.cgi?createimage&host=${MACRO_HOSTNAME}" | /usr/bin/base64)
((ATTACHMENT_ID++))
IMG_ATTACHMENTS[$ATTACHMENT_ID]="$GRAPH_BASE64"
MESSAGE_BODY+="<div style=\"font-size: 10pt; font-family: monospace; text-align: center\">
	Have a look at the state history for the host:<br />
	<!-- curl ${CURL_OPTIONS_NAGIOS} \"${PROGRAM_BASEURL}/cgi-bin/trends.cgi?createimage&host=${MACRO_HOSTNAME}\" -->
	<img src=\"cid:embedded_img_${ATTACHMENT_ID}\">
	<br />
	</div><br />"

# include useful links

MESSAGE_BODY+="<div style=\"font-size: 9pt; font-family: monospace;\">
	<ul>
	<li><a href=\"${PROGRAM_BASEURL}/cgi-bin/extinfo.cgi?type=1&host=${MACRO_HOSTNAME}\">Extended Host Info Page</a> - nagios extended info for host ${MACRO_HOSTNAME}</li>
	<li><a href=\"${PROGRAM_BASEURL}/cgi-bin/cmd.cgi?cmd_typ=33&host=${MACRO_HOSTNAME}\">Acknowledge Alert</a> - acknowledge this host alert</li>
	<li><a href=\"${PROGRAM_BASEURL}/cgi-bin/status.cgi?host=all&sorttype=2&sortoption=3\">Alert Status Page</a> - all nagios alerts panel</li>"

# footer

MESSAGE_BODY+="	</ul>
	${MACRO_LONGDATETIME}
	</div>
	</body>
	</html>"
