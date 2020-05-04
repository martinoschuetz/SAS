local util=require("fscb.common.util")
local forecast_pack=require("fscb.multistage.forecast")

--[[
validate input arguments for feature_extract
set argument defaults for feature_extract

return fxArgs
]]
local function validate_fx_args(args)
  local fxArgs
  
  -- check required input arguments
  util.my_assert(util.check_value(args.inData), "[FEATURE_EXTRACT component] Input data is not specified")
  util.my_assert(util.check_value(args.depVar), "[FEATURE_EXTRACT component] Dependent variable is not specified")
  util.my_assert(util.check_value(args.idVar), "[FEATURE_EXTRACT component] No variable specified for time ID")
  util.my_assert(util.check_value(args.idInterval), "[FEATURE_EXTRACT component] Time ID interval is not specified")
  util.my_assert(util.check_value(args.model), "[FEATURE_EXTRACT component] No model is specified")
  
  fxArgs = {}
  fxArgs.inData = args.inData
  fxArgs.depVar = args.depVar
  fxArgs.idVar = args.idVar
  fxArgs.idInterval = args.idInterval
  fxArgs.model = args.model
  fxArgs.aggDep = args.aggDep
  fxArgs.seasonDummy = args.seasonDummy
  fxArgs.seasonalInterval = args.seasonalInterval
  fxArgs.seasonAdjust = args.seasonAdjust
  fxArgs.seasonality = args.seasonality
  fxArgs.adjustVars = args.adjustVars
  fxArgs.classVars = args.classVars
  fxArgs.glmByVars = args.glmByVars
  fxArgs.byVars = args.byVars
  fxArgs.indTransVars = args.indTransVars
  fxArgs.depTransform = args.depTransform
  fxArgs.predictVarName = args.predictVarName
  fxArgs.fillMissing = args.fillMissing
  fxArgs.outAdjustmentData = args.outAdjustmentData
  fxArgs.outFor = args.outFor
  fxArgs.setmissing = args.setmissing
  fxArgs.zeromiss = args.zeromiss
  fxArgs.trimmiss = args.trimmiss
  fxArgs.hpfBack = args.hpfBack
  fxArgs.hpfStart = args.hpfStart
  fxArgs.hpfEnd = args.hpfEnd
  fxArgs.hpfLead = args.hpfLead
  fxArgs.hpfHorizonStart = args.hpfHorizonStart
  fxArgs.format = args.format
  fxArgs.glmInclude = args.glmInclude
  
  if util.check_value(args.glmInclude) then
    fxArgs.glmInclude = tonumber(args.glmInclude)
  else
    fxArgs.glmInclude = 0
  end
  
  fxArgs.processLib = "WORK"
  if util.check_value(args.processLib) then
    if sas.libref(args.processLib)==0 then
      fxArgs.processLib = args.processLib
    else
      util.my_warning(false, "[FEATURE_EXTRACT component]  The given processLib"..args.processLib.." does not exist, use work as processLib.")
    end
  end 
  
  if not util.check_value(fxArgs.aggDep) then
    fxArgs.aggDep = "total"
  end
  if not util.check_value(fxArgs.seasonDummy) then
    fxArgs.seasonDummy = false
  end
  if fxArgs.seasonDummy then
    util.my_assert(util.check_value(fxArgs.seasonalInterval), "[FEATURE_EXTRACT component] Time interval for seasonality is not specified")
  end
  if not util.check_value(fxArgs.seasonAdjust) then
    fxArgs.seasonAdjust = false
  end
  if util.check_value(fxArgs.adjustVars) then
    util.my_assert(util.check_value(fxArgs.outAdjustmentData), "[FEATURE_EXTRACT component] outAdjustmentData is not specified")
  else
    util.my_assert(util.check_value(fxArgs.outFor), "[FEATURE_EXTRACT component] outFor is not specified")
  end
  if util.check_value(fxArgs.depTransform) then
    if string.upper(fxArgs.depTransform) ~= "NONE" and string.upper(fxArgs.depTransform) ~= "LOG" then
      util.my_warning(false, "[FEATURE_EXTRACT component] depTransform ".. fxArgs.depTransform.."is not recognized, set to NONE")
      fxArgs.depTransform = "NONE"
    end
  end
  if not util.check_value(fxArgs.fillMissing) then
    fxArgs.fillMissing = false
  end
  
  local all_matched
  local match
  local unmatch
  -- check required input variable in the data
  all_matched, match, unmatch = util.invar_check(fxArgs.inData, fxArgs.depVar)
  util.my_assert(all_matched, "[FEATURE_EXTRACT component] The depdent variable ".. fxArgs.depVar.." does not exist in data "..fxArgs.inData..", exit.")
  all_matched, match, unmatch = util.invar_check(fxArgs.inData, fxArgs.idVar)
  util.my_assert(all_matched, "[FEATURE_EXTRACT component] The id variable ".. fxArgs.idVar.." does not exist in data "..fxArgs.inData..", exit.")  
  if util.check_value(fxArgs.classVars) then
    all_matched, match, unmatch = util.invar_check(fxArgs.inData, fxArgs.classVars)
    if util.check_value(unmatch) then
      util.my_assert(all_matched, "[FEATURE_EXTRACT component] The class variables ".. unmatch.." does not exist in data "..fxArgs.inData..", exit.")
    end
  end
  if util.check_value(fxArgs.adjustVars) then
    all_matched, match, unmatch = util.invar_check(fxArgs.inData, fxArgs.adjustVars)
    if util.check_value(unmatch) then
      util.my_assert(all_matched, "[FEATURE_EXTRACT component] The adjust variables ".. unmatch.." does not exist in data "..fxArgs.inData..", exit.")
    end
  end
  if util.check_value(fxArgs.glmByVars) then
    all_matched, match, unmatch = util.invar_check(fxArgs.inData, fxArgs.glmByVars)
    if util.check_value(unmatch) then
      util.my_assert(all_matched, "[FEATURE_EXTRACT component] The glm by variables ".. unmatch.." does not exist in data "..fxArgs.inData..", exit.")
    end
  end
  if util.check_value(fxArgs.byVars) then
    all_matched, match, unmatch = util.invar_check(fxArgs.inData, fxArgs.byVars)
    if util.check_value(unmatch) then
      util.my_assert(all_matched, "[FEATURE_EXTRACT component] The by variables ".. unmatch.." does not exist in data "..fxArgs.inData..", exit.")
    end
  end
  if util.check_value(fxArgs.indTransVars) then
    all_matched, match, unmatch = util.invar_check(fxArgs.inData, fxArgs.indTransVars)
    if util.check_value(unmatch) then
      util.my_assert(all_matched, "[FEATURE_EXTRACT component] The independent variables ".. unmatch.." does not exist in data "..fxArgs.inData..", exit.")
    end
  end
  
  fxArgs.replaceMissingFcst = false
  if util.check_value(args.replaceMissingFcst) then
    fxArgs.replaceMissingFcst = args.replaceMissingFcst
  end
 
  fxArgs.sign = util.check_value(args.sign) and args.sign or "NONNEGATIVE"
  
  return fxArgs 
end


--[[
NAME:           feature_extract

DESCRIPTION:    run glm to perform feature extraction for given data
                
INPUTS:         fxArgs
                -- required in fxArgs
                  inData
                  model
                  depVar
                  idVar
                  idInterval
                  aggDep
                
                -- optional
                  processLib
                  glmByVars      -- byvars for glm
                  byVars         -- level by vars, used in hpfengine
                  classVars
                  adjustVars
                  indTransVars
                  depTransform
                  seasonDummy
                  seasonality
                  seasonalInterval
                  seasonAdjust
                  predictVarName
                  fillMissing    -- flag to indicate whether to fill in missing for adjustment
                  glmInclude     -- force the first n variables to be included in glm model
                  replaceMissingFcst

                  format
                  sign
                  setmissing
                  zeromiss
                  trimmiss
                  hpfBack
                  hpfStart
                  hpfEnd
                  hpfLead
                  hpfHorizonStart

OUTPUTS:        outFor            -- if no adjustment is done
                outAdjustmentData -- if adjustment is required by user


USAGE: 
                
]]

function feature_extract(fxArgs)

  local localArgs = validate_fx_args(fxArgs)
  local fxRc = 0
  
  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO FEATURE_EXTRACT:********"
    local s=table.tostring(localArgs)
    if util.check_value(debugFile) then
      util.dump_to_file(r, debugFile)
      local a = "localArgs="..string.gsub(s, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
    else 
      print(r.."\n")
      print("localArgs=", s)                    
    end
  end 

  local localClassVars = ""
  local localModel = localArgs.model         -- to model statement
  local localTransVars = {}
  local localAdjustVars = {}              -- table to store all variables to be included in adjustment
  local adjustClassVars = {}              -- table to store all class variables to be included in adjustment
  local adjustIntervalVars = {}           -- table to store all interval (continuous) variables to be included in adjustment
  local numAdjustVars = 0
  local i
  local j
  local j1 = 1                            -- table index for adjustIntervalVars
  local j2 = 1                            -- table index for adjustClassVars
  local adjustmentFlag = false            -- flag to indicate whether adjustment is required or not
  local adjustClassFlag = false           -- flag to indicate whether class variables are included in adjustment or not
  local depTransFlag = false              -- flag to indicate whether transformation is done for dependent or not
  local setPredictVarName = ""
  local glmInclude = ""
  
  local localPredName = "p_"..localArgs.depVar
  local glmIndata = localArgs.inData
  
  if localArgs.glmInclude > 0 then 
    glmInclude = "include = "..localArgs.glmInclude
  end
  
  if util.check_value(localArgs.predictVarName) then
    setPredictVarName = "predicted = "..localArgs.predictVarName
    localPredName = localArgs.predictVarName
  end
  
  if util.check_value(localArgs.classVars) then
    localClassVars = localArgs.classVars
  end
  
  -- check if there is any adjustment vars specified, set the adjustmentFlag correspondingly
  -- split adjustment vars to adjustClassVars and ajdustIntervalVars
  if util.check_value(localArgs.adjustVars) then
    localAdjustVars = util.split_string(localArgs.adjustVars)
    adjustmentFlag = true
    
    if util.check_value(localArgs.classVars) then
      numAdjustVars = #localAdjustVars
      for i = 1, numAdjustVars do
        if util.check_sub_string(localClassVars,localAdjustVars[i]) then
          adjustClassVars[j2] = localAdjustVars[i]
          adjustClassFlag = true
          j2 = j2 + 1
          -- create reference macro variable for the class adjustment variable
          local adjustClassMacroVar = string.upper(localAdjustVars[i]).."_ref"
          sas.symput(adjustClassMacroVar, "")
        else
          adjustIntervalVars[j1] = localAdjustVars[i]
          j1 = j1 + 1
        end
      end
    else
      adjustIntervalVars = localAdjustVars
    end
  end
  
  local transformStatement = ""
  local seasonIdxStatement = ""
  
  -- check transformation variable list
  -- validate all variables in the list, output warning msg if class variables cannot be included
  if util.check_value(localArgs.depTransform) and string.upper(localArgs.depTransform) == "LOG" then
    depTransFlag = true
    transformStatement = "orig_depVar = "..localArgs.depVar..";"
    transformStatement = transformStatement.."if "..localArgs.depVar..">0 then "..localArgs.depVar.."= log("..localArgs.depVar.."); else "..localArgs.depVar.."= .;"
  end
  if util.check_value(localArgs.indTransVars) then
    i = 1
    local VarsTbl = util.split_string(localArgs.indTransVars)
    for j=1, #VarsTbl do
      local v = VarsTbl[j]
      if util.check_sub_string(localArgs.classVars, v) then
        util.my_warning(false, "[FEATURE_EXTRACT component] Class variable "..v.."cannot do log transform, remove it from the transformation variable list.")
      else 
        localTransVars[i] = v
        i = i + 1
        transformStatement = transformStatement.."if "..v..">0 then "..v.." = log("..v.."); else "..v.."= .;"
      end
    end
  end
  
  if util.check_value(localArgs.seasonDummy) and localArgs.seasonDummy then
    -- set the number of season to the seasonality if specified by user
    -- otherwise the number of season is indicated by the seasonalInterval
    local num_season
    if util.check_value(localArgs.seasonality) then num_season = tonumber(localArgs.seasonality)
    else
      fxRc = sas.submit([[
        data _NULL_;
          total_season = intseas('@interval@');
          call symputx('total_season',compress(total_season),'l');
        run;
      ]],{interval=localArgs.seasonalInterval})
      util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when computing the number of seasons, exit.")
      num_season = sas.symget('total_season')
    end
    
    seasonIdxStatement = "season_idx = intindex('"..localArgs.seasonalInterval.."',"..localArgs.idVar..","..num_season..");"
    
    -- add season_idx to model and class
    localModel = localModel.." season_idx"
    localClassVars = localClassVars.." season_idx"
    
    if util.check_value(localArgs.seasonAdjust) and localArgs.seasonAdjust then
      adjustmentFlag = true
      localAdjustVars[numAdjustVars + 1] = "season_idx"
      adjustClassVars[j2] = "season_idx"
      adjustClassFlag = true
      sas.symput("SEASON_IDX_ref", "")
    end
  end
  
  -- preprocess the input data to add seasonal dummies and do data transformation if specified
  if util.check_value(seasonIdxStatement) or util.check_value(transformStatement) then
    fxRc = sas.submit([[
      data @glmData@;
        set @inData@;
        @seasonIdxStatement@
        @transformStatement@
      run;
    ]],{inData=glmIndata, glmData=localArgs.processLib..".local_glm_indata", seasonIdxStatement=seasonIdxStatement, transformStatement=transformStatement})
    util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when preprocessing the input data, exit.")
    glmIndata = localArgs.processLib..".local_glm_indata"
  end
    
  -- prepare args for glm model
  local glmByStatement = ""
  if util.check_value(localArgs.glmByVars) then
    glmByStatement = "by "..localArgs.glmByVars
    fxRc = sas.submit([[
      proc sort data = @indata@;
        @byStatement@;
      run; 
    ]],{indata = glmIndata, byStatement = glmByStatement})
    util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when sorting the data "..glmIndata.."by "..localArgs.glmByVars..", exit.")
    
    glmIndata = glmIndata
  end
  
  local classStatement = ""
  if util.check_value(localClassVars) then
    classStatement = "class "..localClassVars
  end
  local codepath = ""
  codepath = sas.pathname(localArgs.processLib)
  codepath = '"'..codepath..'/glmScoreCode.sas'..'"'
  
  if adjustmentFlag then
    -- prepare sas statement to score data and compute corresponding adjustment    
    local setAdjustmentClause = ""  
    local glmArgs = {
                     codepath = codepath,
                     indata = glmIndata,
                     model = localModel,
                     include = glmInclude,
                     classStatement = classStatement,
                     byStatement = glmByStatement,
                     setPredictVarName = setPredictVarName,
                     glmOut = localArgs.processLib..".glm_out",
                     glmParam = "glm_param"}
  
    --run glmselect on the data
    fxRc = sas.submit([[
            
      ods listing close;
      ods html close;
      proc glmselect data = @indata@;
        @classStatement@;
        model @model@/ @include@;
        @byStatement@;
        code file = @codepath@;
        output out = @glmOut@ @setPredictVarName@;
        ods output parameterestimates=@glmParam@;
      run;
      ]], glmArgs)
    util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when calling Proc GLMSELECT, exit.")
    
    -- if there are class variables included in adjustment
    -- get the reference level for each class variable  
    if adjustClassFlag then
      local getClassRefClause = "effect = kupcase(effect);"
      local statement1 = "if findw(compress(effect), '@TOKEN@', '*', '') > 0 then call symputx('@TOKEN@_ref',@TOKEN@,'l');" 

      for _,v in pairs(adjustClassVars) do
        getClassRefClause = getClassRefClause.." "..statement1:gsub("@TOKEN@", v:upper())
      end
      
      -- get reference level(value) for each class variable
      fxRc = sas.submit([[
        data _NULL_;
          set @glmParam@;
          if df = 0;
          @getClassRefClause@
        run;]], {getClassRefClause = getClassRefClause, glmParam = "glm_param"})
      util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when acquiring reference level for class variables, exit.")
      
      for _,v in pairs(adjustClassVars) do
        local tempClassVar = string.upper(v).."_ref"
        local varType = util.check_vartype(glmIndata,v)
        if sas.symget(tempClassVar) ~= "" then
          if varType == 'N' then
            setAdjustmentClause = setAdjustmentClause..v..' = &'..tempClassVar..'; '
          else
            setAdjustmentClause = setAdjustmentClause..v..' = "&'..tempClassVar..'"; '
          end
        end
      end
    end
    
    -- for each variable considered for adjustment
    -- set interval variables to 0
    -- set class variables to reference level
    for _,v in pairs(adjustIntervalVars) do
      setAdjustmentClause = setAdjustmentClause..v.." = 0; "
    end
    
    -- score original data with variable values adjusted (see above)
    -- compute adjustment: adjustment = original_forecast - adjusted_forecast
    local scorePredict = "p_"..localArgs.depVar
    local outLib = ""
    local outAdjustName = ""
    local dropStatement = "drop="..localPredName.." adjusted_P"
    local depTransformStatement = ""
    if util.check_value(localArgs.glmByVars) then
      dropStatement = dropStatement.." _BY_"
    end
    if util.check_value(localArgs.seasonAdjust) and localArgs.seasonAdjust then
      dropStatement = dropStatement.." season_idx"
    end
    if depTransFlag then
      depTransformStatement = localArgs.depVar.." = exp("..localArgs.depVar..");"
      depTransformStatement = depTransformStatement..localPredName.." = exp("..localPredName..");"
      depTransformStatement = depTransformStatement.."adjustment = exp(adjustment);"
    end
    
    outLib,outAdjustName = util.get_libname_tablename(localArgs.outAdjustmentData)
    local adjustArgs = {codepath = codepath,
                        indata = glmIndata,
                        localPredName = localPredName,
                        idVar = localArgs.idVar,
                        scorePredict = scorePredict,
                        setAdjustmentClause = setAdjustmentClause,
                        byStatement = glmByStatement,
                        byVars = localArgs.byVars,
                        dropStatement = dropStatement,
                        class = localClassVars,
                        outAdjustmentData = localArgs.outAdjustmentData,
                        outLib = outLib,
                        outAdjustName = outAdjustName,
                        scoreDataV = localArgs.processLib..".score_data_v",
                        glmOutAdj = localArgs.processLib..".glm_out_adj",
                        glmOut = localArgs.processLib..".glm_out",
                        depTransformStatement = depTransformStatement
                        }
    
    fxRc = sas.submit([[
      data @scoreDataV@/view = @scoreDataV@;
        set @indata@;
        @setAdjustmentClause@;
        %include @codepath@;
        adjusted_P = @scorePredict@;
        drop @scorePredict@;
      run;
      
      data @glmOutAdj@;
         merge @glmOut@ @scoreDataV@;
         @byStatement@;
         adjustment = @localPredName@ - adjusted_P;
         @depTransformStatement@
      run;
      
      proc sort data = @glmOutAdj@ out = @outAdjustmentData@(@dropStatement@);
         by @byVars@ @idVar@;
      run;
      
      proc datasets lib = @outLib@ nowarn nolist nodetails;
         modify @outAdjustName@ (sortedby=@byVars@ @idVar@); 
      quit;
  
      ]], adjustArgs)
    util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when computing adjustment, exit.")
    
    -- call hpfengine to fill in missing for adjustment
    if localArgs.fillMissing then
      local forecast_hpfArgs = {}
      local forecast_args = {}
      forecast_hpfArgs.hpfSetmissing    = localArgs.setmissing
      forecast_hpfArgs.hpfZeromiss      = localArgs.zeromiss
      forecast_hpfArgs.hpfTrimmiss      = localArgs.trimmiss
      forecast_hpfArgs.hpfBack          = localArgs.hpfBack
      forecast_hpfArgs.hpfStart         = localArgs.hpfStart
      forecast_hpfArgs.hpfLead          = localArgs.hpfLead
      forecast_hpfArgs.hpfHorizonStart  = localArgs.hpfHorizonStart
      
      forecast_args.runDiag = nil
      forecast_args.inData = localArgs.outAdjustmentData
      forecast_args.fcstVar = "adjustment"
      forecast_args.idVar = localArgs.idVar
      forecast_args.interval = localArgs.idInterval
      forecast_args.outFor = localArgs.processLib.."._adjustment_smoothed"
      forecast_args.byVars = localArgs.byVars
      forecast_args.acc = localArgs.aggDep
      forecast_args.format = localArgs.format
      forecast_args.sign = localArgs.sign
      forecast_args.globalSelection = "exmselect"
      forecast_args.externalStatement = "external adjustment"
      forecast_args.processLib = localArgs.processLib
      forecast_args.replaceMissingFcst = localArgs.replaceMissingFcst
      print("[FEATURE_EXTRACT component] Call HPFENGINE to fill in missing for adjustment...")
      forecast_pack.run_hpf(forecast_args, forecast_hpfArgs)
      
      -- merge smoothed adjustment table back with localArgs.outAdjustmentData
      fxRc = sas.submit([[
        data @outAdjustmentData@;
          merge @outAdjustmentData@ @smoothedAdjustment@(keep = @byVars@ @idVar@ predict);
          by @byVars@ @idVar@;
          if missing(adjustment) then adjustment = predict;
          drop predict;
        run;          
      ]],{outAdjustmentData = localArgs.outAdjustmentData, 
          smoothedAdjustment = localArgs.processLib.."._adjustment_smoothed", 
          byVars = localArgs.byVars,
          idVar = localArgs.idVar}); 
    end
    
  -- end if adjustmentFlag == 1
  else
         
    local glmArgs = {indata = glmIndata,
                     byStatement = glmByStatement,
                     include = glmInclude,
                     setPredictVarName = setPredictVarName,
                     model = localModel,
                     classStatement = classStatement,
                     glmOut = localArgs.processLib..".glm_out"}
    
    --run glmselect on the data
    fxRc = sas.submit([[
      ods listing close;
      ods html close;
      proc glmselect data = @indata@ noprint;
        @classStatement@;
        model @model@ / @include@;
        @byStatement@;
        output out = @glmOut@ @setPredictVarName@;
      run;
      ]],glmArgs)
    util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when calling proc GLMSELECT, exit.")
    
    local setHistoryDate = ""
    if util.check_value(localArgs.hpfHorizonStart) then
      setHistoryDate = "and "..localArgs.idVar.." < "..localArgs.hpfHorizonStart
    end
    
    if depTransFlag then 
      fxRc = sas.submit([[
        data @glmOut@;
          set @glmOut@;
          @predict@ = exp(@predict@);
          if missing(@depVar@) @setHistoryDate@ then do; 
            @predict@ = 0;
          end;
          @depVar@ = orig_depVar;
          drop orig_depVar;
        run;
      ]],{depVar = localArgs.depVar, setHistoryDate = setHistoryDate, predict = localPredName,glmOut = localArgs.processLib..".glm_out"})
      util.my_assert(fxRc <= 4, "[FEATURE_EXTRACT component] Error occurred when transforming variables, exit.")
    end
    
    local externalStatement = ""
    if util.check_value(localArgs.predictVarName) then
      externalStatement = "external "..localArgs.predictVarName
    else
      externalStatement = "external "..localPredName
    end
    
    local forecast_hpfArgs = {}
    local forecast_args = {}
    forecast_hpfArgs.hpfSetmissing    = localArgs.setmissing
    forecast_hpfArgs.hpfZeromiss      = localArgs.zeromiss
    forecast_hpfArgs.hpfTrimmiss      = localArgs.trimmiss
    forecast_hpfArgs.hpfBack          = localArgs.hpfBack
    forecast_hpfArgs.hpfStart         = localArgs.hpfStart
    forecast_hpfArgs.hpfLead          = localArgs.hpfLead
    forecast_hpfArgs.hpfHorizonStart  = localArgs.hpfHorizonStart
    
    forecast_args.runDiag = nil
    forecast_args.inData = localArgs.processLib..".glm_out"
    forecast_args.fcstVar = localArgs.depVar
    forecast_args.idVar = localArgs.idVar
    forecast_args.interval = localArgs.idInterval
    forecast_args.outFor = localArgs.outFor
    forecast_args.byVars = localArgs.byVars
    forecast_args.acc = localArgs.aggDep
    forecast_args.format = localArgs.format
    forecast_args.sign = localArgs.sign
    forecast_args.globalSelection = "exmselect"
    forecast_args.externalStatement = externalStatement
    forecast_args.processLib = localArgs.processLib
    forecast_args.replaceMissingFcst = localArgs.replaceMissingFcst
    forecast_args.overrideFor = localArgs.processLib..".glm_out"
    forecast_args.overrideVar = "predict"
    print("[FEATURE_EXTRACT component] Call HPFENGINE to generate forecast from GLM results...")
    forecast_pack.run_hpf(forecast_args, forecast_hpfArgs)
  end
  return fxRc  
end

return{feature_extract=feature_extract}
