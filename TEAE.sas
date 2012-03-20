libname data "C:\SAS\Projects\Daiichi\GTFL Design";

options mprint mlogic symbolgen;

proc sql noprint;
   select count(DISTINCT TRT01A)
   into :trt_n
   from data.adsl
   where SAFFL='Y'
   order by TRT01AN;
quit;

%let trt_n=%trim(%left(&trt_n));

proc sql noprint;
   select DISTINCT left(trim(TRT01A))
   into :trt_1 - :trt_&trt_n.
   from data.adsl
   where SAFFL='Y'
   order by TRT01AN;
quit;

/*************** Data Input Module ***************/

/***** %indata *****/

proc sql noprint;
   create table indata as
   select USUBJID, TEAEFL, AEBODSYS as col1, AEDECOD as col2
   from data.adae
   order by USUBJID;
quit;

/***** %adsl *****/

%macro adsl;

   proc sql noprint;
      create table adsl as
      select USUBJID as SUBJECT, 
             case
                %do i=1 %to &trt_n;
                   when TRT01A=trim(left("&&trt_&i.")) then "TRT_&i.N"
                %end;
             end as TRT,
             TRT01AN as TRTN
      from data.adsl
      where SAFFL='Y'
      order by TRT01AN;
   quit;

%mend adsl;

%adsl;

proc sql noprint;
   create table all as
   select *
   from indata a right join adsl b
   on a.USUBJID=b.SUBJECT
   order by SUBJECT;
quit;

/*************** Data Analysis Module ***************/

/***** %freq for overall N *****/

proc sql noprint;
   create table freq1 as
   select TRT, count(DISTINCT USUBJID) as count
   from all
   group by TRT, TRTN
   order by TRTN;
quit;

proc transpose data=freq1 out=t_1(drop=_NAME_);
   id TRT;
   var count;
run;

proc sql noprint;
   select count
   into :trt_n_1 - :trt_n_&trt_n.
   from freq1;
quit;


/***** %freq for TEAE Count *****/

proc sql noprint;
   create table freq2 as
   select TRT, count(DISTINCT USUBJID) as count
   from all
   where TEAEFL='Y'
   group by TRT, TRTN
   order by TRTN;
quit;

proc transpose data=freq2 out=t_2(drop=_NAME_);
   id TRT;
   var count;
run;


/***** %freq for BODSYS Counts *****/

proc sql noprint;
   create table freq3 as
   select TRT, col1, count(DISTINCT USUBJID) as count
   from all
   where TEAEFL='Y'
   group by TRT, TRTN, col1
   order by col1;
quit;

proc transpose data=freq3 out=t_3(drop=_NAME_);
   id TRT;
   by col1;
   var count;
run;


/***** %freq for Term Counts *****/

proc sql noprint;
   create table freq4 as
   select TRT, col1, col2, count(DISTINCT USUBJID) as count
   from all
   where TEAEFL='Y'
   group by TRT, TRTN, col1, col2
   order by col1, col2;
quit;

proc transpose data=freq4 out=t_4(drop=_NAME_);
   id TRT;
   by col1 col2;
   var count;
run;

/*************** Reporting Module ***************/


data rep1;
   set T_3(in=in1) T_4(in=in2);
   by col1;
   if in2 then
      col1 = '    '||trim(left(col2));
   drop col2;
run;

%macro zeros(in_z,out_z);

   data &out_z;
      set &in_z;
	  %do i=1 %to &trt_n;
	     if trt_&i.n=. then
		    trt_&i.n=0;
	  %end;
   run;

%mend zeros;

%macro chars(in_c,out_c);

   data &out_c;
      set &in_c;
	  %do i=1 %to &trt_n;
	     trt_&i.c=put(trt_&i.n,2.0)||' ('||put((trt_&i.n/&&trt_n_&i.)*100, 5.1)||')';
		 drop trt_&i.n;
	  %end;
   run;

%mend chars;

%zeros(T_2,TEAE_CNT);
%chars(TEAE_CNT,F_TEAE);

%zeros(REP1,TERM);
%chars(TERM,F_TERM);

%macro blank;

   data blank;
      set f_term;
      call missing(col1, %do i=1 %to &trt_n-1;
                            trt_&i.c,
                         %end;
						 trt_&trt_n.c);
      output;
      stop;
   run;

%mend blank;

%blank;

data final;
   set f_teae(in=in1) blank blank(in=in2) blank(in=in3) blank f_term;
   if in1 then
      col1='Subjects with AE';
   if in2 then
      col1='Primary System Organ Class';
   if in3 then
      col1='    Preferred Term';
run;

%macro report;

   proc report data=final headline headskip nowd;

      columns col1 %do i=1 %to &trt_n;
                      trt_&i.c
   				%end;;

      define col1 / center flow width=25 '';
      %do i=1 %to &trt_n;
          define trt_&i.c / center "&trt_&i./N=&trt_n_&i./_/n(%)";
      %end;
   run;

%mend report;

%report;
