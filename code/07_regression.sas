/*****************************************************************************
 *  MODULE 07 — MASTER REGRESSION
 *  ---------------------------------------------------------------------------
 *  RQ: Does 10-K sentiment predict post-filing abnormal returns,
 *      AFTER controlling for earnings surprise?
 *  ---------------------------------------------------------------------------
 *  Inputs: proj.apple_sentiment (Step 3), proj.apple_car (Step 6),
 *          proj.aapl_surprise (Step 5)
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 07: Master Regression — Sentiment -> CAR";

/*===========================================================================*/
/*  7.1 Build the analysis dataset (merge by fiscal year)                    */
/*===========================================================================*/
proc sql;
    create table proj.analysis_data as
    select 
        c.fyear,
        c.filing_date,
        
        /* Dependent: CAR windows */
        c.AR_day0,
        c.CAR_0_1,
        c.CAR_0_3,
        c.CAR_0_5,
        c.CAR_1_10,
        
        /* Sentiment (from Step 3) */
        s.neg_pct,
        s.pos_pct,
        s.unc_pct,
        s.lit_pct,
        s.net_tone,
        
        /* Earnings surprise control (from Step 5) */
        es.eps_surprise,
        es.surprise_pct,
        es.sue_stdev
        
    from proj.apple_car as c
    left join proj.apple_sentiment as s on c.fyear = s.fyear
    left join proj.aapl_surprise   as es on c.fyear = es.fyear
    order by c.fyear;
quit;

proc print data=proj.analysis_data label;
    var fyear CAR_0_3 neg_pct unc_pct net_tone surprise_pct;
    title2 "Analysis Dataset (merged)";
    format CAR_0_3 percent8.3 surprise_pct percent8.2
           neg_pct unc_pct net_tone 8.3;
run;

/*===========================================================================*/
/*  7.2 Descriptive statistics                                               */
/*===========================================================================*/
proc means data=proj.analysis_data n mean std min max maxdec=4;
    var CAR_0_1 CAR_0_3 CAR_0_5 CAR_1_10 
        neg_pct pos_pct unc_pct net_tone
        surprise_pct sue_stdev;
    title2 "Descriptive Statistics";
run;

/*===========================================================================*/
/*  7.3 Correlation matrix (key variables)                                   */
/*===========================================================================*/
proc corr data=proj.analysis_data;
    var CAR_0_1 CAR_0_3 CAR_0_5 CAR_1_10;
    with neg_pct unc_pct net_tone surprise_pct;
    title2 "Correlations: CARs vs Sentiment and Surprise";
run;

/*===========================================================================*/
/*  7.4 MAIN REGRESSION — THE HEADLINE RESULT                                */
/*===========================================================================*/
title2 "MAIN REGRESSION: CAR[0,+3] = f(Negative Sentiment, Earnings Surprise)";
proc reg data=proj.analysis_data;
    model CAR_0_3 = neg_pct surprise_pct;
run; quit;

/*===========================================================================*/
/*  7.5 Alternative specifications (robustness)                              */
/*===========================================================================*/
title2 "ROBUSTNESS 1: Net Tone instead of Negative Sentiment";
proc reg data=proj.analysis_data;
    model CAR_0_3 = net_tone surprise_pct;
run; quit;

title2 "ROBUSTNESS 2: Uncertainty sentiment";
proc reg data=proj.analysis_data;
    model CAR_0_3 = unc_pct surprise_pct;
run; quit;

title2 "ROBUSTNESS 3: Shorter window CAR[0,+1]";
proc reg data=proj.analysis_data;
    model CAR_0_1 = neg_pct surprise_pct;
run; quit;

title2 "ROBUSTNESS 4: Longer window CAR[+1,+10] — post-filing drift";
proc reg data=proj.analysis_data;
    model CAR_1_10 = neg_pct surprise_pct;
run; quit;

title2 "ROBUSTNESS 5: Sentiment alone (no surprise control)";
proc reg data=proj.analysis_data;
    model CAR_0_3 = neg_pct;
run; quit;

/*===========================================================================*/
/*  7.6 Scatter plot — the visual proof                                      */
/*===========================================================================*/
ods graphics on / width=9in height=5in;

title "Negative Sentiment vs CAR[0,+3]";
title2 "Each point is one Apple 10-K filing (2010-2024)";
proc sgplot data=proj.analysis_data;
    scatter x=neg_pct y=CAR_0_3 / 
        datalabel=fyear
        markerattrs=(symbol=circlefilled size=12 color=darkblue);
    reg x=neg_pct y=CAR_0_3 / 
        lineattrs=(color=red thickness=2);
    xaxis label="Negative Word %";
    yaxis label="CAR [0,+3]" grid;
run;

title "Sentiment Trajectory vs Returns Trajectory";
proc sgplot data=proj.analysis_data;
    series x=fyear y=neg_pct / 
        lineattrs=(color=darkred thickness=3) 
        markers markerattrs=(symbol=circlefilled)
        y2axis;
    series x=fyear y=CAR_0_3 / 
        lineattrs=(color=darkblue thickness=3)
        markers markerattrs=(symbol=circlefilled);
    xaxis label="Fiscal Year" values=(2010 to 2024 by 2);
    yaxis label="CAR [0,+3]";
    y2axis label="Negative Word %";
run;

ods graphics off;
title;