#!/tvbin/tivosh

source /tvlib/tcl/tv/mfslib.tcl

set channelno [lindex $argv 0]
set stationid [lindex $argv 1]
set lineupid [lindex $argv 2]

proc OpenObject {db objspec} {
     if {[string range $objspec 0 0] == "/"} {
        set obj [db $db open $objspec]
     } elseif { [regexp {([0-9]*)/(.*)} $objspec junk fsid subobjid] } {
        set obj [db $db openidconstruction $fsid $subobjid]
     } else {
        set obj [db $db openid $objspec]
     }
     return $obj
}

set db [dbopen]
RetryTransaction {
    set station [OpenObject $db $stationid]
    set stationname [dbobj $station get Name]
    puts "station $stationname"

    set lineup [OpenObject $db $lineupid]

    set channel [db $db createsub Channel $lineup]
    dbobj $channel set Number $channelno
    dbobj $channel set Station $station
    puts "channel $channelno"

    dbobj $lineup add Channel $channel
}
