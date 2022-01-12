#!/tvbin/tivosh

source /tvlib/tcl/tv/mfslib.tcl

set serverid [lindex $argv 0]
set callsign [lindex $argv 1]
set name [lindex $argv 2]

set db [dbopen]
RetryTransaction {
    set station [db $db create Station]
    dbobj $station set ServerId $serverid
    dbobj $station set CallSign $callsign
    dbobj $station set Name $name
}
puts "created /Server/$serverid"
