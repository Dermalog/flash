#!/bin/bash

function usage {
cat <<EOF
USAGE: $(basename $0) [eb|ek]
  * eb -- for dermalog embedded board
  * ek -- for evaluation kit
EOF
}

if  [[ -z ${1} ]]; then
    echo "please specify board"
    usage
    exit 1
fi

if [[ ${1} == "eb" ]]; then
    tcl="flash_eb.tcl"
fi

if [[ ${1} == "ek" ]]; then
    tcl="flash_ek.tcl"
fi

if [[ -z ${tcl} ]]; then
    echo "unknown board '${1}'"
    usage
    exit 2
fi

../sam-ba/sam-ba /dev/ttyACM0 AT91SAMA5D3x-EK ${tcl}
#:> logfile.log 2>&1
cat logfile.log
