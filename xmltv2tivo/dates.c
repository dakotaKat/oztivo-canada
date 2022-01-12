/* xmltv2tivo - date functions */

#include "xmltv2tivo.h"

char *StrnCpy(char *dest,const char *src, size_t n)
{
  char *d = dest;
  if (!dest) return(NULL);
  if (!src) {
    *dest = 0;
    return(dest);
  }
  while (n-- && (*d++ = *src++)) ;
  *d = 0;
  return(dest);
}

/* Why does xmltimetotm() return a tm structure whereas tivoEpochDate and tivoEpochTime take
a time_t data type as an argument?  */

/*========================================================================================*/
/* xmltimetotmTime() - convert XMLTV .XML times to a tm time structure, to allow for the calculation
of epoch times and differences between start time and end time and therefore the durations of 
programmes...    e.g. "20021225150000 GMT" */

struct tm xmltimetotmTime (char *xmltime)
{
	struct tm tmtime;
	char buf[10];
	StrnCpy(buf, xmltime, 4);
	tmtime.tm_year = atoi(buf) - 1900;
	StrnCpy(buf, &xmltime[4], 2);
	tmtime.tm_mon = atoi(buf) - 1;
	StrnCpy(buf, &xmltime[6], 2);
	tmtime.tm_mday = atoi(buf);
	StrnCpy(buf, &xmltime[8], 2);
	tmtime.tm_hour = atoi(buf);
	StrnCpy(buf, &xmltime[10], 2);
	tmtime.tm_min = atoi(buf);
	StrnCpy(buf, &xmltime[12], 2);
	tmtime.tm_sec = atoi(buf);
	tmtime.tm_isdst= - 1;
	
	/*
	strptime(xmltime, "%Y %m %d %H %M %S", &tmtime);
	if (strstr(xmltime,"DT") > 0) {
		tmtime.tm_isdst=1;
	} else {
		tmtime.tm_isdst=0;
	}
	*/
	return(tmtime);

}

/*========================================================================================*/
/* Passed a time_t value, returns a tivoEpoch date - no of days since Unix epoch */
unsigned int tivoEpochDate(time_t timettime)
{
unsigned int tivoepoch;

tivoepoch= timettime/SECS_IN_DAY;
return(tivoepoch);
}

/*========================================================================================*/
/* Passed a time_t value, returns a tivoEpoch time - no of secs since midnight */
unsigned int tivoEpochTime(time_t timettime)
{
unsigned int tivoepoch;

tivoepoch= timettime%SECS_IN_DAY;
return(tivoepoch);
}
/*========================================================================================*/
/* Passed a tivoEpoch date, returns a struct tm */
/* get the tivoepoch into a time_t.., then convert to tm.. */

/* struct tm *gmtime(const time_t *timep);*/

struct tm *tmDate(unsigned int tdate)
{
time_t aDate;

aDate=(time_t) tdate*SECS_IN_DAY;

return(gmtime(&aDate));
}

