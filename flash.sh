#!/bin/bash

function usage {
cat <<EOF
USAGE: $(basename $0) <eb|ek> <board_serial> <factory_serial> <macAddr> <ipcfg>
  * eb -- for dermalog embedded board
  * ek -- for evaluation kit
  * board_serial -- the serial number flashed to board like ZZ999999
EOF
}

export DISPLAY=10.120.13.44:0.0

if  [[ -z ${1} ]]; then
    echo "please specify board"
    usage
    exit 1
fi

if [[ -z ${2} ]]; then
    echo "please specify board serial number"
    usage
    exit 2
fi

../sam-ba/sam-ba /dev/ttyACM0 AT91SAMA5D3x-EK flash.tcl "${1}" "${2}" "${3}" "${4}" "${5}"
#:> logfile.log 2>&1
#cat logfile.log
