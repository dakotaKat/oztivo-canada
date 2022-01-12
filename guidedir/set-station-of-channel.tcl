#!/tvbin/tivosh

source /tvlib/tcl/tv/mfslib.tcl

set channelid [lindex $argv 0]
set stationid [lindex $argv 1]

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
    set chan [OpenObject $db $channelid]
    set number [dbobj $chan get Number]
    puts "channel $number"

    set station [OpenObject $db $stationid]
    set stationname [dbobj $station get Name]
    puts "station $stationname"

    dbobj $chan set Station $station
}
