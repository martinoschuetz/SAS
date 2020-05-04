local util = require("fscb.common.util")
local macro = require("fscb.customInterval.forecast_macro")

--[[
validate input arguments for custom_interval_identification
and set argument defaults if needed

return ciArgs
]]
local function validate_ci_args(args)

  local ciArgs={} 

  -- check required input arguments
  util.my_assert(util.check_value(args.inData), "[CUSTOM_INTERVAL_IDENTIFICATION component] Input data is not specified")
  util.my_assert(util.check_value(args.idVar), "[CUSTOM_INTERVAL_IDENTIFICATION component] No variable specified for time ID")
  util.my_assert(util.check_value(args.idInterval), "[CUSTOM_INTERVAL_IDENTIFICATION component] Time ID interval is not specified")
  util.my_assert(util.check_value(args.demandVar), "[CUSTOM_INTERVAL_IDENTIFICATION component] Dependent variable is not specified")
  util.my_assert(util.check_value(args.outArray), "[CUSTOM_INTERVAL_IDENTIFICATION component] Output data for array is not specified")
  util.my_assert(util.check_value(args.outScalar), "[CUSTOM_INTERVAL_IDENTIFICATION component] Output data for scalar is not specified")
  local all_matched
  local match
  local unmatch  
  all_matched, match, unmatch = util.invar_check(args.inData, args.idVar)
  util.my_assert(all_matched, "[CUSTOM_INTERVAL_IDENTIFICATION component] The time ID variable ".. args.idVar.." does not exist in data "..args.inData)
  all_matched, match, unmatch = util.invar_check(args.inData, args.demandVar)
  util.my_assert(all_matched, "[CUSTOM_INTERVAL_IDENTIFICATION component] The dependent variable ".. args.demandVar.." does not exist in data "..args.inData)
  ciArgs.byVars=""
  if util.check_value(args.byVars) then
    all_matched, match, unmatch = util.invar_check(args.inData, args.byVars)
    if not all_matched then
      util.my_assert(all_matched, "[CUSTOM_INTERVAL_IDENTIFICATION component] The BY variables ".. unmatch.." does not exist in data "..args.inData)
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
      util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  The given processLib"..args.processLib.." does not exist, use work as processLib.")
    end
  end 
  
  if not util.check_value(ciArgs.lead) then
    ciArgs.lead = 0
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
  
  if not util.check_value(ciArgs.segMaxPctError) then
    ciArgs.segMaxPctError = ""
  end
  if not util.check_value(ciArgs.segMaxError) then
    ciArgs.segMaxError = ""
  end
  
  if not util.check_value(ciArgs.zeroDemandThresholdPct) then
    ciArgs.zeroDemandThresholdPct = 0
  end
  if not util.check_value(ciArgs.zeroDemandThreshold) then
    ciArgs.zeroDemandThreshold = 0
  end
  if not util.check_value(ciArgs.seasonality) then
    local rc = sas.submit([[
        data _NULL_;
           call symputx('ciSeasonality', INTSEAS("@idInterval@"));
        run;
        ]], {idInterval=ciArgs.idInterval})
    ciArgs.seasonality = tonumber(sas.symget("ciSeasonality"))
  end
    
  if not util.check_value(ciArgs.gapPeriodThreshold) then
    ciArgs.gapPeriodThreshold = math.ceil(ciArgs.seasonality/4)
  end
  if not util.check_value(ciArgs.ltsMinDemandCycLen) then
    ciArgs.ltsMinDemandCycLen = math.ceil(ciArgs.seasonality*3/4)
  elseif ciArgs.ltsMinDemandCycLen>= ciArgs.seasonality then
    util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  Invalid ltsMinDemandCycLen value ("..ciArgs.ltsMinDemandCycLen
                            .."), should be less than seasonality ("
                            ..ciArgs.seasonality.."). Use "..math.ceil(ciArgs.seasonality*3/4).." instead.")
    ciArgs.ltsMinDemandCycLen = math.ceil(ciArgs.seasonality*3/4)
  end
  
  ciArgs.seasonIndexData = ""
  ciArgs.seasonIndexVar = ""
  if util.check_value(args.seasonIndexData) then
    
    all_matched, match, unmatch = util.invar_check(args.seasonIndexData, args.seasonIndexVar)
    if not all_matched then
      util.my_warning(all_matched, "[CUSTOM_INTERVAL_IDENTIFICATION component] The season index variable ".. unmatch.." does not exist in data "..args.seasonIndexData..". Ignored.")
    else
      ciArgs.seasonIndexData = args.seasonIndexData
      ciArgs.seasonIndexVar = args.seasonIndexVar
    end
  end 
  
  if not util.check_value(ciArgs.eventIdentifyFlag) then
    ciArgs.eventIdentifyFlag = 1
  end
  if not util.check_value(ciArgs.eventDefBufferLen) then
    ciArgs.eventDefBufferLen = 0
  end
  if not util.check_value(ciArgs.eventPeriodLenThreshold) then
    ciArgs.eventPeriodLenThreshold = math.ceil(ciArgs.seasonality/4)
  end  
  if ciArgs.eventPeriodLenThreshold >=ciArgs.seasonality then 
    util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  Invalid eventPeriodLenThreshold value ("..ciArgs.eventPeriodLenThreshold
                            .."), should be less than seasonality ("
                            ..ciArgs.seasonality.."). Use "..math.ceil(ciArgs.seasonality/4).." instead.")
    ciArgs.eventPeriodLenThreshold = math.ceil(ciArgs.seasonality/4)
  end
  -- validate event definition
  if ciArgs.eventIdentifyFlag == 1 then 
    local validData = false
    local validList = false
    local defEventList = "VALENTINES EASTER HALLOWEEN CHRISTMAS"
    local defEventMsg = "use the default event list ("..defEventList..") instead."
    -- validate event definition list
    if util.check_value(ciArgs.eventDefList) then
      local list = {"BOXING", "CANADA", "CANADAOBSERVED", "CHRISTMAS", "COLUMBUS", "EASTER", "FATHERS", 
                    "HALLOWEEN", "LABOR", "MEMORIAL", "MLK", "MOTHERS", "NEWYEAR", "THANKSGIVING", 
                    "THANKSGIVINGCANADA", "USINDEPENDENCE", "USPRESIDENTS", "VALENTINES", "VETERANS", 
                    "VETERANSUSG", "VETERANSUSPS", "VICTORIA"}
      local vlist = util.split_string(string.upper(ciArgs.eventDefList))
      all_matched = true
      match = ""
      unmatch = ""
      local i, k, s, v, found
      for i = 1, #vlist do
        s = vlist[i]
        found = false
        for k, v in pairs(list) do
          if (s==v) then
            found = true
            break
          end
        end
        if not found then
          all_matched = false
          unmatch = util.add_to_string(unmatch, s)
        else
          match = util.add_to_string(match, s)
        end
      end 
      if util.check_value(match) then
        util.my_warning(all_matched, "[CUSTOM_INTERVAL_IDENTIFICATION component]  The event definition ("..unmatch..") in eventDefList is not supported. Ignore.")
        defEventMsg = "ignore."
        ciArgs.eventDefList = match
        validList = true
      end
    end
    -- validate event definition data
    if util.check_value(ciArgs.eventDefData) then 
      if not sas.exists(ciArgs.eventDefData) then
        util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  The event definition data file "..ciArgs.eventDefData.." does not exist. "..defEventMsg)
        ciArgs.eventDefData = ""
      elseif not util.check_file_non_empty(ciArgs.eventDefData) then
        util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  The event definition data file "..ciArgs.eventDefData.." is empty. "..defEventMsg)
        ciArgs.eventDefData = ""
      else
        validData = true      
      end      
    end
    -- if neither list nor data is valid, use the default list
    if (not validList) and (not validData) then
      if util.check_value(ciArgs.eventDefList) then -- the list was specified, but there is no valid elements inside
        util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  The event definition ("..ciArgs.eventDefList..") in eventDefList is not supported. "..defEventMsg)
      elseif not util.check_value(ciArgs.eventDefData) then -- neither the list nor the data is specified
        util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  The event definition is not specified in either eventDefList or eventDefData. "..defEventMsg)
      end
      ciArgs.eventDefList = defEventList
    end
    
    if ciArgs.eventDefBufferLen + ciArgs.eventPeriodLenThreshold >=ciArgs.seasonality then 
      util.my_warning(false, "[CUSTOM_INTERVAL_IDENTIFICATION component]  Invalid eventDefBufferLen value ("..ciArgs.eventDefBufferLen
                        .."), should be less than seasonality ("
                        ..ciArgs.seasonality..")-eventPeriodLenThreshold("..ciArgs.eventPeriodLenThreshold"). Use 0 instead.")
      ciArgs.eventPeriodLenThreshold = 0
    end
  end
  
  if (not util.check_value(ciArgs.start)) or (not util.check_value(ciArgs["end"])) then
    local sortData=ciArgs.processLib..".inDataSortedByID"
    local intSum=ciArgs.processLib..".intSum"
    local rc = sas.submit([[
        data @inDataNM@;
          set @inData@;
          if @demandVar@ ne .;
        run;
        proc sort data=@inDataNM@; by @idVar@; run;
        proc timeid data=@inDataNM@ outinterval=@intSum@;
           id @idVar@;
        run;
        data @intSum@;
          set @intSum@;
          call symputx('ciIdInDataStart', start);
          call symputx('ciIdInDataEnd', end);
        run;
        ]], {inDataNM=ciArgs.processLib..".ciIDInDataNoMiss", inData=ciArgs.inData, 
             demandVar=ciArgs.demandVar, outData=sortData, intSum=intSum, 
             idVar=ciArgs.idVar},nil,4)   

    if not util.check_value(ciArgs.start) then
      ciArgs.start = util.value_to_date(sas.symget("ciIdInDataStart"))
    end
    if not util.check_value(ciArgs["end"]) then
      ciArgs["end"] = util.value_to_date(sas.symget("ciIdInDataEnd"))
    end
  end
  
  if ciArgs.lead>0 then
    rc = sas.submit([[
        data _NULL_;
          call symputx('ciIdFcstEnd', INTNX("@interval@",@dEnd@+1,@lead@));
        run;
        ]], {interval=ciArgs.idInterval, dEnd=ciArgs["end"], lead=ciArgs.lead})  
    ciArgs.fcstEnd = util.value_to_date(sas.symget("ciIdFcstEnd"))
  else 
    ciArgs.fcstEnd = ciArgs["end"] 
  end
  
  ciArgs.inSeasonRule = "MEAN"
  if util.check_value(args.inSeasonRule) then
    local list = {"MIN", "MAX", "MEAN", "MODE", "MED", "LAST"}
    ciArgs.inSeasonRule = util.validate_sym(args.inSeasonRule, "inSeasonRule", list, nil, nil, "MEAN")
  end  
  
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

  ciArgs.forecastFlag=0 
  if util.check_value(args.forecastFlag) then 
    ciArgs.forecastFlag = args.forecastFlag
  end  
  
  ciArgs.debug=0 
  if util.check_value(args.debug) then 
    ciArgs.debug=args.debug
  end
  
  return ciArgs
  
end

--[[
NAME:           custom_interval_identification

DESCRIPTION:    identify custom intervals for each by group
                
INPUTS:         args
                --required in args
                  cmpLib
                  inData
                  idVar
                  idInterval
                  demandVar
                  outScalar
                  outArray

                --optional in args
                  processLib
                  byVars
                  lead
                  seasonality
                  accumulate
                  setmissing
                  align
                  segMaxPctError
                  segMaxError
                  zeroDemandThresholdPct
                  zeroDemandThreshold
                  gapPeriodThreshold
                  ltsMinDemandCycLen
                  seasonIndexData
                  seasonIndexVar
                  eventIdentifyFlag
                  eventPeriodLenThreshold
                  eventDefData
                  eventDefList
                  eventDefBufferLen
                  start
                  end
                  inSeasonRule
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

function custom_interval_identification(args)

  local rc   
  local localArgs={} 

  -- validate input arguments
  localArgs = validate_ci_args(args)
  
  -- print out input arguments if in debug

  if localArgs.debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO CUSTOM_INTERVAL_IDENTIFICATION:********"
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
    
  -- set up local parameters used in the proc timedata call
  localArgs.outAgg = localArgs.processLib..".ciIdOutAgg"
  localArgs.byStatement = util.check_value(localArgs.byVars) and "by "..localArgs.byVars or ""
  localArgs.outScalarOption = "STS_TYPE SEASON_START SEASON_LENGTH EVENT_INDEX BEFORE_EVENT AFTER_EVENT"
  localArgs.outArrayOption = "_season_code _season_index"
  if localArgs.forecastFlag == 1 or localArgs.debug == 1 then 
    localArgs.outArrayOption = localArgs.outArrayOption.. " _ci_fcst"
  end
  if localArgs.debug == 1 then 
    localArgs.outArrayOption = localArgs.outArrayOption.. " _seg_index _seg_value _active_demand _demand_cycle_len _period_start _period_end"
    localArgs.outArrayOption = localArgs.outArrayOption.. " _event_date _before_dist _after_dist _season_flag _out_fcst _eva_score"
    localArgs.outScalarOption = localArgs.outScalarOption.. " _LOCAL_ZERO_THRESHOLD _DEMAND_CYC_LEN_MAX _DEMAND_CYC_LEN_MEAN _CURRENT_CYC_INDEX _TRAILING_ZERO_LEN"
    localArgs.outScalarOption = localArgs.outScalarOption.. " _SEASON_LENGTH_MIN _SEASON_LENGTH_MAX _BEFORE_DIST_MIN _BEFORE_DIST_MAX _AFTER_DIST_MIN _AFTER_DIST_MAX bestSS"
    localArgs.outScalarOption = localArgs.outScalarOption.. " _BEST_SCORE _EVA_COUNT"
  end
  
  -- define macro code
  localArgs.repositoryNm = localArgs.processLib..".TmpModRepCopy"
  localArgs.diagEstNm = localArgs.processLib..".TmpDiagEst"
  localArgs.indataset = localArgs.processLib..".TmpInDataSet"
  localArgs.outdataset = localArgs.processLib..".TmpOutDataSet"
  macro.forecast_macro(localArgs)
  
  -- prepare event data file
  localArgs.eventFile = localArgs.processLib..".ciIdEventFile"
  localArgs.eventFileObs = 0
  if localArgs.eventIdentifyFlag == 1 then
    -- TODO: consider eventDefData case
    -- If eventDefData is provided, it should be combined with eventDefList to generate eventFile, 
    -- and it should have higher priority then eventDefList
    if util.check_value(localArgs.eventDefList) then
      -- the eventFile contains the following columns: event_idx, event_name, year, event_date, weight
      local vlist = util.split_string(string.upper(localArgs.eventDefList))
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
          call symputx('ciIdEventFileObs', count);
        run;
      ]],{eventData=localArgs.eventFile, startDate=localArgs.start, endDate=localArgs.fcstEnd, dataArg=dataArg, numEvent=#vlist})
      localArgs.eventFileObs = tonumber(sas.symget("ciIdEventFileObs"))
    end
  end

  -- start the main proc timedata call to identify custom intervals
  rc = sas.submit_([[
    %dcc_class_fcmp_fnc(cmp_lib=@processLib@.timefnc);
    options cmplib = (@cmpLib@ @processLib@.timefnc);
    proc sort data=@inData@; by @byVars@ @idVar@; run;
    ]], localArgs)  
    
  if util.check_value(localArgs.seasonIndexData) then 
    localArgs.tempOutAgg = localArgs.processLib..".ciIdOutAggTemp"
    rc = sas.submit_([[  
      proc timedata data=@inData@ out=@tempOutAgg@ seasonality=@seasonality@ lead=@lead@;
        @byStatement@;
        id @idVar@ interval=@idInterval@ accumulate=@accumulate@ setmissing=@setmissing@ align=@align@ start=@start@ end=@end@;
        var @demandVar@;
      run;
      proc timedata data=@tempOutAgg@ auxdata=@seasonIndexData@ out=@outAgg@ outscalar=@outScalar@ outarray=@outArray@ seasonality=@seasonality@;
        @byStatement@;
        id @idVar@ interval=@idInterval@ accumulate=@accumulate@ setmissing=@setmissing@ align=@align@;
        var @demandVar@ @seasonIndexVar@;
        outscalars @outScalarOption@;
        outarrays @outArrayOption@;
        register TSA;
      ]], localArgs)  
  else
    rc = sas.submit_([[  
      proc timedata data=@inData@ out=@outAgg@  outscalar=@outScalar@ outarray=@outArray@ seasonality=@seasonality@ lead=@lead@;
        @byStatement@;
        id @idVar@ interval=@idInterval@ accumulate=@accumulate@ setmissing=@setmissing@ align=@align@ start=@start@ end=@end@;
        var @demandVar@;
        outscalars @outScalarOption@;
        outarrays @outArrayOption@;
        register TSA;
      ]], localArgs) 
  end
     
  rc = sas.submit_([[      
      /************************************************
        initialize scalar values
      ************************************************/
      _TOT_NOBS = dim(@demandVar@)-@lead@;
      _LEADING_ZERO_LEN=.;_TRAILING_ZERO_LEN=.;_TRIM_NOBS=.;
      _ABS_DEMAND_MAX=.;
      _DEMAND_CYC_LEN_COUNT=.; _CURRENT_CYC_INDEX=.; _CURRENT_CYC_INDEX=.;
      _DEMAND_CYC_LEN_MEAN=.; _DEMAND_CYC_LEN_MIN=.; _DEMAND_CYC_LEN_MAX=.;
      _SEASON_LENGTH_MIN=.; _SEASON_LENGTH_MAX=.; 
      _BEFORE_DIST_MIN=.; _BEFORE_DIST_MAX=.; _AFTER_DIST_MIN=.; _AFTER_DIST_MAX=.;
      _EVA_COUNT=0; bestSS=.;
      
      STS_TYPE = -1;
      SEASON_START=.; SEASON_LENGTH=.; EVENT_INDEX=.; BEFORE_EVENT=.; AFTER_EVENT=.; NSEASONS=.;
        
      /************************************************
       compute _LOCAL_ZERO_THRESHOLD
      ************************************************/
      array _absolute_demand[1]/NOSYMBOLS; call dynamic_array(_absolute_demand, _TOT_NOBS); 
      array _demand[1]/NOSYMBOLS; call dynamic_array(_demand, _TOT_NOBS); 
      array _demand_all[1]/NOSYMBOLS; call dynamic_array(_demand_all, _TOT_NOBS+@lead@); 
      array _idVar[1]/NOSYMBOLS; call dynamic_array(_idVar, _TOT_NOBS); 
      do i=1 to dim(_demand_all); _demand_all[i]=.; end;
      do t=1 to _TOT_NOBS;
         if @demandVar@[t] ne . then _absolute_demand[t]=abs(@demandVar@[t]);
         else _absolute_demand[t] = .;
         _demand[t]=@demandVar@[t];
         _demand_all[t]=@demandVar@[t];
         _idVar[t]=@idVar@[t];
      end;
      _LOCAL_ZERO_THRESHOLD = 0;

      if @zeroDemandThresholdPct@ ne 0 then do;
          call ci_compute_order_stats(_absolute_demand, _ABS_DEMAND_MIN, _ABS_DEMAND_MEDIAN, _ABS_DEMAND_MAX);
          if _ABS_DEMAND_MAX ne . then _LOCAL_ZERO_THRESHOLD=_ABS_DEMAND_MAX*@zeroDemandThresholdPct@;
          else _LOCAL_ZERO_THRESHOLD=0;
      end;
      else do;
          _LOCAL_ZERO_THRESHOLD = @zeroDemandThreshold@;
      end;   
    ]], localArgs)
    
    if localArgs.debug ~= 1 then
      rc = sas.submit_([[      
        array _seg_index[1]/NOSYMBOLS; call dynamic_array(_seg_index, _TOT_NOBS); 
        array _seg_value[1]/NOSYMBOLS; call dynamic_array(_seg_value, _TOT_NOBS); 
        array _active_demand[1]/NOSYMBOLS; call dynamic_array(_active_demand, _TOT_NOBS+@lead@); 
        array _demand_cycle_len[1]/NOSYMBOLS; call dynamic_array(_demand_cycle_len, _TOT_NOBS);
        array _period_start[1]/NOSYMBOLS; call dynamic_array(_period_start, _TOT_NOBS); 
        array _period_end[1]/NOSYMBOLS; call dynamic_array(_period_end, _TOT_NOBS);
        array _event_date[1]/NOSYMBOLS; call dynamic_array(_event_date, @eventFileObs@+1); 
        array _before_dist[1]/NOSYMBOLS; call dynamic_array(_before_dist, @eventFileObs@+1); 
        array _after_dist[1]/NOSYMBOLS; call dynamic_array(_after_dist, @eventFileObs@+1);
        array _season_flag[1]/NOSYMBOLS; call dynamic_array(_season_flag, _TOT_NOBS+@lead@);
        array _out_fcst[1]/NOSYMBOLS; call dynamic_array(_out_fcst, _TOT_NOBS+@lead@);    
        array _eva_score[1]/NOSYMBOLS; call dynamic_array(_eva_score, _TOT_NOBS+@lead@);    
      ]], localArgs)    
    end
    
    if localArgs.debug ~= 1 and localArgs.forecastFlag ~=1 then
      rc = sas.submit_([[      
        array _ci_fcst[1]/NOSYMBOLS; call dynamic_array(_ci_fcst, _TOT_NOBS+@lead@);     
      ]], localArgs)    
    end
    
    rc = sas.submit_([[   
      /************************************************
        initialize array values
      ************************************************/
      do i=1 to dim(_season_code); _season_code[i]=.; end;
      do i=1 to dim(_seg_index); _seg_index[i]=.; end;
      do i=1 to dim(_seg_value); _seg_value[i]=.; end;
      do i=1 to dim(_active_demand); _active_demand[i]=.; end;
      do i=1 to dim(_demand_cycle_len); _demand_cycle_len[i]=.; end;
      do i=1 to dim(_period_start); _period_start[i]=.; end;
      do i=1 to dim(_period_end); _period_end[i]=.; end;
      do i=1 to dim(_event_date); _event_date[i]=.; end;
      do i=1 to dim(_before_dist); _before_dist[i]=.; end;
      do i=1 to dim(_after_dist); _after_dist[i]=.; end;
      do i=1 to dim(_season_index); _season_index[i]=.; end;
      do i=1 to dim(_season_flag); _season_flag[i]=.; end;
      do i=1 to dim(_out_fcst); _out_fcst[i]=.; end;
      do i=1 to dim(_eva_score); _eva_score[i]=.; end;
      
      /************************************************
        demand series approximation
      ************************************************/   
      rc = TSA_SEGMENTATION(_demand,"MEAN", "ABSOLUTE", 2, _TOT_NOBS-1, @segMaxError@, @segMaxPctError@, _seg_index, _seg_value);
      
      /************************************************
        compute statistics related to NOBS
      ************************************************/
      _LEADING_ZERO_LEN = dc_lead_zero_length(_seg_value, _LOCAL_ZERO_THRESHOLD);
      _TRAILING_ZERO_LEN = dc_trail_zero_length(_seg_value, _LOCAL_ZERO_THRESHOLD);
      if dim(_seg_value) > _TOT_NOBS then _TRAILING_ZERO_LEN=_TRAILING_ZERO_LEN-@lead@;
      _TRIM_NOBS = _TOT_NOBS-_LEADING_ZERO_LEN-_TRAILING_ZERO_LEN;
      if _TRIM_NOBS<0 then _TRIM_NOBS=0;
      
      /************************************************
       identify components
      ************************************************/
      array _nonzero_demand[1]/NOSYMBOLS; call dynamic_array(_nonzero_demand, _TOT_NOBS); 
      array _demand_interval[1]/NOSYMBOLS; call dynamic_array(_demand_interval, _TOT_NOBS); 
      array _active_period_len[1]/NOSYMBOLS; call dynamic_array(_active_period_len, _TOT_NOBS); 
      array _gap_len[1]/NOSYMBOLS; call dynamic_array(_gap_len, _TOT_NOBS); 
      array _active_demand_trim[1]/NOSYMBOLS; call dynamic_array(_active_demand_trim, _TOT_NOBS); 
      array _seg_value_trim[1]/NOSYMBOLS; call dynamic_array(_seg_value_trim, _TOT_NOBS); 
      do i=1 to _TOT_NOBS; _seg_value_trim[i]=_seg_value[i]; end;

      call dc_identify_components(_seg_value_trim, _TRIM_NOBS, _LEADING_ZERO_LEN, _TRAILING_ZERO_LEN, _LOCAL_ZERO_THRESHOLD, @gapPeriodThreshold@,
                                   _nonzero_demand, _active_demand_trim, _demand_interval, _active_period_len, _demand_cycle_len, _gap_len,
                                   _NONZERO_DEMAND_COUNT, _DEMAND_COUNT, _DEMAND_INT_COUNT, _DEMAND_PERIOD_LEN_COUNT, _DEMAND_CYC_LEN_COUNT, 
                                   _GAP_INT_LEN_COUNT, _CURRENT_CYC_INDEX);  
      do i=1 to _TOT_NOBS; _active_demand[i]=_active_demand_trim[i]; end;
      call ci_find_active_period_range(_active_demand_trim, 0, 0, _period_start, _period_end, periodCount, tmp_rc);

      /************************************************
       check if the series is STS or not
       if eventIdentifyFlag is on, identify STS_TYPE
      ************************************************/
      if periodCount>0 and _DEMAND_CYC_LEN_COUNT>0 then do;
          do i=1 to dim(_demand_cycle_len);
            _demand_cycle_len[i]=.;
          end;
          _DEMAND_CYC_LEN_COUNT=periodCount;
          do i=1 to periodCount;
            _demand_cycle_len[i]=_period_end[i]-_period_start[i]+1;
          end;
          call dc_compute_basic_stats(_demand_cycle_len, _DEMAND_CYC_LEN_COUNT, _DEMAND_CYC_LEN_MEAN, _DEMAND_CYC_LEN_STDEV, _DEMAND_CYC_LEN_MIN, 
                                      _DEMAND_CYC_LEN_MEDIAN, _DEMAND_CYC_LEN_MAX);
        if _DEMAND_CYC_LEN_MAX<=@ltsMinDemandCycLen@ and _CURRENT_CYC_INDEX-_TRAILING_ZERO_LEN<=@ltsMinDemandCycLen@ then do;
          if @eventIdentifyFlag@ eq 0 then STS_TYPE = 1; /*seasonal*/
        end;
        else STS_TYPE = 0; /*NON-STS*/
      end;
      else STS_TYPE = 0; /*NON-STS*/
     
      if @eventIdentifyFlag@ ne 0 and STS_TYPE ne 0 then do;
        if _DEMAND_CYC_LEN_MEAN>@eventPeriodLenThreshold@ then STS_TYPE = 1; /*seasonal*/
        else do;
          call ci_find_active_event(_active_demand_trim, _idVar, "@eventFile@", @eventFileObs@, "@idInterval@", @eventDefBufferLen@, EVENT_INDEX, tmp_rc);
          if EVENT_INDEX eq . then STS_TYPE=1; /*seasonal*/
          else STS_TYPE=2; /*event*/
        end;
      end;

      /************************************************
       Generate information for STS series
      ************************************************/      
      array _season_code_trim[1]/NOSYMBOLS; call dynamic_array(_season_code_trim, _TOT_NOBS);
      do i=1 to _TOT_NOBS; _season_code_trim[i]=.; end;
      
      if STS_TYPE=1 then do; /*season*/
        /************************************************
         Generate information for season type
        ************************************************/
    ]], localArgs)    
    
    if util.check_value(localArgs.seasonIndexVar) then
      rc = sas.submit_([[      
        do i=1 to _TOT_NOBS+@lead@;
          _season_index[i]=@seasonIndexVar@[i];
        end; 
      ]], localArgs)  
    else
      rc = sas.submit_([[      
        do i=1 to _TOT_NOBS+@lead@;
          _season_index[i]=_SEASON_[i];
        end; 
      ]], localArgs) 
    end

   rc = sas.submit_([[         
        array periodRange[1]/NOSYMBOLS; call dynamic_array(periodRange, periodCount); 
        do t=1 to periodCount;
          periodRange[t]=_period_end[t]-_period_start[t]+1; 
        end;
        call ci_compute_order_stats(periodRange, _SEASON_LENGTH_MIN, _SEASON_LENGTH_MEDIAN, _SEASON_LENGTH_MAX);
        
        array allPeriodStart[1]/NOSYMBOLS; call dynamic_array(allPeriodStart, periodCount+2); 
        array allPeriodEnd[1]/NOSYMBOLS; call dynamic_array(allPeriodEnd, periodCount+2);
        call ci_find_active_period_range(_active_demand_trim, 1, 1, allPeriodStart, allPeriodEnd, allPeriodCount, tmp_rc);
        array inPeriodStart[1]/NOSYMBOLS; call dynamic_array(inPeriodStart, periodCount+1); 
        array inPeriodEnd[1]/NOSYMBOLS; call dynamic_array(inPeriodEnd, periodCount+1);
        
        bestSL = .; bestSS = .; 
        _BEST_SCORE=.;
        do sl=_SEASON_LENGTH_MIN to _SEASON_LENGTH_MAX;
          ssIndex=1;
          do t=1 to allPeriodCount;
            options = ci_season_compute_option_count(allPeriodStart, allPeriodEnd, allPeriodCount, _TOT_NOBS, sl, t);
            ssIndex=ssIndex*options;
          end;
          do ss=1 to ssIndex;
            call ci_find_season_series_seasons(allPeriodStart, allPeriodEnd, allPeriodCount, _TOT_NOBS, sl, ss,
                                               _season_code_trim, tmp_rc);
            if tmp_rc eq 0 then do;
              _EVA_COUNT=_EVA_COUNT+1;

              call ci_find_inseason_periods_by_code(_season_code_trim, 0, 1,inPeriodStart, inPeriodEnd, inPeriodCount);
              seasonStart=ci_find_season_start_index(inPeriodStart, inPeriodCount, _season_index, "@inSeasonRule@");
              call ci_season_find_trim_info(_idVar, _season_code_trim, _season_index, _TOT_NOBS, "@idInterval@", @seasonality@, seasonStart, 
                                            leadLen, trailLen, expectTrailLen, rc);
                       
              call ci_generate_forecast_one(_demand, _season_code_trim, _TOT_NOBS, leadLen, trailLen, expectTrailLen, sl, 
                                "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "@idForecastMode@", "@idForecastSign@", 
                                "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                                _out_fcst, outsize, rc);
                                
              call ci_compute_forecast_measure(_demand, _out_fcst, _TOT_NOBS, "@idForecastCriterion@", score, scoreCount);  
              _eva_score[_EVA_COUNT]=score;                
              if _BEST_SCORE eq . then do;
                _BEST_SCORE=score;
                bestSL = sl; bestSS = ss; 
              end; 
              else if _BEST_SCORE>score then do;
                _BEST_SCORE=score;
                bestSL = sl; bestSS = ss; 
              end;           
            end;/*if tmp_rc eq 0 then do;*/
          end;/*do ss=1 to ssIndex;*/
        end;/*do sl=_SEASON_LENGTH_MIN to _SEASON_LENGTH_MAX;*/
        
        SEASON_LENGTH=bestSL;
        call ci_find_season_series_seasons(allPeriodStart, allPeriodEnd, allPeriodCount, _TOT_NOBS, bestSL, bestSS,
                                           _season_code_trim, rc); 
        call ci_find_inseason_periods_by_code(_season_code_trim, 0, 1,inPeriodStart, inPeriodEnd, inPeriodCount);
        SEASON_START=ci_find_season_start_index(inPeriodStart, inPeriodCount, _season_index, "@inSeasonRule@");                                                                   
        call ci_season_find_trim_info(_idVar, _season_code_trim, _season_index, _TOT_NOBS, "@idInterval@", @seasonality@, SEASON_START, 
                                      leadLen, trailLen, expectTrailLen, rc);
        do i=1 to _TOT_NOBS; _season_code[i]=_season_code_trim[i];end;
        if @lead@>0 then do;
          flag=0;
          if _season_code[_TOT_NOBS]>0 then flag=1;
          do i=_TOT_NOBS+1 to _TOT_NOBS+@lead@;
            if flag=1 then do;
              if _season_code[i-1]<SEASON_LENGTH then _season_code[i]=_season_code[i-1]+1;
              else do;
                flag=0;
                _season_code[i]=0;
              end;
            end;
            else do;
              if _season_index[i] eq SEASON_START then do;
                if i<_TOT_NOBS+@lead@ then do;
                  if _season_index[i] eq _season_index[i+1] then _season_code[i]=0;
                  else do;
                    flag=1;
                    _season_code[i]=1;
                  end;
                end; 
                else do;
                  flag=1;
                  _season_code[i]=1;
                end;        
              end;
              else _season_code[i]=0;
            end;
          end;
          
        end;
                                              
      ]], localArgs)    

                                          
    if localArgs.debug == 1 then
      rc = sas.submit_([[
          call ci_generate_forecast_one(_demand, _season_code_trim, _TOT_NOBS, leadLen, trailLen, expectTrailLen, bestSL, 
                            "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "@idForecastMode@", "@idForecastSign@", 
                            "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                            _out_fcst, outsize, rc);
      ]], localArgs)    
    end
    
    if localArgs.debug == 1 or localArgs.forecastFlag == 1 then
      rc = sas.submit_([[
        
          call ci_find_inseason_periods_by_code(_season_code, 0, 1,inPeriodStart, inPeriodEnd, inPeriodCount);
          seasonStart=ci_find_season_start_index(inPeriodStart, inPeriodCount, _season_index, "@inSeasonRule@");
          call ci_season_find_trim_info(@idVar@, _season_code, _season_index, _TOT_NOBS+@lead@, "@idInterval@", @seasonality@, seasonStart, 
                                        leadLen, trailLen, expectTrailLen, rc);
  
          call ci_generate_forecast_one(_demand_all, _season_code, _TOT_NOBS+@lead@, leadLen, trailLen, expectTrailLen, bestSL, 
                            "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "ALL", "@idForecastSign@", 
                            "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                            _ci_fcst, outsize, rc);
      ]], localArgs)    
    end
    
    rc = sas.submit_([[        
      end;
      else if STS_TYPE=2 then do;    
        /************************************************
         Generate information for event type
        ************************************************/  
        call ci_get_event_date("@eventFile@", @eventFileObs@, EVENT_INDEX, _event_date, EVENT_COUNT, tmp_rc);        
        call ci_compute_event_distance(_period_start, _period_end, periodCount, _idVar, demandSize, 
                                       _event_date, EVENT_COUNT, "@idInterval@", @eventDefBufferLen@, EVENT_INDEX,
                                       _before_dist, _after_dist, tmp_rc);  
        call dc_compute_basic_stats(_before_dist, _BEFORE_DIST_COUNT, _BEFORE_DIST_MEAN, _BEFORE_DIST_STDEV, _BEFORE_DIST_MIN, 
                                    _BEFORE_DIST_MEDIAN, _BEFORE_DIST_MAX);              
        call dc_compute_basic_stats(_after_dist, _AFTER_DIST_COUNT, _AFTER_DIST_MEAN, _AFTER_DIST_STDEV, _AFTER_DIST_MIN, 
                                    _AFTER_DIST_MEDIAN, _AFTER_DIST_MAX); 
        bestBD=.; bestAD=.;
        _BEST_SCORE=.;
        
        do bd=_BEFORE_DIST_MIN to _BEFORE_DIST_MAX;
          do ad=_AFTER_DIST_MIN to _AFTER_DIST_MAX;
            valid=1;
            if bd<0 and (ad<=0 or -bd>ad) then valid=0;
            if bd=0 and ad<0 then valid=0;
            if ad<0 and (bd<=0 or bd<-ad) then valid=0;
            if ad=0 and bd<0 then valid=0;
            if valid = 1 then do;
              _EVA_COUNT=_EVA_COUNT+1;
              call ci_find_event_series_seasons(_idVar, _event_date, EVENT_COUNT, "@idInterval@", bd, ad, _season_code_trim, inLen, tmp_rc); 

              call ci_event_find_trim_info(_idVar, _season_code_trim, _event_date, _TOT_NOBS, EVENT_COUNT, "@idInterval@", bd, 
                                           leadLen, trailLen, expectTrailLen, rc);
              call ci_generate_forecast_one(_demand, _season_code_trim, _TOT_NOBS, leadLen, trailLen, expectTrailLen, inLen, 
                                            "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "@idForecastMode@", "@idForecastSign@", 
                                            "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                                            _out_fcst, outsize, rc);
              
              call ci_compute_forecast_measure(_demand, _out_fcst, _TOT_NOBS, "@idForecastCriterion@", score, scoreCount);
              _eva_score[_EVA_COUNT]=score;
              if _BEST_SCORE eq . then do;
                _BEST_SCORE=score;
                bestBD=bd; bestAD=ad;
              end;
              else if _BEST_SCORE>score then do;
                _BEST_SCORE=score;
                bestBD=bd; bestAD=ad;
              end;
            end;/*if valid = 1 then do;*/
          end;/*do ad=_AFTER_DIST_MIN to _AFTER_DIST_MAX;*/
        end;/*do bd=_BEFORE_DIST_MIN to _BEFORE_DIST_MAX;*/
        
        BEFORE_EVENT=bestBD; AFTER_EVENT=bestAD;
        call ci_find_event_series_seasons(@idVar@, _event_date, EVENT_COUNT,  "@idInterval@", bestBD, bestAD, _season_code, inLen, tmp_rc);  
      ]], localArgs)    
           
    if localArgs.debug == 1 then
      rc = sas.submit_([[
          call ci_find_event_series_seasons(_idVar, _event_date, EVENT_COUNT,  "@idInterval@", bestBD, bestAD, _season_code_trim, inLen, tmp_rc);  
          call ci_event_find_trim_info(_idVar, _season_code_trim, _event_date, _TOT_NOBS, EVENT_COUNT, "@idInterval@", bestBD, 
                                       leadLen, trailLen, expectTrailLen, rc);
          call ci_generate_forecast_one(_demand, _season_code_trim, _TOT_NOBS, leadLen, trailLen, expectTrailLen, inLen, 
                                        "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "@idForecastMode@", "@idForecastSign@",
                                        "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                                        _out_fcst, outsize, rc);        
      ]], localArgs)    
    end 
        
    if localArgs.debug == 1 or localArgs.forecastFlag ==1 then
      rc = sas.submit_([[

          call ci_event_find_trim_info(@idVar@, _season_code, _event_date, _TOT_NOBS+@lead@, EVENT_COUNT, "@idInterval@", bestBD, 
                                       leadLen, trailLen, expectTrailLen, rc);
          call ci_generate_forecast_one(_demand_all, _season_code, _TOT_NOBS+@lead@, leadLen, trailLen, expectTrailLen, inLen, 
                                        "@offSeasonRule@", "@idForecastMethod@", "@idForecastAccumulate@", "ALL", "@idForecastSign@",
                                        "@idForecastCriterion@", "@repositoryNm@", "@diagEstNm@", "@indataset@", "@outdataset@",
                                        _ci_fcst, outsize, rc);
      ]], localArgs)    
    end 
    
    rc = sas.submit_([[
      end;
      ]])    
    
    if localArgs.debug == 1 then
      rc = sas.submit_([[
        do i=1 to _TOT_NOBS+@lead@;
          if _season_code[i]>0 then _season_flag[i]=1;
          else _season_flag[i]=0;
        end;
      ]], localArgs)    
    end 
    rc = sas.submit([[   
    run;
    ]])   
          

end



return{custom_interval_identification=custom_interval_identification}
