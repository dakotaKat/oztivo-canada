#include "xmltv2tivo.h"

/*========================================================================================*/
/* Find the StationDay record for *channelName, and for given epoch date,
First look up FSID for *channelName.. then return a pointer to the
StationDay record with the FSID for *channelName, and given tivoEpochDate. */

struct stationDayRecord *findStationDay(unsigned char *channelName, unsigned int tivoEpochDate)
{
int i, i2, foundChannelFSID;
static unsigned long aChannelFSID = 0;
struct channelPair *channelPtr;

	foundChannelFSID=0;
	channelPtr = tivoChannelTable;		/* point to base of channel table */

	for(i=0;i<channelsTotal && channelPtr->channelFSID && !foundChannelFSID; i++)
		{
#ifdef DEBUG
		fprintf(stderr, "findStationDay() - looking at %s\n", channelPtr->channelName);
#endif
		if(!strcmp(channelPtr->channelName,channelName))
			{
			aChannelFSID=channelPtr->channelFSID;
			foundChannelFSID=1;
			}
		channelPtr++;
		}
	if(!foundChannelFSID)
		{
#ifdef DEBUG
		fprintf(stderr, "DEBUG: findStationDay(): Couldn\'t find a FSID for %s\n", channelName);
#endif
		return(NULL);
		}

	/* Now search StationDay records for channel FSID and epoch Date..
	- iterate through the channel indices and then the epoch date indices of stationDays */

	i=0; i2=0;
	while(i<channelsTotal && stationDays[i][0].stationIndex != aChannelFSID && stationDays[i][0].stationIndex)
		i++;
	if(stationDays[i][0].stationIndex != aChannelFSID)
		return(NULL); /* didn't find a StationDay record for the Channel FSID */

	while(i2<MAX_DAYS_OF_DATA && stationDays[i][i2].tivoEpochDate != tivoEpochDate && stationDays[i][i2].tivoEpochDate)
		 i2++;
	if(stationDays[i][i2].tivoEpochDate != tivoEpochDate)
		return(NULL); /* Didn't find a StationDay record for the tivoEpochDate */

	if(stationDays[i][i2].stationIndex != aChannelFSID && stationDays[i][i2].tivoEpochDate != tivoEpochDate)
		return(NULL); /* shouldnt actually be here */

	return(&stationDays[i][i2]);
}


/*========================================================================================*/
/* Find an empty showing timeslot in the stationDayRecord pointed to by stationDayPtr ..
some time, we need to error check the Showing sub-records for a StationDay - e.g. to
make sure none overlap, and that they are in chronological order */

struct showingRecord *findEmptyShowing(struct stationDayRecord *stationDayPtr)
{
int i=0;

	while(stationDayPtr->showing[i].programmeIndex)
		{
#ifdef DEBUG
		fprintf(stderr, "Looking at stationDayPtr->showing[%d].time=%u ->..date=%u ->station=%lu \n", i, 
			stationDayPtr->showing[i].tivoEpochTime, 
			stationDayPtr->showing[i].tivoEpochDate,
			stationDayPtr->showing[i].stationIndex);
#endif
		if(i==MAX_TIMESLOTS)
			return(NULL);	/* Shucks! no free timeslot - must be a bug..*/
		i++;
		}
	return(&stationDayPtr->showing[i]);
}

/*========================================================================================*/

/* Compare two category pairs, return value identifes whether a->categoryName is less than..
 b->categoryName  */

int categoryCmp(const struct categoryGenrePair *a, const struct categoryGenrePair *b)
{
/*	fprintf(stderr, "categoryCmp() a->%s  b->%s \n", a->categoryName, b->categoryName);*/
	return( strcmp(a->categoryName,b->categoryName ));
}

/*========================================================================================*/
/* Search the category->genre table for category with given name */

struct categoryGenrePair *findCategory(unsigned char *categoryName)
{
struct categoryGenrePair target;

	strcpy(target.categoryName, categoryName);

	return ( bsearch(&target, categoryGenreTable, categoriesTotal, sizeof(struct categoryGenrePair),
		(int (*) (const void *, const void *)) categoryCmp));
}
/*========================================================================================*/

/* Compare two series pairs, return value identifes whether a->seriesTitle is "less than",
equal to, or greater than b->seriesTitle  */

int seriesCmp(const struct seriesPair *a, const struct seriesPair *b)
{
	return( strcmp(a->seriesTitle, b->seriesTitle ));
}

/*========================================================================================*/
/* Check the seriesTable to see whether a seriesTitle already has an associated FSID */

/* If we implemented two seriesTables, then this fn would search them both - firstly the
(sorted) table which contained those seriesPairs loaded from myseriesfile and then the
second table which would contain only the new seriesPairs identified during the current parse
of the XML (and which would have to be re-sorted after every addition) */

unsigned long checkExistingSeries(unsigned char *seriesTitle)
{
struct seriesPair target, *result;

	strcpy(target.seriesTitle, seriesTitle);
							/* search old seriesPair table */
	result = bsearch(&target, oldSeriesTable, oldSeriesTotal, sizeof(struct seriesPair), 
		(int (*) (const void *, const void *)) seriesCmp);
	if(result)
		return(result->seriesFSID);
							/* sear new seriesPair table */
	result = bsearch(&target, newSeriesTable, newSeriesTotal, sizeof(struct seriesPair), 
		(int (*) (const void *, const void *)) seriesCmp);
	if(result)
		return(result->seriesFSID);

	else
		return(0);
}

/*========================================================================================*/
void sortSeriesTable(struct seriesPair *table, unsigned long tableSize)
{
	qsort(table, tableSize, sizeof(struct seriesPair), (int (*) (const void *,
		const void *)) seriesCmp);
}
/*========================================================================================*/

int addSeriesPairToTable(struct seriesRecord s)
/* seriesRecord... char seriesTitle[MAX_TIVO_TITLE_LEN];
	unsigned long seriesFSID;		*/
{
struct seriesPair *sPr;

	newSeriesTotal++;

	sPr=newSeriesTable;

	sPr+=newSeriesTotal-1;

	strcpy(sPr->seriesTitle, s.programmeTitle);
	sPr->seriesFSID = s.seriesIndex;
#ifdef DEBUG
	fprintf(stderr, "addSeriesPairToTable() : Added \"%s\" (FSID %lu)\n", sPr->seriesTitle, sPr->seriesFSID);
#endif
	sortSeriesTable(newSeriesTable, newSeriesTotal); /* Put the new seriesPair in place */
	return(1);

}
/*========================================================================================*/
/* Merge the new seriesPair table into the old seriesPair table*/
/* seriesRecord... char seriesTitle[MAX_TIVO_TITLE_LEN]; unsigned long seriesFSID;		*/

int mergeSeriesTables(void)
{
struct seriesPair *s, *t;
unsigned long i;


#ifdef DEBUG
	fprintf(stderr,"\nmergeSeriesTables(): oldSeriesTotal=%lu, newSeriesTotal=%lu\n\n", 
		oldSeriesTotal, newSeriesTotal);
#endif

	if(newSeriesTotal > 0)
		oldSeriesTable=realloc(oldSeriesTable, ((oldSeriesTotal + newSeriesTotal) * sizeof(struct seriesPair)));

	if(!oldSeriesTable)
		return(0);	/* couldn't realloc for new (old)seriesTable */

	s=oldSeriesTable; t=newSeriesTable;

	if(oldSeriesTotal)
		s+=oldSeriesTotal; 

	for(i=0;i<newSeriesTotal; i++)	{	/* add the new seriesPairs to the oldTable */
#ifdef DEBUG
		fprintf(stderr,"mergeSeriesTables(): moving new[%lu] to old \"%s\"\n", i, t->seriesTitle);
#endif
		strcpy(s->seriesTitle, t->seriesTitle);
		s->seriesFSID=t->seriesFSID;
		s++; t++;
		}
	oldSeriesTotal+=newSeriesTotal;
	sortSeriesTable(oldSeriesTable, oldSeriesTotal);   
	return(1);
}
