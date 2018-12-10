/*
http://sww.sas.com/saspedia/Assigning_unique_row_ids_to_a_CAS_table_using_DATA_step
Assigning unique row IDs is not as straightforward in CAS as it is in MVA
because in CAS, RETAIN, LAG, and _N_ hold per-thread values.
*/
options msglevel=i;
options cashost="dach-viya-smp.sas.com";
options CASPORT=5570;
cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US" /*metrics=true*/);
caslib _all_ assign;

proc casutil;
	load incaslib="casdata" casdata="simulated_row7000_col1500.sashdat" outcaslib="casuser" casout="simulated_row7000_col1500";
run;

/*
This program mimics the standard MVA DATA step method for assigning a unique, consecutive ID that starts from 1.
Beware, with single=yes, all data is moved to 1 worker, for output data this is permanent
*/
data casuser.simulated_row7000_col1500_id / single=yes;
	set casuser.simulated_row7000_col1500;
	rowid=_N_;
run;

/*
This program assigns unique and increasing IDs and does it in parallel.
The row number is placed in the lower digits of ROWID and the thread number is place in upper digits.
The drawback is that the row number does not start at 1 and there must be "fewer than 1E6 rows" in each thread.
This program runs faster than method 1 because it is multi-threaded.
Unlike "single=yes", the unique IDs are not sequential starting from 1.
*/
data casuser.simulated_row7000_col1500_id;
	set casuser.simulated_row7000_col1500;
	rowid=_N_ + (_THREADID_ * 1E6);
	thid=_THREADID_;
	nth=_NTHREADS_;
	n=_N_;
run;

/* 	This method does not have the constraint of 1E6 max rows per thread because it places
the thread number in the lower digits of ROWID, and places the row number in the upper digits.
However, like "simple threaded," the unique IDs are not sequential starting from 1.
*/
data casuser.simulated_row7000_col1500_id;
	if _N_=1 then
		do;
			_mult=10 ** (int(log10(_NTHREADS_)) + 1);
			retain _mult;
			drop _mult;
		end;
	set casuser.simulated_row7000_col1500;
	rowid=_THREADID_ + (_N_ * _mult);
	thid=_THREADID_;
	nth=_NTHREADS_;
	n=_N_;
run;



/* 	
	This method produces the same results as the "single=yes" method without having to move the data to a single worker.
	The unique IDs are sequential starting from 1 and end with the total number of observations in the table.
	It is a two-pass technique and it runs multi-threaded.
	This technique loads the data, creates some metadata, uses the metadata to generate some code and executes the code.
	Please see comments in the example below for more detail.
*/


proc casutil;
	droptable incaslib="casuser" casdata="simulated_row7000_col1500" quiet;
	droptable incaslib="casuser" casdata="simulated_row7000_col1500_id" quiet;
	droptable incaslib="casuser" casdata="metadata" quiet;
run;

proc cas;
 
  /* Load the target data set. The table may
     already be in CAS in your use case. */
 
  upload path="/opt/data/sashdat/simulated_row7000_col1500.sashdat";
 
  /* This block of code creates some metadata. 
 
     The metadata tells us how many observations are assigned to 
     each thread id. The meta data is used in the 2nd pass to calculate 
     the unique consecutive rowid. In other words, we want to know
     how many rows are assigned to thread number X. And how may 
     rows are assigned to thread number Y, and so forth.
 
     The process of inputting a data set is deterministic. Because the 
     data is not modified in this step, when the data set is input a 2nd
     time, each thread will receive the same data and the same thread id.
     This is true for the previous methods as well. It is mentioned here because
     it's pertinent to the process. In the previous methods it seems irrelevant.  
 
     See an example of the metadata below. */
 
  datastep.runcode /
    code = "
      data metadata(keep=n t);
      set simulated_row7000_col1500 end=done;
      t=_THREADID_;
      n=_N_;
      if done then
        output metadata;
      run;
    ";
  run;
 quit;
 
 proc cas;
  /* Required for fetch actions */
/*  loadActionSet "tkcasva"; run;*/
  loadActionSet "table"; run;

  /* Determine the number of observations in the metadata data set. */
  /*nobs result=nb1 / */
  table.recordCount result=nb1 /
    table={caslib="CASUSER", name="metadata"};
  describe nb1; run;
/*  print $(nb1.recordCount); run;
 */
  /* Fetch all observations in the metadata. You need to use both to= and maxrows=
     because the default maxrows is 1000. You could also hard code to the maximum
     number of threads available. The following code will tell you total threads available:
 
     proc cas;
       runcode / code="data __tmp; n = _nthreads_; if _threadid_ = 1 then output;"; run;
     quit;
     proc print data=cas.__tmp; run; */   
 
  fetch result=local / fetchVars={{name="n"},{name="t"}},
    table={caslib="CASUSER", name="metadata"} to=$(nb1.recordCount) maxrows=$(nb1.recordCount);
/*    table={caslib="CASUSER", name="metadata"} to=$(nb1.nobs) maxrows=$(nb1.nobs);*/
  run;
 	quit;
 	proc cas;
  /* This will take the metadata out of CAS. The metadata is not
     big data therefore this is OK to do. It's necessary in order to
     write the code stream for the 2nd pass "on the fly". The code written uses
     the metadata and the knowledge that reading a data set is deterministic.
     The code expression will run multi-threaded and number the rows 
     sequentially starting from one. */

  localt=findtable(local); 
 
  codeExpr = 'data simulated_row7000_col1500_id; set simulated_row7000_col1500; select (_THREADID_);';
 
  do x over localt;
    if missing(prevcount) then prevcount=0;
    if missing(newcount) then  newcount=0;
    newcount=newcount+prevcount;
    numvar=x.t;
    nv = put(numvar, d10.);
    nc = put(newcount, d10.);
    codeExpr = codeExpr || " when ( " || nv || ") unique= " || nc || "+ _N_;";
    prevcount=x.n;
  end;
 
  codeExpr = codeExpr || " otherwise put 'PROBLEM ' _THREADID_=; end; ";
 
  print codeExpr;
  datastep.runcode / code=codeExpr;
  run;
quit;

proc casutil;
	droptable incaslib="casuser" casdata="simulated_row7000_col1500" quiet;
	droptable incaslib="casuser" casdata="simulated_row7000_col1500_id" quiet;
	droptable incaslib="casuser" casdata="metadata" quiet;
run;

cas mySession terminate;