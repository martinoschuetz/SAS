local util=require("fscb.common.util")

--[[
NAME:           hierarchy_info

DESCRIPTION:    function to provide hierarchical by vars info, set default table names for each level
                
INPUTS:         hierarchy  -- byvars
                processLib                                

OUTPUTS:        hierarchyInfo
                  level
                  dataName                 
                  adjustmentDataName
                  baseName
                  modelRepository
                  outFor
                  outForReconcile
                  rptOutFor
                  rptOutStat
                  rptOutSum
USAGE:          
                
]]
function hierarchy_info(processLib, hierarchy)

  local lib = util.check_value(processLib) and processLib or "work"
  
  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO HIERARCHY_INFO:********"
    local s=table.tostring(hierarchy)
    if util.check_value(debugFile) then
      util.dump_to_file(r, debugFile)
      local a = "hierarchy="..string.gsub(s, '00000000.-=', '')
      util.dump_to_file(a, debugFile)
    else 
      print(r.."\n")
      print("hierarchy=", s)                    
    end
  end 
  
  if not hierarchy then
    return nil
  end
  local t = {}
  local i = 0
  for i = 0, #hierarchy do
    t[i] = {}
    if i == 0 then
      t[i].levelName = "_ALL_"
      t[i].byVars = ""
    end
    t[i].level = i
    t[i].dataName = lib..".agg_"..i
    t[i].adjustmentDataName = lib..".agg_"..i.."_adj"
    t[i].outFor = lib..".agg_"..i.."_outfor"
    t[i].outForReconcile = lib..".agg_"..i.."_recfor"
    t[i].rptOutFor = lib..".agg_"..i.."_rpt_outfor"
    t[i].rptOutStat = lib..".agg_"..i.."_rpt_outstat"
    t[i].rptOutSum = lib..".agg_"..i.."_rpt_outsum"
  end

  local hierByVars = ""
  for i,v in ipairs(hierarchy) do
    if i == 1 then 
      hierByVars = v
    else 
      hierByVars = hierByVars.." "..v
    end
    t[i].levelName = v
    t[i].byVars = hierByVars
  end
  return t
end

--[[
function to validate args
]]
local function validate_dataprep_args(args)
  local dpArgs = {}
  
  -- validate args
  util.my_assert(args, "[DATA_PREP component] No arguments specified")
  util.my_assert(args.inData, "[DATA_PREP component] No input data specified")
  util.my_assert(args.byVars, "[DATA_PREP component] No BY variables specified")
  util.my_assert(args.depVar, "[DATA_PREP component] No dependent variable specified")
  util.my_assert(args.idVar, "[DATA_PREP component] No ID var specified")
  util.my_assert(args.idInterval, "[DATA_PREP component] No ID INTERVAL specified")
  
  dpArgs.inData = args.inData
  dpArgs.byVars = args.byVars
  dpArgs.depVar = args.depVar
  dpArgs.idVar = args.idVar
  dpArgs.idInterval = args.idInterval
  dpArgs.setmissing = util.check_value(args.setmissing) and args.setmissing or "MISSING"
  dpArgs.zeromiss = util.check_value(args.zeromiss) and args.zeromiss or "NONE"
  dpArgs.aggDep = util.check_value(args.aggDep) and args.aggDep or "TOTAL"
  dpArgs.processLib = "WORK"
  dpArgs.start = args.start
  dpArgs.horizonStart= args.horizonStart
  if util.check_value(args.processLib) then
    if sas.libref(args.processLib)==0 then
      dpArgs.processLib = args.processLib
    else
      util.my_warning("[DATA_PREP component] The given processLib"..args.processLib.." does not exist, use work as processLib.")
    end
  end 
  
  local all_matched
  local match
  local unmatch
  -- check required input variable in the data
  all_matched, match, unmatch = util.invar_check(dpArgs.inData, dpArgs.depVar)
  util.my_assert(all_matched, "[DATA_PREP component] The depdent variable ".. dpArgs.depVar.." does not exist in data, exit."..dpArgs.inData..", exit.")
  
  all_matched, match, unmatch = util.invar_check(dpArgs.inData, dpArgs.idVar)
  util.my_assert(all_matched, "[DATA_PREP component] The id variable ".. dpArgs.idVar.." does not exist in data, exit."..dpArgs.inData..", exit.")
  if util.check_value(dpArgs.byVars) then
    all_matched, match, unmatch = util.invar_check(dpArgs.inData, dpArgs.byVars)
    if util.check_value(unmatch) then
      util.my_assert(all_matched, "[DATA_PREP component] The by variables ".. unmatch.." does not exist in data "..dpArgs.inData..", exit.")
    end
  end 
  if util.check_value(args.indVars) then
    dpArgs.indVars = {}
    local numIndVars = #args.indVars
    local indString = ""
    for i = 1, numIndVars do
      all_matched, match, unmatch = util.invar_check(args.inData, args.indVars[i].name)
      util.my_assert(all_matched, "[DATA_PREP component] The independent variable ".. args.indVars[i].name.." does not exist in data "..args.inData..", exit.")
      dpArgs.indVars[i] = {}
      dpArgs.indVars[i].name = args.indVars[i].name
      dpArgs.indVars[i].setmissing = util.check_value(args.indVars[i].setmissing) and args.indVars[i].setmissing or "MISSING"
      dpArgs.indVars[i].zeromiss = util.check_value(args.indVars[i].zeromiss) and args.indVars[i].zeromiss or "NONE"
      dpArgs.indVars[i].indepHierAgg = util.check_value(args.indVars[i].indepHierAgg) and args.indVars[i].indepHierAgg or "TOTAL"
      i = i + 1
    end
  end
  
  return dpArgs
end

--[[
NAME:           build_hierarchy

DESCRIPTION:    function to sort the indata of the given by variables and build the aggregated data using proc timedata
                
INPUTS:         args
                  inData
                  processLib
                  byVars
                  depVar
                  indVars[i]
                  {
                    name
                    setmissing
                    zeromiss
                    indepHierAgg
                  }
                  idVar
                  idInterval
                  setmissing
                  zeromiss
                  aggDep  
                  start
                  horizonStart                              

OUTPUTS:        hierarchyInfo
                  dataName                 

USAGE:          
                
]]

function build_hierarchy(args)
  local prepRc = 0
  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO BUILD_HIERARCHY:********"
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

  validate_dataprep_args(args)
  
  local localArgs = {}
  localArgs = validate_dataprep_args(args)

  --first need to get the by variables from the arg
  local hierarchy = localArgs.byVars

  --split the byVars into a table 
  local hierComponent = util.split_string(hierarchy)
  local numOfAggregation = #hierComponent

  local hierarchyInfo = hierarchy_info(localArgs.processLib, hierComponent)
  local localIndataSorted = localArgs.processLib .."._indata_sorted"

  --generate the PROC SORT statement to sort data according to the
  --localArgs.byVars 
  prepRc = sas.submit([[
    proc sort data = @indata@ out = @outdata@;
      by @hierarchy@;
    run;]],
    {indata = localArgs.inData, hierarchy = hierarchy, outdata = localIndataSorted})
  util.my_assert(prepRc <= 4, "[DATA_PREP component] Error occurred when sorting input data in BUILD_HIERARCHY, exit.")
  
  --generate the PROC TIMEDATA statement
  local byStatement = ""
  for i = 0, numOfAggregation do
    local sortedByVars =""
    if i > 0 then
      byStatement  = "by "..hierarchyInfo[i].byVars
      sortedByVars = hierarchyInfo[i].byVars
    end
    sortedByVars = util.add_to_string(sortedByVars, localArgs.idVar)
    local startStatement = util.check_value(localArgs.start) and "start="..localArgs.start or ""
    
    sas.submit_([[
      proc timedata data = @indata@ out = @outdata@;
        @byStatement@;
        id @idVar@ interval = @idInterval@ @startStatement@ notsorted;
        var @depVar@ / accumulate = @aggDep@ setmiss = @setmissing@ zeromiss = @zeromiss@;
      ]],
      {indata = localIndataSorted, byStatement = byStatement, outdata = hierarchyInfo[i].dataName,
       depVar = localArgs.depVar, idVar = localArgs.idVar, idInterval = localArgs.idInterval, startStatement = startStatement,
       aggDep = localArgs.aggDep, setmissing = localArgs.setmissing, zeromiss = localArgs.zeromiss})
       
    if util.check_value(localArgs.indVars) then
      for s, v in pairs(localArgs.indVars) do
        sas.submit_([[
            var @indVar@ / accumulate = @aggInd@ setmiss = @setmissing@ zeromiss = @zeromiss@;
          ]],
          {indVar = v.name, aggInd = v.indepHierAgg, setmissing = v.setmissing, zeromiss = v.zeromiss})
      end
    end
    prepRc = sas.submit([[run;]])
    util.my_assert(prepRc <= 4, "[DATA_PREP component] Error occurred when calling proc TIMEDATA to aggregate data in BUILD_HIERARCHY, exit.")
    
    if util.check_value(localArgs.horizonStart) then
      sas.submit([[
        data @outdata@;
          set @outdata@;
          if @idVar@>=@horizonStart@ then @depVar@=.;
        run;
      ]],
      {outdata = hierarchyInfo[i].dataName, idVar = localArgs.idVar, horizonStart=localArgs.horizonStart, depVar = localArgs.depVar})
    end
  
    local outLib = ""
    local outTable = ""
    outLib,outTable = util.get_libname_tablename(hierarchyInfo[i].dataName)
    prepRc = sas.submit([[
      proc datasets lib = @outLib@ nowarn nolist nodetails;
         modify @outTable@ (sortedby=@sortedByVars@); 
      quit;
      ]])
    util.my_assert(prepRc <= 4, "[DATA_PREP component] Error occurred when writing sorted by information for table "..hierarchyInfo[i].dataName..", exit.")
  
  end
  
  return hierarchyInfo
end

return{build_hierarchy=build_hierarchy}
