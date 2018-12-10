cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");

cas _all_ list;

/* Specify a libref for local data sets */
libname locallib clear;
libname locallib '/home/sasdemo/Examples/germsz/data';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib clear;
libname mycaslib cas caslib=casuser;

/************LOAD DATA INTO CAS*********/
%if not %sysfunc(exist(mycaslib.data_100000_100)) %then %do;

/* You can load data using a "load" statement in PROC CASUTIL */
proc casutil ;
	load data=locallib.data_100000_100 casout="data_100000_100";
run;

%end;

data mycaslib.data_100000_100;
	set mycaslib.data_100000_100;
	id = _n_;
run;

/***********************Explore the data*****************************/
proc cardinality data=mycaslib.data_100000_100 maxlevels=20 
		outcard=mycaslib.varSummary_data_100000_100 
		out=mycaslib.levelDetail_data_100000_100;
run;

proc delete data=mycaslib.varSummary_data_100000_100 
		mycaslib.levelDetail_data_100000_100;
run;

/* Stratified Sampling producing 50% training, 30% validation, and 20% test data. */
proc partition data=mycaslib.data_100000_100 partind samppct=30 samppct2=20 
		seed=1234;
	by y_binary;
	output out=mycaslib.data_100000_100_partitioned;
run;

data mycaslib.abt_max;
	set mycaslib.data_100000_100_partitioned(where=(_PartInd_ ne 2));
run;

data mycaslib.sbt_max(drop=_PartInd_);
	set mycaslib.data_100000_100_partitioned(where=(_PartInd_ eq 2));
run;


/*****************Train predictive Models********************/

/* Gradient Boosting using fixed parameter */
/*
proc treeboost data=data(where=(selected=1)) event="1" iterations=50 maxdepth=6
	leaffraction=0.001 maxbranch=2 shrinkage=0.2 trainproportion=1;
	input inf: noise: cat:;
	target y_binary / level=binary;
	score data=data(where=(selected=0)) out=fit_results role=test;
run;
*/
proc gradboost data=mycaslib.data_100000_100_partitioned 
	MAXBRANCH=2 MAXDEPTH=6 MINLEAFSIZE=100	learningrate=0.2 samplingrate=1;
	partition role=_PartInd_ (train='0' validate='1' test='2');
	target y_binary / level=nominal;
	input inf: noise: / level=interval;
	input cat: / level=nominal;
	SAVESTATE RSTORE=mycaslib.gradboost_fix;
	ods output FitStatistics=Work._Gradboost_FitStats_ 	VariableImportance=Work._Gradboost_VarImp_;
	score out=MYCASLIB.scored_gb copyvars=(_all_);
run;

proc sgplot data=Work._Gradboost_FitStats_;
	title3 'Misclassifications by Number of Iterations';
	title4 'Training vs. Validation vs. Test';
	series x=Trees y=MiscTrain;
	series x=Trees y=MiscValid /lineattrs=(pattern=dot thickness=2);
	series x=Trees y=MiscTest /lineattrs=(pattern=dash thickness=2);
	yaxis label='Misclassification Rate';
	label Trees='Number of Iterations';
	label MiscTrain='Training';
	label MiscValid='Validation';
run;
title3;

proc sgplot data=Work._Gradboost_VarImp_;
	title3 'Variable Importance';
	hbar variable / response=importance nostatlabel categoryorder=respdesc;
run;
title3;

proc delete data=Work._Gradboost_VarImp_; run;
proc delete data=Work._Gradboost_FitStats_; run;

proc astore;
    score data=mycaslib.sbt_max
          rstore=mycaslib.gradboost_fix
          out=mycaslib.sbt_max_scrd;
quit;
 
proc fedsql;
   create table mycaslib.sbt_max_scored as
      select product.prodid, product.product, customer.name,
         sales.totals, sales.country
      from myspde.product, myoracle.sales, myoracle.customer
      where product.prodid = sales.prodid and 
         customer.custid = sales.custid;
   select * from mybase.results;
quit;


/* Autotuning*/
proc gradboost data=mycaslib.data_100000_100_partitioned;
	/* partition role=_PartInd_ (train='0' validate='1' test='2')*/;
	target y_binary / level=nominal;
	input inf: noise: / level=interval;
	input cat: / level=nominal;
	/*autotune tuningparameters=(ntrees samplingrate vars_to_try(init=24) learningrate lasso ridge ) popsize=10 maxiter=10 objective=ASE; */
	autotune /* popsize=10 maxiter=10 */ kfold=5 objective=auc;  
	ods output FitStatistics=Work._Gradboost_FitStats_ VariableImportance=Work._Gradboost_VarImp_;
	score out=MYCASLIB.scored_gb copyvars=(_all_);
run;


proc delete data=Work._Gradboost_VarImp_; run;
proc delete data=Work._Gradboost_FitStats_; run;



/*Logistic Regression*/
proc logselect data=mycaslib.data_100000_100_partitioned;
	partition role=_PartInd_ (validate='1');
	class cat:;
	model y_binary(event='1')=cat: inf: noise: / link=logit;
	selection method=backward (stop=sbc choose=sbc) hierarchy=none;
	output out=mycaslib.scored_lg predicted copyvars=(_all_);
run;

data mycaslib.scored_lg;
	set mycaslib.scored_lg;
	P_y_binary1=_PRED_;
	P_y_binary0=1-_PRED_;
run;

/*Forest*/
proc forest data=mycaslib.data_100000_100_partitioned;
	/*partition role=_PartInd_ (train='0' validate='1' test='2');*/
	target y_binary / level=nominal;
	input inf: noise: / level=interval;
	input cat: / level=nominal;
	autotune objective=auc;
	ods output FitStatistics=Work._Forest_FitStats_ VariableImportance=Work._Forest_VarImp_;
	score out=mycaslib.scored_forest copyvars=(_all_);
	savestate rstore=mycaslib.forest_tunes;
run;

/*Neural*/
libname _tmpcas_ cas;

proc nnet data=mycaslib.data_100000_100_partitioned missing=mean;
	partition role=_PartInd_ (train='0' validate='1' test='2');
	
	target y_binary / level=nominal;
	input inf: noise: / level=interval;
	input cat: / level=nominal;
	
	architecture mlp direct;
	hidden 50;
	hidden 50;
	optimization regL2=0.1;

	/*autotune objective=auc;*/
	ods output FitStatistics=Work._NN_FitStats_ VariableImportance=Work._NN_VarImp_;
	score out=mycaslib.scored_nn copyvars=(_all_);
	train outmodel=_tmpcas_._nnet_model_;

run;

proc delete data=_tmpcas_._nnet_model_; run;

/********************ASSESS*********************************/
/************************************************************************/
/* This example illustrates fitting and comparing several Machine       */
/* Learning algorithms for predicting the binary target in the          */
/* HMEQ data set. The steps include:                                    */
/*                                                                      */
/* (1) PREPARE AND EXPLORE                                              */
/*     a) Check data is loaded into CAS                                 */
/*                                                                      */
/* (2) PERFORM SUPERVISED LEARNING                                      */
/*     a) Fit a model using a Random Forest                             */
/*     b) Fit a model using Gradient Boosting                           */
/*     c) Fit a model using a Neural Network                            */
/*     d) Fit a model using a Support Vector Machine                    */
/*                                                                      */
/* (3) EVALUATE AND IMPLEMENT                                           */
/*     a) Score the data                                                */
/*     b) Assess model performance                                      */
/*     c) Generate ROC and Lift charts                                  */
/************************************************************************/
/************************************************************************/
/* Assess                                                               */
/************************************************************************/
%macro assess_model(prefix=, var_evt=, var_nevt=);
	proc assess data=mycaslib.scored_&prefix.;
		by _partind_;
		input P_TargetBuy1;
		target TargetBuy / level=nominal event='1';
		fitstat pvar=P_TargetBuy0 / pevent='0';
		ods output fitstat=&prefix._fitstat rocinfo=&prefix._rocinfo liftinfo=&prefix._liftinfo;
	run;

%mend assess_model;

ods exclude all;
%assess_model(prefix=GB, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=lg, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=rf, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=nn, var_evt=p_&target.1, var_nevt=p_&target.0);
ods exclude none;

/************************************************************************/
/* ROC and Lift Charts using validation data                            */
/************************************************************************/
ods graphics on;

data all_rocinfo_val;
	set rf_rocinfo(in=s) GB_rocinfo(in=g) lg_rocinfo(in=l) nn_rocinfo(in=n);
	length model $ 16;

	select;
		when (s) model='Random Forest';
		when (g) model='GradientBoosting';
		when (l) model='Logistic Regression';
		when (n) model='Neural Network';
	end;

	if _partind_=1 then
		output;
run;

data all_liftinfo_val;
	set RF_liftinfo(in=s) GB_liftinfo(in=g) nn_liftinfo(in=n) lg_liftinfo(in=l);
	length model $ 16;

	select;
		when (s) model='Random Forest';
		when (g) model='GradientBoosting';
		when (l) model='Logistic Regression';
		when (n) model='Neural Network';
	end;

	if _partind_=1 then
		output;
run;

/* Print AUC (Area Under the ROC Curve) */
title "AUC (using validation data) ";

proc sql ;
	select distinct model, c from all_rocinfo_val order by c desc;
quit;

/* Draw ROC charts */
proc sgplot data=all_rocinfo_val aspect=1;
	title "ROC Curve (using validation data)";
	xaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
	yaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
	lineparm x=0 y=0 slope=1 / transparency=.7;
	series x=fpr y=sensitivity / group=model;
run;

/* Draw lift charts */
proc sgplot data=all_liftinfo_val;
	title "Lift Chart (using validation data)";
	yaxis label=' ' grid;
	series x=depth y=lift / group=model markers markerattrs=(symbol=circlefilled);
run;

/*Score Final Model*/
proc astore ;
	score data=MYCASLIB.BIG_ORGANICS_Imputed out=MYCASLIB.score 
		rstore=MYCASLIB.SCORE;
run;

proc contents data=MYCASLIB.score;
run;

cas mySession terminate;



