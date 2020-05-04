local util = require("fscb.common.util")
local prep = require('fscb.multistage.data_prep')


--[[
NAME:           input_prep

DESCRIPTION:    function to prepare multscom based on input user settings and data spec
                
INPUTS:         userSettings
                dataSpec                                

OUTPUTS:        multscom
USAGE:          
                
]]
function input_prep(userSettings, dataSpec)

    -- initialize multscom
  local multscom                        = {}
  multscom.fxSpec                       = {}
  multscom.fcstSpec                     = {}
  multscom.fcstSpec.fcstInfo            = {}
  multscom.recSpec                      = {}
  multscom.rptSpec                      = {}
  multscom.dataLib                      = "_sgout"
  multscom.dataMember                   = "segment"
  multscom.depVar                       = string.upper(dataSpec.dependent_variable.name)
  multscom.timeID                       = string.upper(dataSpec.time_id.name)
  multscom.intervalName                 = dataSpec.time_id.interval_name
  multscom.depHierAgg                   = dataSpec.dependent_variable.hierarchy_aggregation
  multscom.setmissing                   = dataSpec.dependent_variable.missing_interpretation
  multscom.zeromiss                     = dataSpec.dependent_variable.zero_interpretation
  multscom.trimmiss                     = dataSpec.dependent_variable.missing_trim
  multscom.customFormat                 = util.check_value(dataSpec.time_id.custom_format)
                                          and dataSpec.time_id.custom_format
                                          or dataSpec.time_id.default_format
  multscom.seasonality                  = dataSpec.time_id.seasonality
  multscom.hpfTransType                 = userSettings.hpfTransType
  multscom.hpfTransOpt                  = userSettings.hpfTransOpt
  multscom.sign                         = userSettings.sign
  multscom.replaceMissingFcst           = util.string_to_boolean(userSettings.replaceMissingFcst,
                                                                 "replaceMissingFcst")
  multscom.replaceMissingAdjust         = util.string_to_boolean(userSettings.replaceMissingAdjust,
                                                                 "replaceMissingAdjust")                                                                 
                                                                                                                            
  local format                          = util.check_value(multscom.customFormat) and multscom.customFormat or ""                                               
  multscom.hpfHorizonStart              = util.check_value(dataSpec.dependent_variable.horizon_start)
                                          and util.value_to_date(dataSpec.dependent_variable.horizon_start, format)
                                          or ""
  multscom.hpfStart                     = util.check_value(dataSpec.time_id.start) and util.value_to_date(dataSpec.time_id.start, format) or ""
  multscom.hpfLead                      = dataSpec.lead
  multscom.hpfForecastAlpha             = dataSpec.confidence_limit
  -- get by vars
  local byVars = string.upper(util.get_string_from_table(dataSpec.byvars))
  multscom.byVars = byVars
  
  -- validate input arguments
  local all_matched
  local match
  local unmatch
  local inData = multscom.dataLib.."."..multscom.dataMember
  all_matched, match, unmatch = util.invar_check(inData, multscom.depVar)
  util.my_assert(all_matched, "[INPUT_PREP component] The dependent variable ".. multscom.depVar.." does not exist in data "..inData)
  all_matched, match, unmatch = util.invar_check(inData, multscom.timeID)
  util.my_assert(all_matched, "[INPUT_PREP component] The time ID variable ".. multscom.timeID.." does not exist in data "..inData)
  all_matched, match, unmatch = util.invar_check(inData, byVars)
  if not all_matched then
   util.my_assert(all_matched, "[INPUT_PREP component] The BY variables ".. unmatch.." does not exist in data "..inData)
   end
   
  -- check model by variables
  multscom.modelHierVars   = userSettings.modelHierVars
  if util.check_value(multscom.modelHierVars) then
    all_matched, match, unmatch = util.invar_check(inData, multscom.modelHierVars)
    if not all_matched then
      util.my_warning(false, "[INPUT_PREP component] The modelHierVars ".. unmatch.." do not exist in data "..inData..", use hierarchy BY variables instead")
      multscom.modelHierVars = multscom.byVars
    end 
  else
    util.my_warning(false, "[INPUT_PREP component] The modelHierVars is not specified, use hierarchy BY variables")
    multscom.modelHierVars = multscom.byVars   
  end
  multscom.modelHierVars = string.upper(multscom.modelHierVars)
  local modelLevel       = util.split_string(string.upper(multscom.modelHierVars))
  local numModelLevel    = #modelLevel
  util.my_assert(numModelLevel>=2, "[INPUT_PREP component] The modelHierVars (".. multscom.modelHierVars..") is invalid, should contain at least 2 levels ")
  
  
  -- get project info about independent variables
  multscom.indepVar      = nil
  local indVars          = nil
  local numIndVars       = 0
  if util.check_value(dataSpec.independent_variables) then
    multscom.indepVar    = {}
    for s, v in pairs(dataSpec.independent_variables) do
      local var={}
      all_matched, match, unmatch = util.invar_check(inData, v.name)
      if not all_matched then
        util.my_warning(false, "[INPUT_PREP component] The independent variable ".. unmatch.." does not exist in data "..inData..", ignored")
      else
        numIndVars         = numIndVars+1
        var.name           = string.upper(v.name)
        var.setmissing     = v.missing_interpretation
        var.zeromiss       = v.zero_interpretation
        var.trimmiss       = v.missing_trim
        var.indepHierAgg   = v.hierarchy_aggregation
        table.insert(multscom.indepVar, var)
        indVars = util.add_to_string(indVars, var.name)
      end
    end
  end

  
  -- build hierarchy info (data prep) based on modeling hierarchy
  local hierarchyInfo
  local prepArgs          = {}
  prepArgs.inData         = multscom.dataLib..'.'..multscom.dataMember
  prepArgs.byVars         = multscom.modelHierVars
  prepArgs.depVar         = multscom.depVar
  prepArgs.indVars        = multscom.indepVar
  prepArgs.idVar          = multscom.timeID
  prepArgs.idInterval     = multscom.intervalName
  prepArgs.setmissing     = multscom.setmissing
  prepArgs.zeromiss       = multscom.zeromiss
  prepArgs.trimmiss       = multscom.trimmiss
  prepArgs.aggDep         = multscom.depHierAgg
  prepArgs.start          = multscom.hpfStart
  prepArgs.horizonStart   = multscom.hpfHorizonStart
  prepArgs.processLib     = "_msTmp"
  hierarchyInfo           = prep.build_hierarchy(prepArgs)
  multscom.hierarchyInfo  = hierarchyInfo
  
    
  -- get by forecast level by variable
  multscom.fcstSpec.fcstLowVars   = ''
  multscom.fcstSpec.fcstHighVars  = ''
  multscom.stg1LowLvlVar          = ''
  multscom.stg1HighLvlVar         = ''
  multscom.fcstSpec.fcstLowLevel  = -1
  if util.check_value(userSettings.stg1LowLvlVar) then
    if string.upper(userSettings.stg1LowLvlVar) == "_TOP" then
        multscom.fcstSpec.fcstLowLevel = 0
    else
      if util.check_sub_string(multscom.modelHierVars, userSettings.stg1LowLvlVar) then
        multscom.stg1LowLvlVar      = string.upper(userSettings.stg1LowLvlVar)
      else
        util.my_warning(false, "[INPUT_PREP component] The stg1LowLvlVar ".. userSettings.stg1LowLvlVar.." does not exist in the modeling hierarchy ("
                                ..multscom.modelHierVars.."), use "..modelLevel[numModelLevel-1].." , instead")
        multscom.stg1LowLvlVar      = modelLevel[numModelLevel-1]
      end
    end
  else
      util.my_warning(false, "[INPUT_PREP component] The stg1LowLvlVaris not specified, use "..modelLevel[numModelLevel-1].." , instead")
      multscom.stg1LowLvlVar       = modelLevel[numModelLevel-1]
  end
  
  multscom.fcstSpec.fcstHighLevel = -1
  if util.check_value(userSettings.stg1HighLvlVar) then
    if string.upper(userSettings.stg1HighLvlVar) == "_TOP" then
      multscom.fcstSpec.fcstHighLevel = 0
    else
      if util.check_sub_string(multscom.modelHierVars, userSettings.stg1HighLvlVar) then
        multscom.stg1HighLvlVar      = string.upper(userSettings.stg1HighLvlVar)
      else
        util.my_warning(false, "[INPUT_PREP component] The stg1HighLvlVar ".. userSettings.stg1HighLvlVar.." does not exist in the modeling hierarchy ("
                                ..multscom.modelHierVars.."), ignored")
      end
    end
  end
  
  local lowVars          = ''
  local i                = 0
  for i = 1, numModelLevel do
    local v = modelLevel[i]
    lowVars = util.add_to_string(lowVars, v)
    if multscom.stg1LowLvlVar == v then
      multscom.fcstSpec.fcstLowVars = lowVars
      multscom.fcstSpec.fcstLowLevel = i
    end
    if multscom.stg1HighLvlVar == v then
      multscom.fcstSpec.fcstHighVars = lowVars
      multscom.fcstSpec.fcstHighLevel = i
    end
  end
  
  if(multscom.fcstSpec.fcstHighLevel>=multscom.fcstSpec.fcstLowLevel) then
      util.my_warning(false, "[INPUT_PREP component] The stg1HighLvlVar ".. userSettings.stg1HighLvlVar.." should be at a level higher than stg1LowLvlVar"
                              ..userSettings.stg1LowLvlVar..", the stg1HighLvlVar is ignored")   
      multscom.stg1HighLvlVar         = '' 
      multscom.fcstSpec.fcstHighVars  = ""
      multscom.fcstSpec.fcstHighLevel = -1
  end
  
  -- prepare info for fxSpec
  
  multscom.stg1Fx                         = util.string_to_boolean(userSettings.stg1Fx, "stg1Fx")
  multscom.fxSpec[1]                      = {}
  if multscom.stg1Fx then
    multscom.fxSpec[1].fxInData           = hierarchyInfo[multscom.fcstSpec.fcstLowLevel].dataName
    multscom.fxSpec[1].fxOutFor           = "_msTmp.fx1OutFor"
    multscom.fxSpec[1].fxOutAdjustData    = "_msTmp.fx1OutAdjust"
    multscom.fxSpec[1].glmByVars          = userSettings.stg1FxByVars

    -- set the fx model
    multscom.fxSpec[1].model              = multscom.depVar.." = "
    multscom.fxSpec[1].glmInclude         = 0
      -- first, always add level by variables in the model for intercept
    local modelLvlVar                       = multscom.fcstSpec.fcstLowVars
    if util.check_value(multscom.fxSpec[1].glmByVars) and multscom.fcstSpec.fcstLowLevel>=1 then
      -- no need to include level by variables in the glm by-variables list
      modelLvlVar = ""
      for i=1, multscom.fcstSpec.fcstLowLevel do
        local v = modelLevel[i]
        if not util.check_sub_string(multscom.fxSpec[1].glmByVars, v) then
          modelLvlVar = util.add_to_string(modelLvlVar, v)
        end
      end
    end
    if util.check_value(modelLvlVar) then
      modelLvlVar                         = util.get_delim_string(modelLvlVar, "*")
      multscom.fxSpec[1].model            = multscom.fxSpec[1].model..modelLvlVar
      multscom.fxSpec[1].glmInclude       = 1
    end
      -- include the user specified model or the default all-independent variable
    if util.check_value(userSettings.stg1FxModel) then
      if util.check_value(modelLvlVar) then
        local modelComponent              = util.split_string(string.upper(userSettings.stg1FxModel))
        for i=1, #modelComponent do
          if modelComponent[i] ~= modelLvlVar then
            multscom.fxSpec[1].model      = util.add_to_string(multscom.fxSpec[1].model, modelComponent[i])
          end
        end
      else
        multscom.fxSpec[1].model          = multscom.fxSpec[1].model..string.upper(userSettings.stg1FxModel)
      end
    else
      if util.check_value(indVars) then
        multscom.fxSpec[1].model          = multscom.fxSpec[1].model.." "..indVars
      end
    end

    multscom.fxSpec[1].byVars             = multscom.fcstSpec.fcstLowVars
    
    if util.check_value(userSettings.stg1FxClassVars) then
      multscom.fxSpec[1].classVars        = userSettings.stg1FxClassVars
    else
      multscom.fxSpec[1].classVars        = ""
      -- if stg1FxClassVars is not specified, include all character independent variables automatically
      if numIndVars>0 then
        for i = 1, numIndVars do
          local v = multscom.indepVar[i].name
          if util.check_vartype(multscom.fxSpec[1].fxInData, v) == "C" 
             and util.check_sub_string(multscom.fxSpec[1].model, v) then
            multscom.fxSpec[1].classVars  = util.add_to_string(multscom.fxSpec[1].classVars, v)
          end
        end
      end
    end
    -- include all level by variables in the model automatically
    if multscom.fcstSpec.fcstLowLevel>=1 then
      for i = 1, multscom.fcstSpec.fcstLowLevel do
        local v = modelLevel[i]
        if util.check_sub_string(multscom.fxSpec[1].model, v) and (not util.check_sub_string(multscom.fxSpec[1].classVars, v)) then
          multscom.fxSpec[1].classVars  = util.add_to_string(multscom.fxSpec[1].classVars, v)
        end
      end
    end
    
    multscom.fxSpec[1].indTransVars       = userSettings.fx1TransVars
    
    multscom.fxSpec[1].adjustVars         = ""
    if numIndVars>0 then
      for i = 1, numIndVars do
        if util.check_sub_string(multscom.fxSpec[1].model, multscom.indepVar[i].name) then
          multscom.fxSpec[1].adjustVars   = util.add_to_string(multscom.fxSpec[1].adjustVars, 
                                                               multscom.indepVar[i].name)
        end
      end
    end
    
    multscom.fxSpec[1].seasonDummy        = util.check_value(userSettings.stg1FxSeasonDummy) 
                                            and util.string_to_boolean(userSettings.stg1FxSeasonDummy, "stg1FxSeasonDummy")
                                            or false
    multscom.fxSpec[1].seasonalInterval   = userSettings.stg1FxSeasonalInterval
    if multscom.fxSpec[1].seasonDummy and not util.check_value(multscom.fxSpec[1].seasonalInterval) then
      multscom.fxSpec[1].seasonalInterval = multscom.intervalName
    end
    multscom.fxSpec[1].depTransform       = userSettings.stg1FxDepTransform
    multscom.fxSpec[1].seasonAdjust       = util.check_value(userSettings.stg1SeasonAdjust) 
                                            and util.string_to_boolean(userSettings.stg1SeasonAdjust, "stg1SeasonAdjust")
                                            or false
    multscom.fxSpec[1].predictVarName     = "predict"
  end
  multscom.fxSpec[2]                      = {}
  multscom.fxSpec[2].fxInData             = hierarchyInfo[numModelLevel].dataName
  multscom.fxSpec[2].fxOutFor             = "_msTmp.fx2OutFor"
  multscom.fxSpec[2].fxOutAdjustData      = "_msTmp.fx2OutAdjust"
  multscom.fxSpec[2].glmByVars            = userSettings.stg2FxByVars
  -- if both the stg2FxModel and stg2FxByVars are not specified, use the vars identifying stg1LowLvlVar for stg2FxByVars
  if (not util.check_value(userSettings.stg2FxModel)) and (not util.check_value(multscom.fxSpec[2].glmByVars)) then
    multscom.fxSpec[2].glmByVars          = util.add_to_string(multscom.fxSpec[2].glmByVars, multscom.fcstSpec.fcstLowVars)
  end
  
  -- set the fx model
  multscom.fxSpec[2].model                = multscom.depVar.." = "
  multscom.fxSpec[2].glmInclude           = 0
    -- first, always add level by variables in the model for intercept
  local modelLvlVar                       = multscom.modelHierVars
  if util.check_value(multscom.fxSpec[2].glmByVars) then
    -- no need to include level by variables in the glm by-variables list
    modelLvlVar = ""
    for i=1, numModelLevel do
      local v = modelLevel[i]
      if not util.check_sub_string(multscom.fxSpec[2].glmByVars, v) then
        modelLvlVar = util.add_to_string(modelLvlVar, v)
      end
    end
  end
  if util.check_value(modelLvlVar) then
    modelLvlVar                           = util.get_delim_string(modelLvlVar, "*")
    multscom.fxSpec[2].model              = multscom.fxSpec[2].model..modelLvlVar
    multscom.fxSpec[2].glmInclude         = 1
  end
    -- include the user specified model or the default all-independent variable
  if util.check_value(userSettings.stg2FxModel) then
    if util.check_value(modelLvlVar) then
      local modelComponent                = util.split_string(string.upper(userSettings.stg2FxModel))
      for i=1, #modelComponent do
        if modelComponent[i] ~= modelLvlVar then
          multscom.fxSpec[2].model        = util.add_to_string(multscom.fxSpec[2].model, modelComponent[i])
        end
      end
    else
      multscom.fxSpec[2].model            = multscom.fxSpec[2].model..string.upper(userSettings.stg2FxModel)
    end
  else
    if util.check_value(indVars) then
      multscom.fxSpec[2].model            = multscom.fxSpec[2].model.." "..indVars
    end    
  end

  multscom.fxSpec[2].byVars               = multscom.modelHierVars
  if util.check_value(userSettings.stg2FxClassVars) then
    multscom.fxSpec[2].classVars          = userSettings.stg2FxClassVars
  else
    multscom.fxSpec[2].classVars          = ""
    -- if stg2FxClassVars is not specified, include all character independent variables automatically
    if numIndVars>0 then
      for i = 1, numIndVars do
        local v = multscom.indepVar[i].name
        if util.check_vartype(multscom.fxSpec[2].fxInData, v) == "C" 
           and util.check_sub_string(multscom.fxSpec[2].model, v) then
          multscom.fxSpec[1].classVars    = util.add_to_string(multscom.fxSpec[2].classVars, v)
        end
      end
    end
  end
  -- include all level by variables in the model automatically
  for i = 1, numModelLevel do
    local v = modelLevel[i]
    if util.check_sub_string(multscom.fxSpec[2].model, v) and (not util.check_sub_string(multscom.fxSpec[2].classVars, v)) then
      multscom.fxSpec[2].classVars  = util.add_to_string(multscom.fxSpec[2].classVars, v)
    end
  end
  multscom.fxSpec[2].indTransVars         = userSettings.fx2TransVars
  multscom.fxSpec[2].adjustVars           = ""
  multscom.fxSpec[2].seasonDummy          = util.check_value(userSettings.stg2FxSeasonDummy) 
                                            and util.string_to_boolean(userSettings.stg2FxSeasonDummy, "stg2FxSeasonDummy")
                                            or false
  multscom.fxSpec[2].seasonalInterval     = userSettings.stg2FxSeasonalInterval
  if multscom.fxSpec[2].seasonDummy and not util.check_value(multscom.fxSpec[2].seasonalInterval) then
    multscom.fxSpec[2].seasonalInterval   = multscom.intervalName
  end
  multscom.fxSpec[2].depTransform         = userSettings.stg2FxDepTransform
  multscom.fxSpec[2].seasonAdjust         = false
  multscom.fxSpec[2].predictVarName       = "predict"
  
  -- TODO:coeffDefault
  
  
  -- prepare info for fcstSpec
  
  local hpfInputVars = ""
  if util.check_value(hpfInputVars) and util.check_value(dataSpec.independent_variables) then
    local varsList = util.split_string(string.upper(userSettings.hpfInputVars))
    for i = 1, #varsList do
      local add = 1
      if multscom.stg1Fx then
        if util.check_value(multscom.fxSpec[1].adjustVars) and util.check_sub_string(multscom.fxSpec[1].adjustVars, varsList[i]) then
          add = 0
          util.my_warning(false, "[INPUT_PREP component] The hpfInputVar ".. varsList[i]..
                                  " is also used as an adjustment variable in stage 1 feature extraction, ignored.")
        end
      end
      if not util.check_sub_string(dataSpec.independent_variables, varsList[i]) then
        add = 0
        util.my_warning(false, "[INPUT_PREP component] The hpfInputVar ".. varsList[i]..
                                " is not listed as an independent variable, ignored.")
      end
      if add==1 then
        hpfInputVars  = util.add_to_string(hpfInputVars, varsList[i])
      end
    end
  end
  multscom.fcstSpec.hpfInputVars      = hpfInputVars
  multscom.fcstSpec.customCode        = userSettings.hpfCustomCode
  multscom.fcstSpec.globalSelection   = userSettings.globalSelection
  multscom.fcstSpec.hpfRetainchoose   = userSettings.hpfRetainchoose 
  multscom.fcstSpec.hpfBack           = util.check_value(userSettings.hpfBack) and tonumber(userSettings.hpfBack) or nil
  multscom.fcstSpec.hpfSelectCrit     = userSettings.hpfSelectCrit
  multscom.fcstSpec.hpfSelectMinSeason= util.check_value(userSettings.hpfSelectMinSeason) and tonumber(userSettings.hpfSelectMinSeason) or nil
  multscom.fcstSpec.hpfSelectMinTrend = util.check_value(userSettings.hpfSelectMinTrend) and tonumber(userSettings.hpfSelectMinTrend) or nil
  multscom.fcstSpec.hpfSelectMinMean  = util.check_value(userSettings.hpfSelectMinMean) and tonumber(userSettings.hpfSelectMinMean) or nil
  multscom.fcstSpec.hpfDiagIdm        = util.check_value(userSettings.hpfDiagIdm) and tonumber(userSettings.hpfDiagIdm) or nil
  multscom.fcstSpec.trendOptions      = userSettings.trendOptions
  multscom.fcstSpec.ucmOptions        = userSettings.ucmOptions
  multscom.fcstSpec.arimaxOptions     = userSettings.arimaxOptions
  multscom.fcstSpec.esmOptions        = userSettings.esmOptions
  multscom.fcstSpec.idmOptions        = userSettings.idmOptions
  multscom.fcstSpec.fcstInfo[1]                  = {}
  multscom.fcstSpec.fcstInfo[1].adjustVar        = ""
  if multscom.stg1Fx then
    if util.check_value(multscom.fxSpec[1].adjustVars) then
      multscom.fcstSpec.fcstInfo[1].fcstIndata   = multscom.fxSpec[1].fxOutAdjustData
      multscom.fcstSpec.fcstInfo[1].adjustVar    = "adjustment"
    elseif util.check_value(multscom.fxSpec[1].seasonAdjust) and multscom.fxSpec[1].seasonAdjust
           and util.check_value(multscom.fxSpec[1].seasonDummy) and multscom.fxSpec[1].seasonDummy then
      multscom.fcstSpec.fcstInfo[1].fcstIndata   = multscom.fxSpec[1].fxOutAdjustData
      multscom.fcstSpec.fcstInfo[1].adjustVar    = "adjustment"
    else
      multscom.fcstSpec.fcstInfo[1].fcstIndata   = multscom.fxSpec[1].fxOutFor
    end
  else
    multscom.fcstSpec.fcstInfo[1].fcstIndata     = hierarchyInfo[multscom.fcstSpec.fcstLowLevel].dataName
  end
  multscom.fcstSpec.fcstInfo[1].byVars           = multscom.fcstSpec.fcstLowVars
  multscom.fcstSpec.fcstInfo[1].baseName         = "Low"
  multscom.fcstSpec.fcstInfo[1].outFor           = "_msTmp.fcstLowOutFor"
  multscom.fcstSpec.fcstInfo[1].modelRepository  = userSettings.customModelRepositoryLow
  multscom.fcstSpec.fcstInfo[1].globalSelection  = userSettings.globalSelectionLow
  
  if multscom.fxSpec.depTransform=="LOG" then 
    multscom.fcstSpec.fcstInfo[1].preAdjust      = "DIVIDE"
    multscom.fcstSpec.fcstInfo[1].postAdjust     = "MULTIPLY"
  else
    multscom.fcstSpec.fcstInfo[1].preAdjust      = "SUBTRACT"
    multscom.fcstSpec.fcstInfo[1].postAdjust     = "ADD"
  end
  
  if multscom.fcstSpec.fcstHighLevel >=0 then
    multscom.fcstSpec.fcstInfo[2]                 = {}
    multscom.fcstSpec.fcstInfo[2].fcstIndata      = hierarchyInfo[multscom.fcstSpec.fcstHighLevel].dataName
    multscom.fcstSpec.fcstInfo[2].byVars          = multscom.fcstSpec.fcstHighVars
    multscom.fcstSpec.fcstInfo[2].baseName        = "High"
    multscom.fcstSpec.fcstInfo[2].adjustVar       = ""
    multscom.fcstSpec.fcstInfo[2].outFor          = "_msTmp.fcstHighOutFor"
    multscom.fcstSpec.fcstInfo[2].preAdjust       = ""
    multscom.fcstSpec.fcstInfo[2].postAdjust      = ""
    multscom.fcstSpec.fcstInfo[2].modelRepository = userSettings.customModelRepositoryHigh
    multscom.fcstSpec.fcstInfo[2].globalSelection = userSettings.globalSelectionHigh
    multscom.fcstSpec.outForReconcile             = "_msTmp.fcstOutForReconcile"
  end
  
  -- prepare info for recSpec
  multscom.recSpec.diaggregation  = userSettings.disaggregation
  multscom.recSpec.aggregate      = userSettings.aggregate
  multscom.recSpec.clmethod       = userSettings.clmethod
  multscom.recSpec.recDisaggData  = multscom.fxSpec[2].fxOutFor
  if multscom.fcstSpec.fcstHighLevel >=0 then
    multscom.recSpec.recAggData     = multscom.fcstSpec.outForReconcile
  else
    multscom.recSpec.recAggData     = multscom.fcstSpec.fcstInfo[1].outFor
  end
  multscom.recSpec.byVars         = multscom.modelHierVars
  multscom.recSpec.outFor         = "_msTmp.recOutFor"
  
  -- prepare info for rptSpec
  multscom.rptSpec.lowInData      = multscom.dataLib.."."..multscom.dataMember
  multscom.rptSpec.fcstInData     = multscom.recSpec.outFor
  multscom.rptSpec.byVars         = multscom.byVars
  local byLevel                   = util.split_string(multscom.byVars)
  multscom.rptSpec.rptOut         = {}
  for i = 0, #byLevel do
      local rptVar = {}            
      rptVar.rptOutFor            = "_EXP"..i..".outfor"
      rptVar.rptOutStat           = "_EXP"..i..".outstat"
      rptVar.rptOutSum            = nil
      multscom.rptSpec.rptOut[i]  = rptVar
  end
  
  -- check debug information
  local debug = 0
  local tdebug = sas.symget("DEBUG")
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end 
  -- print out multscom information if in debug mode
  if debug == 1 then
    local t=table.tostring(multscom)
    if util.check_value(debugFile) then
      local a="**********MULTSCOM:**********"
      util.dump_to_file(a, debugFile)
      local s = "multscom = "..string.gsub(t, '00000000.-=', '')
      util.dump_to_file(s, debugFile)
    else 
      print("MULTSCOM:\n")               
      print("multscom=", t)
    end
  end
  
  return multscom
end

return{input_prep=input_prep}
