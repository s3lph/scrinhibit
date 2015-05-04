#!/bin/bash

#    SCRinhibit v0.01
#
#    A bash script to keep the screensaver from appearing
#    under certain circumstances
#
#  The MIT License (MIT)
#
#    Copyright (c) 2015 Sebastian Philipp
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.
#

#config directory
SI_DIR='.'
#screensaver keyword
SI_SCRSV=''
#check interval
SI_DELAY=60
#whether to daemonize or not
SI_DAEMONIZE=1
#whether to be verbose or not
SI_VERBOSITY=0;

#Blacklist file prefix when on battery power
SI_BATT_PREFIX=''

#show help message
function usage() {
    echo -e "\
SCRinhibit v0.02 - A bash script to keep the screensaver from appearing under certain\n\
circumstances\n\
\n\
Copyright (c) 2015 Sebastian Philipp\n\
Licensed under the terms of the MIT License\n\
\n\
SYNOPSIS\n\
\tSCRinhibit [OPTIONS]...\n\
\n\
OPTIONS\n\
\t-v\tBe verbose\n\
\t-a\tShow copyright notice\n\
\t-s\tScreensaver keyword (required, see below)\n\
\t-c\tDirectory in which the config files lie (defaults to .)\n\
\t-d\tDo not daemonize the script (defaults to daemon)\n\
\t-i\tInterval in seconds after which to recheck inhibition (defaults to 60)\n\
\t-?, -h\tShow this manual\n
\n\
SCREENSAVER KEYWORDS\n\
Keyword\tScreensaver\n\
  cin\tcinnamon-screensaver\n\
  kde\tKDE4 Screensaver\n\
  gno\tgnome-screensaver\n\
  xdg\txdg-screensaver (workaround, may help if screensaver not listed)\n\
\n\
WHEN WILL IT INHIBIT? (AND WHEN NOT?)\n\
  - When a process listed in procblacklist.conf is running\n\
  - When a X window of a process listed in fsblacklist.conf is in fullscreen\n\
  - When on battery power, the files battery_procblacklist.conf and\n\
    battery_fsblacklist.conf will be used, but only, if they exist\n\
  - No inhibition if the screensaver is already active. So set the interval properly!\n"
}

#parse arguments
function parse_args() {
    while getopts ":vs:i:c:da?h" opt; do
	case $opt in
	    'v')#verbosity
		SI_VERBOSITY=1
		;;
	    's')#screensaver keyword
		SI_SCRSV=$OPTARG
		;;
	    'i')#inhibit delay
		SI_DELAY=$OPTARG
		;;
	    'c')#config dir
		SI_DIR=$OPTARG
		;;
	    'd')#daemonize
		SI_DAEMONIZE=0
		;;
	    'a')#show copyright notice
		echo -e "\
SCRinhibit v0.02 - A bash script to keep the screensaver from appearing under certain\n\
circumstances\n\
\n\
\n\
  The MIT License (MIT)\n\
\n\
    Copyright (c) 2015 Sebastian Philipp\n\
\n\
  Permission is hereby granted, free of charge, to any person obtaining a copy\n\
  of this software and associated documentation files (the "Software"), to deal\n\
  in the Software without restriction, including without limitation the rights\n\
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell\n\
  copies of the Software, and to permit persons to whom the Software is\n\
  furnished to do so, subject to the following conditions:\n\
\n\
  The above copyright notice and this permission notice shall be included in\n\
  all copies or substantial portions of the Software.\n\
\n\
  THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\n\
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n\
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\n\
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n\
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\n\
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN\n\
  THE SOFTWARE.\n\
"
		exit
		;;
	    *|'?'|'h')#show help message
                usage
		exit
		;;
	esac
    done
}

#Inhibit the screensaver, command is determined by screensaver keyword
function inhibit_screensaver() {
    case $1 in
	'cin')#cinnamon-screensaver
	    qdbus org.cinnamon.ScreenSaver / SimulateUserActivity &> /dev/null
	    ;;
	'kde')#KDE4 screensaver
	    qdbus org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity &> /dev/null
	    ;;
	'gno')#gnome-screensaver
	    qdbus org.gnome.ScreenSaver /org/gnome/ScreenSaver SimulateUserActivity &> /dev/null
	    ;;
	'xdg')#xdg-screensaver reset
	    xdg-screensaver reset &> /dev/null
	    ;;
	*)
	    return
	    ;;
    esac
}

#Check whether the selected screensaver is currently active.
function check_scrsv_active() {
    case $1 in
	'cin')#cinnamon-screensaver
	    if [[ "$(qdbus org.cinnamon.ScreenSaver / GetActive)" = 'true' ]]; then
		return 1
	    fi
	    return 0
	    ;;
	'kde')#KDE4 Screensaver
	    if [[ "$(qdbus org.freedesktop.ScreenSaver /ScreenSaver GetActive)" = 'true' ]]; then
		return 1
	    fi
	    return 0
	    ;;
	'gno')#gnome-screensaver
	    if [[ "$(qdbus org.gnome.ScreenSaver /org/gnome/ScreenSaver GetActive)" = 'true' ]]; then
		return 1
	    fi
	    return 0
	    ;;
	'xdg')#xdg-screensaver status
	    if [[ "$(xdg-screensaver status)" = 'enabled' ]]; then
		return 1
	    fi
	    return 0
	    ;;
    esac
}

#read each process name from 'ps x' and compare with procblacklist.conf
function find_proc() {
    for p in $(ps x | awk '{print $5}' | sed -r 's/^.*\/(.*?)/\1/g' | sed '/^$/d'); do
	proc=$(grep "$(echo $p)" $SI_DIR/${SI_BATT_PREFIX}procblacklist.conf)
	if [[ -z $proc ]]; then
	    continue;
	fi
	if [[ $SI_VERBOSITY == 1 ]]; then
	    echo "Screensaver inhibited due to $proc being running."
	fi
	inhibit_screensaver $SI_SCRSV
	return
    done
    if [[ $SI_VERBOSITY == 1 ]]; then
	echo "Screensaver not inhibited by process check."
    fi
}

#get PID of each fullscreen window and compare with fsblacklist.conf
function find_fullscreen() {
    for w in $(wmctrl -l | awk '{print $1}'); do
	if [[ -n $(xprop -id $w | grep NET_WM_STATE_FULLSCREEN) ]]; then
	    fspid=$(xprop -id $w _NET_WM_PID | awk '{print $3}')
	    fspname=$(ps x | grep $fspid | grep -v grep | awk '{print $5}' | \
		sed -r 's/^.*\/(.*?)/\1/g' | awk '{print $1}')
	    if [[ -n $(grep "$(echo $fspname | awk '{print $1}')" \
		$SI_DIR/${SI_BATT_PREFIX}fsblacklist.conf) ]]; then
		if [[ $SI_VERBOSITY == 1 ]]; then
		    echo "Screensaver inhibited due to $fspname being in fullscreen."
		fi
		inhibit_screensaver $SI_SCRSV
		return
	    fi
	fi
    done
    if [[ $SI_VERBOSITY == 1 ]]; then
	echo "Screensaver not inhibited by fullscreen check."
    fi
}

#Check whether AC power is disconnected and both battery_blacklists exists
#If yes, use battery profile, else not
function check_ac() {
    if [[ -n $(grep on-line /proc/acpi/ac_adapter/*/state) ]] || \
	[[ ! -f $SI_DIR/battery_fsblacklist.conf ]] || \
	[[ ! -f $SI_DIR/battery_procblacklist.conf ]]; then
	SI_BATT_PREFIX=''
	if [[ $SI_VERBOSITY == 1 ]]; then
	    echo "Using AC profile"
	fi
    else 
	if [[ $SI_VERBOSITY == 1 ]]; then
	    echo "Using battery profile"
	fi
	SI_BATT_PREFIX='battery_'
    fi
}

#inhibition loop
function loop() {
    while [[ true ]]; do
	sleep $SI_DELAY
	check_scrsv_active $SI_SCRSV
	if [[ $? == 1 ]]; then
	    echo "Screensaver already active, not inhibited."
	    continue;
	fi
	check_ac
	find_proc
	find_fullscreen
    done
}

###
###   Program execution starts here
###

#Parse arguments
parse_args $@

#Show help message if no screensaver set
if [[ -z $SI_SCRSV ]]; then
    usage
    exit
fi

#Show verbose init output
if [[ $SI_VERBOSITY == 1 ]]; then
    echo -e "  Fullscreen blacklist:"
    cat $SI_DIR/fsblacklist.conf
    echo -e "\n  Process blacklist:"
    cat $SI_DIR/procblacklist.conf
    echo -e "\nInterval: $SI_DELAY seconds\n"
fi

#Start inhibition loop, daemonized or not
if [[ $SI_DAEMONIZE -eq 1 ]]; then
    loop &> /dev/null&
else
    loop
fi
