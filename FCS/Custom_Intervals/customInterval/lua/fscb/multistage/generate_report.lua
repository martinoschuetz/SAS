-- load reconcile package
-- load forecast package
local forecast_pack = require("fscb.multistage.forecast")
local reconcile = require("fscb.multistage.reconcile")
local post = require("fscb.multistage.post_process")
local util = require("fscb.common.util")

local function validate_rpt_args(args)
  local rptArgs = {}
  local rc = 0
  
  if not util.check_value(args.rptOut) then
    rc = 1  -- no output table specified, skip the generate_report process
    return rc, rptArgs
  end
  
  -- check required input arguments
  util.my_assert(util.check_value(args.lowInData), "[REPORTING component] Low level input data is not specified")
  util.my_assert(util.check_value(args.fcstInData), "[REPORTING component] Forecast input data is not specified")
  util.my_assert(util.check_value(args.depVar), "[REPORTING component] No dependent variable specified")
  util.my_assert(util.check_value(args.idVar), "[REPORTING component] No variable specified for time ID")
  util.my_assert(util.check_value(args.idInterval), "[REPORTING component] Time ID interval is not specified")
  util.my_assert(util.check_value(args.byVars), "[REPORTING component] No by variables specified")

  local hierComponent = util.split_string(args.byVars)
  local numOfAggregation = #hierComponent
  rptArgs.rptOut = {}
  for i = 1, numOfAggregation do
    rptArgs.rptOut[i] = {}
    if util.check_value(args.rptOut[i]) then
      rptArgs.rptOut[i].rptOutFor = args.rptOut[i].rptOutFor
      rptArgs.rptOut[i].rptOutStat = args.rptOut[i].rptOutStat
      rptArgs.rptOut[i].rptOutSum = args.rptOut[i].rptOutSum
    end
  end
    
  rptArgs.lowInData = args.lowInData
  rptArgs.fcstInData = args.fcstInData
  
  if not util.check_value(args.replaceMissingFcst) then
    rptArgs.replaceMissingFcst = false
  else
    rptArgs.replaceMissingFcst = args.replaceMissingFcst
  end
  
  rptArgs.depVar = args.depVar
  rptArgs.idVar = args.idVar
  rptArgs.idInterval = args.idInterval
  rptArgs.rptOut = args.rptOut
  rptArgs.byVars = args.byVars
  if not util.check_value(args.modelHierVars) then
     rptArgs.modelHierVars = rptArgs.byVars
     util.my_warning(false, "[REPORTING component] modelHierVars is not specified, using project byVars as modelHierVars")
  else
    rptArgs.modelHierVars = args.modelHierVars
  end
   
  rptArgs.setmissing = util.check_value(args.setmissing) and args.setmissing or "MISSING"
  rptArgs.zeromiss = util.check_value(args.zeromiss) and args.zeromiss or "NONE"
  rptArgs.sign = util.check_value(args.sign) and args.sign or "NONNEGATIVE"
  rptArgs.aggDep = util.check_value(args.aggDep) and args.aggDep or "TOTAL"
  rptArgs.trimmiss = args.trimmiss
  rptArgs.hpfBack = args.hpfBack
  rptArgs.hpfStart = args.hpfStart
  rptArgs.hpfEnd = args.hpfEnd
  rptArgs.hpfLead = args.hpfLead
  rptArgs.hpfHorizonStart = args.hpfHorizonStart
  rptArgs.format = args.format
  rptArgs.processLib = "WORK"
  if util.check_value(args.processLib) then
    if sas.libref(args.processLib)==0 then
      rptArgs.processLib = args.processLib
    else
      util.my_warning(false, "[REPORTING component] The given processLib"..args.processLib.." does not exist, use work as processLib.")
    end
  end
   
  return rc, rptArgs
end

--[[
NAME:           generate_report

DESCRIPTION:    function to generate report for all levels in the hiearchy
                
INPUTS:         args
                  lowInData
                  fcstInData
                  depVar
                  idVar
                  idInterval
                  aggDep
                  byVars
                  modelHierVars
                  processLib
                  
                optional:
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
                  replaceMissingFcst
   
                                                                             
OUTPUTS:        args
                  rptOut[i]
                    rptOutFor
                    rptOutStat
                    rptOutSum
USAGE:          
                
]]

function generate_report(args)
  
  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO GENERATE_REPORT:********"
    local s=table.tostring(args)
    if util.check_value(debugFile) then
      util.dump_to_file(r, debugFile)
      local a = "args="..string.gsub(s, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
    else 
      print(r.."\n")
      print("args=", s)                    
    end
  end 
  
  local rptRc = 0
  local localArgs = {}
  rptRc, localArgs = validate_rpt_args(args)
  util.my_assert(rptRc >= 0, "[REPORTING component] No output tables specified for GENERATE_REPORT, exit the process.")
  
  local hierComponent = util.split_string(localArgs.byVars)
  local numOfAggregation = #hierComponent
  local lowFcstData = localArgs.fcstInData
  local forecast_hpfArgs={}
  local levelByVars = ""
  forecast_hpfArgs.hpfSetmissing    = localArgs.setmissing
  forecast_hpfArgs.hpfZeromiss      = localArgs.zeromiss
  forecast_hpfArgs.hpfTrimmiss      = localArgs.trimmiss
  forecast_hpfArgs.hpfBack          = localArgs.hpfBack
  forecast_hpfArgs.hpfStart         = localArgs.hpfStart
  forecast_hpfArgs.hpfLead          = localArgs.hpfLead
  forecast_hpfArgs.hpfHorizonStart  = localArgs.hpfHorizonStart
      
  -- disaggregate FcstInData down to lowest hierarchy level first
  if localArgs.modelHierVars ~= localArgs.byVars then
  
    -- check if model hierarchy and project hierarchy have the same number of nodes at low level
    local modelByVarsComma = util.get_delim_string(localArgs.modelHierVars, ",")
    local byVarsComma      = util.get_delim_string(localArgs.byVars, ",")
    local byVarsTbl        = util.split_string(localArgs.byVars)
    local commonVars       = ""
    local newByVarsOrder   = ""
    for i=1, #byVarsTbl do
      if util.check_sub_string(localArgs.modelHierVars, byVarsTbl[i]) then
        commonVars = commonVars.." "..byVarsTbl[i]
      else
        newByVarsOrder = newByVarsOrder.." "..byVarsTbl[i]
      end
    end
    newByVarsOrder = commonVars..newByVarsOrder
    local commonVarsComma  = util.get_delim_string(commonVars, ",")
      
    rptRc = sas.submit([[
      proc sql noprint;
        create table @distinctModelNodes@ as
        select distinct @modelByVars@
        from @modelTable@;
        
        create table @distinctProjNodes@ as
        select distinct @projByVars@
        from @projTable@;
      quit;
      
      data _NULL_;
        set @modelTable@ end = last;
        if last then call symputx('modelNodes', compress(_N_), 'l');
      run;
      
      data _NULL_;
        set @projTable@ end = last;
        if last then call symputx('projNodes', compress(_N_), 'l');
      run;
    ]], {distinctModelNodes = localArgs.processLib.."._dist_modelNodes", modelByVars = modelByVarsComma, modelTable = localArgs.fcstInData, 
         distinctProjNodes = localArgs.processLib.."._dist_projNodes", projByVars = byVarsComma, projTable = localArgs.lowInData}
    )
    util.my_assert(rptRc<=4, "[REPORTING component] ERROR occurred when checking if modeling hierarchy and project hierarchy agree at the lowest level, exit.")
    
    local numModelNodes = sas.symget("modelNodes")
    local numProjNodes = sas.symget("projNodes")
    if numModelNodes < numProjNodes then
      -- Modeling hierarchy has less low level nodes than project hierarchy, reconcile forecast to lowest level
      print("[REPORTING component] Modeling hierarchy has less low level nodes than project hierarchy, reconcile forecast to lowest level.")
      
      local lowInData = localArgs.processLib.."._sortedLowInData"
      local sortedByVars = newByVarsOrder.." "..localArgs.idVar
      rptRc = sas.submit([[
        proc sort data=@origLowInData@ out=@lowInData@; by @sortedByVars@; run;
        proc datasets lib = @outLib@ nowarn nolist nodetails;
           modify @outTable@ (sortedby=@sortedByVars@); 
        quit;
        ]],{origLowInData = localArgs.lowInData, lowInData=lowInData, sortedByVars=sortedByVars, 
            outLib=localArgs.processLib, outTable="_sortedLowInData"})
      util.my_assert(rptRc<=4, "[REPORTING component] ERROR occurred sorting the data "..localArgs.lowInData..", exit.")
    
      -- generate low level forecast using hpfengine
      local forecast_args = {}
      
      forecast_args.runDiag = nil
      forecast_args.inData = lowInData
      forecast_args.fcstVar = localArgs.depVar
      forecast_args.idVar = localArgs.idVar
      forecast_args.interval = localArgs.idInterval
      forecast_args.outFor = localArgs.processLib..".lowFcst"
      forecast_args.byVars = newByVarsOrder
      forecast_args.acc = localArgs.aggDep
      forecast_args.format = localArgs.format
      forecast_args.sign = localArgs.sign
      forecast_args.processLib = localArgs.processLib
      forecast_args.replaceMissingFcst = localArgs.replaceMissingFcst
      forecast_pack.run_hpf(forecast_args, forecast_hpfArgs)
      
      -- reconcile fcstInData to lowest level
      local recArgs={}
      recArgs.disaggData = forecast_args.outFor
      recArgs.aggData = localArgs.fcstInData
      recArgs.outFor = localArgs.processLib..".lowRecFcst"
      recArgs.byVars = newByVarsOrder
      recArgs.direction = "td"
      recArgs.aggregateOption = localArgs.aggDep
      local rArgs = {}
      rArgs.idVar = localArgs.idVar
      rArgs.idInterval = localArgs.idInterval
      rArgs.dateFormat = localArgs.format
      reconcile.reconcile_submit(rArgs, recArgs) 
      
      lowFcstData = recArgs.outFor
      
      -- sort the lowFcstData in correct order
      rptRc = sas.submit([[
        proc sort data = @lowFcstData@;
          by @byVars@ @idVar@;
        run;
      ]],{lowFcstData = lowFcstData, byVars = localArgs.byVars, idVar = localArgs.idVar}
      )
      util.my_assert(rptRc<=4, "[REPORTING component] ERROR occurred sorting the data "..lowFcstData..", exit.")
    -- end of generating project low level reconciled forecast
    else
      -- merge fcstInData with project hierarchy to make sure it contains all project by vars    
      rc = sas.submit([[
        proc sql noprint;
          create table @tmpTbl@ as
          select distinct @commaByVars@
          from @inData@
          order by @commaCommonVars@;
        quit;
        proc sort data=@inFcst@; by @commonVars@; run;
        data @lowFcstMerged@;
          merge @inFcst@(in=in1)
                @tmpTbl@;
          by @commonVars@;
          if in1;
        run;
      ]],{tmpTbl=localArgs.processLib.."._distRecOutFor", commaByVars=byVarsComma, inData=localArgs.lowInData,
          commaCommonVars=commonVarsComma, inFcst=localArgs.fcstInData, commonVars=commonVars,
          lowFcstMerged = localArgs.processLib.."._lowRecMerged"})
      util.my_assert(rc<4, "ERROR occurred when preparing the low level forecast data "..localArgs.fcstInData..", exit.")
      lowFcstData = localArgs.processLib.."._lowRecMerged" 
    end
  end -- end of modelHierVars ~= byVars
  
  local lowInData = localArgs.processLib.."._sortedLowInData"
  local sortedByVars = localArgs.idVar
  rptRc = sas.submit([[
    proc sort data=@origLowInData@ out=@lowInData@; by @sortedByVars@; run;
    proc datasets lib = @outLib@ nowarn nolist nodetails;
       modify @outTable@ (sortedby=@sortedByVars@); 
    quit;
    ]],{origLowInData = localArgs.lowInData, lowInData=lowInData, sortedByVars=sortedByVars, 
        outLib=localArgs.processLib, outTable="_sortedLowInData"})
  util.my_assert(rptRc<=4, "[REPORTING component] ERROR occurred sorting the data "..localArgs.lowInData..", exit.")
  
  for i = 0, numOfAggregation - 1 do
    
    -- call hpfengine    
    local forecast_args = {}
    if i > 0 then
      levelByVars = levelByVars.." "..hierComponent[i]
    end
    forecast_args.runDiag = nil
    forecast_args.inData = lowInData
    forecast_args.fcstVar = localArgs.depVar
    forecast_args.idVar = localArgs.idVar
    forecast_args.interval = localArgs.idInterval
    forecast_args.outFor = localArgs.processLib..".aggdata_fcst"
    forecast_args.byVars = levelByVars
    forecast_args.acc = localArgs.aggDep
    forecast_args.format = localArgs.format
    forecast_args.sign = localArgs.sign
    forecast_args.processLib = localArgs.processLib
    forecast_args.replaceMissingFcst = localArgs.replaceMissingFcst
    forecast_pack.run_hpf(forecast_args, forecast_hpfArgs)
    
    -- call reconcile
    local recArgs={}
    recArgs.disaggData = lowFcstData
    recArgs.aggData = localArgs.processLib..".aggdata_fcst"
    recArgs.outFor = localArgs.processLib..".recfor"
    recArgs.byVars = localArgs.byVars
    recArgs.direction = "bu"
    recArgs.aggregateOption = localArgs.aggDep
    local rArgs = {}
    rArgs.idVar = localArgs.idVar
    rArgs.idInterval = localArgs.idInterval
    rArgs.dateFormat = localArgs.format
    reconcile.reconcile_submit(rArgs, recArgs) 
    
    -- call hpfengine again to generate summary statistics
    local rpt_args = forecast_args
    rpt_args.inData = localArgs.processLib..".recfor"
    rpt_args.fcstVar = "actual"
    rpt_args.outFor = localArgs.rptOut[i].rptOutFor
    rpt_args.outStat = localArgs.rptOut[i].rptOutStat
    rpt_args.outSum = localArgs.rptOut[i].rptOutSum
    rpt_args.globalSelection = "exmselect"
    rpt_args.externalStatement = "external predict std upper lower"
    rpt_args.acc = localArgs.aggDep
    rpt_args.format = localArgs.format
    rpt_args.sign = localArgs.sign
    rpt_args.processLib = localArgs.processLib
    forecast_pack.run_hpf(rpt_args, forecast_hpfArgs)

    if util.check_value(levelByVars) then 
      util.create_index_for_table(rpt_args.outFor, levelByVars)
      util.create_index_for_table(rpt_args.outStat, levelByVars)
      util.create_index_for_table(rpt_args.outSum, levelByVars)
    end
  
  end
  
  -- call hpfengine to generate summary statistics for low level
  local rpt_args = {}
  rpt_args.runDiag = nil
  rpt_args.inData = lowFcstData
  rpt_args.fcstVar = "actual"   -- hard-coded to actual
  rpt_args.idVar = localArgs.idVar
  rpt_args.interval = localArgs.idInterval
  rpt_args.byVars = localArgs.byVars
  rpt_args.outFor = localArgs.rptOut[numOfAggregation].rptOutFor
  rpt_args.outStat = localArgs.rptOut[numOfAggregation].rptOutStat
  rpt_args.outSum = localArgs.rptOut[numOfAggregation].rptOutSum
  rpt_args.globalSelection = "exmselect"
  rpt_args.externalStatement = "external predict std upper lower"
  rpt_args.acc = localArgs.aggDep
  rpt_args.format = localArgs.format
  rpt_args.sign = localArgs.sign
  rpt_args.processLib = localArgs.processLib
  forecast_pack.run_hpf(rpt_args, forecast_hpfArgs)  
  
  if util.check_value(rpt_args.byVars) then 
    util.create_index_for_table(rpt_args.outFor, rpt_args.byVars)
    util.create_index_for_table(rpt_args.outStat, rpt_args.byVars)
    util.create_index_for_table(rpt_args.outSum, rpt_args.byVars)
  end
end

return{generate_report=generate_report}
