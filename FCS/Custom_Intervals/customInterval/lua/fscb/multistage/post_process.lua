local util = require("fscb.common.util")


--[[
NAME:           override_missing

DESCRIPTION:    function to override missing forecast values, either use the specified input data,
                or use the historical average
                
INPUTS:         args 
                  inFor
                  overrideFor
                  outFor
                  byVars
                  timeID
                  depVar
                  fcstVar
                  overrideVar
                  processLib                             

OUTPUTS:        outFor
USAGE:          
                
]]
function override_missing(args)

  local all_matched
  local match
  local unmatch
  local rc
  
  -- print out input arguments if in debug
  local tdebug = sas.symget("DEBUG")
  local debug = 0
  local debugFile = sas.symget("DEBUG_FILE")
  if util.check_value(tdebug) then
    debug = tonumber(tdebug)
  end
  if debug == 1 then 
    local r="********INPUT ARGUMENT VALUE INTO POST_PROCESS:********"
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
  
  --validate input arguments
  util.my_assert(util.check_value(args.inFor), 
                 "[POST_PROCESS component] The input data inFor is not specified")
  util.my_assert(sas.exists(args.inFor), 
                 "[POST_PROCESS component] The input data inFor".. args.inFor .." does not exist")
  util.my_assert(util.check_value(args.outFor), 
                 "[POST_PROCESS component] The output data name outFor is not specified") 
  util.my_assert(util.check_value(args.timeID), 
                 "[POST_PROCESS component] The timeID name is not specified")
  util.my_assert(util.check_value(args.depVar), 
                 "[POST_PROCESS component] The dependent variable name depVar is not specified")
  util.my_assert(util.check_value(args.fcstVar), 
                 "[POST_PROCESS component] The forecast variable name fcstVar is not specified")
                 
  all_matched, match, unmatch = util.invar_check(args.inFor, args.timeID)
  util.my_assert(all_matched, "[POST_PROCESS component] The time ID variable ".. 
                               args.timeID.." does not exist in data "..args.inFor)
  all_matched, match, unmatch = util.invar_check(args.inFor, args.depVar)
  util.my_assert(all_matched, "[POST_PROCESS component] The dependent variable ".. 
                               args.depVar.." does not exist in data "..args.inFor)
  all_matched, match, unmatch = util.invar_check(args.inFor, args.fcstVar)
  util.my_assert(all_matched, "[POST_PROCESS component] The forecast variable ".. 
                               args.fcstVar.." does not exist in data "..args.inFor)                               
  if util.check_value(args.byVars) then
    all_matched, match, unmatch = util.invar_check(args.inFor, args.byVars)
    if not all_matched then
      util.my_assert(all_matched, "[POST_PROCESS component] The BY variable ".. 
                                   unmatch.." does not exist in data "..args.inFor)
    end
  end            
                                                     
  local overrideFor = util.check_value(args.overrideFor) and args.overrideFor or ""
  if util.check_value(overrideFor) then
    util.my_assert(util.check_value(args.overrideVar), 
                   "[POST_PROCESS component] The override dependent variable name overrideVar is not specified")
    if not sas.exists(args.overrideFor) then
      util.my_warning(false,  
                     "[POST_PROCESS component] The input override data overrideFor".. args.overrideFor.." does not exist, ignore")
      overrideFor   = ""
    else
      all_matched, match, unmatch = util.invar_check(args.overrideFor, args.timeID)
      if not all_matched then
        util.my_warning(all_matched, "[POST_PROCESS component] The time ID variable ".. 
                                      args.timeID.." does not exist in data "..args.overrideFor..", ignore override data")
        overrideFor = ""
      end
      all_matched, match, unmatch = util.invar_check(args.overrideFor, args.overrideVar)
      if not all_matched then
        util.my_warning(all_matched, "[POST_PROCESS component] The dependent variable ".. 
                                      args.overrideVar.." does not exist in data "..args.overrideFor..", ignore override data")
        overrideFor = ""                                
      end
      if util.check_value(args.byVars) then
        all_matched, match, unmatch = util.invar_check(args.overrideFor, args.byVars)
        if not all_matched then
          util.my_warning(all_matched, "[POST_PROCESS component] The BY variable ".. 
                                        unmatch.." does not exist in data "..args.overrideFor..", ignore override data")
          overrideFor = "" 
        end
      end 
    end
  end
  print("overrideFor table is "..overrideFor)
  
  -- compute historical average
  local tmpLibNm    = util.check_value(args.processLib) and args.processLib or "WORK"
  local avgTbl      = tmpLibNm.."._histAvgTbl"
  local commaByVars = ""
  local byVars      = ""
  local selectId    = ""
  local groupBy     = ""
  if util.check_value(args.byVars) then
    byVars          = args.byVars
    local byVarsTbl = util.split_string(args.byVars)
    local i
    for i=1, #byVarsTbl do
      if i<#byVarsTbl then 
        commaByVars = util.add_to_string(commaByVars, byVarsTbl[i]..",")
      else
        commaByVars = util.add_to_string(commaByVars, byVarsTbl[i])
      end
    end
    selectId        = commaByVars..", "..args.timeID
    groupBy         = "group by "..commaByVars
  else
    selectId = args.timeID
  end
  rc = sas.submit([[
    proc sql noprint;
      create table @avgTbl@ as
      select distinct @selectId@, avg(@depVar@) as _HISAVG
      from @inFor@
      @groupBy@
      order by @selectId@;
    quit;
  ]],{avgTbl=avgTbl, selectId=selectId, groupBy=groupBy, depVar=args.depVar, inFor=args.inFor})
  util.my_assert(rc<=4, "[POST_PROCESS component] ERROR occurred when computing historical average for override forecast, exit.")
  
  -- sort the indata(s)

  local byStatement    = ""
  local sortedByVars   = ""
  if util.check_value(byVars) then
    byStatement  = "by "..byVars.." "..args.timeID
    sortedByVars = byVars.." "..args.timeID
  else
    byStatement  = "by "..args.timeID
    sortedByVars = args.timeID
  end
  
  rc = sas.submit([[
    proc sort data=@inFor@; @byStatement@; run;
  ]],{inFor=args.inFor, byStatement=byStatement})
  util.my_assert(rc<=4, "[POST_PROCESS component] ERROR occurred when sorting the input forecast data "..args.inFor..", exit.")
  
  if util.check_value(overrideFor) then
    local overrideTbl = tmpLibNm.."._overrideTbl"
    rc = sas.submit([[
      proc sql noprint;
        create table @overrideTbl@ as
        select @selectId@, @overrideVar@ as _msOverrideFcst
        from @data@
        order by @selectId@;
      quit;
    ]],{overrideTbl=overrideTbl, selectId=selectId, overrideVar=args.overrideVar, data=overrideFor})
    util.my_assert(rc<=4, "[POST_PROCESS component] ERROR occurred when sorting the input override forecast data "
                          ..args.overrideFor..", exit.")

    rc = sas.submit([[                      
        data @outFor@(drop=_msOverrideFcst _HISAVG);
          merge @inFor@ (in=_msoverrideindexa)
                @overrideTbl@
                @avgTbl@;
          @byStatement@;
          if missing(@fcstVar@) then do;
            if ~missing(_msOverrideFcst) then @fcstVar@=_msOverrideFcst;
            else @fcstVar@=_HISAVG;
          end;
          if _msoverrideindexa;
        run; 
     ]],{outFor=args.outFor, inFor=args.inFor, overrideTbl=overrideTbl, avgTbl=avgTbl, byStatement=byStatement,fcstVar=args.fcstVar})            
  
  else
    rc = sas.submit([[                      
        data @outFor@(drop=_HISAVG);
          merge @inFor@ (in=_msoverrideindexa)
                @avgTbl@;
          @byStatement@;
          if missing(@fcstVar@) then @fcstVar@=_HISAVG;
          if _msoverrideindexa;
        run; 
     ]],{outFor=args.outFor, inFor=args.inFor, avgTbl=avgTbl, byStatement=byStatement,fcstVar=args.fcstVar})            
  
  end
  util.my_assert(rc<=4, "[POST_PROCESS component] ERROR occurred when overriding the missing values, exit.")
  
  local outLib = ""
  local outTable = ""
  outLib,outTable = util.get_libname_tablename(args.outFor)
  rc = sas.submit([[
    proc datasets lib = @outLib@ nowarn nolist nodetails;
       modify @outTable@ (sortedby=@sortedByVars@); 
    quit;
    ]])
  util.my_assert(rc <= 4, "[POST_PROCESS component] Error occurred when writing sorted by information for table "..args.outFor..", exit.")


end

return{override_missing=override_missing}
