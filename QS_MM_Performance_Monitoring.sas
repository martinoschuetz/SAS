cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US" metrics=true);

caslib _all_ assign;

/* Generate Score Code File */
*------------------------------------------------------------*;
* Macro Variables for input, output data and files;
  %let dm_datalib =casdata;
  %let dm_lib     = WORK;
  %let dm_folder  = %sysfunc(pathname(work));
*------------------------------------------------------------*;
*------------------------------------------------------------*;
  * Training for tree;
*------------------------------------------------------------*;

proc partition data=&dm_datalib..HMEQ_TRAIN partind samppct=50 samppct2=30;
	by BAD;
	output out=&dm_datalib..hmeq_partioned;
run;

proc treesplit data=&dm_datalib..hmeq_partioned
     maxdepth=10 numbin=20
     nsurrogates=0 minleafsize=5 maxbranch=2 assignmissing=USEINSEARCH
     minuseinsearch=1
     pruningtable
     treeplot printtarget;
  grow IGR
  ;
  target 'BAD'n  / level=nominal;
  input 'CLAGE'n 'CLNO'n 'DEBTINC'n 'LOAN'n 'MORTDUE'n 'VALUE'n 'YOJ'n / level=interval;
  input 'REASON'n 'DELINQ'n 'DEROG'n 'JOB'n 'NINQ'n    / level=nominal;
  partition rolevar= _PartInd_ (TRAIN='1' VALIDATE='2' TEST='0');
  prune costcomplexity;
  code file="/opt/data/mm_hmeq/Models/Tree1/score.sas" nocomppgm labelid=25790823;
  ODS output
     CostComplexity = &dm_lib..pruning
     VariableImportance = &dm_lib..varimportance TreePlotTable = &dm_lib..treeplot TreePerformance = &dm_lib..TreePerf
     PredProbName = &dm_lib..PredProbName
     PredIntoName = &dm_lib..PredIntoName
  ;
  ods exclude treeplottable;
run;

%let _mm_projectuuid=%nrstr(3e47280f-c6d1-496c-9e1e-5cc4c2c695f3);
%let _mm_modelid=%nrstr(857b6c25-8250-4c3f-a3ef-ee051ae6580a);
%let _mm_modelflag = 0;
%let _mm_targetvar=BAD;
%let _mm_scorecodetype = %str(DATASTEP);
%let _mm_targetevent=1;
%let _mm_eventprobvar=P_BAD1;
%let _mm_targetnonevent=0;
%let _mm_noneventprobvar=P_BAD0;

%let _mm_targetlevel=BINARY;
%let _mm_predictedvar=;
%let _mm_keepvars=P_BAD1;
%let _mm_cakeepvars=YOJ MORTDUE DEROG VALUE CLNO LOAN CLAGE DELINQ NINQ;
%let _mm_trace = ON;
%let _mm_max_bins = 10;
%let _mm_perfoutcaslib=public;
%let _mm_perfincaslib=casdata;
%let _mm_perf_intableprefix=hmeq_perf_;
%let _mm_runscore=Y;
%let _mm_saveperfresult=Y;

/* Create a score code fileref if set _mm_runscore=Y  */
filename scoreref '/opt/data/mm_hmeq/Models/Tree1/score.sas';


%mm_performance_monitor
(
  perflib=&_MM_PerfInCaslib,
  perfdatanameprefix=&_MM_Perf_InTablePrefix,
  mm_mart=&_MM_PerfOutCaslib,
  scorecodefref=scoreref,
  runscore=&_MM_RunScore
);

%put SYSERR = &syserr.;
%put SYSCC = &syscc.;

/* View the performance monitoring results. */
libname mm_mart cas caslib="&_MM_PerfOutCaslib" tag="&_MM_ProjectUUID";

/* View a list of the MM_MART library tables. */
proc datasets lib=mm_mart; run; 

proc datasets lib=mm_mart nolist kill; quit; run;	

cas mySession terminate;
