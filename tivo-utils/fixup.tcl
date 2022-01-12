#!/tvbin/tivosh
#
# fixup30.tcl 2002/07/14
#
# based upon previous fixup scripts
#


# source of RetryTransaction function
tvsource $tcl_library/tv/mfslib.tcl


proc FIXUP {db} {
    try {
	RetryTransaction {
            set now [clock seconds]
            set today [expr ($now / 86400)]
            set stateExpiration [expr ($today + 7)]
		set nextCall [expr ($stateExpiration * 86400)]
		set lastCallStatus "Succeeded"

            set sobj [db $db open /State/GeneralConfig]

		dbobj $sobj set Complete 7

            set sobj [db $db open /State/MyWorld]

		dbobj $sobj set DemoMode 0

            set sobj [db $db open /State/PhoneConfig]

		dbobj $sobj set LastCallAttemptSecInDay $now
		dbobj $sobj set LastCallStatus $lastCallStatus
		dbobj $sobj set LastDialInUpdateDate $today
		dbobj $sobj set LastSuccessCallSecInDay $now
		dbobj $sobj set LastSuccessPgdCallSecInDay $now
		dbobj $sobj set NextCallAttemptSecInDay $nextCall

            set sobj [db $db open /State/ServiceConfig]

		dbobj $sobj set ServiceState 5
		dbobj $sobj set ServiceStateExpiration $stateExpiration

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
