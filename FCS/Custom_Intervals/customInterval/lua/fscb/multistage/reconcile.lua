local util=require("fscb.common.util")

--[[
validate input args for reconcile
set argument defaults for reconcile
]]
local function validate_rec_args(args, recArgs)
  local localArgs = {}
  -- check required input arguments
  util.my_assert(util.check_value(recArgs.aggData), "[RECONCILE component] Agg data is not specified")
  util.my_assert(util.check_value(recArgs.disaggData), "[RECONCILE component] Disagg data is not specified")
  util.my_assert(util.check_value(args.idVar), "[RECONCILE component] No variable specified for time ID")
  util.my_assert(util.check_value(args.idInterval), "[RECONCILE component] Time ID interval is not specified")
  util.my_assert(util.check_value(recArgs.outFor), "[RECONCILE component] outFor table is not specified")
  
  localArgs.aggData = recArgs.aggData
  localArgs.disaggData = recArgs.disaggData
  localArgs.idVar = args.idVar
  localArgs.idInterval = args.idInterval
  localArgs.dateFormat = args.dateFormat
  localArgs.byVars = recArgs.byVars
  localArgs.outFor = recArgs.outFor
  
  localArgs.direction = util.check_value(recArgs.direction) and recArgs.direction or "TD"
  localArgs.disaggOption = util.check_value(recArgs.disaggOption) and recArgs.disaggOption or "PROPORTIONS"
  localArgs.aggregateOption = util.check_value(recArgs.aggregateOption) and recArgs.aggregateOption or "TOTAL"
  localArgs.clmethodOption = util.check_value(recArgs.clmethodOption) and recArgs.clmethodOption or "SHIFT"
  localArgs.sign = util.check_value(recArgs.sign) and recArgs.sign or "NONNEGATIVE"
  
  return localArgs
end

--[[
NAME:           reconcile_submit

DESCRIPTION:    function to do reconciliation
                
INPUTS:         args
                  idVar
                  idInterval
                  dateFormat
                recArgs
                  aggData
                  disaggData
                  byVars
                  direction
                  sign
                  disaggOption
                  aggregateOption
                  clmethodOption                                                              

OUTPUTS:        recArgs
                  outFor

USAGE:          
                
]]
function reconcile_submit(args, recArgs)
  local recRc = 0
  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO RECONCILE_SUBMIT:********"
    local s=table.tostring(recArgs)
    local t=table.tostring(args)
    if util.check_value(debugFile) then
      util.dump_to_file(r, debugFile)
      local a = "args="..string.gsub(t, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
      local a = "recArgs="..string.gsub(s, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
    else 
      print(r.."\n")
      print("args=", t)
      print("recArgs=", s)                    
    end
  end

  local localArgs = {}
  localArgs = validate_rec_args(args, recArgs)

  local byStatement
  local sortedByVars
  if localArgs.byVars == "" then
    byStatement = ""
    sortedByVars = localArgs.idVar
  else
    byStatement = "by "..localArgs.byVars
    sortedByVars = localArgs.byVars.." "..localArgs.idVar
    recRc = sas.submit([[
      proc sort data=@disaggdata@; by @sortedByVars@; run;
      ]],{disaggdata = localArgs.disaggData, sortedByVars=sortedByVars})
    util.my_assert(recRc<=4, "[RECONCILE component] ERROR occurred sorting the input data, exit.")
  
  end
  
  local dateFormatStatement = util.check_value(localArgs.dateFormat) and "format="..localArgs.dateFormat or ""
  local directionStatement = util.check_value(localArgs.direction) and "direction="..localArgs.direction or ""
    
  -- prepare args for PROC HPFRECONCILE
  local reconcileArgs = {disaggdata = localArgs.disaggData, aggdata = localArgs.aggData, outfor = localArgs.outFor, directionStatement = directionStatement,
                         sign = localArgs.sign, disaggOption = localArgs.disaggOption, aggregateOption = localArgs.aggregateOption, clmethodOption = localArgs.clmethodOption,
                         id_var = localArgs.idVar,
                         id_interval = localArgs.idInterval, dateFormatStatement=dateFormatStatement, byStatement=byStatement}
  
  -- generate the PROC HPFRECONCILE statement
  recRc = sas.submit([[
    proc hpfreconcile disaggdata=@disaggdata@ aggdata=@aggdata@
                  outfor=@outfor@
                  @directionStatement@
      sign=@sign@ disaggregation=@disaggOption@ aggregate=@aggregateOption@
      clmethod=@clmethodOption@ forceconstraint;
      id @id_var@ interval=@id_interval@ @dateFormatStatement@;
      @byStatement@;
    run;]],reconcileArgs,nil,4)
    
  util.my_assert(recRc<=4, "[RECONCILE component] ERROR occurred calling hpfreconcile, exit.")

  
  return recRc
end

return{reconcile_submit = reconcile_submit}
