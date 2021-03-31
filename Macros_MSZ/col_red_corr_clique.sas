options mprint;
%macro col_red_corr_clique(dsin=, dsout=, threshold=, corr=, ids=);

	%put &=dsin.;
	%put &=dsout.;
	%put &=threshold.;
	%put &=corr.;
	%put &=id.;

	cas casauto;
	caslib _all_ assign;

	proc corr data=&dsin.(drop=&ids.) out=_corr_table(where=(_TYPE_ eq 'CORR')) &corr. noprint;
		var _numeric_;
	run;

	data _corr_table;
		length n1 3.;
		set _corr_table;
		n1 = _n_;
	run;

	PROC TRANSPOSE DATA=_corr_table
		OUT=LinkSetIn(drop=_LABEL_ rename=(_NAME_=var1 vars=var2 corr1=corr) where=(var2 ne 'n1'))
		PREFIX=Corr
		NAME=vars;
		by n1 _name_;
		VAR _numeric_;
	quit;

	/* Only use upper triangular values above a certain treshold*/
	data LinkSetIn(where=(abs(corr) gt &threshold.));
		retain n2;
		set LinkSetIn(rename=(var1=from var2=to));
		by n1;

		if first.n1 then
			n2 = 1;
		else n2 = n2 +1;

		if (n2 > n1);
	run;

	data casuser.LinkSetIn;
		set LinkSetIn;
	run;

	/* Compute Correlation Cliques */
	proc cas;
		loadactionset "network";
		action network.clique result=r status=s /
			indexOffset = 1
			links       = {name = "LinkSetIn"}
			out         = {name = "Cliques", replace=true}
			maxCliques  = "all";
		run;
		print r.ProblemSummary;	run;
		print r.SolutionSummary; run;

		action table.fetch / table = "Cliques" sortBy = "clique"; run;
	quit;

	proc sql noprint;
		create table LinkSetOut as
			select t1.n1, t1.n2, t1.from as _from_, t1.to as _to_, t1.corr, t2.clique
				from casuser.LinkSetIn t1
					left join casuser.cliques t2
						on (t1.from = t2.node)
					order by t2.clique, t1.n1, t1.n2;
	quit;

	title "Highly correlated variables graph";
	proc netdraw graphics data=LinkSetOut;
		actnet /  align=clique separatearcs cnodefill=azure  arrowhead=0;
	run;

	title;

	/* 	Compute number of edges per cliques.
	All nodes of a clique with just on edge must remain. */
	proc sql noprint;
		create table edges_per_clique as
			select t1.clique, count(t1.clique) as no_edges
				from LinkSetOut t1
					group by t1.clique
						order by t1.clique;
	quit;

	/* Compute in how many cliques each edge is present.
	Edges which are present in several cliques should not be further eleminated. */
	proc sql noprint;
		create table edges_in_cliques as
			select t1._from_, t1._to_, count(clique) as no_cliques
				from LinkSetOut t1
					group by t1._from_, t1._to_
						order by t1._from_, t1._to_;
	quit;

	/* Combine information to only select nodes which are connecting cliques or in an isolated clique. */
	/* Add no of edges */
	proc sql noprint;
		create table LinkSetOuttmp as
			select t1.*, t2.no_edges
				from LinkSetOut t1
					left join edges_per_clique t2
						on (t1.clique = t2.clique);
	quit;

	/* 	Add number of cliques per edge and select only important edges which contains nodes to be keept.
	ToDo: Node list may be further reduced.
	Edges with which are only in one clique, the clique has one edge but one node is in another clique. */
	proc sql noprint;
		create table LinkSetOutFinal as
			select t1.*, t2.no_cliques
				from LinkSetOuttmp t1
					left join edges_in_cliques t2
						on (t1._from_ = t2._from_ and t1._to_ = t2._to_)
					where ((t2.no_cliques >= 2) or (t2.no_cliques = 1 and t1.no_edges = 1))
						order by t1.clique, t1._from_, t1._to_;
	quit;

	/* Append nodes in one list. Use data set to have the right charater length */
	data node_base;
		set LinkSetOutFinal(rename=(_from_=node) keep=_from_ obs=0);
	run;
	proc append base=node_base data=LinkSetOutFinal(rename=(_from_ = node) keep=_from_); run;
	proc append base=node_base data=LinkSetOutFinal(rename=(_to_ = node) keep=_to_); run;

	proc sort data=node_base nodupkey;
		by node;
	run;

	proc sql noprint;
		select node into :nodes separated by ' ' from node_base;
	quit;

	%let N=&sqlobs.;
	%put &=N.;
	%put &=nodes.;

	data &dsout.;
		set &dsin.(keep=&ids. &nodes.);
	run;
/*	
	cas casauto terminate;


	ods exclude all;
	proc datasets library=work kill; run; quit;
	ods exclude none;
*/

%mend col_red_corr_clique;

/*%col_red_corr_clique(dsin=sashelp.baseball, dsout=data.baseball_red, threshold=0.8, corr=spearman, ids=name);*/
