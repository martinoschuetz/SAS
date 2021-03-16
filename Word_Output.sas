/*****************************************************************************/
/* Generate a MS Word document                                              */
/*****************************************************************************/
title;
ods graphics on;
ods word file="/home/sasdemo/Hello_Word.docx" startpage=no
	options(keep_next="yes");
title "Cars";

proc odstext;
	H1 "Cars"/style={textalign=c};
	p "This is the cars dataset." /style={ FONTWEIGHT=bold};
	p "First 5 observations:" /style={ FONTWEIGHT=bold};
run;

proc print data=SASHELP.CARS (obs=5);
run;

proc odstext;
	H2 "Car Types";
run;

proc freq data=SASHELP.CARS;
	tables Type /nocum plots=(freqplot);
run;

proc odstext;
	H2 "My favorite car:";
run;

proc odslist data=SASHELP.CARS (where=(model=" 911 GT2 2dr"));
	item "Make: " || put(make,$50.);
	item "Model: " || put(model,$50.);
	item "Engine: " || put(enginesize, 8.1);
	item "HP: " || put(Horsepower, 8.0);
run;

/*****************************************************************************/
/* Close the Word document                                                   */
/*****************************************************************************/
ods word close;

/*********************************************************************/
/* Send the final doc as e-mail                                      */
/*********************************************************************/

/*
filename outbox email 'elson.filho@sas.com';

filename mymail EMAIL
from ='elson.filho@sas.com'
to ='elson.filho@sas.com'
subject ='Hello Word'
attach =('/home/sbreff/Docs/Hello_Word.docx'
        content_type="application/vnd.ms-word"
        recfm=v lrecl=30000);

data _null_;
file mymail;
put 'Hi there!';
put 'This email should have an attachment of a MS Word document.';
put 'Cheers';
put 'Your SAS program';
run;

*/