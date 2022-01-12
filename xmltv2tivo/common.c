/*
  TiVo slice decoder

  Copyright 2000 Andrew Tridgell (tridge@samba.org)

  released under the GNU GPL v2 

  THIS PROGRAM AND DERIVATIVES MUST NOT BE USED TO AVOID
  SUBSCRIBING TO THE TIVO SERVICE IN COUNTRIES WHERE THAT
  SERVICE IS AVAILABLE. 
*/

#include "slice.h"
#include "readconfig.h"

char *types[MAX_TYPES];
struct tag attrs[MAX_TYPES][MAX_ATTRS];

static char* strrtrim( char* s)
/*removes trailing spaces from the end of a string*/
{
    int i;
    if (s) 
	{
        i = strlen(s); 
		while ((--i)>0 && isspace(s[i]))
		{
			s[i]=0;
		}
    }
    return s;
}

/* void load_schema(char *fname) */
void load_schema(void)
{
	char * fname = NULL;
	dictionary * ini = NULL;

	FILE *f = NULL;
	int itype, iattr;
	char *type, *attr, *flag;
	char line[BUF_LEN];

	if ( ! (fname = getenv("TIVO_SCHEMA"))) {
		ini = read_configfile();
		if ( ! ini ) {
/*			fprintf(stderr, "Error: Can open config file!\n"); */
			exit(1);
		}else{
			fname = iniparser_getstr(ini, SCHEMA_TOKEN);
			if ( ! fname ) {
				fname = SCHEMA_FILE ;
			}
			if ( ! fill_cfg_path(line, fname) ) {
				fprintf(stderr, "Error: Can't get schema filename!\n");
				exit(1);
			};
			fname = line;
		}
	}
	f = fopen(fname, "r");
	if (!f) {
		perror(fname);
		exit(1);
	}
	while (fgets(line, sizeof(line), f)) {
		if (!isdigit(line[0])) continue;
		if (line[strlen(line)-1] == '\n') line[strlen(line)-1] = 0;
		itype = atoi(strtok(line,"\t "));
		type = strrtrim(strtok(NULL,"\t "));
		iattr = atoi(strtok(NULL,"\t "));
		attr = strrtrim(strtok(NULL,"\t "));
		flag = strrtrim(strtok(NULL,"\t "));
		
		if (!types[itype]) types[itype] = strdup(type);
		attrs[itype][iattr].name = strdup(attr);
		if (strcmp(flag,"string")==0) {
			attrs[itype][iattr].type = TYPE_STRING;
		} else if (strcmp(flag,"int")==0) {
			attrs[itype][iattr].type = TYPE_INT;
		} else if (strcmp(flag,"object")==0) {
			attrs[itype][iattr].type = TYPE_OBJECT;
		} else if (strcmp(flag,"file")==0) {
			attrs[itype][iattr].type = TYPE_FILE;
		}
	}

	fclose(f);

#if 1
	for (itype=0;itype<MAX_TYPES;itype++) {
		if (types[itype] == NULL) {
			sprintf(line,"Unknown#%02x", itype);
			types[itype] = strdup(line);
		}
		for (iattr=0;iattr<MAX_ATTRS;iattr++) {
			if (attrs[itype][iattr].name == NULL) {
				sprintf(line,"Unknown#%02x", iattr);
				attrs[itype][iattr].name = strdup(line);
			}
		}
	}
#endif
}


