/************************************************************************/
/* This code example illustrates the use of PROC TEXTMINE for           */
/* identifying important terms and topics in a document collection.     */
/*                                                                      */
/* PROC TEXTMINE parses the news data set to                            */
/*   1. generate a dictionary of important terms                        */
/*   2. generate a collection of important topics                       */
/*                                                                      */
/* The OUTTERMS= option specifies the terms dictionary to be created.   */
/* The OUTTOPICS= option specifies the SAS data set to contain the      */
/* number of topics specified by the K= option. The user can peruse the */
/* TERMS and TOPICS data sets to gain insight about the document        */
/* collection.                                                          */
/*                                                                      */
/* PROC TMSCORE allows the user to score new document collections       */
/* based on training performed by a previous PROC TEXTMINE analysis.    */
/************************************************************************/

/************************************************************************/
/* Setup and initialize for later use in the program                    */
/************************************************************************/
/* Specify a libref to the input tables */
libname locallib '/home/sasdemo/data';

/* Define a CAS engine libref for CAS in-memory data tables */
libname mycaslib cas caslib=casuser;


/************************************************************************/
/* Load data into CAS                                                   */
/************************************************************************/
%if not %sysfunc(exist(mycaslib.trump)) %then %do;
  proc casutil;
    load data=locallib.analysis_2016 casout="trump";
  run;
%end;

%if not %sysfunc(exist(mycaslib.engstop)) %then %do;
  proc casutil;
    load data=locallib.engstop casout="engstop";
  run;
%end;


/************************************************************************/
/* 1. Parse the documents in table news and generate the                */
/*    term-by-term matrix                                               */
/* 2. Perform dimensionality reduction via SVD, and                     */
/* 3. Perform topic discovery based on SVD                              */
/************************************************************************/
proc textmine data=mycaslib.trump;
  doc_id id;
  var text;
  target speaker;
  /* part (1) */
  parse reducef=2 entities=std stop=mycaslib.engstop
        outterms=mycaslib.terms outparent=mycaslib.parent
        outconfig=mycaslib.config cellwgt=LOG TERMWGT=MI;
  /* part (2) and (3) */      
  svd k=25  svdu=mycaslib.svdu outdocpro=mycaslib.docpro
      outtopics=mycaslib.topics;
      select "ADJ" "ADV" "NOUN" "VERB" / GROUP="POS" keep;
run;


/************************************************************************/
/* Print results                                                        */
/************************************************************************/
proc sql;
  create table terms as
  select * from mycaslib.terms 
  order by numdocs descending;
quit;

/* Show the 10 topics found by PROC TEXTMINE */
proc print data=mycaslib.topics;
  title '10 Topics found by PROC TEXTMINE';
run;

/* Show the top 10 entities that appear in the news */
proc print data=terms(obs=10);
  where attribute='Entity';  
  title 'Top 10 entities that appear in the news';
run;

/* Show the top 10 noun terms that appear in the news */
proc print data=terms(obs=10);
  where role='Noun';  
  title 'Top 10 noun terms that appear in the news';
run;

/* Show the structured representation of the first 5 documents */
proc print data=mycaslib.docpro(obs=5);
  title 'Stuctured representation of first 5 documents';
run;
title;


/*******************INCLUDE TARGET*******/

/*get labels*/
proc sql;
	select cat("COL",_topicid)||'="'||_name||'"' into :labels separated by " "
	from mycaslib.topics;
quit;


proc delete data=mycaslib.analysis; run;
data mycaslib.analysis;
	merge mycaslib.docpro mycaslib.trump(keep=speaker);
	label &labels;
	u=rand('UNIFORM',0,1);
	_PARTIND_=(u>0.7);
run;


/*Train GradBoost*/
proc gradboost data=MYCASLIB.Analysis;
	partition role=_PartInd_ (validate='1');
	target Speaker / level=nominal;
	input COL: / level=interval;
	
	ods output FitStatistics=Work._Gradboost_FitStats_ 
		VariableImportance=Work._Gradboost_VarImp_;
	score out=MYCASLIB.scored_gb copyvars=(Speaker Col: _PARTIND_);
run;


/*Investigate Important Topics*/
proc sql;
	create table Gradboost_VarImp as
	select t1.*, t2._name
	from _Gradboost_VarImp_ t1
	left join mycaslib.topics t2 on t1.variable=cat("COL",t2._topicid)
	order by -importance
	;
quit;
proc print data=GradBoost_VarImp;
  title 'Important Topics';
run;

/*Forest*/
proc forest data=MYCASLIB.Analysis;
	partition role=_PartInd_ (validate='1');
	target Speaker / level=nominal;
	input COL: / level=interval;
	

	score out=mycaslib.scored_rf copyvars=(Speaker COL: _PARTIND_);
		
	savestate rstore=MYCASLIB.score;
run;



/*Neural*/
libname _tmpcas_ cas;

proc nnet data=MYCASLIB.Analysis missing=mean;
	partition role=_PartInd_ (validate='1');
	target Speaker / level=nominal;
	input COL: / level=interval;
	architecture mlp direct;
	hidden 50;
	hidden 50;
	train outmodel=_tmpcas_._Nnet_model_;
	optimization regL2=0.1;
	score out=MYCASLIB.scored_nn copyvars=(_all_);
run;


/*Evaluate*/
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
    input P_SpeakerTrump;
    target Speaker / level=nominal event='TRUMP';
    fitstat pvar=P_SpeakerClinton / pevent='CLINTON';
  
    ods output
      fitstat=&prefix._fitstat 
      rocinfo=&prefix._rocinfo 
      liftinfo=&prefix._liftinfo;
run;
%mend assess_model;

ods exclude all;
%assess_model(prefix=GB, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=rf, var_evt=p_&target.1, var_nevt=p_&target.0);
%assess_model(prefix=nn, var_evt=p_&target.1, var_nevt=p_&target.0);
ods exclude none;


/************************************************************************/
/* ROC and Lift Charts using validation data                            */
/************************************************************************/
ods graphics on;

data all_rocinfo_val;
  set rf_rocinfo(in=s)
      GB_rocinfo(in=g)
    
      nn_rocinfo(in=n);

      
  length model $ 16;
  select;
    when (s) model='Random Forest';
    when (g) model='GradientBoosting'; 
  
    when (n) model='Neural Network';
  end;
  
  if _partind_=1 then output;
run;

data all_liftinfo_val;
  set RF_liftinfo(in=s)
      GB_liftinfo(in=g)
	nn_liftinfo(in=n);
	
      
  length model $ 16;
  select;
    when (s) model='Random Forest';
    when (g) model='GradientBoosting'; 
   
     when (n) model='Neural Network';
   end;
  if _partind_=1 then output;
run;

/* Print AUC (Area Under the ROC Curve) */
title "AUC (using validation data) ";
proc sql;
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


/************************************************************************/
/* Score new text data                                                  */
/************************************************************************/
proc tmscore data=mycaslib.trump svdu=mycaslib.svdu 
     config=mycaslib.config terms=mycaslib.terms
     svddocpro=mycaslib.score_docpro outparent=mycaslib.score_parent;
  var text;
  doc_id id;
run;

/*Score Final Model*/
proc astore ;
	score data=MYCASLIB.score_docpro out=MYCASLIB.score rstore=MYCASLIB.SCORE;
run;

proc contents data=MYCASLIB.score;
run;
