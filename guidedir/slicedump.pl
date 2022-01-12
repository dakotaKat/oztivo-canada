#!/usr/bin/perl
#
# TiVo slice file dumper.
#
=pod


Usage
-----

SliceDump.pl slice_file

slice_file                    The name of the TiVo slice file that will 
be
                              dumped to stdout.


Description
-----------

This Perl script is intended to be used to dump the data in TiVo slice files.
It embodies the rules for slice file format and knows about the most common
slice file records.  It also does rudimentary quality assurance checking to
assist one in creating valid slice files.


Output
------

This script will dump a TiVo slice file, with all the records/fields broken
out and described, as output on stdout.  You may want to redirect the output
to a file via "perl SliceDump.pl slice_file >output_file".  The output is
supposed to be self-explanatory.


Numbers Format
--------------

All TiVo numerics have a special expanding format that is designed to save
space (and just maybe confuse the heck out of us reverse engineers).  
They work by reserving either two or four bits in the first byte of any 
number for the number length code.  The first two or four bits encode the 
length as follows:

     00   - A single byte.
     10   - Two bytes.
     11   - Three or more bytes (determined by the next two bits).
     1100 - Three bytes.
     1110 - Four bytes.
     1111 - Five bytes.

Additionally (according to TiVo's rules), the largest number a single byte
can encode is 0x3F.  Two bytes can encode 0x0FFF as their largest number
(which would appear as 0x8FFF).  Three bytes can encode 0x0FFFFF (which
would appear as 0xCFFFFF), while four and five bytes can encode 0x0FFFFFFF
(appearing as 0xEFFFFFFF) and 0xFFFFFFFF (appearing as 0xF0FFFFFFFF),
respectively.

Meanwhile, to read and decode a numeric, look at the high bit of the 
first byte of the number.  If it is on (i.e. 0x80), the number expands to 
more than one byte.  Next, check to see if the high four bits are 0xF0, 
0xE0, 0xC0 or 0x80.  If so, the number has four through one extra bytes.

This pretty much explains why you see all those 0x80s and 0xC0s in the
numeric data, doesn't it?


Overall Format
--------------

 +0    1   First byte of file (don't know its significance but have seen
           claims it has something to do with spanning or partial files.
           Everybody I know uses 0x03).
 +1    4   Length of record (excluding the length iself).  \
 +5    2   Record type.                                     +-- Repeats
 +7    x   Record data (variable length).                  /
 +y        More records follow until the end.

 Notes: 1) All data is in network byte order (i.e. hi-byte first, etc.).


Program Type Record - 0x0103
----------------------------

 +0    4   Length of record (excluding the length itself).
 +1    2   0x0103 - program record.
 +6    a   Numeric server ID (see above for the numbers story).
 +6+a  b   Numeric server version (same).
 ...   1   Field type (see below).
       c   Variable information follows, depending on field.
           More fields follow until the end.

     Program Record Fields
     ---------------------

     0x00      0    End of list marker.
     0x41 A    x    TmsID (Times/Mirror ID).
     0x45 E    x    Movie/show title.
     0x4A J    z    Index tuple which points to the associated title type
                    record.  The tuple consists of an object type, attribute
                    and link (server ID).
     0x4D M    x    Description (seems like the maximum length is 0xC8 or,
                    at least, Tridge seems to think so, but then maybe not).
     0x51 Q    x    Language string (e.g. "English").
     0x54 T    y    Show type.
     0x58 X    y    Numeric release date (for all reasonable dates this will
                    always be two bytes).
     0x5C \    y    MPAA rating.
     0x60 `    y    Star rating.
     0x64 d    y    Numeric movie run time (see above for the numbers story).
     0x69 i    x    Country (e.g. "USA").
     0x6D m    x    Network source.
     0x70 p    y    Source type.
     0x75 u    y    Episode title.
     0x78 x    y    Advisory.
     0x7D }    x    Actor's name (last name first, separated from first
                    name, middle initial by "|".  E.g. "Blow|Joe M.").
     0x81      x    Guest star's name (last name first, separated from first
                    name, middle initial by "|".  E.g. "Blow|Joe M.").
     0x85      x    Director's name (last name first, separated from first
                    name, middle initial by "|").
     0x89      x    Executive producer's name (last name first, separated
                    from first name, middle initial by "|").
     0x8D      x    Producer's name (last name first, separated from first
                    name, middle initial by "|").
     0x91      x    Writer's name (last name first, separated from first
                    name, middle initial by "|").
     0x95      x    Show host's name (last name first, separated from first
                    name, middle initial by "|").
     0x9C      y    Numeric genre number (see above for the numbers story).
     0xA0      y    Color code.
     0xA4      y    Episode number.
     0xA8      y    Original episode number.
     0xB4      y    Is episode (0x00 = no, 0x01 = yes).  Should be set to
                    yes for shows that repeat and may or may not use the
                    same description over and over.  We'll have to see.
     0xC4      y    Original air date.

     Notes: 1) Fields with length "x" have a length following the
               field type.  These lengths are numerics (see the numbers
               story, above), just like everywhere else.
            2) Numbers, where used (shown with a length of "y"), are
               expandable, according to the numbers story (see above).
            3) Index tuples, where used (shown with a length of "z"), are
               composed of three expandable numbers, one after the other.
               Each of these numbers expands according to the numbers story
               (see above).


Series Type Record - 0x0104
---------------------------

 +0    4   Length of record (excluding the length itself).
 +1    2   0x0104 - series record.
 +6    a   Numeric server ID (see above for the numbers story).
 +6+a  b   Numeric server version (same).
 ...   1   Field type (see below).
       c   Variable information follows, depending on field.
           More fields follow until the end.

     Series Record Fields
     --------------------

     0x00      0    End of list marker.
     0x41 A    x    TmsID (Times/Mirror ID).
     0x45 E    x    Movie/show title.
     0x50 P    y    Numeric genre number (see above for the numbers story).
     0x58 X    y    Flag indicating whether show is episodic.

     Notes: 1) Fields with length "x" have a length following the
               field type.  These lengths are numerics (see the numbers
               story, above), just like everywhere else.
            2) Numbers, where used (shown with a length of "y"), are
               expandable, according to the numbers story (see above).


Station Type Record - 0x0105
----------------------------

 +0    4   Length of record (excluding the length itself).
 +1    2   0x0105 - station record.
 +6    a   Numeric server ID (see above for the numbers story).
 +6+a  b   Numeric server version (same).
 ...   1   Field type (see below).
       c   Variable information follows, depending on field.
           More fields follow until the end.

     Station Record Fields
     ---------------------

     0x00      0    End of list marker.
     0x41 A    x    TmsID (Times/Mirror ID).
     0x45 E    x    Full name of station.
     0x49 E    x    Call sign of station.
     0x4D M    x    City where station is located.
     0x51 M    x    State where station is located.
     0x55 U    x    Zipcode of station.
     0x59 Y    x    Country where station is located.
     0x5D ]    x    Affilitation (e.g. satellite).
     0x61 a    x    DMA name (undoubtedly having to do with the Direct
                    Marketing Association and how we can sell you more
                    shit rather than Direct Memory Access).
     0x64 d    y    DMA number (see above for the numbers story).
     0x68 h    y    FCC broadcast channel number.
     0x6C l    y    Logo index (0x10000 == TiVo space).
     0x70 p    y    Affiliation index (see above for the numbers story).
     0x74 y    y    Pay per view flag.

     Notes: 1) Fields with length "x" have a length following the
               field type.  These lengths are numerics (see the numbers
               story, above), just like everywhere else.
            2) Numbers, where used (shown with a length of "y"), are
               expandable, according to the numbers story (see above).


Station Day Type Record - 0x0106
--------------------------------

 +0    4   Length of record (excluding the length itself).
 +1    2   0x0106 - station day record.
 +6    a   Numeric server ID (see above for the numbers story).
 +6+a  b   Numeric server version (same).
 ...   1   Field type (see below).
       c   Variable information follows, depending on field.
           More fields follow until the end.

     Station Day Record Fields
     -------------------------

     0x00      0    End of list marker.
     0x42 B    z    Index tuple which points to the associated station and
                    program records.  The tuple consists of an object type
                    (which indicates which type of record it points to),
                    attribute and link (server ID).
     0x44 D    y    Day number (number of days from the epoch).
     0x46 F    z    Another index tuple which points to the associated
                    station record within each showing detail slot.  The
                    tuple consists of an object type (which indicates which
                    type of record it points to), attribute and link (server
                    ID).
     0x48 H    y    Date in showing detail (number of days from the epoch).
     0x4A J    w    Slot tag for program showing in this time slot.
     0x4C L    y    Start time of slot (in seconds from midnight).
     0x50 P    y    Duration of slot (in seconds).
     0x54 T    y    Part index.
     0x58 X    y    Part count.
     0x5C \    y    Premiere number.
     0x60 `    y    Live program number.
     0x64 d    y    Bits (don't know what this is).
     0x6C l    y    Don't index flag.
     0x70 p    y    TV rating.
     0x7C |    y    Dolby program material.

     Notes: 1) Numbers, where used (shown with a length of "y"), are
               expandable, according to the numbers story (see above).
            2) Index tuples, where used (shown with a length of "z"), are
               composed of three expandable numbers, one after the other.
               Each of these numbers expands according to the numbers story
               (see above).
            3) Slot numbers, where used (shown with a length of "w"), are
               composed of two expandable numbers, one after the other.
               Each of these numbers expands according to the numbers story
               (see above).

After the list of slot tags (0x4A) for all of the programs in the station's
day, an end field occurs (0x00).  Following this field is a two-number slot
ID which is then followed by the slot detail data for that slot.  The detail
data uses field tags just like those shown above.  At the end of the slot
detail is an end field (0x00).  The two-number slot ID and slot detail data
repeats once for each slot listed by the slot tags (0x4A).  This whole
series of slots and slot details looks like this:

     0x4A,m,0x0A       Slot tag 1 (seems to start at 10 or 12).
     0x4A,m,0x0B       Slot tag 2.
     0x4A,m,0x0C       Slot tag 3.
               .
               .
               .
     0x4A,m,n          Slot tag n.
     0x00              End of slot list.
     m,0x0A,slot-info  Slot 1 detail.
     0x00              End of slot 1 detail.
     m,0x0B,slot-info  Slot 2 detail.
     0x00              End of slot 2 detail.
     m,0x0C,slot-info  Slot 3 detail.
     0x00              End of slot 3 detail.
               .
               .
               .
     m,n,slot-info     Slot n detail.
     0x00              End of slot n detail.  The end of it all when n
                       slots reached.


=cut
#
# Include useful modules.
#
use FileHandle;
#
# Field types and how to process them.
#
# Each type has a format:
#
#      I - Index tuple numeric field (see the story about expanding numbers).
#      L - Logo index numeric field (see the story about expanding numbers)
#          where the TiVo space is 0x10000.
#      N - Numeric field (see the story about expanding numbers).
#      S - String, length follows.
#      T - Time slot pair numeric field (see the story about expanding
#          numbers).
#      0 - End of data marker.
#      n - One through 9 byte field (fixed length).  Used to skip over fields
#          for debugging purposes until you really figure them out
#
%ProgramTable = (                                       # 0x0103
        0x00, "0|End",                                  # End of data marker
        0x41, "S|TmsID",                                # TmsID (Times/Mirror ID)
        0x45, "S|Title",                                # Movie/episode title
        0x4A, "I|Index",                                # Index tuple
        0x4D, "S|Description",                  # Description
        0x51, "S|Language",                             # Language string
        0x54, "N|Show Type",                    # Show type
        0x58, "N|Date",                         # Release date
        0x5C, "N|MPAA Rating",                  # MPAA rating
        0x60, "N|Star Rating",                  # Star rating
        0x64, "N|Time",                         # Movie run time
        0x69, "S|Country",                              # Country
        0x6D, "S|Network Source",               # Network source
        0x70, "N|Source Type",                  # Source type
        0x75, "S|Episode Title",                        # Episode title
        0x78, "N|Advisory",                             # Advisory
        0x7D, "S|Actor",                                # Actor's name
        0x81, "S|Guest Star",                   # Guest star's name
        0x85, "S|Director",                             # Director's name
        0x89, "S|Executive Producer",           # Executive Producer's name
        0x8D, "S|Producer",                             # Producer's name
        0x91, "S|Writer",                               # Writer's name.
        0x95, "S|Host",                         # Show host's name
        0x9C, "N|Genre",                                # Genre number
        0xA0, "N|Color",                                # Color code
        0xA4, "N|Episode Number",               # Episode number
        0xA8, "N|Original Episode",             # Original episode number
        0xB4, "N|Is Episode",                   # Is episode
        0xC4, "N|Original Air Date",            # Original air date
        0xFF, "0|Junk");                                # Placeholder

%SeriesTable = (                                        # 0x0104
        0x00, "0|End",                                  # End of data marker
        0x41, "S|TmsID",                                # TmsID (Times/Mirror ID)
        0x45, "S|Title",                                # Movie/episode title
        0x50, "N|Genre",                                # Genre number
        0x58, "N|Is Episodic",                  # Flag indicating show is episodic
        0xFF, "0|Junk");                                # Placeholder

%StationTable = (                                       # 0x0105
        0x00, "0|End",                                  # End of data marker
        0x41, "S|TmsID",                                # TmsID (Times/Mirror ID)
        0x45, "S|Name",                         # Station name
        0x49, "S|Call Sign",                    # Call sign
        0x4D, "S|City",                         # City where station is located
        0x51, "S|State",                                # State where station is located
        0x55, "S|Zip Code",                             # Zip code of station
        0x59, "S|Country",                              # Contry where station is located
        0x5D, "S|Affiliation",                  # Affiliation (e.g. satellite)
        0x61, "S|DMA Name",                             # DMA name
        0x64, "N|DMA Number",                   # DMA number
        0x68, "N|FCC Channel Number",           # FCC broadcast channel number
        0x6C, "L|Logo Index",                   # Logo index
        0x70, "N|Affiliation Index",            # Affiliation index
        0x74, "N|Pay Per View",                 # Pay per view flag
        0xFF, "0|Junk");                                # Placeholder

%StationDayTable = (                            # 0x0106
        0x00, "T|Showing Detail",               # Showing detail information.  Note
                                                                # that this is really the end of data
                                                                # marker but it made the program a lot
                                                                # easier to write if we used it as a
                                                                # field start tag for the showing
                                                                # detail info.  Giant kludge.
        0x42, "I|Index 1",                              # Index tuple
        0x44, "N|Day",                                  # Day in question
        0x46, "I|Index 2",                              # Index tuple
        0x48, "N|Date",                         # Date
        0x4A, "T|Showing",                              # Program showing in this time slot
        0x4C, "N|Time",                         # Start time of slot (in seconds)
        0x50, "N|Duration",                             # Duration of slot (in seconds)
        0x54, "N|Part Index",                   # Part index
        0x58, "N|Part Count",                   # Part count
        0x5C, "N|Premiere",                             # Premiere number
        0x60, "N|Live",                         # Live program number
        0x64, "N|Bits",                         # Huh?
        0x6C, "N|Don't Index",                  # Don't index flag
        0x70, "N|TV Rating",                    # Rating
        0x7C, "N|Dolby",                                # Dolby program material
        0xFF, "0|Junk");                                # Placeholder
#
# Error checking information.
#
$NumErrors = 0;                                 # Count of numeric errors
$IxErrors = 0;                                          # Count of index errors
%IndexFound = ();                                       # Table of indexes found
%IndexPointer = ();                                     # Table of index pointers
#
# Local variables.
#
my ($InputFile, $InputHand);
my ($ReadLen, $ReadBuf);
my $Offset = 0;
my $EndOffset = 999999999;
my ($CmdLnOffset);
#
# Get the input file name and open it up.
#
$InputFile = shift or die("No input file name supplied");

$InputHand = new FileHandle;

$InputHand->open("<$InputFile") or die("Can't open input file 
$InputFile: $!");
binmode($InputHand);

print("Dumping slice file $InputFile\n");
#
# See if there's a maximum byte offset on the command line.  If so, only
# dump to there.
#
$CmdLnOffset = shift;
$EndOffset = $CmdLnOffset if (defined($CmdLnOffset));
#
# Read the first byte of the slice and dump it.
#
$ReadLen = $InputHand->read($ReadBuf, 1);
$Offset += $ReadLen;

printf("\nFirst byte %02x\n", unpack("C", $ReadBuf));
#
# Read all of the records, one at a time.
#
while (($Offset < $EndOffset)
        && (($ReadLen = $InputHand->read($ReadBuf, 4)) == 4))
        {
        my $RecordLen = unpack("N", $ReadBuf);
        my $RecordName = "Unknown";
        my $ptFieldTable = 0;

        $Offset += $ReadLen;
        #
        # Read a record with the given length.
        #
        die("Last record's length is too short")
                if (($ReadLen = $InputHand->read($ReadBuf, $RecordLen)) != 
$RecordLen);
        #
        # Decide what to do with the record.
        #
        my $RecordType = unpack("n", $ReadBuf);
        $ReadBuf = substr($ReadBuf, 2);

        if ($RecordType == 0x0103)
                { $RecordName = "Program"; $ptFieldTable = \%ProgramTable; }
        elsif ($RecordType == 0x0104)
                {$RecordName = "Series"; $ptFieldTable = \%SeriesTable; }
        elsif ($RecordType == 0x0105)
                { $RecordName = "Station"; $ptFieldTable = \%StationTable; }
        elsif ($RecordType == 0x0106)
                { $RecordName = "Station Day"; $ptFieldTable = \%StationDayTable; }

        printf("\n%08x - Record %04x (%s), Length %08x\n", $Offset, $RecordType,
                $RecordName, $RecordLen);

        $Offset += $ReadLen;
        #
        # Dump any fixed format data first.
        #
        # For most record types, there are two numerics that give the server ID
        # and version.  The first is essentially the record's index number and
        # the second identifies the version of the record.
        #
        if (($RecordType == 0x0103) || ($RecordType == 0x0104)
                || ($RecordType == 0x0105) || ($RecordType == 0x0106))
                {
                my ($ServerID, $ServerVer, $NumLen);

                ($ServerID, $NumLen) = GetNumeric($ReadBuf);
                $ReadBuf = substr($ReadBuf, $NumLen);

                ($ServerVer, $NumLen) = GetNumeric($ReadBuf);
                $ReadBuf = substr($ReadBuf, $NumLen);

                print("  Server ID, version = $ServerID, $ServerVer\n");
                #
                # Save each record's index so that we can verify that they aren't
                # orphaned or duplicated.
                #
                if (exists($IndexFound{$ServerID}))
                        {
                        print("  Error - Index $ServerID is used more than once\n");
                        $IxErrors++;
                        }
                else { $IndexFound{$ServerID} = ($RecordType & 0xFF); }
                }
        #
        # For other record types, we have no clue.
        #
        else
                {
                print("  Unknown record type = ");

                while (length($ReadBuf) > 0)
                        {
                        printf("%02x", unpack("C", $ReadBuf));
                        $ReadBuf = substr($ReadBuf, 1);
                        }

                print("\n");
                }
        #
        # Process all of the fields.
        #
        while (length($ReadBuf) > 0)
                {
                my $FieldType = unpack("C", $ReadBuf);
                $ReadBuf = substr($ReadBuf, 1);
                #
                # If we know what this field type is, format it accordingly.
                #
                if (exists($ptFieldTable->{$FieldType}))
                        {
                        my ($Format, $Title);
                        #
                        # Get the format and title string.
                        #
                        $ptFieldTable->{$FieldType} =~ /^(.+)\|(.+)$/;
                        $Format = $1; $Title = $2;
                        #
                        # Process each field according to format.
                        #
                        # Field is a numeric index tuple.
                        #
                        if ($Format eq "I")
                                {
                                my ($ObjType, $Attr, $Index, $NumLen);

                                ($ObjType, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                ($Attr, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                ($Index, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                print("  $Title = $ObjType, $Attr, $Index");

                                if ($ObjType == 3) { print(" --> program record\n"); }
                                elsif ($ObjType == 4) { print(" --> series record\n"); }
                                elsif ($ObjType == 5) { print(" --> station record\n"); }
                                elsif ($ObjType == 6)
                                        { print(" --> station day record\n"); }
                                else { print("\n"); }
                                #
                                # Save index pointers for later checking to see that they
                                # actually point to something.
                                #
                                $IndexPointer{$Index} = $ObjType;
                                }
                        #
                        # Field is a logo index.
                        #
                        elsif ($Format eq "L")
                                {
                                my ($Value, $NumLen);

                                ($Value, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                if (($Value & 0xFFFF0000) == 0x10000)
                                        {
                                        $Value &= 0xFFFF;
                                        print("  $Title = Space TiVo, Index $Value\n");
                                        }
                                else { print("  $Title = $Value\n"); }
                                }
                        #
                        # Field is numeric.
                        #
                        elsif ($Format eq "N")
                                {
                                my ($Value, $NumLen);

                                ($Value, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                print("  $Title = $Value\n");
                                }
                        #
                        # Field is a string.
                        #
                        elsif ($Format eq "S")
                                {
                                my ($StrLen, $NumLen);

                                ($StrLen, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                if ($StrLen > length($ReadBuf))
                                        {
                                        printf("  $Title length is whacked, junk = %02x",
                                                $StrLen);

                                        while (length($ReadBuf) > 0)
                                                {
                                                printf("%02x", unpack("C", $ReadBuf));
                                                $ReadBuf = substr($ReadBuf, 1);
                                                }

                                        print("\n");
                                        }
                                else
                                        {
                                        print("  $Title = ".substr($ReadBuf, 0, $StrLen)."\n");
                                        $ReadBuf = substr($ReadBuf, $StrLen);
                                        }
                                }
                        #
                        # Field is a numeric time slot pair.
                        #
                        # Note that the length check is used in conjunction with the
                        # showing info field ID kludge.
                        #
                        if ($Format eq "T")
                                {
                                my ($Type, $Value, $NumLen);

                                next if (length($ReadBuf) < 2);

                                ($Type, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                ($Value, $NumLen) = GetNumeric($ReadBuf);
                                $ReadBuf = substr($ReadBuf, $NumLen);

                                print("  $Title = $Type, $Value\n");
                                }
                        #
                        # Field is the end of data marker.  Just ignore it.
                        #
                        elsif ($Format eq "0") { next; }
                        #
                        # Field is fixed length (1-9).
                        #
                        elsif (($Format ge "1") && ($Format le "9"))
                                {
                                printf("  $Title = ");

                                while ($Format > 0)
                                        {
                                        printf("%02x", unpack("C", $ReadBuf));
                                        $ReadBuf = substr($ReadBuf, 1);
                                        $Format--;
                                        }

                                print("\n");
                                }
                        }
                #
                # Otherwise, its hex dump to the end of the record time (no chance
                # for synch up).
                #
                else
                        {
                        printf("  Unknown field type %02x = ", $FieldType);

                        while (length($ReadBuf) > 0)
                                {
                                printf("%02x", unpack("C", $ReadBuf));
                                $ReadBuf = substr($ReadBuf, 1);
                                }

                        print("\n");
                        }
                }
        }

die("Bad length somewhere") if ($ReadLen != 0);
#
# Error reporting.
#
my ($Index, $ObjType);

print("\nError Analysis\n");

print("  There were $NumErrors numeric errors\n") if ($NumErrors > 1);

while (($Index, $ObjType) = each %IndexPointer)
        {
        if (!exists($IndexFound{$Index}))
                {
                if ($ObjType == 0x05)
                        { print("  Warning - Station index $Index may point to limbo\n"); }
                else { print("  Error - Index $Index points to limbo\n"); }
                $IxErrors++;
                }
        elsif ($IndexFound{$Index} != $ObjType)
                {
                print("  Error - Index $Index points to wrong type record: $ObjType 
!=".$IndexFound{$Index}."\n");
                $IxErrors++;
                }
        }

while (($Index, $ObjType) = each %IndexFound)
        {
        next if ($ObjType == 6);
        if (!exists($IndexPointer{$Index}))
                {
                print("  Error - Record $Index is orphaned\n");
                $IxErrors++;
                }
        }

print("  There were $IxErrors index errors/warnings\n") if ($IxErrors > 
1);

print("  This file looks pretty good!\n")
        if (($NumErrors <= 0) && ($IxErrors <= 0));
#
# Close up shop.
#
$InputHand->close;
undef $InputHand;

exit 0;
###############################################################################
sub GetNumeric
#
# ByteStream                            The byte stream from which the numeric
#                                       value is to be retrieved.  It is
#                                       assumed that the number begins with
#                                       the first byte of this stream.
#
# returns                               An array consisting of two elements.
#                                       The first is the numeric value and the
#                                       second is a count of the number of
#                                       bytes (1-5) that the numeric uses.
#
# This routine extracts a variable length, expandable, numeric value from the
# byte stream passed to it.  It returns the numeric value and a count of how
# many bytes should be skipped to reach the end of the numeric in the byte
# stream.
#
# All TiVo numerics have a special expanding format that is designed to save
# space.  They work by reserving either two or four bits in the first byte of
# any number for the number length code.  The first two or four bits encode
# the length as follows:
#
#      00   - A single byte.
#      10   - Two bytes.
#      11   - Three or more bytes (determined by the next two bits).
#      1100 - Three bytes.
#      1110 - Four bytes.
#      1111 - Five bytes.
#
# To read and decode a numeric, this routine looks at the high bit of the
# first byte in the stream passed to it.  If it is on (i.e. 0x80), the number
# expands to more than one byte.  Next, it checks to see if it is 0xF0, 0xE0,
# 0xC0 or 0x80.  If so, the number has four through one extra bytes and the
# length code is used to determine how many bytes to fetch and add to the
# number.
#
{
my ($ByteStream) = @_;
my ($Result, $ResultLen);
my ($FetchByte);
#
# Fetch the first byte and see wot's wot.
#
$FetchByte = unpack("C", $ByteStream);

if ($FetchByte & 0x80)
        {
        my ($Junk, $FetchWord);
        #
        # See how many extra bytes to add.
        #
        if (($FetchByte & 0xF0) == 0xF0)
                {
                $FetchByte &= 0x0F; $ResultLen = 4;
                ($Junk, $FetchWord) = unpack("C N", $ByteStream);
                }
        elsif (($FetchByte & 0xF0) == 0xE0)
                {
                $FetchByte = 0; $ResultLen = 3;
                $FetchWord = unpack("N", $ByteStream); $FetchWord &= 0x0FFFFFFF;
                }
        elsif (($FetchByte & 0xF0) == 0xC0)
                {
                $FetchByte &= 0x0F; $ResultLen = 2;
                ($Junk, $FetchWord) = unpack("C n", $ByteStream);
                }
        elsif (($FetchByte & 0xC0) == 0x80)
                {
                $FetchByte = 0; $ResultLen = 1;
                $FetchWord = unpack("n", $ByteStream); $FetchWord &= 0x3FFF;
                }
        else
                {
                printf("  Error - Next field contains an improperly tagged numeric 
value: %02x\n",
                        $FetchByte);
                $NumErrors++;
                }
        #
        # Put it all together.
        #
        $Result = ($FetchByte << (8 * $ResultLen)) | $FetchWord;
        $ResultLen++;
        }
#
# Its just a single byte number.
#
else { $Result = $FetchByte; $ResultLen = 1; }
#
# Quality assurance time.  It is possible to pack too much data into the 1-
# and 2-byte numerics.  Check for this.
#
if ((($ResultLen == 1) && ($Result > 0x3F)) ||
        (($ResultLen == 2) && ($Result > 0x0FFF)))
        {
        printf("  Error - Next field contains an improperly packed numeric 
value: %04x\n",
                $Result);
        $NumErrors++;
        }
#
# Return the result array.
#
return ($Result, $ResultLen);
}
