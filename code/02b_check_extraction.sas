libname proj "~/apple_sentiment_project";

/*===========================================================================*/
/*  Check 1: Do we have the lines datasets?                                  */
/*===========================================================================*/
title "Check 1: Work datasets that exist";
proc sql;
    select memname, nobs
    from dictionary.tables
    where libname = "WORK" 
      and upcase(memname) like "LINES%"
    order by memname;
quit;

/*===========================================================================*/
/*  Check 2: Did the tokens table get built?                                 */
/*===========================================================================*/
title "Check 2: Does proj.apple_10k_tokens exist?";
proc sql;
    select memname, nobs
    from dictionary.tables
    where libname = "PROJ"
    order by memname;
quit;

/*===========================================================================*/
/*  Check 3: File sizes on disk (confirms downloads worked)                  */
/*===========================================================================*/
title "Check 3: Downloaded HTML files on disk";
filename ls pipe "ls -la ~/apple_sentiment_project/texts/";
data _null_;
    infile ls;
    input;
    put _infile_;
run;
filename ls clear;

title;