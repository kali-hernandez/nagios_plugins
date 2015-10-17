nagios_plugins
==============

Custom nagios plugins
----------------------

  * check_graphite_metric
Check metrics provided by a graphite installation. Useful if you have a running
graphite monitoring system in place and want to set alerts through nagios
without duplication of scripts running locally, and setting nrpe or ssh checks.

Requires running graphite. Allows https interfaces with user authentication.
Allows lo/hi thresholds for alerts. Allows for hysteresis margins.

Check command help for more details on usage.

Set a service check similar to this:

```
define command{
        command_name    check_graphite_metric
        command_line    $USER1$/check_graphite_metric -H $HOSTNAME$ $ARG1$
}

define service{
	use			generic-service
	service_description	your_check
	check_command		check_graphite_metric!-W TH_W_HI -C TH_C_HI -w TH_W_LO -c TH_C_LO -m '%HOST%.your.metric.name'
}
```

  * check_apt_updates
Checks for pending upgradable packages using apt. Returns warning when "soft" 
(i.e. non-security) upgradable packages are available, and critical when any
"critical" upgrade is available (i.e in the security repositories).

Accepts a parameter (-c) to watch only for critical updates.

Only works for local (must be called through nrpe) and requires the system to 
perform apt-get update on its own (the check doesn't update apt available list
since it would require root privileges)

  * ceck_foo
Silly check that will return an OK value by default, or else the return value
passed as parameter. It was useful for making nagios "pseudo-hosts" where I
wanted to associate checks which are service and not host based, defining a
new host and setting check_foo as the alive check command so that it appears
always as up.

Custom nagios notifications
---------------------------

  * notify_by_email_html.sh
Send notifications in html format, with extended information. If service and
of graphite_metric kind, then include the graphite image and links to wider 
time frames for extra information, as well as links to nagios reports and 
acknowledge functions. For non-grahite and host checks include nagios' trend
native graph of status history. Defaults to service notifications if -t not
provided.
Requires nagios to pass environment variables to scripts, by setting
enable_environment_macros=1 on nagios.cfg

Set the notification like:

```
define command{
        command_name    notify-service-by-email
        command_line    $USER1$/notify_by_email_html.sh $CONTACTEMAIL$ -t [host|service]
}
```
