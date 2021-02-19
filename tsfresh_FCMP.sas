options set=MAS_M2PATH="/opt/sas/viya/home/SASFoundation/misc/embscoreeng/mas2py.py";
options set=MAS_PYPATH="/usr/local/bin/python3.7";
options cmplib=work.fcmp;

proc fcmp outlib=work.fcmp.pyfuncs;
  function tsfresh(arr[*]);
  declare object py(python);
  submit into py;
    def sum_py(arr):
      "Output: out_py"
      import tsfresh
      import numpy as np
      x = np.array(arr)
      out_py=tsfresh.feature_extraction.feature_calculators.abs_energy(x)
      return float(out_py)
  endsubmit;
  rc = py.publish();
  rc = py.call("sum_py", arr);
  sum_result = py.results["out_py"];
  return(sum_result);
  endsub;
run;

/* Get number of lines
	- data_in is your input dataset
*/
proc sql;
	select count(*) into: NRows from work.data_in;
quit;

/*  Generate array and execute TSFRESH
	- data_in is the input dataset
	- var_analysis is the column you want to run abs_energy on
	- result is the output from TSFRESH
*/
data _null_;
	array dex[&NRows.];
	retain dex;
	set work.data_in;
	dex[_N_] = var_analysis;
	if _N_=&NRows. then do; 
		result = tsfresh(dex);
		put result=;
	end;
run;