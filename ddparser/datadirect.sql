drop database IF EXISTS tvdata;
create database tvdata;
use tvdata;
grant all on tvdata.* to 'dbuser'@'localhost' identified by 'dbpassword';
drop table if exists MpaaRatings ;
create table MpaaRatings (
    mpaarating_id integer unsigned not null primary key auto_increment,
    mpaarating char(6),
    tivorating integer unsigned
) TYPE=INNODB;
INSERT INTO MpaaRatings VALUES ( NULL, "G", 1 );
INSERT INTO MpaaRatings VALUES ( NULL, "PG", 2 );
INSERT INTO MpaaRatings VALUES ( NULL, "PG-13", 3 );
INSERT INTO MpaaRatings VALUES ( NULL, "R", 4 );
INSERT INTO MpaaRatings VALUES ( NULL, "X", 5 );
INSERT INTO MpaaRatings VALUES ( NULL, "NC", 6 );
INSERT INTO MpaaRatings VALUES ( NULL, "NC-17", 6 );
INSERT INTO MpaaRatings VALUES ( NULL, "AO", 7 );
INSERT INTO MpaaRatings VALUES ( NULL, "NR", 8 );

drop table if exists TvRatings ;
create table TvRatings (
    tvrating_id integer unsigned not null primary key auto_increment,
    
    tvrating char(6),
    tivorating integer unsigned
) TYPE=INNODB;
INSERT INTO TvRatings VALUES ( NULL, "TV-Y7", 1 );
INSERT INTO TvRatings VALUES ( NULL, "TV-Y", 2 );
INSERT INTO TvRatings VALUES ( NULL, "TV-G", 3 );
INSERT INTO TvRatings VALUES ( NULL, "TV-PG", 4 );
INSERT INTO TvRatings VALUES ( NULL, "TV-14", 5 );
INSERT INTO TvRatings VALUES ( NULL, "TV-MA", 6 );

drop table if exists ShowTypes ;
create table ShowTypes (
    showtype_id integer unsigned auto_increment primary key,
    showtype char(32) not null,
    tivovalue integer unsigned

) TYPE=INNODB;

INSERT INTO ShowTypes VALUES ( NULL, "Serial", 1 );
INSERT INTO ShowTypes VALUES ( NULL, "Short film", 2 );
INSERT INTO ShowTypes VALUES ( NULL, "Special", 3 );
INSERT INTO ShowTypes VALUES ( NULL, "Limited series", 4 );
INSERT INTO ShowTypes VALUES ( NULL, "Series", 5 );
INSERT INTO ShowTypes VALUES ( NULL, "Miniseries", 6 );
INSERT INTO ShowTypes VALUES ( NULL, "Paid programming", 7 );

drop table if exists StarRatings ;
create table StarRatings (
    starrating_id integer unsigned not null auto_increment primary key,
    
    starrating char(5),
    tivorating integer unsigned
) TYPE=INNODB;
INSERT INTO StarRatings VALUES ( NULL, "*", 1 );
INSERT INTO StarRatings VALUES ( NULL, "*+", 2 );
INSERT INTO StarRatings VALUES ( NULL, "**", 3 );
INSERT INTO StarRatings VALUES ( NULL, "**+", 4 );
INSERT INTO StarRatings VALUES ( NULL, "***", 5 );
INSERT INTO StarRatings VALUES ( NULL, "***+", 6 );
INSERT INTO StarRatings VALUES ( NULL, "****", 7 );

drop table if exists Advisories ;
create table Advisories (
    advisory_id integer unsigned not null primary key auto_increment,

    tivoadvisory integer unsigned,
    advisory varchar( 32 )
) TYPE=INNODB;
INSERT INTO Advisories VALUES ( NULL, 10, "Adult Situations" );
INSERT INTO Advisories VALUES ( NULL, 8, "Adolescentes y Adultos" );
INSERT INTO Advisories VALUES ( NULL, 10, "Adultos" );
INSERT INTO Advisories VALUES ( NULL, 4, "Brief Nudity" );
INSERT INTO Advisories VALUES ( NULL, 2, "Graphic Language" );
INSERT INTO Advisories VALUES ( NULL, 5, "Graphic Violence" );
INSERT INTO Advisories VALUES ( NULL, 1, "Language" );
INSERT INTO Advisories VALUES ( NULL, 7, "Mild Violence" );
INSERT INTO Advisories VALUES ( NULL, 3, "Nudity" );
INSERT INTO Advisories VALUES ( NULL, 8, "Publico General" );
INSERT INTO Advisories VALUES ( NULL, 9, "Rape" );
INSERT INTO Advisories VALUES ( NULL, 8, "Strong Sexual Content" );
INSERT INTO Advisories VALUES ( NULL, 6, "Violence" );

drop table if exists Genres ;
create table Genres (
    genre_id integer unsigned not null auto_increment primary key,

    genre varchar( 32 ),
    tivogenre integer unsigned,
    
    INDEX ( genre )
) TYPE=INNODB;
/* Toplevels
 1000 = Interests
 1001 = Children
 1002 = Comedy
 1003 = Daytime
 1004 = Documentary
 1005 = Drama
 1006 = Movies
 1007 = News and Business
 1008 = Science and Nature
 1009 = Sports
 1010 = Talk Shows
 1011 = Action Adventure
 1012 = Educational
 1013 = Mystery and Suspense
 1014 = Sci-Fi and Fantasy
 1016 = Arts
 */
INSERT INTO Genres VALUES ( NULL, "Action", 1 );
INSERT INTO Genres VALUES ( NULL, "Action", 1011 );
INSERT INTO Genres VALUES ( NULL, "Adults only", 2 );
INSERT INTO Genres VALUES ( NULL, "Adults only", 1000 );
INSERT INTO Genres VALUES ( NULL, "Adventure", 1 );
INSERT INTO Genres VALUES ( NULL, "Adventure", 1011 );
INSERT INTO Genres VALUES ( NULL, "Aerobics", 133 );
INSERT INTO Genres VALUES ( NULL, "Agriculture", 134 );
INSERT INTO Genres VALUES ( NULL, "Agriculture", 1000 );
INSERT INTO Genres VALUES ( NULL, "Animals", 3 );
INSERT INTO Genres VALUES ( NULL, "Animals", 1008 );
INSERT INTO Genres VALUES ( NULL, "Animated", 4 );
INSERT INTO Genres VALUES ( NULL, "Animated", 1000 );
INSERT INTO Genres VALUES ( NULL, "Anime", 135 );
INSERT INTO Genres VALUES ( NULL, "Anime", 1000 );
INSERT INTO Genres VALUES ( NULL, "Anthology", 5 );
INSERT INTO Genres VALUES ( NULL, "Anthology", 1000 );
INSERT INTO Genres VALUES ( NULL, "Archery", 136 );
INSERT INTO Genres VALUES ( NULL, "Arm wrestling", 137 );
INSERT INTO Genres VALUES ( NULL, "Art", 6 );
INSERT INTO Genres VALUES ( NULL, "Art", 1016 );
INSERT INTO Genres VALUES ( NULL, "Arts/crafts", 138 );
INSERT INTO Genres VALUES ( NULL, "Arts/crafts", 1016 );
INSERT INTO Genres VALUES ( NULL, "Auction", 139 );
INSERT INTO Genres VALUES ( NULL, "Auction", 1000 );
INSERT INTO Genres VALUES ( NULL, "Auto", 7 );
INSERT INTO Genres VALUES ( NULL, "Auto", 1000 );
INSERT INTO Genres VALUES ( NULL, "Auto racing", 140 );
INSERT INTO Genres VALUES ( NULL, "Aviation", 141 );
INSERT INTO Genres VALUES ( NULL, "Aviation", 1000 );
INSERT INTO Genres VALUES ( NULL, "Awards", 9 );
INSERT INTO Genres VALUES ( NULL, "Awards", 1000 );
INSERT INTO Genres VALUES ( NULL, "Badminton", 142 );
INSERT INTO Genres VALUES ( NULL, "Ballet", 10 );
INSERT INTO Genres VALUES ( NULL, "Ballet", 1016 );
INSERT INTO Genres VALUES ( NULL, "Baseball", 11 );
INSERT INTO Genres VALUES ( NULL, "Basketball", 12 );
INSERT INTO Genres VALUES ( NULL, "Beach soccer", 143 );
INSERT INTO Genres VALUES ( NULL, "Beach volleyball", 144 );
INSERT INTO Genres VALUES ( NULL, "Biathlon", 145 );
INSERT INTO Genres VALUES ( NULL, "Bicycle", 14 );
INSERT INTO Genres VALUES ( NULL, "Bicycle", 1000 );
INSERT INTO Genres VALUES ( NULL, "Bicycle racing", 146 );
INSERT INTO Genres VALUES ( NULL, "Billiards", 15 );
INSERT INTO Genres VALUES ( NULL, "Biography", 16 );
INSERT INTO Genres VALUES ( NULL, "Biography", 1004 );
INSERT INTO Genres VALUES ( NULL, "Blackjack", 237 );
INSERT INTO Genres VALUES ( NULL, "Blackjack", 1000 );
INSERT INTO Genres VALUES ( NULL, "Boat", 17 );
INSERT INTO Genres VALUES ( NULL, "Boat", 1000 );
INSERT INTO Genres VALUES ( NULL, "Boat racing", 147 );
INSERT INTO Genres VALUES ( NULL, "Bobsled", 148 );
INSERT INTO Genres VALUES ( NULL, "Bodybuilding", 18 );
INSERT INTO Genres VALUES ( NULL, "Bowling", 19 );
INSERT INTO Genres VALUES ( NULL, "Boxing", 20 );
INSERT INTO Genres VALUES ( NULL, "Bullfighting", 149 );
INSERT INTO Genres VALUES ( NULL, "Bus./financial", 21 );
INSERT INTO Genres VALUES ( NULL, "Bus./financial", 1007 );
INSERT INTO Genres VALUES ( NULL, "Canoe", 150 );
INSERT INTO Genres VALUES ( NULL, "Card Games", 238 );
INSERT INTO Genres VALUES ( NULL, "Card Games", 1000 );
INSERT INTO Genres VALUES ( NULL, "Cheerleading", 151 );
INSERT INTO Genres VALUES ( NULL, "Children", 22 );
INSERT INTO Genres VALUES ( NULL, "Children", 1001 );
INSERT INTO Genres VALUES ( NULL, "Children-music", 22 );
INSERT INTO Genres VALUES ( NULL, "Children-music", 69 );
INSERT INTO Genres VALUES ( NULL, "Children-music", 1001 );
INSERT INTO Genres VALUES ( NULL, "Children-music", 1016 );
INSERT INTO Genres VALUES ( NULL, "Children-special", 22 );
INSERT INTO Genres VALUES ( NULL, "Children-special", 100 );
INSERT INTO Genres VALUES ( NULL, "Children-special", 1001 );
INSERT INTO Genres VALUES ( NULL, "Children-talk", 22 );
INSERT INTO Genres VALUES ( NULL, "Children-talk", 106 );
INSERT INTO Genres VALUES ( NULL, "Children-talk", 1001 );
INSERT INTO Genres VALUES ( NULL, "Children-talk", 1010 );
INSERT INTO Genres VALUES ( NULL, "Collectibles", 24 );
INSERT INTO Genres VALUES ( NULL, "Collectibles", 1000 );
INSERT INTO Genres VALUES ( NULL, "Comedy", 25 );
INSERT INTO Genres VALUES ( NULL, "Comedy", 1002 );
INSERT INTO Genres VALUES ( NULL, "Comedy-drama", 25 );
INSERT INTO Genres VALUES ( NULL, "Comedy-drama", 35 );
INSERT INTO Genres VALUES ( NULL, "Comedy-drama", 1002 );
INSERT INTO Genres VALUES ( NULL, "Comedy-drama", 1005 );
INSERT INTO Genres VALUES ( NULL, "Community", 152 );
INSERT INTO Genres VALUES ( NULL, "Community", 1000 );
INSERT INTO Genres VALUES ( NULL, "Computers", 26 );
INSERT INTO Genres VALUES ( NULL, "Computers", 1008 );
INSERT INTO Genres VALUES ( NULL, "Consumer", 1000 );
INSERT INTO Genres VALUES ( NULL, "Cooking", 27 );
INSERT INTO Genres VALUES ( NULL, "Cooking", 1000 );
INSERT INTO Genres VALUES ( NULL, "Cricket", 154 );
INSERT INTO Genres VALUES ( NULL, "Crime", 29 );
INSERT INTO Genres VALUES ( NULL, "Crime drama", 30 );
INSERT INTO Genres VALUES ( NULL, "Crime drama", 1005 );
INSERT INTO Genres VALUES ( NULL, "Curling", 31 );
INSERT INTO Genres VALUES ( NULL, "Dance", 32 );
INSERT INTO Genres VALUES ( NULL, "Dance", 1016 );
INSERT INTO Genres VALUES ( NULL, "Darts", 155 );
INSERT INTO Genres VALUES ( NULL, "Debate", 156 );
INSERT INTO Genres VALUES ( NULL, "Debate", 1007 );
INSERT INTO Genres VALUES ( NULL, "Diving", 105 );
INSERT INTO Genres VALUES ( NULL, "Docudrama", 33 );
INSERT INTO Genres VALUES ( NULL, "Docudrama", 1004 );
INSERT INTO Genres VALUES ( NULL, "Docudrama", 1005 );
INSERT INTO Genres VALUES ( NULL, "Documentary", 34 );
INSERT INTO Genres VALUES ( NULL, "Documentary", 1004 );
INSERT INTO Genres VALUES ( NULL, "Dog racing", 157 );
INSERT INTO Genres VALUES ( NULL, "Dog show", 158 );
INSERT INTO Genres VALUES ( NULL, "Dog show", 1000 );
INSERT INTO Genres VALUES ( NULL, "Dog sled", 94 );
INSERT INTO Genres VALUES ( NULL, "Drag racing", 159 );
INSERT INTO Genres VALUES ( NULL, "Drama", 35 );
INSERT INTO Genres VALUES ( NULL, "Drama", 1005 );
INSERT INTO Genres VALUES ( NULL, "Educational", 36 );
INSERT INTO Genres VALUES ( NULL, "Educational", 1012 );
INSERT INTO Genres VALUES ( NULL, "Entertainment", 160 );
INSERT INTO Genres VALUES ( NULL, "Entertainment", 1000 );
INSERT INTO Genres VALUES ( NULL, "Environment", 223 );
INSERT INTO Genres VALUES ( NULL, "Environment", 1008 );
INSERT INTO Genres VALUES ( NULL, "Equestrian", 161 );
INSERT INTO Genres VALUES ( NULL, "Exercise", 48 );
INSERT INTO Genres VALUES ( NULL, "Exercise", 1000 );
INSERT INTO Genres VALUES ( NULL, "Extreme", 162 );
INSERT INTO Genres VALUES ( NULL, "Fantasy", 39 );
INSERT INTO Genres VALUES ( NULL, "Fantasy", 1014 );
INSERT INTO Genres VALUES ( NULL, "Fashion", 40 );
INSERT INTO Genres VALUES ( NULL, "Fashion", 1000 );
INSERT INTO Genres VALUES ( NULL, "Fencing", 163 );
INSERT INTO Genres VALUES ( NULL, "Field hockey", 164 );
INSERT INTO Genres VALUES ( NULL, "Figure skating", 165 );
INSERT INTO Genres VALUES ( NULL, "Fishing", 41 );
INSERT INTO Genres VALUES ( NULL, "Football", 42 );
INSERT INTO Genres VALUES ( NULL, "French", 43 );
INSERT INTO Genres VALUES ( NULL, "French", 1000 );
INSERT INTO Genres VALUES ( NULL, "Fundraiser", 44 );
INSERT INTO Genres VALUES ( NULL, "Fundraiser", 1000 );
INSERT INTO Genres VALUES ( NULL, "Gaelic football", 166 );
INSERT INTO Genres VALUES ( NULL, "Game show", 45 );
INSERT INTO Genres VALUES ( NULL, "Game show", 1003 );
INSERT INTO Genres VALUES ( NULL, "Gay/lesbian", 167 );
INSERT INTO Genres VALUES ( NULL, "Gay/lesbian", 1000 );
INSERT INTO Genres VALUES ( NULL, "Golf", 46 );
INSERT INTO Genres VALUES ( NULL, "Gymnastics", 47 );
INSERT INTO Genres VALUES ( NULL, "Handball", 168 );
INSERT INTO Genres VALUES ( NULL, "Health", 48 );
INSERT INTO Genres VALUES ( NULL, "Health", 1000 );
INSERT INTO Genres VALUES ( NULL, "Historical drama", 50 );
INSERT INTO Genres VALUES ( NULL, "Historical drama", 1005 );
INSERT INTO Genres VALUES ( NULL, "History", 49 );
INSERT INTO Genres VALUES ( NULL, "Hockey", 51 );
INSERT INTO Genres VALUES ( NULL, "Holiday", 52 );
INSERT INTO Genres VALUES ( NULL, "Holiday", 1000 );
INSERT INTO Genres VALUES ( NULL, "Holiday music", 52 );
INSERT INTO Genres VALUES ( NULL, "Holiday music", 69 );
INSERT INTO Genres VALUES ( NULL, "Holiday music", 1000 );
INSERT INTO Genres VALUES ( NULL, "Holiday music", 1016 );
INSERT INTO Genres VALUES ( NULL, "Holiday music special", 52 );
INSERT INTO Genres VALUES ( NULL, "Holiday music special", 69 );
INSERT INTO Genres VALUES ( NULL, "Holiday music special", 100 );
INSERT INTO Genres VALUES ( NULL, "Holiday music special", 1000 );
INSERT INTO Genres VALUES ( NULL, "Holiday music special", 1016 );
INSERT INTO Genres VALUES ( NULL, "Holiday special", 52 );
INSERT INTO Genres VALUES ( NULL, "Holiday special", 100 );
INSERT INTO Genres VALUES ( NULL, "Holiday special", 1000 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children", 22 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children", 52 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children", 1000 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children", 1001 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children special", 22 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children special", 52 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children special", 100 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children special", 1000 );
INSERT INTO Genres VALUES ( NULL, "Holiday-children special", 1001 );
INSERT INTO Genres VALUES ( NULL, "Home improvement", 169 );
INSERT INTO Genres VALUES ( NULL, "Home improvement", 1000 );
INSERT INTO Genres VALUES ( NULL, "Horror", 55 );
INSERT INTO Genres VALUES ( NULL, "Horse", 56 );
INSERT INTO Genres VALUES ( NULL, "Horse", 1009 );
INSERT INTO Genres VALUES ( NULL, "House/garden", 54 );
INSERT INTO Genres VALUES ( NULL, "House/garden", 1000 );
INSERT INTO Genres VALUES ( NULL, "How-to", 58 );
INSERT INTO Genres VALUES ( NULL, "How-to", 1012 );
INSERT INTO Genres VALUES ( NULL, "Hunting", 170 );
INSERT INTO Genres VALUES ( NULL, "Hurling", 171 );
INSERT INTO Genres VALUES ( NULL, "Hydroplane racing", 172 );
INSERT INTO Genres VALUES ( NULL, "Indoor soccer", 173 );
INSERT INTO Genres VALUES ( NULL, "Interview", 60 );
INSERT INTO Genres VALUES ( NULL, "Interview", 1007 );
INSERT INTO Genres VALUES ( NULL, "Intl basketball", 12 );
INSERT INTO Genres VALUES ( NULL, "Intl hockey", 51 );
INSERT INTO Genres VALUES ( NULL, "Intl soccer", 174 );
INSERT INTO Genres VALUES ( NULL, "Kayaking", 175 );
INSERT INTO Genres VALUES ( NULL, "Lacrosse", 62 );
INSERT INTO Genres VALUES ( NULL, "Law", 176 );
INSERT INTO Genres VALUES ( NULL, "Luge", 177 );
INSERT INTO Genres VALUES ( NULL, "Martial arts", 64 );
INSERT INTO Genres VALUES ( NULL, "Medical", 65 );
INSERT INTO Genres VALUES ( NULL, "Medical", 1000 );
INSERT INTO Genres VALUES ( NULL, "Motorcycle", 67 );
INSERT INTO Genres VALUES ( NULL, "Motorcycle", 1000 );
INSERT INTO Genres VALUES ( NULL, "Motorcycle racing", 178 );
INSERT INTO Genres VALUES ( NULL, "Motorsports", 66 );
INSERT INTO Genres VALUES ( NULL, "Mountain biking", 179 );
INSERT INTO Genres VALUES ( NULL, "Music", 69 );
INSERT INTO Genres VALUES ( NULL, "Music", 1016 );
INSERT INTO Genres VALUES ( NULL, "Music special", 69 );
INSERT INTO Genres VALUES ( NULL, "Music special", 100 );
INSERT INTO Genres VALUES ( NULL, "Music special", 1016 );
INSERT INTO Genres VALUES ( NULL, "Music talk", 69 );
INSERT INTO Genres VALUES ( NULL, "Music talk", 106 );
INSERT INTO Genres VALUES ( NULL, "Music talk", 1010 );
INSERT INTO Genres VALUES ( NULL, "Music talk", 1016 );
INSERT INTO Genres VALUES ( NULL, "Musical", 70 );
INSERT INTO Genres VALUES ( NULL, "Musical comedy", 25 );
INSERT INTO Genres VALUES ( NULL, "Musical comedy", 70 );
INSERT INTO Genres VALUES ( NULL, "Musical comedy", 1002 );
INSERT INTO Genres VALUES ( NULL, "Musical romance", 70 );
INSERT INTO Genres VALUES ( NULL, "Musical romance", 82 );
INSERT INTO Genres VALUES ( NULL, "Mystery", 71 );
INSERT INTO Genres VALUES ( NULL, "Mystery", 1013 );
INSERT INTO Genres VALUES ( NULL, "Nature", 72 );
INSERT INTO Genres VALUES ( NULL, "Nature", 1008 );
INSERT INTO Genres VALUES ( NULL, "News", 73 );
INSERT INTO Genres VALUES ( NULL, "News", 1007 );
INSERT INTO Genres VALUES ( NULL, "Newsmagazine", 180 );
INSERT INTO Genres VALUES ( NULL, "Newsmagazine", 1007 );
INSERT INTO Genres VALUES ( NULL, "Olympics", 74 );
INSERT INTO Genres VALUES ( NULL, "Opera", 75 );
INSERT INTO Genres VALUES ( NULL, "Opera", 1016 );
INSERT INTO Genres VALUES ( NULL, "Outdoors", 76 );
INSERT INTO Genres VALUES ( NULL, "Parade", 181 );
INSERT INTO Genres VALUES ( NULL, "Parade", 1000 );
INSERT INTO Genres VALUES ( NULL, "Paranormal", 182 );
INSERT INTO Genres VALUES ( NULL, "Paranormal", 1000 );
INSERT INTO Genres VALUES ( NULL, "Parenting", 183 );
INSERT INTO Genres VALUES ( NULL, "Parenting", 1000 );
INSERT INTO Genres VALUES ( NULL, "Pelota vasca", 184 );
INSERT INTO Genres VALUES ( NULL, "Performing arts", 185 );
INSERT INTO Genres VALUES ( NULL, "Performing arts", 1016 );
INSERT INTO Genres VALUES ( NULL, "Playoff sports", 186 );
INSERT INTO Genres VALUES ( NULL, "Playoff sports", 1009 );
INSERT INTO Genres VALUES ( NULL, "Poker", 236 );
INSERT INTO Genres VALUES ( NULL, "Poker", 1000 );
INSERT INTO Genres VALUES ( NULL, "Politics", 187 );
INSERT INTO Genres VALUES ( NULL, "Politics", 1007 );
INSERT INTO Genres VALUES ( NULL, "Polo", 188 );
INSERT INTO Genres VALUES ( NULL, "Pool", 189 );
INSERT INTO Genres VALUES ( NULL, "Pro wrestling", 190 );
INSERT INTO Genres VALUES ( NULL, "Public affairs", 77 );
INSERT INTO Genres VALUES ( NULL, "Public affairs", 1007 );
INSERT INTO Genres VALUES ( NULL, "Racquet", 78 );
INSERT INTO Genres VALUES ( NULL, "Reality", 79 );
INSERT INTO Genres VALUES ( NULL, "Reality", 1000 );
INSERT INTO Genres VALUES ( NULL, "Religious", 80 );
INSERT INTO Genres VALUES ( NULL, "Religious", 1000 );
INSERT INTO Genres VALUES ( NULL, "Ringuette", 191 );
INSERT INTO Genres VALUES ( NULL, "Rodeo", 81 );
INSERT INTO Genres VALUES ( NULL, "Roller derby", 192 );
INSERT INTO Genres VALUES ( NULL, "Romance", 82 );
INSERT INTO Genres VALUES ( NULL, "Romance-comedy", 83 );
INSERT INTO Genres VALUES ( NULL, "Romance-comedy", 1002 );
INSERT INTO Genres VALUES ( NULL, "Rowing", 193 );
INSERT INTO Genres VALUES ( NULL, "Rugby", 84 );
INSERT INTO Genres VALUES ( NULL, "Running", 85 );
INSERT INTO Genres VALUES ( NULL, "Sailing", 194 );
INSERT INTO Genres VALUES ( NULL, "Science", 87 );
INSERT INTO Genres VALUES ( NULL, "Science", 1008 );
INSERT INTO Genres VALUES ( NULL, "Science fiction", 88 );
INSERT INTO Genres VALUES ( NULL, "Science fiction", 1014 );
INSERT INTO Genres VALUES ( NULL, "Self improvement", 89 );
INSERT INTO Genres VALUES ( NULL, "Self improvement", 1000 );
INSERT INTO Genres VALUES ( NULL, "Shooting", 195 );
INSERT INTO Genres VALUES ( NULL, "Shopping", 90 );
INSERT INTO Genres VALUES ( NULL, "Shopping", 1000 );
INSERT INTO Genres VALUES ( NULL, "Sitcom", 91 );
INSERT INTO Genres VALUES ( NULL, "Sitcom", 1002 );
INSERT INTO Genres VALUES ( NULL, "Skateboarding", 196 );
INSERT INTO Genres VALUES ( NULL, "Skating", 92 );
INSERT INTO Genres VALUES ( NULL, "Skeleton", 197 );
INSERT INTO Genres VALUES ( NULL, "Skiing", 93 );
INSERT INTO Genres VALUES ( NULL, "Snooker", 198 );
INSERT INTO Genres VALUES ( NULL, "Snowboarding", 199 );
INSERT INTO Genres VALUES ( NULL, "Snowmobile", 200 );
INSERT INTO Genres VALUES ( NULL, "Soap", 96 );
INSERT INTO Genres VALUES ( NULL, "Soap", 1003 );
INSERT INTO Genres VALUES ( NULL, "Soap special", 96 );
INSERT INTO Genres VALUES ( NULL, "Soap special", 100 );
INSERT INTO Genres VALUES ( NULL, "Soap special", 1003 );
INSERT INTO Genres VALUES ( NULL, "Soap talk", 96 );
INSERT INTO Genres VALUES ( NULL, "Soap talk", 106 );
INSERT INTO Genres VALUES ( NULL, "Soap talk", 1003 );
INSERT INTO Genres VALUES ( NULL, "Soap talk", 1010 );
INSERT INTO Genres VALUES ( NULL, "Soccer", 97 );
INSERT INTO Genres VALUES ( NULL, "Softball", 98 );
INSERT INTO Genres VALUES ( NULL, "Spanish", 99 );
INSERT INTO Genres VALUES ( NULL, "Special", 100 );
INSERT INTO Genres VALUES ( NULL, "Speed skating", 201 );
INSERT INTO Genres VALUES ( NULL, "Sports event", 221 );
INSERT INTO Genres VALUES ( NULL, "Sports event", 1009 );
INSERT INTO Genres VALUES ( NULL, "Sports non-event", 222 );
INSERT INTO Genres VALUES ( NULL, "Sports non-event", 1009 );
INSERT INTO Genres VALUES ( NULL, "Sports talk", 103 );
INSERT INTO Genres VALUES ( NULL, "Sports talk", 106 );
INSERT INTO Genres VALUES ( NULL, "Sports talk", 1009 );
INSERT INTO Genres VALUES ( NULL, "Sports talk", 1010 );
INSERT INTO Genres VALUES ( NULL, "Squash", 202 );
INSERT INTO Genres VALUES ( NULL, "Standup", 203 );
INSERT INTO Genres VALUES ( NULL, "Standup", 1002 );
INSERT INTO Genres VALUES ( NULL, "Sumo wrestling", 204 );
INSERT INTO Genres VALUES ( NULL, "Surfing", 205 );
INSERT INTO Genres VALUES ( NULL, "Suspense", 104 );
INSERT INTO Genres VALUES ( NULL, "Suspense", 1013 );
INSERT INTO Genres VALUES ( NULL, "Swimming", 105 );
INSERT INTO Genres VALUES ( NULL, "Table tennis", 206 );
INSERT INTO Genres VALUES ( NULL, "Talk", 106 );
INSERT INTO Genres VALUES ( NULL, "Talk", 1010 );
INSERT INTO Genres VALUES ( NULL, "Tennis", 108 );
INSERT INTO Genres VALUES ( NULL, "Theater", 109 );
INSERT INTO Genres VALUES ( NULL, "Theater", 1016 );
INSERT INTO Genres VALUES ( NULL, "Track/field", 111 );
INSERT INTO Genres VALUES ( NULL, "Travel", 112 );
INSERT INTO Genres VALUES ( NULL, "Travel", 1000 );
INSERT INTO Genres VALUES ( NULL, "Triathlon", 207 );
INSERT INTO Genres VALUES ( NULL, "Variety", 113 );
INSERT INTO Genres VALUES ( NULL, "Variety", 1000 );
INSERT INTO Genres VALUES ( NULL, "Volleyball", 114 );
INSERT INTO Genres VALUES ( NULL, "War", 115 );
INSERT INTO Genres VALUES ( NULL, "Water polo", 208 );
INSERT INTO Genres VALUES ( NULL, "Water skiing", 209 );
INSERT INTO Genres VALUES ( NULL, "Watersports", 116 );
INSERT INTO Genres VALUES ( NULL, "Weather", 117 );
INSERT INTO Genres VALUES ( NULL, "Weather", 1007 );
INSERT INTO Genres VALUES ( NULL, "Weightlifting", 210 );
INSERT INTO Genres VALUES ( NULL, "Western", 118 );
INSERT INTO Genres VALUES ( NULL, "Western", 1000 );
INSERT INTO Genres VALUES ( NULL, "Wrestling", 119 );
INSERT INTO Genres VALUES ( NULL, "Yacht racing", 194 );

drop table if exists CastRoles;
create table CastRoles (
    castrole_id tinyint unsigned auto_increment PRIMARY KEY,
    castrole char(32)
) TYPE=INNODB;
INSERT INTO CastRoles VALUES (NULL, "Actor" );
INSERT INTO CastRoles VALUES (NULL, "Guest Star" );
INSERT INTO CastRoles VALUES (NULL, "Host" );
INSERT INTO CastRoles VALUES (NULL, "Director" );
INSERT INTO CastRoles VALUES (NULL, "Producer" );
INSERT INTO CastRoles VALUES (NULL, "Executive Producer" );
INSERT INTO CastRoles VALUES (NULL, "Writer" );
    
drop table if exists Stations ;
create table Stations (
    station_id integer unsigned not null PRIMARY KEY,
    station_ver integer unsigned not null default 1,
    
    callsign varchar(10),
    name varchar(64),
    affiliate varchar(32),

    station_tivo_id integer unsigned
) TYPE=INNODB;

drop table if exists Lineups ;
create table Lineups (
    lineup_id integer unsigned not null auto_increment,
    lineup_tmsid char(12),
    lineup_ver integer unsigned not null,
    
    lineup_name varchar(64),
    lineup_type varchar(32),
    lineup_device varchar(16),
    lineup_postalcode varchar(10),
    tivo_postalcode char(5) not null,
    postal_location char(2) not null,
    lineup_location varchar(28),
    updated timestamp,
    primary key( lineup_id, lineup_ver )
) TYPE=INNODB;

drop table if exists Lineup_map ;
create table Lineup_map (
    lineup_id integer unsigned not null,
    lineup_map_id integer unsigned not null auto_increment PRIMARY KEY,

    station_id integer unsigned not null,
    channel_num varchar(10),

    from_date char( 10 ),
    to_date char( 10 ),
    INDEX ( lineup_id ), 
    INDEX ( station_id ),
    FOREIGN KEY ( lineup_id ) REFERENCES Lineups ( lineup_id ),
    FOREIGN KEY ( station_id ) REFERENCES Stations ( station_id )
     
) TYPE=INNODB;

drop table if exists PostalCodes ;
create table PostalCodes (
    tivo_postalcode varchar(8) not null,
    postal_location char(2) not null,
    postalcode_id integer unsigned not null auto_increment PRIMARY KEY,
    postalcode_ver integer unsigned not null default 1,
    INDEX ( postalcode_id ) 
) TYPE=INNODB;

drop table if exists Series ;
create table Series (
    series_id char(8) not null,
    series_ver integer unsigned not null,

    series_title tinytext not null,
    series_tivoid integer unsigned,
    updated timestamp,
    INDEX ( series_id ),
    INDEX ( series_tivoid ),
    INDEX ( series_title(255) )
) TYPE=INNODB;
alter table Series add primary key ( series_title(255), series_id, series_ver );

drop table if exists Programs ;
create table Programs (
    series_id char(8) not null,
    series_tivoid integer unsigned,

    program_tmsid char(12) not null,
    program_ver integer unsigned not null,
    
    program_title tinytext,
    program_subtitle tinytext,
    program_description text,

    syndicated_episode_number tinytext,
    original_air_date integer,

    showtype_id integer unsigned,
    program_tivoid integer unsigned,
    updated timestamp,
    PRIMARY KEY( series_id, program_tmsid, program_ver ),
    INDEX( series_id ),
    INDEX( series_tivoid ),
    INDEX( program_tmsid, program_ver ),
    INDEX( showtype_id ),
    
    FOREIGN KEY ( series_id ) REFERENCES Series ( series_id ),
    FOREIGN KEY ( series_tivoid ) REFERENCES Series ( series_tivoid ),
    FOREIGN KEY ( showtype_id ) REFERENCES ShowTypes ( showtype_id )
) TYPE=INNODB;

drop table if exists MovieInfo;
create table MovieInfo (
    program_tmsid char(12) not null,
    program_ver integer unsigned not null,

    mpaarating_id integer,
    starrating_id integer,
    year integer unsigned,
    runtime integer unsigned,
    updated timestamp,
    PRIMARY KEY ( program_tmsid, program_ver ),
    INDEX (program_tmsid),
    
    FOREIGN KEY (program_tmsid) REFERENCES Programs ( program_tmsid )
) TYPE=INNODB;
 
drop table if exists Schedule;
create table Schedule (
    schedule_day integer unsigned not null,
    schedule_time integer unsigned not null,

    station_id integer unsigned not null,

    schedule_id integer unsigned not null,
   
    program_tmsid char(12) not null,
    program_ver integer unsigned not null,

    schedule_duration integer unsigned not null,

    closecaption bool default 0,
    stereo bool default 0,
    repeat bool default 0,
    subtitled bool default 0,
    hdtv bool default 0,
    letterbox bool default 0,
    tvrating_id integer unsigned,

    part_id integer unsigned,
    part_max integer unsigned,
    updated timestamp,
    valid   timestamp,
    INDEX ( schedule_day, station_id, schedule_time, valid ),
    INDEX ( station_id ),
    INDEX ( program_tmsid ),
    INDEX ( tvrating_id ),
    FOREIGN KEY (tvrating_id ) REFERENCES TvRatings ( tvrating_id ),
    FOREIGN KEY ( station_id ) REFERENCES Stations ( station_id )
/*  FOREIGN KEY ( program_tmsid ) REFERENCES Programs ( program_tmsid ) */
) TYPE=INNODB;

drop table if exists ProgramGenre;
create table ProgramGenre (
    program_tmsid char(12) not null,

    genre_id integer unsigned not null,
    relevance tinyint not null,
    PRIMARY KEY ( genre_id, program_tmsid ),
    INDEX ( program_tmsid ), 
    FOREIGN KEY ( program_tmsid ) REFERENCES Programs ( program_tmsid )
) TYPE=INNODB;

drop table if exists ProgramAdvisories;
create table ProgramAdvisories (
    program_tmsid char(12) not null,

    advisory_id integer unsigned not null,

    PRIMARY KEY ( program_tmsid, advisory_id ),
    INDEX( advisory_id ),
    FOREIGN KEY ( advisory_id ) REFERENCES Advisories ( advisory_id )
) TYPE=INNODB;

drop table if exists Crew;
create table Crew (
    crew_id integer unsigned not null auto_increment primary key,
    givenname varchar(64),
    surname varchar(64),
    UNIQUE INDEX( surname, givenname )
) TYPE=INNODB;
drop table if exists ProgramCast;
create table ProgramCast (
    crew_id integer unsigned not null,
    castrole_id tinyint unsigned not null,
    program_tmsid char(12) not null,
    INDEX ( crew_id ),
    INDEX ( castrole_id ),
    INDEX ( program_tmsid ),
    INDEX ( crew_id, program_tmsid ),
    FOREIGN KEY ( crew_id ) REFERENCES Crew ( crew_id ),
    FOREIGN KEY ( castrole_id ) REFERENCES CastRoles ( castrole_id ),
    FOREIGN KEY ( program_tmsid ) REFERENCES Programs ( program_tmsid )
) TYPE=INNODB;

drop table if exists StationDayVer;
create table StationDayVer (
    schedule_day integer unsigned not null,
    station_id integer unsigned not null,
    version integer unsigned not null,
    INDEX ( station_id, schedule_day ),
    FOREIGN KEY ( station_id ) REFERENCES Stations ( station_id )
) TYPE=INNODB;

drop table if exists Messages ;
create table Messages (
    message_id integer unsigned not null auto_increment primary key,

    subject tinytext not null,
    sender tinytext not null,
    message text not null,
    priority integer unsigned not null,
    expiration_day integer unsigned not null,
    destination integer unsigned not null,
    valid timestamp
) TYPE=INNODB;

drop table if exists Showcases;
create table Showcases (
    showcase_id integer unsigned not null auto_increment,
    dsname tinytext not null,
    name tinytext not null,
    banner_image_id integer unsigned not null,
    bigbanner_image_id integer unsigned not null,
    icon_image_id integer unsigned not null,
    seq_num integer unsigned not null,

    showcase_ver integer unsigned not null default 1,
    PRIMARY KEY( showcase_id ),
    INDEX ( showcase_id )
) TYPE=INNODB;

drop table if exists Packages;
create table Packages (
    package_id integer unsigned not null auto_increment,
    dsname tinytext not null,
    name tinytext not null,
    description tinytext not null,
    banner_image_id integer unsigned not null,
    infoballoon integer unsigned not null,

    package_ver integer unsigned not null default 1,
    PRIMARY KEY( package_id ),
    INDEX ( package_id )
) TYPE=INNODB;

drop table if exists PackageItems;
create table PackageItems (
    package_id integer unsigned not null,
    program_tmsid char(12) not null,
    station_id integer unsigned,
    schedule_day integer unsigned,
    schedule_time integer unsigned,
    expiration_day integer unsigned not null,
    expiration_time integer unsigned not null,
    affiliation tinytext not null,
    description tinytext not null,

    PRIMARY KEY( package_id,program_tmsid ),
    INDEX ( package_id ),
    INDEX ( program_tmsid ),
    FOREIGN KEY (package_id) REFERENCES Packages ( package_id ),
    FOREIGN KEY (program_tmsid) REFERENCES Programs ( program_tmsid )
) TYPE=INNODB;

drop table if exists Images;
create table Images (
    image_id integer unsigned not null auto_increment,
    dsname tinytext not null,
    name tinytext not null,
    mtime integer unsigned not null,

    image_ver integer unsigned not null default 1,
    PRIMARY KEY( image_id ),
    INDEX ( image_id ),
    INDEX ( dsname(255) ),
    INDEX ( name(255) )
) TYPE=INNODB;
