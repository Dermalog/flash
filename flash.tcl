# ----------------------------------------------------------------------------
#         ATMEL Microcontroller Software Support 
# ----------------------------------------------------------------------------
# Copyright (c) 2012, Atmel Corporation
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# - Redistributions of source code must retain the above copyright notice,
# this list of conditions and the disclaimer below.
#
# Atmel's name may not be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# DISCLAIMER: THIS SOFTWARE IS PROVIDED BY ATMEL "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT ARE
# DISCLAIMED. IN NO EVENT SHALL ATMEL BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
# OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# ----------------------------------------------------------------------------

set board_suffix   [lindex $argv 3 ]
set board_serial   [lindex $argv 4 ]
set factory_serial [lindex $argv 5 ]
set macAddr        [lindex $argv 6 ]
set ipcfg          [lindex $argv 7 ]

## Find out sama5d3 variant to load the corresponding dtb file
array set sama5d3_variant {
   0x00444300 sama5d31
   0x00414300 sama5d33
   0x00414301 sama5d34
   0x00584300 sama5d35
   0x00004301 sama5d36
}

set chip_variant [format "0x%08x" [read_int 0xffffee44]]
set variant_name "none"

foreach {key value} [array get sama5d3_variant] {
   if {$key == $chip_variant} {
      set variant_name $value
      break;
   }
}

if {$variant_name == "none"} {
   puts "-E- === Unknown sama5d3 variant: $chip_variant ==="
   exit
} else {
   puts "-I- Chip variant is $variant_name"
}
if {$board_suffix == "none"} {
   puts "-E- === Unknown $variant_name board ==="
   exit
} else {
   puts "-I- Board variant is $board_suffix"
}


################################################################################
#  proc uboot_env: Convert u-boot variables in a string ready to be flashed
#                  in the region reserved for environment variables
################################################################################
set board "$variant_name$board_suffix"

puts " ===================== flash.tcl ========================="

puts "board_suffix   $board_suffix"
puts "board_serial   $board_serial"
puts "factory_serial $factory_serial"
puts "macAddr        $macAddr"
puts "ipcfg          $ipcfg"
puts "board          $board"

proc set_uboot_env {nameOfLstOfVar} {
    upvar $nameOfLstOfVar lstOfVar
    
    # sector size is the size defined in u-boot CFG_ENV_SIZE
    set sectorSize [expr 0x20000 - 5]

    set strEnv [join $lstOfVar "\0"]
    while {[string length $strEnv] < $sectorSize} {
        append strEnv "\0"
    }
    # \0 between crc and strEnv is the flag value for redundant environment
    set strCrc [binary format i [::vfs::crc $strEnv]]
    return "$strCrc\0$strEnv"
}

proc macAddr_generate {} {
	set macAddr [format "0x%04x%08x" [expr int(rand()*0x100)] [expr int(rand()*0x100000000)] ]
        return $macAddr
}

################################################################################
#  Main script: Load the linux demo in NandFlash,
#               Update the environment variables
################################################################################

## Files to load
append bootstrapFile	$board "-boot.bin"
set kernelFile		"uImage-3.6.9"
append dtbFile 		$variant_name $board_suffix ".dtb"

set rootfsFile		"rootfs.ubi"
set userfsFile          "userfs.ubi"
set bootvarsFile        "bootvars.bin"
set envvarsFile         "envvars.bin"

if {! [file exists $bootstrapFile]} {
   puts "-E- === file $bootstrapFile not found ==="
   exit
}

if {! [file exists $kernelFile]} {
   puts "-E- === file $kernelFile not found ==="
   exit
}

if {! [file exists $dtbFile]} {
   puts "-E- === file $dtbFile not found ==="
   exit
}

if {! [file exists $rootfsFile]} {
   puts "-E- === file $rootfsFile not found ==="
   exit
}

if {! [file exists $userfsFile]} {
   puts "-E- === file $userfsFile not found ==="
   exit
}

## NandFlash Mapping
set bootStrapAddr	0x00000000
set bootvarsAddr        0x00040000
set envvarsAddr         0x00080000
set dtbAddr0		0x000c0000
set kernelAddr0		0x00100000
set rootfsAddr0		0x00400000
set dtbAddr1		0x03B00000
set kernelAddr1		0x03B40000
set rootfsAddr1		0x03E40000
set userfsAddr          0x07540000
## NandFlash Mapping
set kernelSize	[format "0x%08X" [file size $kernelFile]]
set dtbSize	[format "0x%08X" [file size $dtbFile]]


lappend bootvars \
    "new_firmware=0" \
    "cmd_nr=0" \
    "ddram_test=0"

if { $macAddr == "" } {
    set macAddr [macAddr_generate]
}

##"cmd0=mem=128M console=ttyS0,115200 mtdparts=atmel_nand:256k(bootstrap),256k(bootvar),256k(envvar),256k(dtb0),3M(kernel0),55M(rootfs0),256k(dtb1),3M(kernel1),55M(rootfs1),11008k(userfs),-(reserved) rootfstype=ubifs ubi.mtd=5 root=ubi0:rootfs lpj=1314816 _quiet" 
lappend envvars \
"cmd0=mem=128M console=ttyS0,115200 mtdparts=atmel_nand:256k(bootstrap),256k(bootvar),256k(envvar),256k(dtb0),3M(kernel0),55M(rootfs0),256k(dtb1),3M(kernel1),55M(rootfs1),-(userfs) rootfstype=ubifs ubi.mtd=5 root=ubi0:rootfs lpj=1314816 quiet" \
"cmd1=mem=128M console=ttyS0,115200 mtdparts=atmel_nand:256k(bootstrap),256k(bootvar),256k(envvar),256k(dtb0),3M(kernel0),55M(rootfs0),256k(dtb1),3M(kernel1),55M(rootfs1),11008k(userfs),-(reserved) rootfstype=ubifs ubi.mtd=8 root=ubi0:rootfs lpj=1314816 quiet" \
"kernelAddr0=$kernelAddr0" \
"kernelAddr1=$kernelAddr1" \
"dtbAddr0=$dtbAddr0" \
"dtbAddr1=$dtbAddr1" \
"macAddr=$macAddr" \
"ip=$ipcfg" \
"serial=$board_serial" \
"factory=$factory_serial" \
"developer=1"

puts $envvars

puts "-I- === Initialize the NAND access ==="
NANDFLASH::Init

puts "-I- === Enable PMECC OS Parameters ==="
NANDFLASH::NandHeaderValue HEADER 0xc0902405

puts "-I- === Erase all the NAND flash blocs and test the erasing ==="
NANDFLASH::EraseAllNandFlash

puts "-I- === Load the bootstrap: $bootstrapFile in the first sector ==="
NANDFLASH::SendBootFilePmeccCmd $bootstrapFile

puts "-I- === Load the boot variables ==="
set fh [open "$bootvarsFile" w]
fconfigure $fh -translation binary
puts -nonewline $fh [set_uboot_env bootvars]
close $fh
send_file {NandFlash} "$bootvarsFile" $bootvarsAddr 0 

puts "-I- === Load the environment variables ==="
set fh [open "$envvarsFile" w]
fconfigure $fh -translation binary
puts -nonewline $fh [set_uboot_env envvars]
close $fh
send_file {NandFlash} "$envvarsFile" $envvarsAddr 0 

puts "-I- === Load the Kernel image and device tree database ==="
send_file {NandFlash} "$dtbFile"    $dtbAddr0    0
send_file {NandFlash} "$kernelFile" $kernelAddr0 0

#send_file {NandFlash} "$dtbFile"    $dtbAddr1    0
#send_file {NandFlash} "$kernelFile" $kernelAddr1 0

puts "-I- === Enable trimffs ==="
NANDFLASH::NandSetTrimffs 1

puts "-I- === Load the linux file system ==="
send_file {NandFlash} "$rootfsFile" $rootfsAddr0 0
#send_file {NandFlash} "$rootfsFile" $rootfsAddr1 0
send_file {NandFlash} "$userfsFile"  $userfsAddr  0

puts "-I- === DONE. ==="
