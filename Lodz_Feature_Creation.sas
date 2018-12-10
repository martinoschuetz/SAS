options mlogic mprint mprintnest;
options cashost="&syshostname..sas.com" casport=5570;

/* Start CAS Session and assign libs */
cas mysess;
caslib _all_ assign;

/* Macro Processor generating simple strings */
%macro var_names(postfix=);
	%do i=0 %to 9;
		%sysfunc(cat(M0, %sysevalf(36+&i.), &postfix.))
	%end;
%mend var_names;

%let outstring=%var_names(postfix=_VL);
%put &=outstring;

%macro delete_file(filename=,baselib=,caslib=);
	%if %sysfunc(fileexist(&baselib..&filename)) %then
		%do;

			proc fedsql sessref=mysess;
				drop table &caslib..&filename.;
			quit;

		%end;
%mend delete_file;

/* Compute P5 and P95 Percentiles for further feature creation */
proc means data=casdata.sensor_lodz2_cleansed noprint;
	var M0:;
	class asset_ID;
	types asset_ID;
	output out=casdata.sensor_stats(drop=_TYPE_ _FREQ_) p5=p95= / autoname;
run;

%delete_file(filename=lodz_abt,baselib=casdata,caslib=casdata);
/* Join statistics by Asset_Id to actual ABT */
proc fedsql sessref=mysess;;
	create table casdata.lodz_abt as
		select t1.asset_ID, 
			t1.operation_date, 
			t1.Measurement_Time,
			t1.time,    
			t1.operation_shift, 
			t1.M036_VL, 
			t1.M037_VL, 
			t1.M038_VL, 
			t1.M039_VL, 
			t1.M040_VL, 
			t1.M041_VL, 
			t1.M042_VL, 
			t1.M043_VL, 
			t1.M044_VL, 
			t1.M045_VL, 
			t2.M036_VL_P5, 
			t2.M037_VL_P5, 
			t2.M038_VL_P5, 
			t2.M039_VL_P5, 
			t2.M040_VL_P5, 
			t2.M041_VL_P5, 
			t2.M042_VL_P5, 
			t2.M043_VL_P5, 
			t2.M044_VL_P5, 
			t2.M045_VL_P5, 
			t2.M036_VL_P95, 
			t2.M037_VL_P95, 
			t2.M038_VL_P95, 
			t2.M039_VL_P95, 
			t2.M040_VL_P95, 
			t2.M041_VL_P95, 
			t2.M042_VL_P95, 
			t2.M043_VL_P95, 
			t2.M044_VL_P95, 
			t1.Target_Body_Trip
		from casdata.sensor_lodz2_cleansed t1
			left join casdata.sensor_stats t2 on (t1.asset_ID = t2.asset_ID);
quit;

/* Compute lower and upper outlier features wrt P5 and P95 percentiles */
%delete_file(filename=lodz_final_abt,baselib=casdata,caslib=casdata);
data casdata.lodz_final_abt(drop=%var_names(postfix=_VL_P5) %var_names(postfix=_VL_P95) i);
	set casdata.lodz_abt;
	array sensors(*) %var_names(postfix=_VL);
	;
	array p5(*) %var_names(postfix=_VL_P5);
	;
	array p95(*) %var_names(postfix=_VL_P95);
	;
	array Loutlier(*) %var_names(postfix=_VL_LT_P5);
	;
	array Uoutlier(*) %var_names(postfix=_VL_GT_P95);

	do i=1 to dim(sensors);
		if sensors[i] < p5[i] then
			Loutlier[i]=1;
		else Loutlier[i]=0;

		if sensors[i] > p95[i] then
			Uoutlier[i]=1;
		else Uoutlier[i]=0;
	end;
run;

cas mysess terminate;