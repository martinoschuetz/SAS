cas mySession sessopts=(metric=true);
caslib _all_ assign;

/* Macro for loading data into CAS. PROMOTE makes them available in the GUI (VA, ...)*/
%macro load_data(baselib=,caslib=,ds=);
	%if not %sysfunc(exist(&caslib..&ds.)) %then %do;
		proc casutil;
			load data=&baselib..&ds. outcaslib="&caslib." casout="&ds." promote;
    		save casdata="&ds." incaslib="&caslib." outcaslib="&caslib." replace;
    	run; quit;
	%end;
%mend load_data;

/* Import and show public leader board */
PROC IMPORT OUT=work.public_leaderboard 
		DATAFILE="/opt/projects/Corporacion_Favorita/input/favorita-grocery-sales-forecasting-publicleaderboard.csv" 
		DBMS=CSV REPLACE;
	DATAROW=2;
	GETNAMES=YES;
RUN;
quit;

data work.public_leaderboard;
	set work.public_leaderboard;
	format SubmissionDate datetime18.;
run;

proc sort data=work.public_leaderboard;
	by SubmissionDate;
run;

ods graphics on / DISCRETEMAX=8700;
proc sgplot data=work.public_leaderboard(where=(score < 1));
	series x=SubmissionDate y=Score;
	xaxis fitpolicy=thin;
run;
ods graphics / reset;

/* Number of residents by region, year 2010*/
PROC IMPORT OUT=work.Censo_Poblacion_2010 
		DATAFILE="/opt/projects/Corporacion_Favorita/input/Censo_Poblacion_2010.xlsx" 
		DBMS=XLSX REPLACE;
	DATAROW=2;
	GETNAMES=YES;
RUN;
quit;
%load_data(baselib=work,caslib=projdata,ds=Censo_Poblacion_2010);

/* Population of Mexico from 1990 - 2020 */
PROC IMPORT OUT=work.Proyecciones_Poblacionales
		DATAFILE="/opt/projects/Corporacion_Favorita/input/Proyecciones_Poblacionales.xlsx" 
		DBMS=XLSX REPLACE;
	DATAROW=2;
	GETNAMES=YES;
RUN; quit;
%load_data(baselib=work,caslib=projdata,ds=Proyecciones_Poblacionales);


%macro import_csv(ds=);
	PROC IMPORT OUT=work.&ds.    
	            DATAFILE="/opt/projects/Corporacion_Favorita/input/&ds..csv" 
			DBMS=CSV REPLACE;
		DATAROW=2;
		GETNAMES=YES;
	RUN; quit;
	%load_data(baselib=work,caslib=projdata,ds=&ds.);
%mend import_csv;

%import_csv(ds=holidays_events);
%import_csv(ds=items);
%import_csv(ds=oil);
%import_csv(ds=sample_submission);
%import_csv(ds=stores);
%import_csv(ds=test);
%import_csv(ds=train);
%import_csv(ds=transactions);


/* Data profiling - Currently not working. Due to Bug? - sieh Tessa. */
proc cas; 
   dataDiscovery.profile /
      algorithm="PRIMARY"
      table={caslib="projdata" name="train"}
      columns={"date", "store_nbr", "item_nrbr", "unit_sales", "onpromotion"}
      cutoff=20
      frequencies=10
      outliers=5
      casOut={caslib="projdata" name="train_profiled" replace=true};
   run;
quit;

proc ds2 bypartition=yes ds2accel=yes;
	ds2_options trace;
	thread t_pgm / overwrite=yes;
	dcl package dq dq();
	dcl varchar(256) _ERR_;
	dcl varchar(256) Standardized;
	keep ID Name Standardized _ERR_;
	method check_err();
		_ERR_=null;

		if dq.hasError() then
			_ERR_=dq.getError();
	end;
	method init();
		dq.loadLocale('ENUSA');
	end;
	method run();
		set myhive.SampleNames;
		Standardized=dq.standardize('Name', Name);
		check_err();
		output;
	end;
	endthread;
	data myhive.StandardizedNames (overwrite=yes);
		declare thread t_pgm t;
		method run();
			set from t;
		end;
	enddata;
	run;
quit;

cas mysession terminate;