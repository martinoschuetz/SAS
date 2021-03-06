/* PREREQUISITES:
 *	+ Visual Text Analytics license
 *	+ Ensure to run 1_CAS_Initialize.sas first 
 *	+ Ensure that AIRLINES_KEY dataset is loaded into CAS
 *	+ You can generate the following SAS code using the SAS Studio Task: Tasks --> SAS Tasks --> SAS Visual Text Analytics --> Text Parsing and Topic Discovery
 */

/* 
 * 
 * Task code generated by SAS� Studio 5.1
 * 
 * Generated on '7/7/18, 10:28 PM'
 * Generated by 'ssethi'
 * Generated on server 'vta-friday'
 * Generated on SAS platform 'Linux LIN X64 3.10.0-327.10.1.el7.x86_64'
 * Generated on SAS version 'V.03.04M0P070418'
 * Generated on browser 'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36'
 * Generated on web client 'https://vta-friday.aatesting.sashq-r.openstack.sas.com/SASStudioV/main?locale=en_US&launchedFromAppSwitcher=true'
 */

ods noproctitle;
libname _tmpcas_ cas caslib="CASUSER";

/* Load default English stop list */
proc casutil;
	load casdata="en_stoplist.sashdat" INCASLIB="referencedata" 
		casout="_stoplist_" outcaslib="CASUSER" replace;
	quit;

	/* Remove duplicate terms from stop list */
proc fedsql sessref=%sysfunc(getlsessref(_tmpcas_));
	create table CASUSER._stoplistUnique_ {options replace=TRUE} as select 
		distinct term from casuser._stoplist_;
	drop table CASUSER._stoplist_;
	quit;

	/* Create punctuation dataset */
data _tmpcas_._punctuation_;
	length TERM varchar(*);

	if _n_=1 then
		do;
			term=".";
			output;
		end;
	input term @@;
	output;
	datalines4;
! " # $ % & ' ( ) * + , - / : ; < = > ? @ [ \ ] ^ _ ` { | } ~
;;;;

	/* Append punctuation dataset to stop list */
data _tmpcas_._stoplistUnique_;
	set _tmpcas_._stoplistUnique_(keep=term) _tmpcas_._punctuation_;
run;

/* Train LDA model */
proc cas;
	session %sysfunc(getlsessref(PUBLIC));
	action ldaTopic.ldaTrain / table={caslib="%sysfunc(getlcaslib(PUBLIC))", 
		name="AIRLINES_KEY"} text="text" docId="key" tm={nounGroups="true", 
		entities="STD", stemming="true"} stopList={caslib="CASUSER", 
		name="_stoplistUnique_"} k=25 alpha=0.01 maxIters=100 
		casOut={caslib="%sysfunc(getlcaslib(CASUSER))", name="LDA_TOPICWORD_DISTR", 
		replace="true"} docDistOut={caslib="%sysfunc(getlcaslib(CASUSER))", 
		name="LDA_PROJECTIONS", replace="true"};
	run;
quit;

proc delete data=_tmpcas_._stoplistUnique_;
run;

proc delete data=_tmpcas_._punctuation_;
run;

libname _tmpcas_;