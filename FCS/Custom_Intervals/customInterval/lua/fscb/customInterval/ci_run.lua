local group     = require('fscb.customInterval.series_grouping')    
local fcmp      = require('fscb.customInterval.fcmp_functions')    
local ciId      = require('fscb.customInterval.ci_identification')  
local ciFcst    = require('fscb.customInterval.ci_forecast')      
local util      = require('fscb.common.util')    


--[[
  validate input arguments for ci_forecast_run
  and set argument defaults if needed
  
  return ciArgs
]]
local function validate_ci_args(args)

  local ciArgs={} 
  
  -- check required input arguments  
  util.my_assert(util.check_value(args.inData), "[CUSTOM_INTERVAL_INPUT_PREP component] Input data is not specified")
  util.my_assert(util.check_value(args.idVar), "[CUSTOM_INTERVAL_INPUT_PREP component] No variable specified for time ID")
  util.my_assert(util.check_value(args.idInterval), "[CUSTOM_INTERVAL_INPUT_PREP component] Time ID interval is not specified")
  util.my_assert(util.check_value(args.demandVar), "[CUSTOM_INTERVAL_INPUT_PREP component] Dependent variable is not specified")
  util.my_assert(util.check_value(args.outFor), "[CUSTOM_INTERVAL_INPUT_PREP component] Output data for forecast results is not specified")
  util.my_assert(util.check_value(args.outModel), "[CUSTOM_INTERVAL_INPUT_PREP component] Output data for models is not specified")
  local all_matched
  local match
  local unmatch  
  all_matched, match, unmatch = util.invar_check(args.inData, args.idVar)
  util.my_assert(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component] The time ID variable ".. args.idVar.." does not exist in data "..args.inData)
  all_matched, match, unmatch = util.invar_check(args.inData, args.demandVar)
  util.my_assert(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component] The dependent variable ".. args.demandVar.." does not exist in data "..args.inData)

  if util.check_value(args.byVars) then
    all_matched, match, unmatch = util.invar_check(args.inData, args.byVars)
    if not all_matched then
      util.my_assert(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component] The BY variables ".. unmatch.." does not exist in data "..args.inData)
    end
  end
  
  if util.check_value(args.patterGroupByVars) then 
    all_matched, match, unmatch = util.invar_check(args.inData, args.patterGroupByVars)
    if not all_matched then
      util.my_assert(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component] The BY variables ".. unmatch.." in patterGroupByVars does not exist in data "..args.inData)
    end
  end
  
  -- check optional input arguments
  for k, v in pairs(args) do    
    ciArgs[k] = v   
  end  
  
  
  ciArgs.keepTmp = 1    
  ciArgs.tempPath = ""
  local validLib = 0    
  if util.check_value(args.processLib) then
    if sas.libref(args.processLib)==0 then
      ciArgs.processLib = args.processLib
      validLib = 1
    end
  end
  if validLib == 0 then 
    -- create temporary folder and library    
    if sas.libref("_ciTmp")~=0 then    
      local workPath = sas.pathname("WORK")    
      util.create_folder(workPath, "_ci_temp")    
      ciArgs.tempPath = string.gsub(workPath, "\\","/").."/_ci_temp"    
      rc = sas.submit([[    
        libname @libname@ "@location@";    
        ]], {libname = "_ciTmp", location = ciArgs.tempPath})    
      util.my_assert(rc<4, "ERROR occurs when assigning the temporary library _ciTmp, exit.")    
      ciArgs.keepTmp = 0
    else    
      ciArgs.keepTmp = 1    
    end
    ciArgs.processLib = "_ciTmp"
  end
  
  if not util.check_value(args.cmpLib) then
    ciArgs.cmpLib = ciArgs.processLib..".ciFuncs"
  end

  if util.check_value(args.byVars) then
    ciArgs.byVars = string.upper(ciArgs.byVars)
  else
    ciArgs.byVars = ""
  end
  if util.check_value(args.patterGroupByVars) then 
    ciArgs.patterGroupByVars = string.upper(ciArgs.patterGroupByVars)
  else 
    ciArgs.patterGroupByVars = ""
  end
 
  local allByVars    = util.split_string(ciArgs.byVars)
  local numByVars    = #allByVars
  ciArgs.allFcstByVars= ''
  if numByVars>0 then
    local lowByVar     = allByVars[numByVars]
    -- get fcst by vars
    if util.check_value(args.fcstByVar) then 
      ciArgs.fcstByVar = string.upper(ciArgs.fcstByVar)
      all_matched, match, unmatch = util.invar_check(args.inData, ciArgs.fcstByVar)
      if not all_matched then
        util.my_warning(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component] The fcstByVar ".. unmatch.." does not exist in data "..args.inData..". Use "..lowByVar.." , instead")
        ciArgs.fcstByVar = lowByVar
      end
    else
      util.my_warning(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component] The fcstByVar is not specified. Use "..lowByVar.." , instead")
      ciArgs.fcstByVar = lowByVar  
    end
    
    
    local lowVars      = ''
    local i            = 0
    for i = 1, numByVars do
      local v = allByVars[i]
      lowVars = util.add_to_string(lowVars, v)
      if ciArgs.fcstByVar == v then
        ciArgs.allFcstByVars = lowVars
      end
    end 
  end
  
  ciArgs.seasonIndexData = ""
  ciArgs.seasonIndexVar = ""
  if util.check_value(args.seasonIndexData) then
    
    all_matched, match, unmatch = util.invar_check(args.seasonIndexData, args.seasonIndexVar)
    if not all_matched then
      util.my_warning(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component] The season index variable ".. unmatch.." does not exist in data "..args.seasonIndexData..". Ignored.")
    else
      ciArgs.seasonIndexData = args.seasonIndexData
      ciArgs.seasonIndexVar = args.seasonIndexVar
    end
  end 
  
  if not util.check_value(ciArgs.seasonality) then
    local rc = sas.submit([[
        data _NULL_;
           call symputx('ciSeasonality', INTSEAS("@idInterval@"));
        run;
        ]], {idInterval=ciArgs.idInterval})
    ciArgs.seasonality = tonumber(sas.symget("ciSeasonality"))
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
          call symputx('ciInDataStart', start);
          call symputx('ciInDataEnd', end);
        run;
        ]], {inDataNM=ciArgs.processLib..".inDataNoMiss", inData=ciArgs.inData, 
             demandVar=ciArgs.demandVar, outData=sortData, intSum=intSum, 
             idVar=ciArgs.idVar},nil,4)   
         
    if not util.check_value(ciArgs.start) then
      ciArgs.start = util.value_to_date(sas.symget("ciInDataStart"))
    end
    if not util.check_value(ciArgs["end"]) then
      ciArgs["end"] = util.value_to_date(sas.symget("ciInDataEnd"))
    end
  end  
    
  ciArgs.sign = "MIXED"
  if util.check_value(args.sign) then
    local list = {"MIXED", "NONNEGATIVE", "NONPOSITIVE"}
    ciArgs.sign = util.validate_sym(args.sign, "sign", list, nil, nil, "MIXED")
  end
    
  ciArgs.forecastCriterion = "MSE"
  if util.check_value(args.forecastCriterion) then
    local list = {"MAPE", "MAE", "MSE"}
    ciArgs.forecastCriterion = util.validate_sym(args.forecastCriterion, "forecastCriterion", list, nil, nil, "MSE")
  end

  if not util.check_value(ciArgs.zeroDemandThresholdPct) then
    ciArgs.zeroDemandThresholdPct = ""
  end
  if not util.check_value(ciArgs.zeroDemandThreshold) then
    ciArgs.zeroDemandThreshold = 0
  end
  
  if not util.check_value(ciArgs.gapPeriodThreshold) then
    ciArgs.gapPeriodThreshold = math.ceil(ciArgs.seasonality/4)
  end
  if not util.check_value(ciArgs.ltsMinDemandCycLen) then
    ciArgs.ltsMinDemandCycLen = math.ceil(ciArgs.seasonality*3/4)
  elseif ciArgs.ltsMinDemandCycLen>= ciArgs.seasonality then
    util.my_warning(false, "[CUSTOM_INTERVAL_INPUT_PREP component]  Invalid ltsMinDemandCycLen value ("..ciArgs.ltsMinDemandCycLen
                            .."), should be less than seasonality ("
                            ..ciArgs.seasonality.."). Use "..math.ceil(ciArgs.seasonality*3/4).." instead.")
    ciArgs.ltsMinDemandCycLen = math.ceil(ciArgs.seasonality*3/4)
  end

  if not util.check_value(ciArgs.segMaxPctError) then
    ciArgs.segMaxPctError = ""
  end
  if not util.check_value(ciArgs.segMaxError) then
    ciArgs.segMaxError = ""
  end  
  
  if not util.check_value(ciArgs.eventIdentifyFlag) then
    ciArgs.eventIdentifyFlag = 1
  end
  if not util.check_value(ciArgs.eventDefBufferLen) then
    ciArgs.eventDefBufferLen = 0
  end
  if not util.check_value(ciArgs.eventPeriodLenThreshold) then
    ciArgs.eventPeriodLenThreshold = math.ceil(ciArgs.seasonality/6)
  end  
  if ciArgs.eventPeriodLenThreshold >=ciArgs.seasonality then 
    util.my_warning(false, "[CUSTOM_INTERVAL_INPUT_PREP component]  Invalid eventPeriodLenThreshold value ("..ciArgs.eventPeriodLenThreshold
                            .."), should be less than seasonality ("
                            ..ciArgs.seasonality.."). Use "..math.ceil(ciArgs.seasonality/6).." instead.")
    ciArgs.eventPeriodLenThreshold = math.ceil(ciArgs.seasonality/6)
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
        util.my_warning(all_matched, "[CUSTOM_INTERVAL_INPUT_PREP component]  The event definition ("..unmatch..") in eventDefList is not supported. Ignore.")
        defEventMsg = "ignore."
        ciArgs.eventDefList = match
        validList = true
      end
    end
    -- validate event definition data
    if util.check_value(ciArgs.eventDefData) then 
      if not sas.exists(ciArgs.eventDefData) then
        util.my_warning(false, "[CUSTOM_INTERVAL_INPUT_PREP component]  The event definition data file "..ciArgs.eventDefData.." does not exist. "..defEventMsg)
        ciArgs.eventDefData = ""
      elseif not util.check_file_non_empty(ciArgs.eventDefData) then
        util.my_warning(false, "[CUSTOM_INTERVAL_INPUT_PREP component]  The event definition data file "..ciArgs.eventDefData.." is empty. "..defEventMsg)
        ciArgs.eventDefData = ""
      else
        validData = true      
      end      
    end
    -- if neither list nor data is valid, use the default list
    if (not validList) and (not validData) then
      if util.check_value(ciArgs.eventDefList) then -- the list was specified, but there is no valid elements inside
        util.my_warning(false, "[CUSTOM_INTERVAL_INPUT_PREP component]  The event definition ("..ciArgs.eventDefList..") in eventDefList is not supported. "..defEventMsg)
      elseif not util.check_value(ciArgs.eventDefData) then -- neither the list nor the data is specified
        util.my_warning(false, "[CUSTOM_INTERVAL_INPUT_PREP component]  The event definition is not specified in either eventDefList or eventDefData. "..defEventMsg)
      end
      ciArgs.eventDefList = defEventList
    end
    
    if ciArgs.eventDefBufferLen + ciArgs.eventPeriodLenThreshold >=ciArgs.seasonality then 
      util.my_warning(false, "[CUSTOM_INTERVAL_INPUT_PREP component]  Invalid eventDefBufferLen value ("..ciArgs.eventDefBufferLen
                        .."), should be less than seasonality ("
                        ..ciArgs.seasonality..")-eventPeriodLenThreshold("..ciArgs.eventPeriodLenThreshold"). Use 0 instead.")
      ciArgs.eventPeriodLenThreshold = 0
    end
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
  
  ciArgs.idForecastMode = "AVG"
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
  
  if not util.check_value(args.runGrouping) then
    if not util.check_value(args.byVars) then 
      ciArgs.runGrouping = 0
    else
      ciArgs.runGrouping = 1
    end 
  end
  
  ciArgs.debug=0 
  if util.check_value(args.debug) then 
    ciArgs.debug=args.debug
    ciArgs.keepTmp = 1
  end
  
  return ciArgs  
end    
   
--[[
NAME:           ci_forecast_run

DESCRIPTION:    main entry for Forecasting with Automatic Custom Interval Identification
                
INPUTS:         args
                --required in args
                  inData
                  idVar
                  idInterval
                  demandVar
                  outFor
                  outModel

                --optional in args
                  processLib
                  cmpLib

                  byVars
                  patterGroupByVars
                  fcstByVar
                  classHighByVar
                  
                  seasonIndexData
                  seasonIndexVar 
                  
                  seasonality    
                  start              
                  end
                  lead
                  setMissing
                  accumulate
                  align
                  sign
                  forecastCriterion
                  
                  zeroDemandThresholdPct
                  zeroDemandThreshold
                  gapPeriodThreshold
                  ltsMinDemandCycLen
                  segMaxPctError
                  segMaxError
                  eventIdentifyFlag
                  eventPeriodLenThreshold
                  eventDefData
                  eventDefList
                  eventDefBufferLen
                  inSeasonRule
                  offSeasonRule
                  idForecastMode
                  idForecastMethod
                  idForecastAccumulate
                  

                  runGrouping
                    shortReclass
                    horizontalReclassMeasure
                    classifyDeactive
                    shortSeriesPeriod
                    lowVolumePeriodInterval
                    lowVolumePeriodMaxTot
                    lowVolumePeriodMaxOccur
                    deactiveThreshold
                    deactiveBufferPeriod
                    profileType
                    
                    clusteringMethod
                    hiIndistanceFlag
                    hiDistanceMeasure
                    clusterWeight
                    hiClusterMethod
                    numOfClusters
                    minNumOfCluster
                    maxNumOfCluster
                    hiNosquare
                    nclCutoffPct1
                    nclCutoffPct2
                    cccCutoff
                    hiRsqMin
                    hiRsqMethod
                    hiRsqChangerate
                    hiRsqModelcomplexity
                    hiNclSelection
                    kmNomiss
                    kmStd
                 
                 debug
                 debugFile
OUTPUTS:        
                  outFor
                  outModel

USAGE:          
                
]]
  
function ci_forecast_run(args)  

    print("Starting Forecasting with Automatic Custom Interval Identification...")  
      
    -- input validation
    local localArgs={} 
    localArgs = validate_ci_args(args)
    if localArgs.debug == 1 then 
      local r="********INPUT ARGUMENT VALUE INTO CI_FORECAST_RUN:********"
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
    -- close unnecessary output    
    local rc = sas.submit([[    
      options linesize=max;    
      ods listing close;    
      ods html close;    
    ]]) 
    
    localArgs.inDataFiltered=localArgs.processLib..".inDataFiltered"
    localArgs.inDataAligned=localArgs.processLib..".inDataAligned"

    rc = sas.submit([[
      proc sort data=@inData@; by @fcstVars@ @idVar@; run;
      proc timedata data=@inData@ outarray=@outData1@  lead=@lead@;
        @byStatement@;
        id @idVar@ interval=@idInterval@ accumulate=@accumulate@ setmissing=@setmissing@ align=@align@ start=@startD@ end=@endD@;
        var @demandVar@ /setmissing=missing;
        outarrays _season_index;
        do i=1 to dim(@idVar@);
          _season_index[i]=_SEASON_[i];
        end;
      run;
      data @outData2@;
        set @outData1@;
        if @idVar@>=@startD@ and @idVar@<=@endD@;
       run;
    ]],{outData1=localArgs.inDataAligned, outData2=localArgs.inDataFiltered, inData=localArgs.inData, idVar=localArgs.idVar,
    fcstVars=localArgs.allFcstByVars, byStatement=util.check_value(localArgs.allFcstByVars) and "by "..localArgs.allFcstByVars or "",
    idInterval=localArgs.idInterval, accumulate=localArgs.accumulate, setmissing=localArgs.setmissing, align=localArgs.align,
    startD=localArgs.start, endD=localArgs["end"], lead=localArgs.lead, demandVar=localArgs.demandVar}) 
    
    local groupArgs                    = {} 
    if localArgs.runGrouping == 1 then
      -- group all input series
      print("...Starting Series Grouping Component...")  
      groupArgs.inData                   = localArgs.inDataFiltered
      groupArgs.idVar                    = localArgs.idVar
      groupArgs.idInterval               = localArgs.idInterval
      groupArgs.demandVar                = localArgs.demandVar
      groupArgs.hierByVars               = localArgs.byVars
      groupArgs.outData                  = localArgs.processLib..".groupOutData"
      groupArgs.outSum                   = localArgs.processLib..".groupOutSum"
      groupArgs.processLib               = localArgs.processLib     
      groupArgs.processByVars            = util.check_value(localArgs.patterGroupByVars) and localArgs.patterGroupByVars or ""
      groupArgs.lowByVar                 = util.check_value(localArgs.fcstByVar) and localArgs.fcstByVar or ""
      groupArgs.highByVar                = util.check_value(localArgs.classHighByVar) and localArgs.classHighByVar or ""              
      groupArgs.setMissing               = localArgs.setmissing
      groupArgs.zeroDemandThresholdPct   = localArgs.zeroDemandThresholdPct     
      groupArgs.zeroDemandThreshold      = localArgs.zeroDemandThreshold
      groupArgs.gapPeriodThreshold       = localArgs.gapPeriodThreshold       
      groupArgs.shortReclass             = util.check_value(localArgs.shortReclass) and localArgs.shortReclass or ""
      groupArgs.horizontalReclassMeasure = util.check_value(localArgs.horizontalReclassMeasure) and localArgs.horizontalReclassMeasure or ""
      groupArgs.classifyDeactive         = util.check_value(localArgs.classifyDeactive) and localArgs.classifyDeactive or 1
      groupArgs.shortSeriesPeriod        = util.check_value(localArgs.shortSeriesPeriod) and localArgs.shortSeriesPeriod or ""
      groupArgs.lowVolumePeriodInterval  = util.check_value(localArgs.lowVolumePeriodInterval) and localArgs.lowVolumePeriodInterval or ""
      groupArgs.lowVolumePeriodMaxTot    = util.check_value(localArgs.lowVolumePeriodMaxTot) and localArgs.lowVolumePeriodMaxTot or ""
      groupArgs.lowVolumePeriodMaxOccur  = util.check_value(localArgs.lowVolumePeriodMaxOccur) and localArgs.lowVolumePeriodMaxOccur or ""
      groupArgs.ltsMinDemandCycLen       = localArgs.ltsMinDemandCycLen
      groupArgs.deactiveThreshold        = util.check_value(localArgs.deactiveThreshold) and localArgs.deactiveThreshold or ""
      groupArgs.deactiveBufferPeriod     = util.check_value(localArgs.deactiveBufferPeriod) and localArgs.deactiveBufferPeriod or ""
      groupArgs.calendarCycPeriod        = localArgs.seasonality
      groupArgs.currentDate              = localArgs["end"]
      groupArgs.profileType              = util.check_value(localArgs.profileType) and localArgs.profileType or ""            
      groupArgs.clusteringMethod         = util.check_value(localArgs.clusteringMethod) and localArgs.clusteringMethod or ""
      groupArgs.hiIndistanceFlag         = util.check_value(localArgs.hiIndistanceFlag) and localArgs.hiIndistanceFlag or ""
      groupArgs.hiDistanceMeasure        = util.check_value(localArgs.hiDistanceMeasure) and localArgs.hiDistanceMeasure or ""
      groupArgs.clusterWeight            = util.check_value(localArgs.clusterWeight) and localArgs.clusterWeight or ""
      groupArgs.hiClusterMethod          = util.check_value(localArgs.hiClusterMethod) and localArgs.hiClusterMethod or ""
      groupArgs.numOfClusters            = util.check_value(localArgs.numOfClusters) and localArgs.numOfClusters or ""
      groupArgs.minNumOfCluster          = util.check_value(localArgs.minNumOfCluster) and localArgs.minNumOfCluster or ""
      groupArgs.maxNumOfCluster          = util.check_value(localArgs.maxNumOfCluster) and localArgs.maxNumOfCluster or ""
      groupArgs.hiNosquare               = util.check_value(localArgs.hiNosquare) and localArgs.hiNosquare or ""
      groupArgs.nclCutoffPct1            = util.check_value(localArgs.nclCutoffPct1) and localArgs.nclCutoffPct1 or ""
      groupArgs.nclCutoffPct2            = util.check_value(localArgs.nclCutoffPct2) and localArgs.nclCutoffPct2 or ""
      groupArgs.cccCutoff                = util.check_value(localArgs.cccCutoff) and localArgs.cccCutoff or ""
      groupArgs.hiRsqMin                 = util.check_value(localArgs.hiRsqMin) and localArgs.hiRsqMin or ""
      groupArgs.hiRsqMethod              = util.check_value(localArgs.hiRsqMethod) and localArgs.hiRsqMethod or ""
      groupArgs.hiRsqChangerate          = util.check_value(localArgs.hiRsqChangerate) and localArgs.hiRsqChangerate or ""
      groupArgs.hiRsqModelcomplexity     = util.check_value(localArgs.hiRsqModelcomplexity) and localArgs.hiRsqModelcomplexity or ""
      groupArgs.hiNclSelection           = util.check_value(localArgs.hiNclSelection) and localArgs.hiNclSelection or ""
      groupArgs.kmNomiss                 = util.check_value(localArgs.kmNomiss) and localArgs.kmNomiss or ""
      groupArgs.kmStd                    = util.check_value(localArgs.kmStd) and localArgs.kmStd or ""
      group.series_grouping(groupArgs) 
      print("...Series Grouping Component has finished.")      

    end
    
    -- compile fcmp functions
    fcmp.fcmp_functions(localArgs.cmpLib)
  
    -- identify custom intervals for STS series
    print("...Starting Custom Interval Identification Component...")  
    local ciIDArgs                       = {} 
    if localArgs.runGrouping == 1 then
      ciIDArgs.inData                    = localArgs.processLib..".groupOutData"
      ciIDArgs.byVars                    = localArgs.patterGroupByVars.." DC_BY PC_BY"
    else
      ciIDArgs.inData                    = localArgs.inDataFiltered
      ciIDArgs.byVars                    = localArgs.patterGroupByVars
    end
    ciIDArgs.cmpLib                      = localArgs.cmpLib
    
    ciIDArgs.idVar                       = localArgs.idVar
    ciIDArgs.idInterval                  = localArgs.idInterval
    ciIDArgs.demandVar                   = localArgs.demandVar
    ciIDArgs.outScalar                   = localArgs.processLib..".ciIDOutScalar"
    ciIDArgs.outArray                    = localArgs.processLib..".ciIDOutArray"
    ciIDArgs.processLib                  = localArgs.processLib
    ciIDArgs.lead                        = localArgs.lead
    ciIDArgs.seasonality                 = localArgs.seasonality
    ciIDArgs.accumulate                  = localArgs.accumulate
    ciIDArgs.setmissing                  = localArgs.setmissing
    ciIDArgs.align                       = localArgs.align
    ciIDArgs.segMaxPctError              = localArgs.segMaxPctError
    ciIDArgs.segMaxError                 = localArgs.segMaxError
    ciIDArgs.zeroDemandThresholdPct      = localArgs.zeroDemandThresholdPct
    ciIDArgs.zeroDemandThreshold         = localArgs.zeroDemandThreshold
    ciIDArgs.gapPeriodThreshold          = localArgs.gapPeriodThreshold
    ciIDArgs.ltsMinDemandCycLen          = localArgs.ltsMinDemandCycLen
    ciIDArgs.seasonIndexData             = localArgs.seasonIndexData
    ciIDArgs.seasonIndexVar              = localArgs.seasonIndexVar
    ciIDArgs.eventIdentifyFlag           = localArgs.eventIdentifyFlag
    ciIDArgs.eventPeriodLenThreshold     = localArgs.eventPeriodLenThreshold
    ciIDArgs.eventDefData                = localArgs.eventDefData
    ciIDArgs.eventDefList                = localArgs.eventDefList
    ciIDArgs.eventDefBufferLen           = localArgs.eventDefBufferLen
    ciIDArgs.start                       = localArgs.start
    ciIDArgs["end"]                      = localArgs["end"]
    ciIDArgs.inSeasonRule                = localArgs.inSeasonRule
    ciIDArgs.offSeasonRule               = localArgs.offSeasonRule
    ciIDArgs.idForecastMode              = localArgs.idForecastMode
    ciIDArgs.idForecastMethod            = localArgs.idForecastMethod
    ciIDArgs.idForecastAccumulate        = localArgs.idForecastAccumulate
    ciIDArgs.idForecastCriterion         = localArgs.forecastCriterion
    ciIDArgs.idForecastSign              = localArgs.sign
    ciIDArgs.debug                       = localArgs.debug
    ciIDArgs.debugFile                   = localArgs.debugFile
    ciIDArgs.forecastFlag                = 0
    if not util.check_value(ciIDArgs.byVars) then
      ciIDArgs.forecastFlag              = 1
    elseif localArgs.allFcstByVars == ciIDArgs.byVars then
      ciIDArgs.forecastFlag              = 1
    end
    
    ciId.custom_interval_identification(ciIDArgs)
    
    if localArgs.runGrouping == 1 then
      rc = sas.submit([[
        data @outScalar@;
          set @outScalar@;
          if DC_BY ne "STS" and _STS_TYPE>0 then _STS_TYPE=-1;
        run;
      ]],{outScalar=ciIDArgs.outScalar})
    end
    
    print("...Custom Interval Identification Component has finished.")   
    
    -- generate forecast
    print("...Starting Forecasting Component...")  
    local fcstArgs                     = {} 
    if ciIDArgs.forecastFlag == 1 then 
      fcstArgs.inData                  = ciIDArgs.outArray
      fcstArgs.byVars                  = ciIDArgs.byVars
    else 
      fcstArgs.inData                  = localArgs.processLib..".ciFcstInData"
      fcstArgs.byVars                  = localArgs.allFcstByVars
      local mergeInData
      local mergeByVars = util.split_string(ciIDArgs.byVars)
      local mergeOnClause = ""
      local i
      for i=1, #mergeByVars do
        if i>1 then 
          mergeOnClause = mergeOnClause.." and "
        end
        mergeOnClause = mergeOnClause.."a."..mergeByVars[i].."=b."..mergeByVars[i]
      end
      if localArgs.runGrouping == 1 then
        mergeInData=groupArgs.outSum
        local whereClause = ""
        local whereByVars = util.split_string(localArgs.allFcstByVars)
        local i
        for i=1, #whereByVars do
          if i>1 then 
            whereClause = whereClause.." and "
          end
          whereClause = whereClause.."a."..whereByVars[i].."=b."..whereByVars[i]
        end
        rc = sas.submit([[
          proc sort data=@mergeInData@; by @fcstByVars@; run;
          proc sort data=@inArray@; by @fcstByVars@; run;
          proc sql noprint;
            create table @outTemp@ as
            select a.*, b.* from @mergeInData@ as a
            join @inArray@ as b
            on @mergeOnClause@;
          run;
          data @outTemp@;
            set @outTemp@;
            drop @demandVar@;
          run;
          proc sql noprint;
            create table @outData@ as
            select a.*, b.@demandVar@
            from @outTemp@ as a,
                 @inData@ as b
            where @whereClause@ and a.@idVar@=b.@idVar@;
         run;
         quit;
        ]],{mergeInData=mergeInData, fcstByVars=ciIDArgs.byVars, mergeOnClause=mergeOnClause,
            outTemp=localArgs.processLib.."._ciFcstInDataTemp", inData=localArgs.inDataAligned,
            mergeOnClause=mergeOnClause, demandVar=localArgs.demandVar, idVar=localArgs.idVar,
            inArray=ciIDArgs.outArray, outData=fcstArgs.inData, whereClause=whereClause},nil,4)
      else 
        local fcstByVarsComma = util.get_delim_string(ciIDArgs.byVars, ",")
        rc = sas.submit([[
          proc sort data=@inArray@; by @fcstByVars@; run;
          proc sql noprint;
            create table @inTemp@ as
            select distinct @fcstByVarsComma@
            from @inData@
            order by @fcstByVarsComma@;
            create table @outData@ as
            select a.*, b.* from @inTemp@ as a
            join @inArray@ as b
            on @mergeOnClause@;
          run;
          quit;
        ]],{inData=localArgs.inDataFiltered, inTemp=localArgs.processLib.."._ciInDataSum", 
            fcstByVars=ciIDArgs.byVars, fcstByVarsComma=fcstByVarsComma,
            mergeOnClause=mergeOnClause, inArray=ciIDArgs.outArray, outData=fcstArgs.inData},nil,4)
      end
   
    end
    fcstArgs.scalarByVars              = ciIDArgs.byVars
    fcstArgs.cmpLib                    = localArgs.cmpLib
    fcstArgs.inScalar                  = ciIDArgs.outScalar
    fcstArgs.idVar                     = localArgs.idVar
    fcstArgs.idInterval                = localArgs.idInterval
    fcstArgs.demandVar                 = localArgs.demandVar
    fcstArgs.outScalar                 = localArgs.outModel
    fcstArgs.outArray                  = localArgs.outFor  
    
    fcstArgs.processLib                = localArgs.processLib
    fcstArgs.lead                      = localArgs.lead
    fcstArgs.seasonality               = localArgs.seasonality
    fcstArgs.accumulate                = localArgs.accumulate
    fcstArgs.setmissing                = localArgs.setmissing
    fcstArgs.align                     = localArgs.align
    fcstArgs.start                     = localArgs.start
    fcstArgs["end"]                    = localArgs["end"]
    fcstArgs.eventFile                 = localArgs.processLib..".ciIdEventFile"
    fcstArgs.eventFileObs              = nil
    fcstArgs.offSeasonRule             = localArgs.offSeasonRule
    fcstArgs.idForecastMode            = localArgs.idForecastMode
    fcstArgs.idForecastMethod          = localArgs.idForecastMethod
    fcstArgs.idForecastAccumulate      = localArgs.idForecastAccumulate
    fcstArgs.idForecastCriterion       = localArgs.forecastCriterion
    fcstArgs.idForecastSign            = localArgs.sign
    fcstArgs.debug                     = localArgs.debug
    fcstArgs.debugFile                 = localArgs.debugFile
    fcstArgs.forecastFlag              = 1-ciIDArgs.forecastFlag  
    
    ciFcst.custom_interval_forecast(fcstArgs)
    
    print("...Forecasting has finished.")  

    -- clean up temporary results    
    if localArgs.keepTmp == 0 then    
      util.remove_dir(localArgs.tempPath)    
    end    
    
    print("Forecasting with Automatic Custom Interval Identification has finished.")

end



return{ci_forecast_run=ci_forecast_run}