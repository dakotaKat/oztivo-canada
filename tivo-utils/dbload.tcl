#!/tvbin/tivosh

setpri fifo 1

lappend auto_path $tcl_library/tv

source $tcl_library/tv/Inc.itcl
tvsource $tcl_library/tv/EndPoint.itcl
tvsource $tcl_library/tv/SwSystem.itcl
tvsource $tcl_library/tv/Database.itcl
tvsource $tcl_library/tv/mfslib.tcl
tvsource $tcl_library/tv/Setup.itcl

namespace import Inc::*

set file [lindex $argv 0]
set id [lindex $argv 1]

set db [dbopen]
dbload $db $file
if { [llength $id] > 0 } {
   dumpobj /Server/$id
}

# update the clock to prevent "clock is warped" message from stopping index
/bin/ntpdate -b 204.176.49.10

# update the time
#putlog "processing timeService: ntpdate - dbload30"
#$cmdStr setCmd "/bin/ntpdate -b 192.168.0.254"
#$cmdStr process foo

# Tell MyWorld that there is new program data.
event send $TmkEvent::EVT_DATA_CHANGED $TmkDataChanged::PROGRAM_GUIDE 0

