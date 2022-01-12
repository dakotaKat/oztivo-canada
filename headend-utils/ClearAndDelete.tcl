#!/tvbin/tivosh
#
# 1 = Clear and Delete
# 2 = Programs
# 3 = Preferences

tvsource $tcl_library/tv/setup.tcl

set db [dbopen]
transaction {
	set obj [db $db open /State/Database]
	dbobj $obj set ZapRequest 1
}
dbclose $db
