local util = require("fscb.common.util")

--[[
NAME:           forecast_macro

DESCRIPTION:    copy default modeling strategy and define macros 
                
INPUTS:         args

OUTPUTS:        args.repositoryNm

USAGE:          
                
]]

function forecast_macro(args)

  local rc   
  local repositoryNm
  if util.check_value(args.repositoryNm) then
    repositoryNm = args.repositoryNm
  else
    repositoryNm = "work.TemModRepCopy"
  end 
  -- copy the default repository if not exist
  if sas.cexist(repositoryNm) == 0 then
    rc = sas.submit([[
      proc catalog catalog=@repositoryNm@;
        copy in=sashelp.hpfdflt out=@repositoryNm@;
      quit;
     ]])
  end
  
  -- declare the macro
  rc = sas.submit([[    
    
      %macro ci_run_hpf;
      
        %let indataset  = %sysfunc(dequote(&indataset));
        %let outdataset = %sysfunc(dequote(&outdataset));
        %let interval = %sysfunc(dequote(&interval));
        %let criterion = %sysfunc(dequote(&criterion));
        %let repositoryNm = %sysfunc(dequote(&repositoryNm));
        %let diagEstNm = %sysfunc(dequote(&diagEstNm));
        
        proc hpfdiagnose data = &indataset
              outest = &diagEstNm RETAINCHOOSE=YES 
              seasonality = &seasonality
              errorcontrol = (severity = HIGH stage = (PROCEDURELEVEL)) EXCEPTIONS = CATCH  
              modelrepository =&repositoryNm
              back = 0 criterion = &criterion;
            forecast demand /acc = total setmissing = MISSING trimmiss = NONE zeromiss = NONE;
            id time_id interval=&interval acc = total notsorted 
               setmissing = MISSING 
               trimmiss = NONE zeromiss = NONE;
        run;
            
      
        proc hpfengine data = &indataset
            inest = &diagEstNm modelrepository =&repositoryNm
            outfor = &outdataset out=_NULL_ 
            outest = &diagEstNm 
            
            task = select(  criterion = &criterion override)
            back = 0  lead=&lead              
            seasonality = &seasonality errorcontrol=(severity=HIGH, stage=(PROCEDURELEVEL))
            EXCEPTIONS=CATCH   
            ;
            forecast demand /acc = total setmissing = MISSING trimmiss = NONE zeromiss = NONE;
            id time_id interval=&interval acc = total notsorted 
               setmissing = MISSING 
               trimmiss = NONE zeromiss = NONE;
        run;

      %mend;    
    ]])

end



return{forecast_macro=forecast_macro}
