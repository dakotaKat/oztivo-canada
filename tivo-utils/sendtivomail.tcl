#!/tvbin/tivosh

source $tcl_library/tv/Inc.itcl
source $tcl_library/tv/mfslib.tcl
source $tcl_library/tv/setup.tcl

#
#Call sendtivomail.tcl 0/1 ErrorText TitleText
#
#####################################
##########   sendMessage   ##########
#####################################
proc sendMessage { error msg ttl } {

    set db [dbopen]

    set now [clock seconds]
    set msgDate [expr $now / 86400]
    set msgTime [expr $now % 86400]
    set msgFrom "TivoGuide Indexing Service"


    # dbeMessageDestinationMessageBoard
    set dest 1
    set msgPriority 2
    set msgExpire [expr ($now / 86400) + 2 ]

    if { "$error" == "1" } {
	set msgSubject "Error updating $ttl"
	set msgBody "We have encountered an error updating your program guide $ttl \n\n $msg"
    } else {
	set msgSubject "$ttl UPDATED"
  	set msgBody "The TivoGuide service has updated your program guide $ttl \n\n $msg"
    }

    RetryTransaction {
        putlog  "Creating $msgSubject Message..."
        set obj [db $db create MessageItem]
        dbobj $obj set DateGenerated $msgDate
        dbobj $obj set TimeGenerated $msgTime
        dbobj $obj set ExpirationDate $msgExpire
        dbobj $obj set From $msgFrom
        dbobj $obj set Subject $msgSubject
        dbobj $obj set Body $msgBody
        dbobj $obj set FromId $Inc::MSG_SRC_INDIV
        dbobj $obj set Priority $msgPriority
        dbobj $obj remove Destination
        dbobj $obj add Destination $dest
    }

    # send an event to MyWorld for the new Message
    putlog "Calling event send $TmkEvent::EVT_DATA_CHANGED DATA_MESSAGES 0"
    event send $TmkEvent::EVT_DATA_CHANGED $TmkDataChanged::MESSAGES 0

    dbclose $db
}

    set errn [lindex $argv 0]
    set errm [lindex $argv 1]
    set errt [lindex $argv 2]

    sendMessage $errn $errm $errt




