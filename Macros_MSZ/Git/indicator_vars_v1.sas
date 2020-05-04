%macro indicator_vars(ds,var);

	/* Compute number of factors of variable without missings */
	proc sql noprint;
/*		select distinct upcase(left(trim(&var.))) as label into : labels separated by ';'*/
		select distinct upcase(strip(&var.)) as label into : labels separated by ';'
			from &ds.
				order by label;
	quit;
/*
	%let N=&sqlobs.;
	%put N=&n.;
	%put labels=&labels.;
*/
	/* Compute whether variable contains missings */
	proc sql noprint;
		select distinct nmiss(&var.) as no_miss into : no_missings from &ds.; 
	quit;
/*
	%put &=no_missings;
*/
	data &ds.;
		set &ds.;

		%do i= 1 %to %sysevalf(&n.- &no_missings.);
			/* %put &=i; */
			%let label=%scan(%BQUOTE(&labels.),&i.,';',I);
			/* %put &=label; */
			attrib &var._&i. length=3 label="&var._&i.: &label.";
			&var._&i=index(upcase(&var.),"&label.") gt 0;
		%end;
		%if %sysevalf(&no_missings. > 0, boolean) %then %do;
			&var._&n.=(sum(of &var._1-&var._%sysevalf(&n.-1))) eq 0;
			label &var._&n.="&var._&n.: 'MISSING'";
		%end;
	run;

%mend;

/*
data test(drop=Age);
  set sashelp.class;
  age_c = strip(put(Age, 3.));

  if name = "Carol" then name = "";
  if age_c = "14" then age_c = "";
run;

%indicator_vars(test,name);
proc print; run;

%indicator_vars(test,sex);
proc print; run;
*/
