#!/tvbin/tivosh
#
# thanks to Phil Hunt for this script

# source of RetryTransaction function
tvsource $tcl_library/tv/mfslib.tcl

proc FIXUP {db} {
    try {
        RetryTransaction {
            set sobj [db $db open /State/PhoneConfig]
                dbobj $sobj set DialConfig 127
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
