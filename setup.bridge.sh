#!/bin/bash
# Copyright 2013
# Charles Steinkuehler <charles@steinkuehler.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

dtbo_err () {
	echo "Error loading device tree overlay file: $DTBO" >&2
	exit 1
}

pin_err () {
	echo "Error exporting pin:$PIN" >&2
	exit 1
}

dir_err () {
	echo "Error setting direction:$DIR on pin:$PIN" >&2
	exit 1
}

SLOTS=/sys/devices/bone_capemgr.*/slots

sudo modprobe -v ads1015

# Make sure required device tree overlay(s) are loaded
for DTBO in parport cape-bone-iio ads1015; do

	if grep -q $DTBO $SLOTS ; then
		echo $DTBO overlay found
	else
		echo Loading $DTBO overlay
		sudo -A su -c "echo $DTBO > $SLOTS" || dtbo_err
		sleep 1
	fi
done;

if [ ! -r /sys/devices/ocp.*/helper.*/AIN0 ] ; then
	echo Analog input files not found in /sys/devices/ocp.*/helper.* >&2
	exit 1;
fi

if [ ! -r /sys/class/uio/uio0 ] ; then
	echo PRU control files not found in /sys/class/uio/uio0 >&2
	exit 1;
fi

# Export GPIO pins:
# One pin needs to be exported to enable the low-level clocks for the GPIO
# modules (there is probably a better way to do this)
# 
# Any GPIO pins driven by the PRU need to have their direction set properly
# here.  The PRU does not do any setup of the GPIO, it just yanks on the
# pins and assumes you have the output enables configured already
# 
# Direct PRU inputs and outputs do not need to be configured here, the pin
# mux setup (which is handled by the device tree overlay) should be all
# the setup needed.
# 
# Any GPIO pins driven by the hal_bb_gpio driver do not need to be
# configured here.  The hal_bb_gpio module handles setting the output
# enable bits properly.  These pins _can_ however be set here without
# causing problems.  You may wish to do this for documentation or to make
# sure the pin starts with a known value as soon as possible.

while read PIN DIR JUNK ; do
        case "$PIN" in
        ""|\#*)	
		continue ;;
        *)
		[ -r /sys/class/gpio/gpio$PIN ] && continue
                sudo -A su -c "echo $PIN > /sys/class/gpio/export" || pin_err
		sudo -A su -c "echo $DIR > /sys/class/gpio/gpio$PIN/direction" || dir_err
                ;;
        esac

done <<- EOF
	30	out	# p9.11		gpio0.30	B_Step
	31	out	# p9.13		gpio0.31	Z_Step
	48	out	# p9.15		gpio1.16	X_Max
	27	out	# P8.17		gpio0.27	Z_Min
	49	out	# P9.23		gpio1.17	Spindle_Dir
	117	out	# P9.25		gpio3.21	Z_Dir
	125	in	# P9.27		gpio3.19	C_Home..........Ambiguous GPIO pin number Alternative 115
	14	out	# P9.26		gpio0.14	Motors_Enable

	15	in	# P9.24		gpio0.15	B_Home
	61	in	# P8.26		gpio1.29	Status_Led.....Supposedly Input ..... External hardware supports only input
	60	out	# P9.12		gpio1.28	A_Min
	47	out	# P8.15		gpio1.15	Y_Dir
	7	out	# P9.42		gpio0.7		B_Dir
	65	out	# P8.18		gpio2.1		Z_Max
	2	out	# P9.22		gpio0.2		A_Step
	3	out	# P9.21		gpio0.3		A_Dir

	69	out	# P8.9		gpio2.5		C_Step
	66	in	# P8.7		gpio2.2		X_Home
	67	out	# P8.8		gpio2.3		C_Dir
	68	out	# P8.10		gpio2.4		Y_Min
	44	out	# P8.12		gpio1.12	X_Step
	45	out	# P8.11		gpio1.13	X_Dir
	26	out	# P8.14		gpio0.26	Y_Max
	46	out	# P8.16		gpio1.14	Y_Step

	23	out	# P8.13		gpio0.23	PWM0 Spindle
	22	in	# P8.19		gpio0.22	Y_Home
	50	out	# P9.14		gpio1.18	X_Min...........Ambiguous GPIO pin number Alternativa 40
	51	out	# P9.16		gpio1.19	A_Max
	5	in	# p9.17		gpio0.5		Z_Home
	4	in	# p9.18		gpio0.4		A_Home
	20	in	# p9.41		gpio0.20	E_Stop
	122	out	# p9.30		gpio3.16	Axes_Enable
EOF
