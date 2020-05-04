options mprint;

/* 	
Lists all files in a directory.
Requires activation of XCMD.
In SMC expand Server Manager -> SASAPP - > SASAPP - Logical Workspace Server. 
Right click on SASAPP - Workspace Server.
Go to Options Tab -> Advanced Options -> Launch Properties - > Check Allow XCMD.

ToDo:
- Incorporate more Windows listing columns.
- Use UTF8 language string functions.
*/

/* Define the file search pattern to be processed   */
%let FILE=*.*;
%let CMD=cmd /c dir /-c;
%let QUOT=%STR(%');

%macro scanDirectory(DIR=);
	filename indir pipe %UNQUOTE(&QUOT. &CMD. "&DIR.\&FILE." &QUOT.);

	/* read in SAS filenames */
	data files(keep=idx date time size dirname fullname filename name filetype);

		attrib idx		length=8 	format=8. 		label='Index in directory listing';
		attrib date 	length=8 	format=date9. 	label='Date of last file modification';
		attrib time 	length=8 	format=hhmm5. 	label='Time of last file modification';
		attrib size 	length=8 	format=BEST15.	label='Size of file in byte';
		attrib dirname 	length=$260	format=$260.	label='Name of directory in which the file resides';
		attrib fullname	length=$260	format=$260.	label='Name of file including directory path and postfix';
		attrib filename	length=$260	format=$260.	label='Name of file including postfix';
		attrib name		length=$260	format=$260.	label='Name of file excluding postfix';
		attrib filetype	length=$260	format=$260.	label='Postfix / filetype of file';

		retain idx 0;

		infile indir truncover;
		input date_orig $ 1-12 time_orig $ 13-17 size 18-35 fullname $ 36-256;

		date = input(trim(date_orig),DDMMYY10.);
		time = input(trim(time_orig), TIME5.);
		dirname = "&DIR.";
		fullname = "&DIR." || fullname;
		idx = idx + 1;

		/* subsetting if to filter out anything not related to a file */
		if date_orig ne "" and size ne .;

		filename = substr(fullname,length("&DIR.")+1);
		/* Perform search from right to left */
		sep_pos = find(filename,'.',-(length(filename)+1));
		name = substr(filename,1,sep_pos-1);
		filetype = substr(filename,sep_pos+1);
	run;

%mend;

%scanDirectory(DIR=D:\Projects\Audi\src);