local util = require("fscb.common.util")
local macro = require("fscb.customInterval.forecast_macro")
local fcst = require("fscb.multistage.forecast")


--[[
validate input arguments for custom_interval_forecast
and set argument defaults if needed

return ciArgs
]]
local function validate_ci_args(args)

  local ciArgs={} 

  -- check required input arguments
  util.my_assert(util.check_value(args.inData), "[CUSTOM_INTERVAL_FORECAST component] Input data is not specified")
  util.my_assert(util.check_value(args.inScalar), "[CUSTOM_INTERVAL_FORECAST component] Input scalar data is not specified")
  util.my_assert(util.check_value(args.idVar), "[CUSTOM_INTERVAL_FORECAST component] No variable specified for time ID")
  util.my_assert(util.check_value(args.idInterval), "[CUSTOM_INTERVAL_FORECAST component] Time ID interval is not specified")
  util.my_assert(util.check_value(args.demandVar), "[CUSTOM_INTERVAL_FORECAST component] Dependent variable is not specified")
  util.my_assert(util.check_value(args.outArray), "[CUSTOM_INTERVAL_FORECAST component] Output data for array is not specified")
  util.my_assert(util.check_value(args.outScalar), "[CUSTOM_INTERVAL_FORECAST component] Output data for scalar is not specified")
  local all_matched
  local match
  local unmatch  
  all_matched, match, unmatch = util.invar_check(args.inData, args.idVar)
  util.my_assert(all_matched, "[CUSTOM_INTERVAL_FORECAST component] The time ID variable ".. args.idVar.." does not exist in data "..args.inData)
  all_matched, match, unmatch = util.invar_check(args.inData, args.demandVar)
  util.my_assert(all_matched, "[CUSTOM_INTERVAL_FORECAST component] The dependent variable ".. args.demandVar.." does not exist in data "..args.inData)
  ciArgs.byVars = ""
  if util.check_value(args.byVars) then
    all_matched, match, unmatch = util.invar_check(args.inData, args.byVars)
    if not all_matched then
      util.my_assert(all_matched, "[CUSTOM_INTERVAL_FORECAST component] The BY variables ".. unmatch.." does not exist in data "..args.inData)
    end
  end
  ciArgs.scalarByVars = ""
  if util.check_value(args.scalarByVars) then
    all_matched, match, unmatch = util.invar_check(args.inScalar, args.scalarByVars)
    if not all_matched then
      util.my_assert(all_matched, "[CUSTOM_INTERVAL_FORECAST component] The BY variables ".. unmatch.." does not exist in data "..args.inScalar)
    end
  end  

  -- check optional input arguments
  for k, v in pairs(args) do    
    ciArgs[k] = v   
  end
  ciArgs.processLib = "WORK"
  if util.check_value(args.processLib) then
    if sas.libref(args.processLib)==0 then
      ciArgs.processLib = args.processLib
    else
      util.my_warning(false, "[CUSTOM_INTERVAL_FORECAST component]  The given processLib"..args.processLib.." does not exist, use work as processLib.")
    end
  end 
  
  if not util.check_value(ciArgs.accumulate) then
    ciArgs.accumulate = "TOTAL"
  end
  if not util.check_value(ciArgs.setmissing) then
    ciArgs.setmissing = 0
  end  
  if not util.check_value(ciArgs.align) then
    ciArgs.align = "E"
  end  

  if not util.check_value(ciArgs.seasonality) then
    local rc = sas.submit([[
        data _NULL_;
           call symputx('ciSeasonality', INTSEAS("@idInterval@"));
        run;
        ]], {idInterval=ciArgs.idInterval})
    ciArgs.seasonality = tonumber(sas.symget("ciSeasonality"))
  end

  local sortData=ciArgs.processLib..".inDataAggSortedByID"
  local intSum=ciArgs.processLib..".intSum"
  local rc = sas.submit([[
      proc sort data=@inData@; by @idVar@; run;
      proc timeid data=@inData@ outinterval=@intSum@;
         id @idVar@;
      run;
      data @intSum@;
        set @intSum@;
        call symputx('ciFcstInDataStart', start);
        call symputx('ciFcstFcstEnd', end);
      run;
      ]], {inData=ciArgs.inData, outData=sortData, intSum=intSum, idVar=ciArgs.idVar},nil,4) 
  
  intSum=ciArgs.processLib..".intSum2"    
  local rc = sas.submit([[
        data @inDataNM@;
          set @inData@;
          if @demandVar@ ne .;
        run;
        proc timeid data=@inDataNM@ outinterval=@intSum@;
           id @idVar@;
        run;
        data @intSum@;
          set @intSum@;
          call symputx('ciFcstInDataEnd', end);
        run;
        ]], {inDataNM=ciArgs.processLib..".ciFcstInDataNoMiss", inData=ciArgs.inData, 
             demandVar=ciArgs.demandVar,intSum=intSum, idVar=ciArgs.idVar},nil,4)
           
  if not util.check_value(ciArgs.start) then
    ciArgs.start = util.value_to_date(sas.symget("ciFcstInDataStart"))
  end           
  if not util.check_value(ciArgs["end"]) then
    ciArgs["end"] = util.value_to_date(sas.symget("ciFcstInDataEnd"))
  end
  ciArgs.fcstEnd = util.value_to_date(sas.symget("ciFcstFcstEnd"))
  
  local rc = sas.submit([[
      data _NULL_;
        call symputx('ciFcstInDataLead', INTCK( "@idInterval@", @dEnd@, &ciFcstFcstEnd ));
      run;
      ]], {idInterval=ciArgs.idInterval, dEnd=ciArgs["end"]})
  if not util.check_value(ciArgs.lead) then
    ciArgs.lead = tonumber(sas.symget("ciFcstInDataLead"))
  elseif ciArgs.lead > sas.symget("ciFcstInDataLead") then
      ciArgs.lead = tonumber(sas.symget("ciFcstInDataLead"))
  end

  if not util.check_value(ciArgs.eventFile) then
    ciArgs.eventFile = ciArgs.processLib..".ciFcstEventFile"
    local eventDefList = "VALENTINES EASTER HALLOWEEN CHRISTMAS"

      -- the eventFile contains the following columns: event_idx, event_name, year, event_date, weight
      local vlist = util.split_string(string.upper(eventDefList))
      local dataArg = ""
      for i = 1, #vlist do
        dataArg = dataArg.."do year=year1 to year2;".."event_idx="..i.."; event_name='"..vlist[i]
                         .."'; event_date=holiday('"..vlist[i].."', year); weight=1;output; end;"
      end
      rc = sas.submit([[
        data @eventData@;
          format event_idx 8. event_name $20. year 8. event_date date9. weight 8.;
          year1=YEAR(@startDate@)-1;
          year2=YEAR(@endDate@)+1;
          @dataArg@
          keep event_idx event_name year event_date weight;
          count=(year2-year1+1)*@numEvent@;
          call symputx('ciFcstEventFileObs', count);
        run;
      ]],{eventData=ciArgs.eventFile, startDate=ciArgs.start, endDate=ciArgs.fcstEnd, dataArg=dataArg, numEvent=#vlist})
      ciArgs.eventFileObs = tonumber(sas.symget("ciFcstEventFileObs"))
  end
  if not util.check_value(ciArgs.eventFileObs) or ciArgs.eventFileObs<=0 then
      local rc = sas.submit([[
      data @eventFile@;
        set @eventFile@ end=lastObs;;
        if lastObs then call symputx('ciFcstEventFileObs', _N_);
      run;
      ]], {eventFile=ciArgs.eventFile})  
      ciArgs.eventFileObs = tonumber(sas.symget("ciFcstEventFileObs"))
  end;
  
  ciArgs.offSeasonRule = "MEAN"
  if util.check_value(args.offSeasonRule) then
    local list = {"MIN", "MAX", "MEAN", "MODE", "MED", "LAST"}
    ciArgs.offSeasonRule = util.validate_sym(args.offSeasonRule, "offSeasonRule", list, nil, nil, "MEAN")
  end  
  
  ciArgs.idForecastMode = "ALL"
  if util.check_value(args.idForecastMode) then
    local list = {"ALL", "AVG"}
    ciArgs.idForecastMode = util.validate_sym(args.idForecastMode, "idForecastMode", list, nil, nil, "ALL")
  end
  
  ciArgs.idForecastMethod = "ACCUMULATE"
  if util.check_value(args.idForecastMethod) then
    local list = {"ACCUMULATE", "SEPARATE"}
    ciArgs.idForecastMethod = util.validate_sym(args.idForecastMethod, "idForecastMethod", list, nil, nil, "ACCUMULATE")
  end
  
  ciArgs.idForecastAccumulate = "TOTAL"
  if util.check_value(args.idForecastAccumulate) then
    local list = {"TOTAL", "AVG", "MIN", "MED", "MAX", "FIRST", "LAST", "MODE"}
    ciArgs.idForecastAccumulate = util.validate_sym(args.idForecastAccumulate, "idForecastAccumulate", list, nil, nil, "TOTAL")
  end
  
  ciArgs.idForecastCriterion = "MSE"
  if util.check_value(args.idForecastCriterion) then
    local list = {"MAPE", "MAE", "MSE"}
    ciArgs.idForecastCriterion = util.validate_sym(args.idForecastCriterion, "idForecastCriterion", list, nil, nil, "MSE")
  end
  
  ciArgs.idForecastSign = "MIXED"
  if util.check_value(args.idForecastSign) then
    local list = {"MIXED", "NONNEGATIVE", "NONPOSITIVE"}
    ciArgs.idForecastSign = util.validate_sym(args.idForecastSign, "idForecastSign", list, nil, nil, "MIXED")
  end

  all_matched, match, unmatch = util.invar_check(args.inData, "_ci_fcst")
  if all_matched then ciArgs.forecastFlag = 0
  else ciArgs.forecastFlag = 1
  end
  ciArgs.dropFcst = 0
  if util.check_value(args.forecastFlag) then
    if args.forecastFlag == 1 then 
      if ciArgs.forecastFlag == 0 then 
        ciArgs.dropFcst = 1
      end
      ciArgs.forecastFlag = 1
    end
  end
  
  ciArgs.debug=0 
  if util.check_value(args.debug) then 
    ciArgs.debug=args.debug
  end
  
  return ciArgs
  
end

--[[
NAME:           custom_interval_forecast

DESCRIPTION:    generate hpf and custom interval forecast for each by group if needed,
                and pick the best one as the final forecast
                
INPUTS:         args
                --required in args
                  cmpLib
                  inData
                  inScalar
                  idVar
                  idInterval
                  demandVar
                  outScalar
                  outArray

                --optional in args
                  processLib
                  byVars
                  scalarByVars
                  lead
                  seasonality
                  accumulate
                  setmissing
                  align
                  start
                  end
                  eventFile
                  eventFileObs
                  offSeasonRule
                  idForecastMode
                  idForecastMethod
                  idForecastAccumulate
                  idForecastCriterion
                  idForecastSign
                  forecastFlag
                  debug
                  debugFile

OUTPUTS:        


USAGE:          
                
]]

function custom_interval_forecast(args)

  local rc   
  local localArgs={} 

  -- validate input arguments
  localArgs = validate_ci_args(args)
  
  -- print out input arguments if in debug

  if localArgs.debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO CUSTOM_INTERVAL_FORECAST:********"
    local s=table.tostring(localArgs)
    if util.check_value(localArgs.debugFile) then
      util.dump_to_file(r, localArgs.debugFile)
      local a = "localArgs="..string.gsub(s, '00000000.-=', '')
      util.dump_to_file(a, localArgs.debugFile)
    else 
      print(r.."\n")
      print("localArgs=", s)                    
    end
  end  
    -- define macro code
  localArgs.repositoryNm = localArgs.processLib..".TmpModRepCopy"
  localArgs.diagEstNm = localArgs.processLib..".TmpDiagEst"
  localArgs.indataset = localArgs.processLib..".TmpInDataSet"
  localArgs.outdataset = localArgs.processLib..".TmpOutDataSet"
  macro.forecast_macro(localArgs)
  
  -- generate hpf forecast
  localArgs.inDataHist = localArgs.processLib..".ciFcstInDataHist"
  rc = sas.submit([[
    data @FilteredinData@ ;
      set @inData@;
      if @idVar@<=@dEnd@;
    run;
  ]],{FilteredinData=localArgs.inDataHist, inData=localArgs.inData,
      idVar = localArgs.idVar, dEnd = localArgs["end"]})
  local fcstArgs={}
  local hpfArgs={}
  fcstArgs.inData = localArgs.inDataHist
  fcstArgs.fcstVar = localArgs.demandVar
  fcstArgs.idVar = localArgs.idVar
  fcstArgs.interval = localArgs.idInterval
  fcstArgs.outFor = localArgs.processLib..".hpfFcstOutFor"
  fcstArgs.processLib = localArgs.processLib
  fcstArgs.runDiag = 1
  fcstArgs.sign = localArgs.idForecastSign
  fcstArgs.byVars = localArgs.byVars
  fcstArgs.modelRepository = localArgs.repositoryNm
  fcstArgs.seasonality = localArgs.seasonality
  fcstArgs.acc = localArgs.accumulate
  hpfArgs.hpfSetmissing = localArgs.setmissing
  hpfArgs.hpfAlign = localArgs.align
  hpfArgs.hpfLead = localArgs.lead
  fcst.run_hpf(fcstArgs,hpfArgs)
  
  -- prepare the merged data which contains inData, hpf_fcst, and inScalar
  localArgs.inMerge1 = localArgs.processLib..".ciFcstInMerge1"
  localArgs.inMerge2 = localArgs.processLib..".ciFcstInMerge2"
  local dropArg = ""
  if localArgs.dropFcst == 1 then
    dropArg = "(drop=_ci_fcst)"
  end
  rc = sas.submit([[
    proc sort data=@inData@; by @byVars@ @idVar@; run;
    data @inMerge1@ (rename=(predict=_hpf_fcst));
      merge @inData@@dropArg@ @outFor@;
      by @byVars@ @idVar@;
    run;
  ]],{inData=localArgs.inData, byVars=localArgs.byVars, idVar=localArgs.idVar,
      inMerge1=localArgs.inMerge1, dropArg=dropArg, outFor=fcstArgs.outFor},nil,4)
  
  local match = nil
  if util.check_value(localArgs.byVars) then 
    local all_matched
    local unmatch  
    all_matched, match, unmatch = util.invar_check(localArgs.inMerge1, localArgs.scalarByVars)
  end
  if util.check_value(match) then
    rc = sas.submit([[
      proc sort data=@inScalar@; by @byVars@; run;
      proc sort data=@inMerge1@; by @byVars@; run;
      data @inMerge2@;
        merge @inMerge1@ @inScalar@;
        by @byVars@;
      run;
    ]],{inScalar=localArgs.inScalar, byVars=match, inMerge1=localArgs.inMerge1,
        inMerge2=localArgs.inMerge2},nil,4)      
  else
    rc = sas.submit([[
      proc sql noprint;
        create table @inMerge2@ as
        select a.*, b.*
        from @inMerge1@ as a,
             @inScalar@ as b;
      quit;
    ]],{inMerge1=localArgs.inMerge1, inMerge2=localArgs.inMerge2, 
        inScalar=localArgs.inScalar, },nil,4)      
  end
  
  -- if the _ci_fcst is passed in through the original data
  localArgs.tdDemandVar = localArgs.demandVar.." _season_code STS_TYPE SEASON_START SEASON_LENGTH EVENT_INDEX BEFORE_EVENT AFTER_EVENT _hpf_fcst"
  localArgs.tdLead = 0
  localArgs.tdEnd = localArgs.fcstEnd
  if localArgs.forecastFlag == 0 then
    localArgs.tdDemandVar = localArgs.tdDemandVar.." _ci_fcst"
  end
    
  -- set up local parameters used in the proc timedata call

  localArgs.outAgg = localArgs.processLib..".ciFcstOutAgg"
  localArgs.byStatement = util.check_value(localArgs.byVars) and "by "..localArgs.byVars or ""
  localArgs.outScalarOption = "_STS_TYPE _BEST_MODEL_INDEX _BEST_SCORE"
  localArgs.outArrayOption = "predict"
  if localArgs.forecastFlag == 1 then 
    localArgs.outArrayOption = localArgs.outArrayOption.. " _ci_fcst"
  end
  if localArgs.debug == 1 then 
    localArgs.outArrayOption = localArgs.outArrayOption.. " _scores"
  end
    

  -- start the main proc timedata call to generate final forecast
  rc = sas.submit_([[
    options cmplib = (@cmpLib@);
    proc sort data=@inMerge2@; by @byVars@ @idVar@; run;
    proc timedata data=@inMerge2@ out=@outAgg@ outscalar=@outScalar@ outarray=@outArray@ seasonality=@seasonality@ lead=@tdLead@;
      @byStatement@;
      id @idVar@ interval=@idInterval@ accumulate=@accumulate@ setmissing=@setmissing@ align=@align@ start=@start@ end=@tdEnd@;
      var @tdDemandVar@ _season_index /setmissing=missing;
      outscalars @outScalarOption@;
      outarrays @outArrayOption@;
      register TSA;
      
          
      /************************************************
        initialize scalar values
      ************************************************/
      _TOT_NOBS = dim(@demandVar@);
      _BEST_MODEL_INDEX=.; _BEST_SCORE=.;
      _STS_TYPE = STS_TYPE[1];

    ]], localArgs)
    
    if localArgs.debug ~= 1 then
      rc = sas.submit_([[      
        array _scores[1]/NOSYMBOLS; call dynamic_array(_scores, _TOT_NOBS); 
      ]], localArgs)    
    end
    if localArgs.forecastFlag == 1 then 
      rc = sas.submit_([[
        do i=1 to dim(_ci_fcst); _ci_fcst[i]=.; end;
      ]], localArgs)  
    end

    -- for non-STS series (STS_TYPE<=0), copy the hpf forecast as the best forecast
    rc = sas.submit_([[   
      /************************************************
        initialize array values
      ************************************************/
      array _event_date[1]/NOSYMBOLS; call dynamic_array(_event_date, @eventFileObs@+1); 
      do i=1 to dim(predict); predict[i]=.; end;
      do i=1 to dim(_scores); _scores[i]=.; end;
      do i=1 to dim(_event_date); _event_date[i]=.; end;
      array _demand[1]/NOSYMBOLS; call dynamic_array(_demand, _TOT_NOBS-@lead@); 
      do i=1 to dim(_demand); _demand[i]=.; end;
      do t=1 to _TOT_NOBS-@lead@;
         _demand[t]=@demandVar@[t];
      end;      
      /************************************************
        check STS_TYPE
      ************************************************/      
      if STS_TYPE[1] <= 0 then do;
        _BEST_MODEL_INDEX = 2; /*_hpf_fcst*/
        do i=1 to _TOT_NOBS;
          predict[i]=_hpf_fcst[i];
        end;
        call ci_compute_forecast_measure(@demandVar@, predict, _TOT_NOBS, "@idForecastCriterion@", scores, scoreCount);
        _scores[2]=scores;
        _BEST_SCORE=scores;
      end;
      else do;
      ]], localArgs)     

    -- for STS series, if the _ci_fcst is not available, first compute _ci_fcst   
    if localArgs.forecastFlag ~= 0 then 
      rc = sas.submit_([[         

        if STS_TYPE[1]=1 then do; /*season*/
                 
          call ci_season_find_trim_info(@idVar@, _season_code, _season_index, _TOT_NOBS, "@idInterval@", @seasonality@, SEASON_START[1],
                                        leadLen, trailLen, expectTrailLen, rc);
  
          call ci_generate_forecast_one(_demand, _season_code, _TOT_NOBS, leadLen, trailLen, expectTrailLen, SEASON_LENGTH[1], 
                            "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "@idForecastMode@", "@idForecastSign@", 
                            "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                            _ci_fcst, outsize, rc);          
       end;
       else do;
          
          call ci_get_event_date("@eventFile@", @eventFileObs@, EVENT_INDEX[1], _event_date, eventCount, tmp_rc); 
          
          inLen=0;
          do i=1 to _TOT_NOBS; 
            if _season_code[i]>inLen then inLen=_season_code[i]; 
          end;
          call ci_event_find_trim_info(@idVar@, _season_code, _event_date, _TOT_NOBS, eventCount, "@idInterval@", BEFORE_EVENT[1], 
                                       leadLen, trailLen, expectTrailLen, rc);
          call ci_generate_forecast_one(_demand, _season_code, _TOT_NOBS, leadLen, trailLen, expectTrailLen, inLen, 
                                        "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "@idForecastMode@", "@idForecastSign@",
                                        "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                                        _ci_fcst, outsize, rc);       
        
       end;   
          
      ]], localArgs)      

    end
     
    -- for STS series, find the best forecast by comparing the hpf forecast and ci forecast    
    rc = sas.submit([[ 
        call ci_compute_forecast_measure(_demand, _ci_fcst, _TOT_NOBS, "@idForecastCriterion@", scores1, scoreCount1);
        call ci_compute_forecast_measure(_demand, _hpf_fcst, _TOT_NOBS, "@idForecastCriterion@", scores2, scoreCount2);
        _scores[1]=scores1;
        _scores[2]=scores2;
        if scores1<=scores2 then do; 
          _BEST_MODEL_INDEX = 1; /*_ci_fcst*/
          _BEST_SCORE=scores1;
          do i=1 to _TOT_NOBS;
            predict[i]=_ci_fcst[i];
          end;
        end;
        else do;
          _BEST_MODEL_INDEX = 2; /*_hpf_fcst*/
          _BEST_SCORE=scores2;
          do i=1 to _TOT_NOBS;
            predict[i]=_hpf_fcst[i];
          end;          
        end;
      end;  /*else end for if STS_TYPE <= 0 then do;*/    
    run;
    ]], localArgs)              
      
    -- clean up output result    
    rc = sas.submit_([[ 
      data @outArray@(rename=(@demandVar@=actual));
        set @outArray@;
        drop STS_TYPE SEASON_START SEASON_LENGTH EVENT_INDEX BEFORE_EVENT AFTER_EVENT;
        if @idVar@>@end@ then @demandVar@=.;
    ]], localArgs) 
    if localArgs.debug == 1 then  
      rc = sas.submit_([[ 
          _season_flag=0;
          if _season_code>0 then _season_flag=1;
        run;
      ]])          
    end
    rc = sas.submit([[ 
      run;
    ]])  
end



return{custom_interval_forecast=custom_interval_forecast}
