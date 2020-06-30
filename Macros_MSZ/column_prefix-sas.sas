/*
options mprint;

data tmp;
	set sashelp.class;
	label Age="LAge";
	label Height="LHeight";
	label Name="LName";
	label Sex="LSex";
	label Weight="LWeight";
run;
*/
/* Don't use prefix with characters which are non conformant with SAS column naming conventions. */
%macro column_prefix(lib=, dsin=, prefix=);

	proc contents data=&dsin. out=_out_ noprint;
	run;

	proc sql noprint;
		select name into :names separated by '|' from _out_;
		select label into :labels separated by '|' from _out_;
	quit;

	%let N=&sqlobs.;
	%let rename_statement=;
	%let relabel_statement=;

	%do i = 1 %to &N.;
		%let name = %scan(&names.,&i.,"|");
		%let lab = %scan(&labels.,&i.,"|");
		%let pair = %sysfunc(catx(=,&name.,%quote(&prefix.)_&name.));
		%let pair2 = %sysfunc(catx(=,&name.,"%quote(&prefix.)_&lab."));
		%let rename_statement=&rename_statement. &pair.;
		%put &=rename_statement.;
		%let relabel_statement=&relabel_statement. &pair2.;
		%put &=relabel_statement.;
	%end;

	proc datasets lib=&lib. nolist;
		modify &dsin.;
		label   %quote(&relabel_statement.);
		rename  %quote(&rename_statement.);
	run;

	quit;

%mend column_prefix;

/*%column_prefix(lib=work, dsin=tmp, prefix=TMP);*/