/* PREREQUISITES:
 *	+ Visual Text Analytics license
 *	+ Ensure to run 1_CAS_Initialize.sas first 
 *	+ Ensure that AIRLINES_KEY dataset is loaded into CAS
 *	+ Ensure that you have created the topics model CASUSER.SVD_ASTORE using 2a_TextParsingandTopicDiscovery_SVD.sas
 *	+ You can generate the following SAS code using the SAS Studio Task: Tasks --> SAS Tasks --> SAS Visual Text Analytics --> Text Scoring
 */

/* 
 * 
 * Task code generated by SAS� Studio 5.1
 * 
 * Generated on '7/7/18, 10:11 PM'
 * Generated by 'ssethi'
 * Generated on server 'vta-friday'
 * Generated on SAS platform 'Linux LIN X64 3.10.0-327.10.1.el7.x86_64'
 * Generated on SAS version 'V.03.04M0P070418'
 * Generated on browser 'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Safari/537.36'
 * Generated on web client 'https://vta-friday.aatesting.sashq-r.openstack.sas.com/SASStudioV/main?locale=en_US&launchedFromAppSwitcher=true'
 */

ods noproctitle;

proc astore;
	score data=PUBLIC.AIRLINES_KEY out=CASUSER.SVD_SCORED_OUTPUT 
		rstore=CASUSER.SVD_ASTORE;
run;

proc contents data=CASUSER.SVD_SCORED_OUTPUT;
run;