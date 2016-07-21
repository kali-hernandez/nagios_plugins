#!/bin/bash
#
# S.M.A.R.T. checker based on smartmontools
# by kali
#

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
Usage: $0 [-U <exit_code>] [-q] [-d]
-u|--unknown_returns <code> : Force UNKNOWN status return this <code> instead of 3
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
if [ ! -x $SMARTD -o ! -x $SMARTCTL ] ; then
	CHECK_OUTPUT="Can't find smartd/smartctl, is smartmontools installed?"
	exit_unk
fi
# Check will most likely run as non-root. Sudo needed for this script or the smartd/smartctl bins. You might want to adjust this
SMARTD="sudo /usr/sbin/smartd"
SMARTCTL="sudo /usr/sbin/smartctl"

## BEGIN ##

# Use smartd discovery logic to find the available devices
ONECHECK_OUT=$($SMARTD -dq onecheck)
case "$?" in
	0)
		# All ok, keep on going
	;;
	17)
		# No devices found
		CHECK_OUTPUT="$SMARTD found no drives to query, maybe running on hardware raid platform?"
		exit_ok
	;;
	*)
		CHECK_OUTPUT="$SMARTD execution failed. Maybe user `whoami` is missing sudo powers?"
		exit_unk
	;;
esac

DEVICES=$(sed -n 's/Device: \(\/dev\/sd[a-z]\).*/\1/p' <<< "$ONECHECK_OUT" | sort -u)

for DEVICE in $DEVICES ; do
	# get overall smartctl status code
	SMART_FULL=$($SMARTCTL -a $DEVICE)
	SMART_RET=$?
	# exit on known smart complete failures
	if [[ $(($SMART_RET & 2)) -gt 0 ]] ; then
		CHECK_OUTPUT="$DEVICE open command failed."
		exit_cri
	fi
	if [[ $(($SMART_RET & 4)) -gt 0 ]] ; then
		CHECK_OUTPUT="$DEVICE is not accepting SMART commands, most likely dead"
		exit_cri
	fi
	if [[ $(($SMART_RET & 8)) -gt 0 ]] ; then
		CHECK_OUTPUT="$DEVICE SMART status check returned 'DISK FAILING'"
		exit_cri
	fi
	# get device smart attributes to be parsed
	SMART_ATTRS=$($SMARTCTL -A $DEVICE)
	if [ $? -ne 0 ] ; then
		CHECK_OUTPUT="$DEVICE retrieval for SMART attributes failed."
		exit_cri
	fi

	# find status file associated with the device, for fetching number of self test errors (not available in smart_attrs)
	STATEFILE=$(sed -n "s;Device: $DEVICE.* written to \(.*\)$;\1;p" <<< "$ONECHECK_OUT")
	if [ $STATEFILE -a -f $STATEFILE ] ; then
		SELF_TEST_ERRORS=$(grep self-test-errors $STATEFILE || echo "0")
	else
		SELF_TEST_ERRORS="0"
	fi
	# retain only value from the grep output
	SELF_TEST_ERRORS=${SELF_TEST_ERRORS##* }

	# parse smart attributes we want to monitor. more can be added here

	PENDING_ERRORS=$(awk '{print $NF}' < <(grep "^197" <<< "$SMART_ATTRS" || echo "0"))
	UNCORRECTABLE_ERRORS=$(awk '{print $NF}' < <(grep "^198" <<< "$SMART_ATTRS" || echo "0"))

	# Declare critical status if self tests are failing
	[ $SELF_TEST_ERRORS -gt 0 ] && STATUS_CRITICAL="1"
	# Declare warning if sectors are failing
	SECTOR_ERRORS=$((PENDING_ERRORS+UNCORRECTABLE_ERRORS))
	[ $SECTOR_ERRORS -gt 0 ] && STATUS_WARNING="1"

	# add device information to the output for clarity
	if [ "$REPORT_QUIET" != "1" -o $SELF_TEST_ERRORS -gt 0 -o $SECTOR_ERRORS -gt 0 ] ; then
		CHECK_OUTPUT+="$DEVICE: self_test_errors=$SELF_TEST_ERRORS"

		# add more lines here if more smart attributes are considered
		CHECK_OUTPUT+=" pending_sectors=$PENDING_ERRORS"
		CHECK_OUTPUT+=" offline_uncorrectable=$UNCORRECTABLE_ERRORS"

		CHECK_OUTPUT+=" ; "
	fi
done

# Cleanup trailing separators from output
CHECK_OUTPUT=${CHECK_OUTPUT%% ; }

# Exit with appropriate status
[ "$STATUS_CRITICAL" == "1" ] && exit_cri
[ "$STATUS_WARNING" == "1" ] && exit_war
exit_ok
