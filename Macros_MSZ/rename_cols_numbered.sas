/*
Renames columns with consecutive numbers by type (character, numeric) for very wide table
Blocks is partitioning the Variable Names into groups in order not to run into overflow in SQL with long Variable names.
Blocks Minimum = 1, opimal sum(length(Varname))/32000;
*/
%macro rename_cols_numbered(dsin=, dsout=, blocks=);

	proc contents data=&dsin. out=contents noprint;	run;

	%do j=0 %to &blocks.-1;

		proc sql noprint;
			select name into : vars separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
			select varnum into : varnums separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
			select ifc(Type eq 1, 'N', 'C') into : Types separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
		quit;
		%let N=&sqlobs.;

		data tmp_&j.;
			set &dsin.;

			%do i=1 %to &n.;
				%let typ = %scan(&Types., &i., ' ');
				%let num = %scan(&varnums., &i., ' ');
				&typ._&num.="%scan(&vars., &i., ' ')"n;
				label &typ._&num.="&typ._&num.: %scan(&vars., &i., ' ')";
			%end;
		run;

		/* Keep might not work if one tight is not in the data. Suppress the error.*/
		options dkricond=nowarn;
		data tmp_&j.;
			set tmp_&j.(keep=C_: N_:);
		run;
		options dkricond=warn;
	
	%end;

	data &dsout.;
		merge tmp_:;
	run;

	proc datasets lib=work nodetails nolist nowarn;
		delete tmp_: contents;
	run;
%mend rename_cols_numbered;
/*
data class;
	set sashelp.class;
run;

%rename_cols_numbered(dsin=class, dsout=class_out, blocks=2);
*/