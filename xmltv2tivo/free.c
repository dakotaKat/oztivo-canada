#include "xmltv2tivo.h"
/* Free malloc'ed memory */

void freeTables()
{

	if(tivoChannelTable)
		free(tivoChannelTable);
	if(categoryGenreTable)
		free(categoryGenreTable);
	if(oldSeriesTable)
		free(oldSeriesTable);
	if(newSeriesTable)
		free(newSeriesTable);
/*	if(stationDayTable)
		free(stationDayTable);	*/
}



