#!/bin/bash
#
# S.M.A.R.T. checker based on smartmontools
# by kali
#
###################################################################################
#
# This script checks on known bad sectors smart attributes, and also ata errors
# (currently 197 --> pending sectors, 198 --> offline uncorrectable).
#
# It also checks on smartctl return status for failed drives, bad command
# responses, etc. Additionally it checks the number of self-test failures reported.
#
# It returns WARNING state on attribute errors, and CRITICAL state for failed SMART
# commands to the drive or self-test failures.
#
# Requires execution as root, either for the script as a whole or for
# smartctl command so you will most likely need to add a couple of lines to your
# sudoers files. If you want to issue 'sudo' to smartd/smartctl commands (and not
# grant sudo for this script) use the '-s' parameter to force this behaviour.
#
# Additionally you will need to schedule self-tests on your hard drives. This can
# be achieved by configuring smartd service, or by setting your own cronjobs.
# Not scheduling self-tests will result in non detection of this kind of errors.
#
###################################################################################


# Define exit functions
exit_ok() { echo "OK - ${CHECK_OUTPUT}" ; exit 0 ; }
exit_war() { echo "WARNING - ${CHECK_OUTPUT}" ; exit 1 ; }
exit_cri() { echo "CRITICAL - ${CHECK_OUTPUT}" ; exit 2 ; }
exit_unk_real() { echo "UNKNOWN - ${CHECK_OUTPUT}" ; exit 3 ; }
exit_bad() { echo "OUT OF RANGE - ${CHECK_OUTPUT}" ; exit 255 ; }
exit_unk() {
	# Let parameters override what status will unkown return. Useful for
	#   installations with missing smartmontools where we don't want to
	#   raise alerts
	case "$EXIT_UNKNOWN" in
		0) exit_ok ;;
		1) exit_war ;;
		2) exit_cri ;;
		255) exit_bad ;;
		*) exit_unk_real ;;
	esac
}

show_usage() {
cat << EOF
Usage: $0 [-U <exit_code>] [-q] [-d] [-s]
-u|--unknown_returns <code> : Force UNKNOWN status return this <code> instead of 3
-s|--sudo                   : Call smartd/smartctl binaries with sudo
-q|--quiet                  : Quiet output: does not include check results in output unless in failure
-d|--debug                  : Enable bash debugging (set -x)
-h|--help                   : Show this help

EOF
}

# Get Args from command line
while (( "$#" )) ; do
	case "${1}" in
		-u|--unknown_returns)
			EXIT_UNKNOWN=${2}
			shift
		;;
		-s|--sudo)
			SUDO_RUN="1"
		;;
		-q|--quiet)
			REPORT_QUIET="1"
		;;
		-d|--debug)
			set -x
		;;
		-h|--help)
			show_usage
			exit 0
		;;
		*)
			CHECK_OUTPUT="Unrecognized parameter: ${1}"
			show_usage
			exit_bad
		;;
	esac
	shift
done

# Define requiered binaries and check they are are available
SMARTD="/usr/sbin/smartd"
SMARTCTL="/usr/sbin/smartctl"
if [ ! -x $SMARTCTL ] ; then
	CHECK_OUTPUT="Can't find smartctl, is smartmontools installed?"
	exit_unk
fi

# Set binaries to run with sudo if requested so
if [ "$SUDO_RUN" == "1" ] ; then
	SMARTCTL="sudo /usr/sbin/smartctl"
fi

## BEGIN ##

if [ -d /sys/block ] ; then
	DEVICES=$(grep ATA /sys/block/*/device/vendor | cut -f3,4 -d/ | sed 's;block;/dev;')
else
	DEVICES=$($SMARTCTL --scan-open | grep "ATA" | grep -vi raid | awk '{print $1}' | sort -u)
fi

for DEVICE in $DEVICES ; do
	DEVICE_STATUS_WARNING="0"
	DEVICE_STATUS_CRITICAL="0"
	DEVICE_REPORT="0"
	DEVICE_OUTPUT="${DEVICE}: "
	# get overall smartctl status code
	SMART_FULL=$($SMARTCTL -a $DEVICE)
	SMART_RET=$?
	# exit device loop on known smart complete failures
	if [[ $(($SMART_RET & 2)) -gt 0 ]] ; then
		CHECK_OUTPUT+="$DEVICE open command failed ; "
		STATUS_CRITICAL="1"
		continue
	fi
	if [[ $(($SMART_RET & 4)) -gt 0 ]] ; then
		CHECK_OUTPUT+="$DEVICE is not accepting SMART commands, most likely dead ; "
		STATUS_CRITICAL="1"
		continue
	fi
	if [[ $(($SMART_RET & 8)) -gt 0 ]] ; then
		CHECK_OUTPUT+="$DEVICE SMART status check returned 'DISK FAILING' ; "
		STATUS_CRITICAL="1"
		continue
	fi

	# parse smart attributes we want to monitor. more can be added here
	ATA_ERRORS=$(awk '{print $NF}' < <(grep "ATA Error Count" <<< "$SMART_FULL" || echo "0"))
	PENDING_ERRORS=$(awk '{print $NF}' < <(grep "^197 " <<< "$SMART_FULL" || echo "0"))
	UNCORRECTABLE_ERRORS=$(awk '{print $NF}' < <(grep "^198 " <<< "$SMART_FULL" || echo "0"))

	# Declare critical status if self tests are failing
	SELF_TEST_ERRORS=$(grep "^#" <<< "$SMART_FULL" | grep fail | wc -l)
	[ $SELF_TEST_ERRORS -gt 0 ] && DEVICE_STATUS_CRITICAL="1"
	# Declare warning if sectors are failing
	SECTOR_ERRORS=$((PENDING_ERRORS+UNCORRECTABLE_ERRORS+ATA_ERRORS))
	[ $SECTOR_ERRORS -gt 0 ] && DEVICE_STATUS_WARNING="1"

	# add device information to the output for clarity
	[ "$DEVICE_STATUS_WARNING" == "1" -o "$DEVICE_STATUS_CRITICAL" == "1" ] && DEVICE_REPORT="1"
	if [ "$REPORT_QUIET" != "1" -o "$DEVICE_REPORT" == "1" ] ; then
		[ "$REPORT_QUIET" != "1" -o $SELF_TEST_ERRORS -gt 0 ] && DEVICE_OUTPUT+="self_test_errors=$SELF_TEST_ERRORS "

		# add more lines here if more smart attributes are considered
		[ "$REPORT_QUIET" != "1" -o $ATA_ERRORS -gt 0 ] && DEVICE_OUTPUT+="ata_errors=$ATA_ERRORS "
		[ "$REPORT_QUIET" != "1" -o $PENDING_ERRORS -gt 0 ] && DEVICE_OUTPUT+="pending_sectors=$PENDING_ERRORS "
		[ "$REPORT_QUIET" != "1" -o $UNCORRECTABLE_ERRORS -gt 0 ] && DEVICE_OUTPUT+="offline_uncorrectable=$UNCORRECTABLE_ERRORS "

		CHECK_OUTPUT+="${DEVICE_OUTPUT}; "
	fi
	[ "$DEVICE_STATUS_WARNING" == "1" ] && STATUS_WARNING="1"
	[ "$DEVICE_STATUS_CRITICAL" == "1" ] && STATUS_CRITICAL="1"
done

# Cleanup trailing separators from output
CHECK_OUTPUT=${CHECK_OUTPUT%% ; }

# Exit with appropriate status
[ "$STATUS_CRITICAL" == "1" ] && exit_cri
[ "$STATUS_WARNING" == "1" ] && exit_war
exit_ok
