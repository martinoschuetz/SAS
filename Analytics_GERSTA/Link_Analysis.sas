filename temp catalog 'sashelp.dmlink.macros.source';
%include temp;
proc freq data= &EM_IMPORT_DATA noprint;
table ACCOUNT_ID_FROM / missing out=_F1;
table ACCOUNT_ID_TO / missing out=_F2;
RUN;
OPTIONS nonotes;
%_rawnodes(append=0,outds=_NODES,inds=_F1,var=ACCOUNT_ID_FROM,role=input,format=$20. );
%_rawnodes(append=1,outds=_NODES,inds=_F2,var=ACCOUNT_ID_TO,role=input,format=$20. );
OPTIONS notes;
* Count Links: 1;
proc freq data=&EM_IMPORT_DATA noprint;
table ACCOUNT_ID_FROM*ACCOUNT_ID_TO / missing out=_L1X2;
RUN;
OPTIONS nonotes;
%_rawlinks(append=0,outds=_LINKS,inds=_L1X2,var1=ACCOUNT_ID_FROM,format1=$20.,var2=ACCOUNT_ID_TO,format2=$20.);
OPTIONS notes;
OPTIONS nonotes;
%_rawmerge(nodes=_NODES,links=_LINKS,missing=0);
%_rawstats(train=&EM_IMPORT_DATA,freqvar=,nodes=_NODES,links=_LINKS);
OPTIONS notes;
OPTIONS nonotes;
%_centrality(nodes=_NODES,links=_LINKS,weighted=1);
%_centrality(nodes=_NODES,links=_LINKS,weighted=0);
%_prefix(inds=_NODES,var=VALUE,prevar=PREFIX,pnum=0,pchar='/');
%_final(nodes=_NODES,links=_LINKS,outnodes=&EM_LIB..&EM_NODEID._NODES,outlinks=&EM_LIB..&EM_NODEID._LINKS, maxobs=10000,desc=1);
OPTIONS notes;
%_PLOTS(nodes=_NODES,links=_LINKS,gout=&EM_LIB..GOUT);
OPTIONS nonotes nosource;
* Delete temporary data;
proc datasets nolist library=work;
delete _LKIN _LINKS _NODES;
delete _L1X2;
delete _L1X3;
delete _L1X4;
delete _L1X5;
delete _L2X3;
delete _L2X4;
delete _L2X5;
delete _L3X4;
delete _L3X5;
delete _L4X5;
delete _F1;
delete _F2;
delete _F3;
delete _F4;
delete _F5;
run;
quit;
OPTIONS notes source;
%em_register(key=LINKS, type=DATA)
data &em_user_links;
set &EM_LIB..&EM_NODEID._LINKS;
run;
%em_register(key=NODES, type=DATA)
data &em_user_nodes;
set &EM_LIB..&EM_NODEID._NODES;
rename count=node_count;
run;
%em_report(viewtype=Constellation, autodisplay=Y, linkkey=LINKS, nodekey=NODES,linkfrom=id1, linkto=id2, linkid=linkid, linkvalue=count, nodesize=node_count, nodeid=id, nodetip=value);
%em_report(viewtype=Data, key=NODES, autodisplay=Y,description=Node Statistics);
proc print data=&EM_LIB..&EM_NODEID._NODES(obs=10);
run;