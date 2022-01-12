These files were created and original run under apache on Windows.

The Perl paths at the beginning of each file will need to be modified. 
As well as a couple things I've noted in Hserver.cgi

Dan

Tivo Service Features
- downloads slice files based on tivo requested lineups
- deletes old slice files off the server when their data has expired
- only send slice files the tivo hasn't already downloaded

It implements test and daily calls, but I never did guided setup.


Here's the basic rundown of how I manage/delete slice files. I 
followed tivo's example on how to name slices. 

Tivo's slice filename convention
<lineup>_<startdate>-<enddate>-v<version>.slice.gz (version might 
noted a little differently)

My naming convention
<lineup>_<startdate>[-<enddate>].slice[.gz]

examples:
mylineup_12169.slice
mylineup_12170-12175.slice.gz

Files have to be named in this format to work with my service 
emulator. Actually you could name something mylineup_testing.slice, 
the file would be downloaded, but never deleted.

I key my deletes off the enddate (or startdate if no enddate given) 
in the filename. If it is more than 3 days ago I delete the file. I 
also delete files that haven't been modified in more than 5 days.

My perl code now remembers the last successful call a tivo made and 
only sends files for the lineup you are subcribed to modified after 
that date.

Tivo sends the subscribed lineups to hserver.cgi. I guess they are 
actually the TmsHeadendId. So you will have to use the name of the 
lineup you created in your filenames.







Tivo Setup notes

Add a line to /etc/tclient.conf and then changed the dialconfig code in the system menu. That way you can switch back to the real tivo service for software updates.

#
# Personal Tivo Service
#

127::192.168.1.1:80:::


This will add a new dailconfig entry to your tivo. The line breaks down like this

label:phone_number:svr_addr:svr_port:ppp_user:ppp_pass

Once you have that you can do to system info screen, scroll to dailconfig,
hit C-C-E-E-0 and then 127 (or whatever number you used for your label)
