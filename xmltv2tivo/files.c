/* xmltv2tivo - read/write maps to/from files */

#include "xmltv2tivo.h"

/* populate a table which maps xmltv channel names to tivo channel FSIDs */

int loadStationMap(void)
{
FILE *fpStationsFile;
char *charptr;
char tivoStationBuffer[MAX_CHANNEL_NAME_LEN], stationName[MAX_CHANNEL_NAME_LEN];
int i;
struct channelPair *c;

#ifdef DEBUG
        fprintf(stderr,"\n--------------------------------------------------------\n");
        fprintf(stderr,"Loading XMLTV Channels->StationFSIDs mapfile\n\n");
#endif

	channelsTotal=0;			/* Count the number of stations in STATION_MAP_FILE, for a malloc */

	fpStationsFile=fopen(STATION_MAP_FILE, "r");

	if(!fpStationsFile)
		return(1);		/* File not found or other file error - quit	*/

	while(!feof(fpStationsFile))
		if(fgets(tivoStationBuffer, MAX_CHANNEL_NAME_LEN, fpStationsFile))
			if(tivoStationBuffer[0] != '#' && tivoStationBuffer[0] != ' ' && tivoStationBuffer[0] != '\n')
				channelsTotal++;
	fprintf(stderr, "Found %d stations in station file: \"%s\"\n\n", channelsTotal, STATION_MAP_FILE);

	tivoChannelTable=malloc(channelsTotal * sizeof (struct channelPair));
	if(!tivoChannelTable)
		{
		fprintf(stderr, "Couldn\tt malloc for channelTable\n");
		fclose(fpStationsFile);
		return(1);
		}

	c=tivoChannelTable;	/* Pointer to channel mapping table */

	for(i=0;i<channelsTotal;i++)	/* Initialise the channel table */
		{
		memset(c->channelName,0, MAX_CHANNEL_NAME_LEN);
		c->channelFSID=0;
		c++;
		}


	rewind(fpStationsFile);

	c=tivoChannelTable;	/* re-point to base of channel mapping table */

	while(!feof(fpStationsFile))
		{
		if(fgets(tivoStationBuffer, MAX_CHANNEL_NAME_LEN, fpStationsFile))
			{
			tivoStationBuffer[strlen(tivoStationBuffer)-1]='\0';
#ifdef DEBUG
			fprintf(stderr, "fgets read \"%s\" from fp \n", tivoStationBuffer);
#endif
			if(tivoStationBuffer[0]=='\"')
				{
				charptr=index(tivoStationBuffer,'\"'); charptr++;
				i=0; 
				
				while (*charptr != '\"' && *charptr)
					{
					stationName[i]=*charptr;
					charptr++; i++;
					}
				charptr++;
				stationName[i]='\0';
				strcpy(c->channelName,stationName);
				c->channelFSID=atol(charptr);
#ifdef DEBUG
				fprintf(stderr, "XML Channel Name=|%s| has FSID=%lu\n",stationName, atol(charptr));
#endif
				c++;
				}
			}
		}

#ifdef DEBUG
	c=tivoChannelTable;
 	for(i=0;c->channelFSID;i++)
                {
                fprintf(stderr,"loadStationMap() \"%s\" = \"%lu\" : ", c->channelName, c->channelFSID);
                fprintf(stderr,"\n");
		c++;
                }
        fprintf(stderr,"\nXMLTV Channels->Tivo StationFSIDs mapfile loaded.");
        fprintf(stderr,"\n--------------------------------------------------------\n");
#endif

	fclose(fpStationsFile);
	return(0);
}


/*========================================================================================*/
int loadIndicesFile(void)
{
FILE *fpIndicesFile;
char *charptr;
char tivoIndexBuffer[MAX_FGETS_LINE];


#ifdef DEBUG
	fprintf(stderr,"\n--------------------------------------------------------\n");
	fprintf(stderr,"Loading TiVo Record indices file\n\n");
#endif
	programmeIndex=0;
	seriesIndex=0;
	stationDayIndex=0;
	sliceIndex=0;


	fpIndicesFile=fopen(TIVO_INDICES_FILE, "r");

	if(!fpIndicesFile)
		return(1);		/* File not found or other file error - quit	*/
	
	while(!feof(fpIndicesFile))
		{
		if(fgets(tivoIndexBuffer, MAX_FGETS_LINE, fpIndicesFile))
			{
			tivoIndexBuffer[strlen(tivoIndexBuffer)-1]='\0';
#ifdef DEBUG
			fprintf(stderr, "fgets read \"%s\" from fpIndicesFile \n", tivoIndexBuffer);

#endif
			charptr=tivoIndexBuffer;	
			if(tivoIndexBuffer[0]!='#')
				{
				if(strstr(tivoIndexBuffer,"Series:"))
					{
					charptr+=(strlen("Series:"));
					seriesIndex=atol(charptr);
					}
				if(strstr(tivoIndexBuffer,"Program:"))
					{
					charptr+=(strlen("Program:"));
					programmeIndex=atol(charptr);
					}
				if(strstr(tivoIndexBuffer,"StationDay:"))
					{
					charptr+=(strlen("StationDay:"));
					stationDayIndex=atol(charptr);
					}
				if(strstr(tivoIndexBuffer,"Slice:"))
					{
					charptr+=(strlen("Slice:"));
					sliceIndex=atol(charptr);
					}
				}
			}
		}

	if(!programmeIndex || !seriesIndex || !stationDayIndex || !sliceIndex)
		{
		fprintf(stderr,"Indices file %s is invalid. Missing indices?\n", TIVO_INDICES_FILE);
		return(1);
		}
#ifdef DEBUG
	fprintf(stderr,"Program Index = %lu\n", programmeIndex);
	fprintf(stderr,"Series Index = %lu\n", seriesIndex);
	fprintf(stderr,"StationDay Index = %lu\n", stationDayIndex);
	fprintf(stderr,"Slice Index = %lu\n", sliceIndex);
#endif
	fclose(fpIndicesFile);
	return(0);
}

/*========================================================================================*/
int writeIndicesFile(void)
{
FILE *fpIndicesFile;

#ifdef DEBUG
	fprintf(stderr,"Program Index = %lu\n", programmeIndex);
	fprintf(stderr,"Series Index = %lu\n", seriesIndex);
	fprintf(stderr,"StationDay Index = %lu\n", stationDayIndex);
	fprintf(stderr,"Slice Index = %lu\n", sliceIndex);
#endif

	fpIndicesFile=fopen(TIVO_INDICES_FILE, "w");

	if(!fpIndicesFile)
		return(1);		/* Couldnt open File not found or other file error - quit */
	
	fprintf(fpIndicesFile,"# xmltv2tivo - List of incremental numbers\n");
	fprintf(fpIndicesFile,"Series: %lu\n", seriesIndex);
	fprintf(fpIndicesFile,"Program: %lu\n", programmeIndex);
	fprintf(fpIndicesFile,"StationDay: %lu\n", stationDayIndex);
	fprintf(fpIndicesFile,"Slice: %lu\n", sliceIndex);

	fclose(fpIndicesFile);
	return(0);
}

/*========================================================================================*/
int writeNewSeriesFile(void)
{
FILE *fpNewSeriesFile;
char newFile[25] = "myseriesfile";
unsigned long i;
struct seriesPair *s;

#ifdef DEBUG
	fprintf(stderr,"A total of %lu new series pairs were found in the xml\n", newSeriesTotal);
#endif


	mergeSeriesTables();

	fpNewSeriesFile=fopen(newFile, "w");
	if(!fpNewSeriesFile)
		return(1);		/* Couldnt open File not found or other file error - quit */
	
	s=oldSeriesTable;

	for(i=0;i<oldSeriesTotal;i++)
		{
#ifdef DEBUG
		fprintf(stderr, "writeNewSeriesFile() : Writing out \"%s\"[%lu] == %lu\n",
			s->seriesTitle, i, s->seriesFSID);
#endif

		fprintf(fpNewSeriesFile,"%s_=>_%lu\n", s->seriesTitle, s->seriesFSID);
		s++;
		}
	if(fflush(fpNewSeriesFile))
		{
		fclose(fpNewSeriesFile);
		return(1);
		}
	fclose(fpNewSeriesFile);

/*#ifdef DEBUG*/
	fprintf(stderr,"A total of %lu series pairs was written to \"%s\"\n", oldSeriesTotal, newFile);
/*#endif*/

	return(0);
}
/*========================================================================================*/

/* read into a structure the elements of the file (GENREMAPFILE) which map
xmltv categories (string) to TiVo Genres (int). Returns 1 if genremap loaded, 0 if not */

int loadGenreMap(void)
{
char tivoGenreBuffer[MAX_CATEGORY_LENGTH], categoryName[MAX_CATEGORY_LENGTH];
FILE *fpGenreFile;
char *charptr;
int i, genreCounter;
struct categoryGenrePair *g;

#ifdef DEBUG
        fprintf(stderr,"\n--------------------------------------------------------\n");
        fprintf(stderr,"Loading Categories->Genre mapfile\n\n");
#endif
	categoriesTotal=0;

	fpGenreFile=fopen(GENRE_MAP_FILE, "r");
	if(!fpGenreFile)
		return(1);		/* File not found or other file error - quit	*/

	while(!feof(fpGenreFile))	/* Count the number of categories in GENRE_MAP_FILE, for a malloc */
		if(fgets(tivoGenreBuffer, MAX_CATEGORY_LENGTH, fpGenreFile))
			if(tivoGenreBuffer[0] == '\"')
				categoriesTotal++;

/*	fprintf(stderr, "Found %d categories in \"%s\"\n", categoriesTotal, GENRE_MAP_FILE);*/

	categoryGenreTable=malloc(categoriesTotal * sizeof (struct categoryGenrePair));
	if(!categoryGenreTable)
		{
		fprintf(stderr, "Couldn\tt malloc for category->genre Table\n");
		fclose(fpGenreFile);
		return(1);
		}

	g=categoryGenreTable;	/* Pointer to base of category->genre mapping table */

	for(i=0;i<categoriesTotal;i++)	/* Initialise the categories->genre table */
		{
		memset(g->categoryName,0, MAX_CATEGORY_LENGTH);
		for(genreCounter=0;genreCounter<MAX_GENRES;genreCounter++)
			g->genreNumber[genreCounter]=0;
		g++;
		}

	rewind(fpGenreFile);

	g=categoryGenreTable;		/* re-set pointer to base of table */

	if(!fpGenreFile)
		{
		fprintf(stderr, "File error - \"%s\"\n", GENRE_MAP_FILE);
		return(1);		/* File not found or other file error - quit	*/
		}

	while(!feof(fpGenreFile))
		{
		if(fgets(tivoGenreBuffer, MAX_CATEGORY_LENGTH, fpGenreFile))
			{
			tivoGenreBuffer[strlen(tivoGenreBuffer)-1]='\0';
			if(tivoGenreBuffer[0]=='\"')
				{
				charptr=tivoGenreBuffer; charptr++;
				i=0; 
				while (*charptr != '\"')
					{
					categoryName[i]=*charptr;	/* parse category name */
					charptr++; i++;
					}
				categoryName[i]='\0';
				strcpy(g->categoryName,categoryName);
				genreCounter=0;

/*				fprintf(stderr, "Have stored \"%s\" == ", g->categoryName);*/

				while(*charptr!='\0')	/* Re-write this... we want a check here when last genrenum on line has been read in */
					{
					while ((!isdigit(*charptr)))	/* parse genre number */
						charptr++;
					g->genreNumber[genreCounter]=atoi(charptr);
/*					fprintf(stderr, "%d ", g->genreNumber[genreCounter]); */
					genreCounter++;

					while (isdigit(*charptr))
						charptr++;
					}
/*				fprintf(stderr,"\n");*/
				g++;
				}
			}
		}

#ifdef DEBUG
	g=categoryGenreTable;
        for(i=0;i<categoriesTotal;i++)
                {
                fprintf(stderr,"\"%s\" : ", g->categoryName);
                for(genreCounter=0;genreCounter<MAX_GENRES;genreCounter++)
                        if(g->genreNumber[genreCounter])
                                fprintf(stderr,"%d ", g->genreNumber[genreCounter]);
                fprintf(stderr,"\n");
		g++;
                }
        fprintf(stderr,"\nCategories->Genre mapfile loaded.");
        fprintf(stderr,"\n--------------------------------------------------------\n");
#endif

	qsort(categoryGenreTable, categoriesTotal, sizeof(struct categoryGenrePair), 
		(int (*) (const void *, const void *)) categoryCmp);	/* Just in case the table elements are not in order */
	fclose(fpGenreFile);
	return(0);
}

/*========================================================================================*/
/* Load the seriesFile and .... */

int loadSeriesFile(void)
{
FILE *fpSeriesFile;

char linebuf[1024];
char aSeriesTitle[MAX_TIVO_TITLE_LEN];
char *p,*q,*r;
struct seriesPair *s;
#ifdef DEBUG
unsigned long i;
#endif

	oldSeriesTotal=0;
	fpSeriesFile=fopen(TIVO_SERIES_FILE, "r");

	if(!fpSeriesFile)
		{
		fprintf(stderr, "No series file \"%s\" found, creating one\n\n", TIVO_SERIES_FILE);
		fpSeriesFile=fopen(TIVO_SERIES_FILE, "w");
		if(!fpSeriesFile)
			{
			fprintf(stderr, "Couldn\'t create series file \"%s\"\n\n", TIVO_SERIES_FILE);
			return(1);
			}
		fclose(fpSeriesFile);
		return(0);
		}

	while(!feof(fpSeriesFile))		/* Count the number of series in TIVO_SERIES_FILE for a malloc */
		if(fgets(linebuf, MAX_CATEGORY_LENGTH, fpSeriesFile))
			if(strstr(linebuf, "_=>_"))
				oldSeriesTotal++;

#ifdef DEBUG
	fprintf(stderr, "Found %lu existing series in \"%s\"\n\n", oldSeriesTotal, TIVO_SERIES_FILE);
#endif

	if(oldSeriesTotal)			/* Try and malloc for the seriesTable */

		{
		oldSeriesTable=malloc(oldSeriesTotal * sizeof (struct seriesPair));
		if(!oldSeriesTable)
			{
			fprintf(stderr, "Couldn\tt malloc for series Table\n");
			fclose(fpSeriesFile);
			return(1);
			}
		}

	s=oldSeriesTable;

	rewind(fpSeriesFile);

	while(!feof(fpSeriesFile))
		{
		memset(linebuf,0, 1024);
		fgets(linebuf, 1024, fpSeriesFile);
		p=strstr(linebuf, "_=>_");
                if(p)
			{
			memset(aSeriesTitle, 0, MAX_TIVO_TITLE_LEN);
			q=linebuf; r=aSeriesTitle;
			while(p!=q)
				*r++=*q++;
			*r='\0';
			p+=4; 			/* i.e. p+=strlen("_=>_"); */
#ifdef DEBUG
			fprintf(stderr, "Series = \"%s\", FSID= %lu\n", aSeriesTitle, atol(p));
#endif
			strcpy(s->seriesTitle, aSeriesTitle);
			s->seriesFSID=atol(p);
			s++;
			}
		}
        fclose(fpSeriesFile);

	sortSeriesTable(oldSeriesTable, oldSeriesTotal);
#ifdef DEBUG
	s=oldSeriesTable;			/* Dump the sorted old seriesTable to stderr */
	for(i=0; i< oldSeriesTotal; i++)
		{
		fprintf(stderr, "loadSeriesFile() : Series[%lu] = \"%s\", FSID = %lu\n", 
				i, s->seriesTitle, s->seriesFSID);
		s++;
		}
#endif
        return(0);      
}
/*========================================================================================*/
int loadFiles(void)
{

	if(loadGenreMap()) {
		fprintf(stderr, "Exiting: Failed to open category->genre mapfile \"%s\" errno=(%d)\n",GENRE_MAP_FILE,errno);	
		return(2);
		}

	if(loadStationMap()) {
		fprintf(stderr, "Exiting: Failed to open station->FSID mapfile \"%s\" errno=(%d)\n",STATION_MAP_FILE,errno);	
		return(2);
		}

	if(loadIndicesFile()) {
		fprintf(stderr, "Exiting: Failed to open indices file \"%s\" errno=(%d)\n",TIVO_INDICES_FILE,errno);	
		return(2);
		}

	if(loadSeriesFile()) {
		fprintf(stderr, "Exiting: Failed to open series file \"%s\" errno=(%d)\n",TIVO_SERIES_FILE,errno);	
		return(2);
		}
	return(0);
}
