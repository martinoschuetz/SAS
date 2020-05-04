libname test "\\missrv01\f_public\custom_interval\testData";
libname temp3 "\\missrv01\f_public\custom_interval\temp\_temp3";


proc lua restart;
    submit;   
        local rootpath=sas.symget("dc_playpen_path")
        package.path = rootpath.."/fswbsrvr/misc/source/lua/?.lua;" .. package.path
        package.loaded["fscb.customInterval.ci_run"]   = nil
        local ciRun =require('fscb.customInterval.ci_run')
        
        local args={}
        args.processLib="temp3"
        args.inData="test.tsc_wood"
        args.idVar="salesdate"
        args.idInterval="WEEK"
        args.demandVar="Qty"
        args.byVars="CategoryDesc UPC Store_State"
        args.outFor="work.outFor"
        args.outModel="work.outModel"
        args.runGrouping = 1
        args.zeroDemandThresholdPct = 0.03
        args.idForecastMode = "AVG"
        args["end"]='"12May2012"d' 
        args.lead=26
        args.debug=1

        rc=ciRun.ci_forecast_run(args)
    endsubmit;
run;

proc timedata data=test.Tsc_wood out=Tsc_wood;
	by CATEGORYDESC UPC STORE_STATE;
    id salesdate interval=WEEK accumulate=TOTAL setmissing=0 align=E;
	var Qty;
run;
proc sql noprint;
	create table temp3.outfor as
	select a.*,b.Qty
	from outfor as a,
	     tsc_wood as b
	where a.CATEGORYDESC=b.CATEGORYDESC and a.UPC=b.UPC and
          a.STORE_STATE=b.STORE_STATE and a.salesdate=b.salesdate
    order by CATEGORYDESC,UPC,STORE_STATE,salesdate;
quit;
data temp3.outmodel;
	set outmodel;
run;
proc sql noprint;
	create table temp3.outforall as
	select a.*,b._BEST_MODEL_INDEX, b._STS_TYPE, b._BEST_SCORE
	from temp3.outfor as a,
	     temp3.outmodel as b
	where a.CATEGORYDESC=b.CATEGORYDESC and a.UPC=b.UPC and
          a.STORE_STATE=b.STORE_STATE
    order by CATEGORYDESC,UPC,STORE_STATE,salesdate;
quit;
