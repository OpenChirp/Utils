#!/bin/bash
# Craig Hesling <craig@hesling.com>
# October 18, 2016

DEVICE=${1:-/dev/ttyUSB0}

# Specifies if echo is used for verification
DEV_ECHO=1

mdotopen() {
	if ! stty -F $DEVICE 115200; then
		echo "# Error - Device $DEVICE does not exist" >&2
		return 1
	fi
	if ! exec 5<>$DEVICE; then
		echo "# Error - Device $DEVICE does not exist" >&2
		return 1
	fi

	# setup control from this script
	setupctrl
	# setup mDot for US/OpenChirp frequencies
	setupus
	return 0
}

mdotclose() {
	if ! exec 5>&-; then
		echo "# Error - Device file descriptor not open" >&2
		return 1
	fi
	return 0
}

setupctrl() {
	local line=""

	# Empty input buffer
	while readline line 0.1; do
		true
	done

	# Enable echoing for verification
	if (( DEV_ECHO )); then
		# enable echoing, but must ignore verification first
		DEV_ECHO=0
		submitcmd ATE1
		DEV_ECHO=1
	else
		submitcmd ATE0
	fi


	# disable verbose mode
	submitcmd ATV0
}

setupus() {
	submitcmd AT+FSB 1
	submitcmd AT+PN 1
}

# read line from serial device to the variable named in first arg
readline() {
	local var=$1
	local timeout=$2

	local stat=0

	if [ -n "$timeout" ]; then
		read -u 5 -t $timeout $var
		stat=$?
	else
		read -u 5 $var
		stat=$?
	fi

	#eval $var=`echo \$$var | tr -d "\015"`
	#eval $var=\${$var//[^[:alnum:]]/}
	eval $var=\${$var//[^[:print:]]/}
	return $stat
}

# write arguments as a line into the serial device
writeline() {
	echo $* >&5
}

errorcode() {
	local codestr=$1
	case $codestr in
		OK)
			return 0
			;;
		ERROR)
			return 1
			;;
		# I'm not aware of any other errors
		*)
			return 1
			;;
	esac
}

showcmd() {
	local cmd=$1
	local line=""

	writeline $cmd

	# Empty input buffer
	while readline line 0.1; do
		echo -e "$line"
	done
}

submitcmd() {
	local cmd=$1
	local timeout=$2

	local line=""
	local result=""
	local status=""


	writeline $cmd

	if (( DEV_ECHO )); then 
		readline line
		#echo "cmd: \"$cmd\""
		#echo "line: \"$line\""
		if [ "$cmd" != "$line" ]; then
			echo "Error - Device didn't echo the command"
		fi
	fi

	while readline line; do
		if [ -z "$line" ]; then
			# this must be the blank line seperator
			break
		else
			# we only expect one result, unless it is an AT& command
			result="$(if [ -n "$result" ]; then printf "%s\n%s\n" "$result" "$line"; else printf "%s" "$line"; fi;)"
		fi
	done

	# get status string
	readline status

	printf "%s\n" "${result}"
	errorcode $status
	return $?
}

reloadlib() {
	. mdotlib.bash $DEVICE
}

## Interface ##
mopen() {
	mdotopen
}
mclose() {
	mdotclose
}

mcmd() {
	submitcmd $@
}

mhelp() {
	local cmd=$1
	showcmd "help $cmd"
}

minfo() {
	submitcmd "AT&V"
}

mjoin() {
	submitcmd AT+JOIN
}

cmds="AT ATI ATZ ATE0 ATE1 ATV0 ATV1 AT&F AT&W AT&V AT&S AT&R AT+IPR AT+DIPR AT+SMODE AT+FREQ AT+FSB AT+PN AT+DI AT+NA AT+NSK AT+DSK AT+NK AT+NI AT+JOIN AT+JR AT+JBO AT+NJM AT+NJS AT+NLC AT+LCC AT+LCT AT+ENC AT+RSSI AT+SNR AT+DP AT+TXDR AT+TXP AT+TXF AT+TXI AT+TXW AT+TXCH AT+TXN AT+TOA AT+RXDR AT+RXF AT+RXO AT+RXI AT+FEC AT+CRC AT+ADR AT+ACK AT+SEND AT+SENDH AT+SENDB AT+SENDI AT+RECV AT+RECVC AT+SD AT+SLEEP AT+WM AT+WI AT+WD AT+WTO AT+PING AT+LOG"
helpcmds="AT ATI ATZ ATE0/1 ATV0/1 AT&F AT&W AT&V AT&S AT&R AT+IPR AT+DIPR AT+SMODE AT+FREQ AT+FSB AT+PN AT+DI AT+NA AT+NSK AT+DSK AT+NK AT+NI AT+JOIN AT+JR AT+JBO AT+NJM AT+NJS AT+NLC AT+LCC AT+LCT AT+ENC AT+RSSI AT+SNR AT+DP AT+TXDR AT+TXP AT+TXF AT+TXI AT+TXW AT+TXCH AT+TXN AT+TOA AT+RXDR AT+RXF AT+RXO AT+RXI AT+FEC AT+CRC AT+ADR AT+ACK AT+SEND AT+SENDH AT+SENDB AT+SENDI AT+RECV AT+RECVC AT+SD AT+SLEEP AT+WM AT+WI AT+WD AT+WTO AT+PING AT+LOG"

complete -W "$helpcmds" mhelp
complete -W "$cmds" mcmd
