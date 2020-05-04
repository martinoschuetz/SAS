local util = require("fscb.common.util")
local rec  = require("fscb.multistage.reconcile")
local post = require("fscb.multistage.post_process")

--[[
NAME:           run_hpf

DESCRIPTION:    generate forecast for a given input data using hpfdiagnose + hpfengine
                
INPUTS:         args
                --required in args
                  inData
                  fcstVar
                  idVar
                  interval
                  outFor
                --optional in args
                  processLib
                  runDiag
                  sign
                  byVars
                  baseName
                  outStat
                  outStatSelect
                  outEst
                  outSum
                  outModelInfo
                  adjustmentStatementDiag
                  inputStatement
                  externalStatement
                  adjustmentStatementEngine 
                  inEst 
                  modelRepository
                  inEvent
                  scoreRepository
                  seasonality
                  acc
                  format
                  globalSelection
                  replaceMissingFcst
                    
                hpfArgs
                --optional in hpfArgs    
                  hpfRetainchoose
                  hpfBack
                  hpfSelectCriterion
                  hpfSelectMinobsSeason
                  hpfSelectMinobsTrend
                  hpfSelectMinobsNonMean
                  hpfTransType
                  hpfTransOpt
                  hpfSetmissing
                  hpfStart
                  hpfEnd
                  hpfTrimmiss
                  hpfZeromiss
                  hpfForecastAlpha
                  hpfDiagIntermit
                  hpfLead
                  hpfHorizonStart
                  transformOptions
                  idmOptions
                  esmOptions
                  eventOptions
                  trendOptions
                  ucmOptions
                  arimaxOptions
                  
                  overrideFor -- input table for replaceMissingFcst, optional
                

OUTPUTS:        outFor
                --optional based on input args
                  outStat
                  outStatSelect
                  outEst
                  outSum
                  outModelInfo

USAGE:          
                
]]

function run_hpf(args,hpfArgs)

  -- required function input args
  local inData = args.inData
  local fcstVar = args.fcstVar 
  local idVar = args.idVar
  local interval = args.interval 
  local outForArg = util.check_value(args.outFor) and "outfor = "..args.outFor or ""
  -- optional args with no default values
  local byVars = util.check_value(args.byVars) and args.byVars or ""
  local byVarsArg = util.check_value(args.byVars) and "by "..args.byVars..";" or "" 
  local sortByArg = "by "..byVars.." "..idVar
  local processLib = util.check_value(args.processLib) and args.processLib or "WORK"

  local seasonalityArg = util.check_value(args.seasonality) 
                         and "seasonality = "..args.seasonality or "" 
  local inEventArg = util.check_value(args.inEvent)
                     and "inevent ="..args.inEvent or ""
  local hpfRetainChoose = util.check_value(hpfArgs.hpfRetainchoose) and "RETAINCHOOSE="..hpfArgs.hpfRetainchoose or ""
  local backArg = util.check_value(hpfArgs.hpfBack) and "back = "..hpfArgs.hpfBack or ""
  local criterionArg = util.check_value(hpfArgs.hpfSelectCriterion)
                       and "criterion = "..hpfArgs.hpfSelectCriterion or ""
  local minobsSeasonArg = util.check_value(hpfArgs.hpfSelectMinobsSeason) 
                          and "minobs = (season = "..hpfArgs.hpfSelectMinobsSeason..")"
                          or ""
  local minobsTrendArg = util.check_value(hpfArgs.hpfSelectMinobsTrend)
                         and "minobs = (trend = "..hpfArgs.hpfSelectMinobsTrend..")"
                         or ""
  local accArg = util.check_value(args.acc) and "acc = "..args.acc or "" 
  local setmissArg = util.check_value(hpfArgs.hpfSetmissing)
                     and "setmissing = "..hpfArgs.hpfSetmissing or "" 
  local startArg = util.check_value(hpfArgs.hpfStart)
                   and "start = "..hpfArgs.hpfStart or ""
  local endArg = util.check_value(hpfArgs.hpfEnd) and "end = "..hpfArgs.hpfEnd or ""
  local trimmissArg = util.check_value(hpfArgs.hpfTrimmiss)
                      and "trimmiss = "..hpfArgs.hpfTrimmiss or "" 
  local zeromissArg = util.check_value(hpfArgs.hpfZeromiss)
                      and "zeromiss = "..hpfArgs.hpfZeromiss or ""
  local adjustmentStatementDiag = util.check_value(args.adjustmentStatementDiag) and args.adjustmentStatementDiag..";" or ""
  local inputStatement = util.check_value(args.inputStatement) and args.inputStatement..";" or ""
  local transformOptions = util.check_value(hpfArgs.transformOptions) and hpfArgs.transformOptions..";" or ""                    
  local eventOptions = util.check_value(hpfArgs.eventOptions) and hpfArgs.eventOptions..";" or ""
  local trendOptions = util.check_value(hpfArgs.trendOptions) and hpfArgs.trendOptions..";" or ""
  local ucmOptions = util.check_value(hpfArgs.ucmOptions) and hpfArgs.ucmOptions..";" or ""
  local arimaxOptions = util.check_value(hpfArgs.arimaxOptions) and hpfArgs.arimaxOptions..";" or ""
  local esmOptions = util.check_value(hpfArgs.esmOptions) and hpfArgs.esmOptions..";" or ""
  local idmOptions = util.check_value(hpfArgs.idmOptions) and hpfArgs.idmOptions..";" or ""
  local baseNm = util.check_value(args.baseName) and args.baseName or ""
  
  local modelRepositoryArg = ""
  if util.check_value(args.modelRepository) then
    modelRepositoryArg = "modelrepository ="..args.modelRepository
  else
    local repositoryNm = processLib..".TemLevModRep"
    modelRepositoryArg = "modelrepository ="..repositoryNm
    if sas.cexist(repositoryNm) == 0 then
      rc = sas.submit([[
        proc catalog catalog=@repositoryNm@;
          copy in=sashelp.hpfdflt out=@repositoryNm@;
        quit;
       ]])
    end
  end
  
  local diagOutEst = ""
  local rc = 0
  
  -- sort the indata
  rc = sas.submit([[
    proc sort data=@inData@; @sortByArg@; run;
    ]])
  util.my_assert(rc<=4, "[FORECAST component] ERROR occurred when sorting the inData "..inData..", exit.")
  
  if util.check_value(args.runDiag) and args.runDiag then
    -- HPFDIAGNOSE STATEMENT FOR A GIVEN LEVEL
 
     -- optional args with default values
    diagOutEst = util.check_value(args.inEst) and args.inEst or processLib..".diagoutest_"..baseNm
    
     -- optional args with no default values
    local diagInEstArg = util.check_value(args.inEst) and "inest = "..diagOutEst or ""
    local baseNameArg = util.check_value(baseNm)
                        and "basename = "..baseNm or "" 

    rc = sas.submit([[
      proc hpfdiagnose data = @inData@ @baseNameArg@
          @diagInEstArg@ outest = @diagOutEst@ @hpfRetainChoose@ 
          @seasonalityArg@ 
          errorcontrol = (severity = HIGH stage = (PROCEDURELEVEL)) EXCEPTIONS = CATCH  
          @modelRepositoryArg@  @inEventArg@
          @backArg@ @criterionArg@
          @minobsSeasonArg@
          @minobsTrendArg@;
        @byVarsArg@
        forecast @fcstVar@ /@accArg@ @setmissArg@ @trimmissArg@ @zeromissArg@;
        id @idVar@ interval = @interval@ @accArg@ notsorted 
           @setmissArg@ @startArg@ @endArg@
           @trimmissArg@ @zeromissArg@;
        @adjustmentStatementDiag@
        @inputStatement@
        @eventOptions@
        @trendOptions@
        @transformOptions@
        @ucmOptions@
        @arimaxOptions@
        @esmOptions@
        @idmOptions@  
      run;
      ]])
    util.my_assert(rc<=4, "[FORECAST component] ERROR occurred when calling HPFDIAGNOSE, exit.")
 
    
  end --end for (if runDiag then)
  
  local inEstArg = util.check_value(diagOutEst) and "inest = "..diagOutEst or ""
  -- optional args with no default values
  local outStatArg = util.check_value(args.outStat) and "outstat = "..args.outStat or ""
  local outStatSelectArg = util.check_value(args.outStatSelect) 
                           and "outstatselect = "..args.outStatSelect or ""
  local outEstArg = util.check_value(args.outEst) and "outest = "..args.outEst or ""
  local outSumArg = util.check_value(args.outSum) and "outsum = "..args.outSum or ""
  local outModelInfoArg = util.check_value(args.outModelInfo)
                          and "outmodelinfo = "..args.outModelInfo or ""
  
  local alphaArg = util.check_value(hpfArgs.hpfForecastAlpha)
                   and "alpha = "..hpfArgs.hpfForecastAlpha or ""
  local minobsNonMeanArg = util.check_value(hpfArgs.hpfSelectMinobsNonMean)
                           and "minobs = "..hpfArgs.hpfSelectMinobsNonMean or ""
  local intermittentArg = util.check_value(hpfArgs.hpfDiagIntermit) 
                          and "intermittent = "..hpfArgs.hpfDiagIntermit or ""
  local leadArg = util.check_value(hpfArgs.hpfLead) and "lead = "..hpfArgs.hpfLead or ""                    
  local scoreRepositoryArg = util.check_value(args.scoreRepository) 
                             and "scorerepository ="..args.scoreRepository or ""
  local horizonstartArg = util.check_value(hpfArgs.hpfHorizonStart)
                          and "horizonstart = "..hpfArgs.hpfHorizonStart or ""
  
  local formatArg = util.check_value(args.format) and "format = "..args.format or ""
  local globalSelectionArg = util.check_value(args.globalSelection)
                             and "globalselection = "..args.globalSelection or ""
  local externalStatement = util.check_value(args.externalStatement) and args.externalStatement..";" or ""
  local adjustmentStatementEngine = util.check_value(args.adjustmentStatementEngine) and args.adjustmentStatementEngine..";" or ""
  local scoreStatement = util.check_value(scoreRepositoryArg) and "score;" or ""
  
  -- HPFENGINE STATEMENT FOR A GIVEN LEVEL
  rc = sas.submit([[
    proc hpfengine data = @inData@
        @inEstArg@ @modelRepositoryArg@ 
        @outForArg@ @outStatArg@ @outStatSelectArg@
        @outEstArg@ @outSumArg@
        @outModelInfoArg@
        task = select( @alphaArg@ @criterionArg@ 
                       @minobsNonMeanArg@  @minobsSeasonArg@ @minobsTrendArg@
                       seasontest=none @intermittentArg@ override)
        @backArg@ @leadArg@               
        @seasonalityArg@ errorcontrol=(severity=HIGH, stage=(PROCEDURELEVEL))
        EXCEPTIONS=CATCH  @scoreRepositoryArg@ @inEventArg@
        @globalSelectionArg@;
      @byVarsArg@
      forecast @fcstVar@ /@accArg@ @setmissArg@ @trimmissArg@ @zeromissArg@;
      id @idVar@ interval = @interval@ 
                 @formatArg@ @accArg@ notsorted @horizonstartArg@ @startArg@ @endArg@;
      @externalStatement@
      @adjustmentStatementEngine@
      @scoreStatement@
    run;
    ]])
    util.my_assert(rc<=4, "[FORECAST component] ERROR occurred when calling HPFENGINE, exit.")

  -- run override missing
  if util.check_value(args.replaceMissingFcst) and args.replaceMissingFcst then
    local overArgs = {}
    overArgs.inFor        = args.outFor
    overArgs.outFor       = args.outFor
    overArgs.byVars       = args.byVars
    overArgs.timeID       = args.idVar
    overArgs.depVar       = "actual"
    overArgs.fcstVar      = "predict"
    overArgs.processLib   = args.processLib
    overArgs.overrideFor  = args.overrideFor
    overArgs.overrideVar  = args.overrideVar
    print("[RUN_HPF] Entering override missing process...")
    post.override_missing(overArgs)
  end
  -- end override missing
  
  if util.check_value(args.sign) then
    if args.sign == "NONNEGATIVE" then 
      -- do not allow negative forecasts
      rc = sas.submit([[
        data @outFor@;
          set @outFor@;
          if ^missing(predict) and predict < 0 then do;
            lower = lower - predict;
            upper = upper - predict;
            predict = 0;
           end;
        run;
        ]],{outFor=args.outFor})
    end
    if args.sign == "NONPOSITIVE" then 
      -- do not allow positive forecasts
      rc = sas.submit([[
        data @outFor@;
          set @outFor@;
          if ^missing(predict) and predict > 0 then do;
            lower = lower - predict;
            upper = upper - predict;
            predict = 0;
           end;
        run;
        ]],{outFor=args.outFor})
    end
    util.my_assert(rc<=4, "[FORECAST component] ERROR occurred when modifying forecast results based on the required sign, exit.")
  end
  
  local outLib = ""
  local outTable = ""
  local sortedByVars = byVars.." "..idVar
  outLib,outTable = util.get_libname_tablename(args.outFor)
  rc = sas.submit([[
    proc datasets lib = @outLib@ nowarn nolist nodetails;
       modify @outTable@ (sortedby=@sortedByVars@); 
    quit;
    ]])
  util.my_assert(rc <= 4, "[FORECAST component] Error occurred when writing sorted by information for table "..args.outFor..", exit.")

    
end

--[[
NAME:           fcst_inargs_check

DESCRIPTION:    validate input arguments
                
INPUTS:         args
                fcstInfo

OUTPUTS:        localArgs
                hpfArgs

USAGE:          
                
]]
local function fcst_inargs_check(args, fcstInfo)

  local all_matched
  local match
  local unmatch

  -- check if the required input argument is specified
  util.my_assert(util.check_value(args.depVar), "[FORECAST component] The dependent variable is not specified")
  util.my_assert(util.check_value(args.idVar), "[FORECAST component] The time ID variable is not specified")
  util.my_assert(util.check_value(args.idInterval), "[FORECAST component] The time ID interval is not specified")
  util.my_assert(fcstInfo[1]~=nil, "[FORECAST component] The fcst low level information in fcstInfo is not specified")
  if #fcstInfo>1 then
    util.my_assert(fcstInfo[2]~=nil, "[FORECAST component] The fcst high level information in fcstInfo is not specified")
    util.my_assert(util.check_value(args.outForReconcile), "[FORECAST component] The output table name outForReconcile is not specified")
  end
    
  -- check shared input arguments in args
  local localArgs = {}
  for k,v in pairs(args) do
    localArgs[k] = v
  end
  if util.check_value(args.inEvent) then
    if not sas.exists(args.inEvent) then
      util.my_warning(false, "[FORECAST component] The inEvent "..args.inEvent.." does not exist, ignored")
      localArgs.inEvent = nil
    end
  end
  if util.check_value(args.scoreRepository) then
    if sas.cexist(args.scoreRepository) == 0 then
      util.my_warning(false, "[FORECAST component] The scoreRepository "..args.scoreRepository.." does not exist, ignored")
      localArgs.scoreRepository = nil
    end
  end
  if util.check_value(args.seasonality) then
    localArgs.seasonality = tonumber(args.seasonality)
  end
  localArgs.sign = "NONNEGATIVE"
  if util.check_value(args.sign) then
    local list = {"MIXED", "NONNEGATIVE", "NONPOSITIVE"}
    localArgs.sign = util.validate_sym(args.sign, "sign", list, nil, nil, "NONNEGATIVE")
  end
  
  --include custom code if provided, mainly for custom model selection etc
  if util.check_value(args.customCode) then
    if sas.fileexists(args.customCode)==0 or util.dir_exists(args.customCode) then
      localArgs.customCode = nil
    end
  end
  
  localArgs.processLib = "WORK"
  if util.check_value(args.processLib) then
    if sas.libref(args.processLib)==0 then
      localArgs.processLib = args.processLib
    end
  end
       
  localArgs.direction = "TD"
  if util.check_value(args.recDirection) then
    local list = {"BU", "TD"}
    localArgs.direction = util.validate_sym(args.recDirection, "direction", list, nil, nil, "TD")
  end
  
  localArgs.disaggOption = "PROPORTIONS"
  if util.check_value(args.disaggOption) then
    local list = {"DIFFERENCE", "PROPORTIONS"}
    localArgs.disaggOption = util.validate_sym(args.disaggOption, "disaggOption", list, nil, nil, "PROPORTIONS")
  end

  localArgs.aggregateOption = "TOTAL"
  if util.check_value(args.aggregateOption) then
    local list = {"TOTAL", "AVERAGE"}
    localArgs.aggregateOption = util.validate_sym(args.aggregateOption, "aggregateOption", list, nil, nil, "TOTAL")
  end

  localArgs.clmethodOption = "SHIFT"
  if util.check_value(args.clmethodOption) then
    local list = {"GAUSSIAN", "SHIFT"}
    localArgs.clmethodOption = util.validate_sym(args.clmethodOption, "clmethodOption", list, nil, nil, "SHIFT")
  end
  
  localArgs.replaceMissingFcst = false
  if util.check_value(args.replaceMissingFcst) then
    localArgs.replaceMissingFcst = args.replaceMissingFcst
  end
  
  -- prepare hpfArgs
  local hpfArgs = {}
  
  hpfArgs.hpfBack                 = tonumber(args.hpfBack)
  hpfArgs.hpfSelectMinobsSeason   = tonumber(args.hpfSelectMinobsSeason)
  hpfArgs.hpfSelectMinobsTrend    = tonumber(args.hpfSelectMinobsTrend)
  hpfArgs.hpfSelectMinobsNonMean  = tonumber(args.hpfSelectMinobsNonMean)
  hpfArgs.hpfSetmissing           = args.hpfSetmissing
  hpfArgs.hpfStart                = args.hpfStart
  hpfArgs.hpfEnd                  = args.hpfEnd
  hpfArgs.hpfTrimmiss             = args.hpfTrimmiss
  hpfArgs.hpfZeromiss             = args.hpfZeromiss
  hpfArgs.hpfForecastAlpha        = tonumber(args.hpfForecastAlpha)
  hpfArgs.hpfDiagIntermit         = tonumber(args.hpfDiagIntermit)
  hpfArgs.hpfLead                 = tonumber(args.hpfLead)
  hpfArgs.hpfHorizonStart         = args.hpfHorizonStart

  hpfArgs.eventOptions            = args.eventOptions
  hpfArgs.trendOptions            = args.trendOptions
  hpfArgs.idmOptions              = args.idmOptions
  hpfArgs.esmOptions              = args.esmOptions
  hpfArgs.ucmOptions              = args.ucmOptions
  hpfArgs.arimaxOptions           = args.arimaxOptions
    
  -- check the input hpfArgs specs
  hpfArgs.hpfRetainchoose = "YES"
  if util.check_value(args.hpfRetainchoose) then
    local list = {"YES", "NO", "TRUE", "FALSE"}
    hpfArgs.hpfRetainchoose = util.validate_sym(args.hpfRetainchoose, "hpfRetainchoose", list, nil, nil, "YES")
  end
  
  if util.check_value(args.hpfSelectCriterion) then
    local list = {"SSE", "MSE", "RMSE", "UMSE", "URMSE", "MAXPE", "MINPE", "MPE", "MAPE", "MDAPE", "GMAPE", 
                  "MAPES", "MDAPES", "GMAPES", "MINPPE", "MAXPPE", "MPPE", "MAPPE", "MDAPPE", "GMAPPE", 
                  "MINSPE", "MAXSPE", "MSPE", "SMAPE", "MDASPE", "GMASPE", "MINRE", "MAXRE", "MRE", "MRAE", 
                  "MDRAE", "GMRAE", "MAXERR", "MINERR", "ME", "MAE", "MASE", "RSQUARE", "ADJRSQ", "AADJRSQ",
                  "RWRSQ", "AIC", "AICC", "SBC", "APC"}
    hpfArgs.hpfSelectCriterion = util.validate_sym(args.hpfSelectCriterion, "hpfSelectCriterion", list, nil, nil, nil)
  end
  -- transform option  
  local transtypeArg = ""
  if util.check_value(args.hpfTransType) then
    local list = {"AUTO", "LOG", "NONE", "SQRT", "LOGISTIC"} --currently do not include BOXCOX(value)
    hpfArgs.hpfTransType = util.validate_sym(args.hpfTransType, "hpfTransType", list, nil, nil, "NONE")
    if util.check_value(hpfArgs.hpfTransType) then
      transtypeArg = "type = "..hpfArgs.hpfTransType
    end
  end
  local transoptArg = ""
  if util.check_value(args.hpfTransOpt) then
    local list = {"MEAN", "MEDIAN"}
    hpfArgs.hpfTransOpt = util.validate_sym(args.hpfTransOpt, "hpfTransOpt", list, nil, nil, "MEAN")
    if util.check_value(hpfArgs.hpfTransOpt) then
      transoptArg = "transopt = "..hpfArgs.hpfTransOpt
    end
  end
  hpfArgs.transformOptions = (util.check_value(transtypeArg) or util.check_value(transoptArg))
                             and "transform "..transtypeArg.." "..transoptArg
                             or ""
                             
  return localArgs, hpfArgs
end

--[[
NAME:           fcst_level_args_check

DESCRIPTION:    validate input arguments and assign arguments for a particular level
                
INPUTS:         args
                fcstInfo
                level

OUTPUTS:        levelArgs

USAGE:          
                
]]
local function fcst_level_args_check(localArgs, fcstInfo, level)

  local all_matched
  local match
  local unmatch
  local levelArgs = {}
  local fcstInfoTbl
  local levelIndex
  
  if level == "HIGH" then
    fcstInfoTbl = fcstInfo[2]
    levelIndex  = "fcst high level"
  else
    fcstInfoTbl = fcstInfo[1]
    levelIndex  = "fcst low level"
  end
  -- check input data at low level
  util.my_assert(util.check_value(fcstInfoTbl.dataName), 
                 "[FORECAST component] The dataName at "..levelIndex.." is not specified")
  util.my_assert(sas.exists(fcstInfoTbl.dataName), 
                 "[FORECAST component] The dataName at "..levelIndex.." ".. fcstInfoTbl.dataName .." does not exist")        
  levelArgs.inData = fcstInfoTbl.dataName
  
  -- check required input variable in the data
  all_matched, match, unmatch = util.invar_check(levelArgs.inData, localArgs.depVar)
  util.my_assert(all_matched, "[FORECAST component] The dependent variable ".. localArgs.depVar.." does not exist in data "..levelArgs.inData)
  levelArgs.fcstVar = localArgs.depVar
  
  all_matched, match, unmatch = util.invar_check(levelArgs.inData, localArgs.idVar)
  util.my_assert(all_matched, "[FORECAST component] The time ID variable ".. localArgs.idVar.." does not exist in data "..levelArgs.inData)
  levelArgs.idVar =  localArgs.idVar
  
  levelArgs.interval = localArgs.idInterval
  
  levelArgs.byVars = fcstInfoTbl.byVars
  if util.check_value(levelArgs.byVars) then
    all_matched, match, unmatch = util.invar_check(levelArgs.inData, levelArgs.byVars)
    if not all_matched then
      util.my_assert(false, "[FORECAST component] The BY variables ".. unmatch.." do not exist in data "..levelArgs.inData)
    end
  end
  
  -- check required output 
  levelArgs.outFor = fcstInfoTbl.outFor
  util.my_assert(util.check_value(levelArgs.outFor), "[FORECAST component] The outFor for "..levelIndex.." is not specified")
  
  -- check optional input variables
  levelArgs.inputStatement = nil
  if util.check_value(localArgs.indVars) then
    all_matched, match, unmatch = util.invar_check(levelArgs.inData, localArgs.indVars)
    if not all_matched then
      util.my_warning(false, "[FORECAST component] The independent variables ".. unmatch.." do not exist in data "..levelArgs.inData..", ignored")
    end
    if match then 
      levelArgs.inputStatement = "input "..match.."/required = no"
    end
  end
  
  -- check optional adjustment variables
  levelArgs.adjustmentStatementDiag = nil
  levelArgs.adjustmentStatementEngine = nil
  if util.check_value(fcstInfoTbl.adjustVar) then
    all_matched, match, unmatch = util.invar_check(levelArgs.inData, fcstInfoTbl.adjustVar)
    if not all_matched then
      util.my_warning(false, "[FORECAST component] The adjustment variables ".. unmatch.." do not exist in data "..levelArgs.inData..", ignored")
    end
    if match and util.check_value(fcstInfoTbl.preAdjust) then
       levelArgs.adjustmentStatementDiag = "adjust "..localArgs.depVar.." = ("
                                           ..fcstInfoTbl.adjustVar
                                           ..")/operation = "
                                           ..fcstInfoTbl.preAdjust
    end
    if match and util.check_value(fcstInfoTbl.preAdjust) 
             and util.check_value(fcstInfoTbl.postAdjust) then
         levelArgs.adjustmentStatementEngine = "adjust "..localArgs.depVar.." = ("
                                               ..fcstInfoTbl.adjustVar
                                               ..")/operation = ("
                                               ..fcstInfoTbl.preAdjust..","
                                               ..fcstInfoTbl.postAdjust
                                               ..")" 
    end
  end
  
  levelArgs.modelRepository = fcstInfoTbl.modelRepository
  if util.check_value(levelArgs.modelRepository) then
    if sas.cexist(levelArgs.modelRepository)==0 then
      util.my_warning(false, "[FORECAST component] The modelRepository catalog ".. fcstInfoTbl.modelRepository.." does not exist, ignored")
      levelArgs.modelRepository = nil
    end
  end
  
  levelArgs.globalSelection = fcstInfoTbl.globalSelection
  if util.check_value(levelArgs.globalSelection) then
    if sas.cexist(levelArgs.globalSelection)==0 then
      util.my_warning(false, "[FORECAST component] The globalSelection catalog ".. fcstInfoTbl.globalSelection.." does not exist, ignored")
      levelArgs.globalSelection = nil
    end
  end

  levelArgs.inEvent             = localArgs.inEvent
  levelArgs.seasonality         = localArgs.seasonality
  levelArgs.acc                 = localArgs.accumulate
  levelArgs.format              = localArgs.format
  levelArgs.sign                = localArgs.sign
  levelArgs.processLib          = localArgs.processLib
  
  levelArgs.baseName            = fcstInfoTbl.baseName
  levelArgs.outStat             = fcstInfoTbl.outStat
  levelArgs.outStatSelect       = fcstInfoTbl.outStatSelect
  levelArgs.outEst              = fcstInfoTbl.outEst
  levelArgs.outSum              = fcstInfoTbl.outSum
  levelArgs.outModelInfo        = fcstInfoTbl.outModelInfo

  levelArgs.externalStatement   = fcstInfoTbl.externalStatement
  levelArgs.runDiag             = true
  levelArgs.replaceMissingFcst = localArgs.replaceMissingFcst
  
  return levelArgs
  
end

--[[
NAME:           run_forecast

DESCRIPTION:    generate forecast at two levels and then reconcile
                
INPUTS:         args
                --required in args
                  depVar
                  idVar         
                  idInterval

                --optional in args
                  outForReconcile (required if need reconciliation; otherwise, do not specify)
                  processLib                  
                  inEvent
                  scoreRepository
                  customCode
                  seasonality
                  accumulate
                  format
                  sign
                  indVars
                  recDirection
                  disaggOption
                  aggregateOption
                  clmethodOption
                    
                  hpfRetainchoose
                  hpfBack
                  hpfSelectCriterion
                  hpfSelectMinobsSeason
                  hpfSelectMinobsTrend
                  hpfSelectMinobsNonMean
                  hpfTransType
                  hpfTransOpt
                  hpfSetmissing
                  hpfStart
                  hpfEnd
                  hpfTrimmiss
                  hpfZeromiss
                  hpfForecastAlpha
                  hpfDiagIntermit
                  hpfLead
                  hpfHorizonStart
                  
                  eventOptions
                  trendOptions
                  idmOptions
                  esmOptions
                  ucmOptions
                  arimaxOptions
                  
                  
                fcstInfo
                --required in fcstInfo
                  fcstInfo[1].dataName
                  fcstInfo[1].outFor
                
                --optional in fcstInfo
                  --required if high level is considered
                    fcstInfo[2].dataName
                    fcstInfo[2].outFor
                  --optional in fcstInfo[1/2] if the level is considered
                    byVars
                    baseName
                    outStat
                    outStatSelect
                    outEst
                    outSum
                    outModelInfo
                    adjustVar
                    preAdjust
                    postAdjust
                    modelRepository  
                    externalStatement
                    globalSelection

OUTPUTS:        
                outForReconcile  (if both levels are considered)
                fcstInfo[1/2].outFor  (if the level is considered)
                --optional based on input args if requested
                  fcstInfo[1/2].outStat
                  fcstInfo[1/2].outStatSelect
                  fcstInfo[1/2].outEst
                  fcstInfo[1/2].outSum
                  fcstInfo[1/2].outModelInfo

USAGE:          
                
]]


function run_forecast(args, fcstInfo)

  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO RUN_FORECAST:********"
    local s=table.tostring(args)
    local t=table.tostring(fcstInfo)
    if util.check_value(debugFile) then
      util.dump_to_file(r, debugFile)
      local a = "args="..string.gsub(s, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
      a = "fcstInfo="..string.gsub(t, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
    else 
      print(r.."\n")
      print("args=", s)                    
      print("fcstInfo=", t)  
    end
  end 

  -- validate and prepare the input arguments
  local localArgs
  local hpfArgs
  localArgs, hpfArgs = fcst_inargs_check(args, fcstInfo)

  --include custom code if provided, mainly for custom model selection etc
  if util.check_value(localArgs.customCode) then
    sas.submit([[
      %include '@customCode@';]],{customCode=localArgs.customCode})
  end

  
  if debug == 1 then 
    local r="******INPUT ARGUMENT VALUE INTO RUN_HPF:******"
    local t=table.tostring(hpfArgs)
    if util.check_value(debugFile) then
      util.dump_to_file(r, debugFile)
      local s = "hpfArgs="..string.gsub(t, '00000000.-=', '')
      util.dump_to_file(s, debugFile)
    else 
      print(r.."\n")                  
      print("hpfArgs=", t)  
    end
  end 
  
  -- prepare low level args
  local lowArgs = fcst_level_args_check(localArgs, fcstInfo, "LOW")
                    
  -- print out low level args if in debug
  if debug == 1 then 
    local t=table.tostring(lowArgs)
    if util.check_value(debugFile) then
      local s = "lowArgs="..string.gsub(t, '00000000.-=', '')
      util.dump_to_file(s, debugFile)
    else                 
      print("lowArgs=", t)  
    end
  end
  --call hpf to generate forecast at low level
  run_hpf(lowArgs,hpfArgs)
  
  if #fcstInfo>1 then
    -- prepare high level args
    local highArgs = fcst_level_args_check(localArgs, fcstInfo, "HIGH")
  
    -- print out high level args if in debug            
    if debug == 1 then 
      local t=table.tostring(highArgs)
      if util.check_value(debugFile) then
        local s = "highArgs="..string.gsub(t, '00000000.-=', '')
        util.dump_to_file(s, debugFile)
      else                 
        print("highArgs=", t)  
      end
    end
   
    --call hpf to generate forecast at high level
    run_hpf(highArgs,hpfArgs)
    
    if util.check_value(args.outForReconcile) then 
      -- call hpf reconcile to reconcile the forecast
      local recArgs={}
      local largs={}
      
      recArgs.outFor = localArgs.outForReconcile
      largs.idVar = localArgs.idVar
      largs.idInterval = localArgs.idInterval
      largs.dateFormat = localArgs.format
      recArgs.aggData = highArgs.outFor
      recArgs.disaggData = lowArgs.outFor
      recArgs.byVars = lowArgs.byVars
      
      recArgs.direction = localArgs.recDirection
      recArgs.sign = localArgs.sign
      recArgs.disaggOption = localArgs.disaggOption
      recArgs.aggregateOption = localArgs.aggregateOption
      recArgs.clmethodOption = localArgs.clmethodOption
      
      rec.reconcile_submit(largs, recArgs)
    end
    
  end
  
end


return{run_hpf=run_hpf,
       run_forecast=run_forecast}
