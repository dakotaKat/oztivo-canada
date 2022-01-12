#!/tvbin/tivosh
#
# source of RetryTransaction function
tvsource $tcl_library/tv/mfslib.tcl

proc FIXUP {db} {
    try {
        RetryTransaction {
            set sobj [db $db open /State/GeneralConfig]
                dbobj $sobj set Complete 7
        }
    } catch errCode {
        puts "Failed to FIXUP, code=($errCode)"
        return 0
    }
    return 1
}

set db [dbopen]
FIXUP $db
dbclose $db
