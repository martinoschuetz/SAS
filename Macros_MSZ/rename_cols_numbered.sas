/*
Renames columns with consecutive numbers by type (character, numeric) for very wide table
Blocks is partitioning the Variable Names into groups in order not to run into overflow in SQL with long Variable names.
Blocks Minimum = 1, opimal sum(length(Varname))/32000;
*/
%macro rename_cols_numbered(dsin=, dsout=, blocks=);

	proc contents data=&dsin. out=contents;
	run;

	%do j=0 %to &blocks.-1;

		proc sql;
			select name into : vars separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
			select varnum into : varnums separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
			select ifc(Type eq 1, 'N', 'C') into : Types separated by ' ' from contents(where=(mod(varnum, &Blocks.) eq &j.)) order by varnum;
		quit;

		%let N=&sqlobs.;

		/* Vor later control of the keep statement */
		%let nominal=0;
		%let numeric=0;

		data tmp_&j.;
			set &dsin.;

			%do i=1 %to &n.;
				%let typ = %scan(&Types., &i., ' ');

				%if (&typ. eq C) %then
					%do;
						%let nominal = 1;
					%end;

				%if (&typ. eq N) %then
					%do;
						%let numeric = 1;
					%end;

				%let num = %scan(&varnums., &i., ' ');
				%let varorig = "%scan(&vars., &i., ' ')"n;
				%put &=varorig;
				&typ._&num.="%scan(&vars., &i., ' ')"n;
				label &typ._&num.="&typ._&num.: %scan(&vars., &i., ' ')";
			%end;
		run;

		%let keep_string=;

		%if &nominal. eq 1 %then
			%do;
				%let keep_string=&keep_string %str(C_:);
			%end;

		%if &numeric. eq 1 %then
			%do;
				%let keep_string=&keep_string %str(N_:);
			%end;

		data tmp_&j.;
			set tmp_&j.(keep=&keep_string.);
		run;

	%end;

	data &dsout.;
		merge tmp_:;
	run;

	%do j=0 %to &blocks.-1;

		proc delete data=tmp_&j.;
		run;

	%end;

	options notes;
%mend rename_cols_numbered;

options mprint mlogic;

data class;
	set sashelp.class;
run;

%rename(dsin=class, dsout=class_out, blocks=2);