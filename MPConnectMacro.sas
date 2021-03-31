******************************************************************************************;
* Program Name: MPConnectMacro.sas                                                       *;
* Program Author: James (Jay) Revere                                                     *;
* Program Created: 20171025                                                              *;
* Program Description: the purpose of this program is to demonstrate the MPConnect       *;
*                      capability of running multiple jobs at the same time with macro   *;
******************************************************************************************;
* Modification History                                                                   *;
******************************************************************************************;
* Date Modified * Editor * Modification Description                                      *;
******************************************************************************************;
* YYYYMMDD        USERID   Narrative                                                     *;
******************************************************************************************;

OPTIONS mprint mlogic symbolgen fullstimer;

******************************************************************************************;
* set the autosignon to yes for automatic signon and identify the sas command             ;
******************************************************************************************;

options autosignon=yes sascmd="!sascmd";

******************************************************************************************;
* this example uses a macro to reduce the overall code to demonstrate the capability     *;
******************************************************************************************;

%macro doit;

******************************************************************************************;
* create a macro loop for the number of session to be spawned                            *;
******************************************************************************************;

%do i = 1 %to 9;

******************************************************************************************;
* using the options statement inside the loop to uniquely identify each spawned session  *;
******************************************************************************************;

options remote=task&i;

******************************************************************************************;
* create a date and time macro variable to uniquely identify the external log files      *;
******************************************************************************************;

%let date_stamp=%sysfunc(today(),yymmddn8.);
%let time_stamp=%sysfunc(compress(%sysfunc(time(),tod8.),%str(:)));
%put &date_stamp._&time_stamp;

******************************************************************************************;
* use the SYSLPUT statement to pass any parameters to the spawned session                *;
******************************************************************************************;

%syslput J=&I;

******************************************************************************************;
* spawn a session using the RSUBMIT COMMAND                                              *;
******************************************************************************************;

RSUBMIT TASK&i. CONNECTWAIT=NO 
LOG="/home/&sysuserid/logs/MPConnectMacro&i._&date_stamp._&time_stamp..log";

******************************************************************************************;
* macro variables defined inside the rsubmit must be qualified with NRSTR otherwise      *;
* they will resolve with the values from the spawning session and not the spawned session*;
******************************************************************************************;

%nrstr(%let date_stamp=%sysfunc(today(),yymmddn8.));
%nrstr(%let time_stamp=%sysfunc(compress(%sysfunc(tranwrd(%sysfunc(time(),tod8.),%str(:),%str())))));

******************************************************************************************;
* define a libref for the session to save output                                         *;
******************************************************************************************;

libname outlib1 "/home/&sysuserid/datasets"; run;

data outlib1.testing_&date_stamp._&time_stamp.;
     do x = 1 to 1000000;
        do y = 1 to &j;
           output;
        end; 
     end;
run;

ENDRSUBMIT;

******************************************************************************************;
* once the session has completed, signoff to close the session                           *;
******************************************************************************************;

signoff task&i;

%end;

%Mend;

%doit;
