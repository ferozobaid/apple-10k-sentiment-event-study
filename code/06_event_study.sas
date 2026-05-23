/*****************************************************************************
 *  MODULE 06 — EVENT STUDY: ABNORMAL RETURNS AROUND 10-K FILINGS
 *  ---------------------------------------------------------------------------
 *  Methodology: Market Model (MacKinlay 1997)
 *    Estimation window: [-120, -11] — 110 trading days pre-filing
 *    Event windows:     [0,+1], [0,+3], [0,+5], [+1,+10]
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 06: Event Study — Abnormal Returns";

/* Window parameters */
%let est_start = -120;
%let est_end   =  -11;
%let evt_start =  -5;     /* a bit of pre-window for visualization */
%let evt_end   =  10;

/*===========================================================================*/
/*  6.1 Assign trading-day index to filing dates                             */
/*  If filing falls on weekend/holiday, use next trading day                 */
/*===========================================================================*/
proc sql;
    create table work.filings_indexed as
    select 
        f.fyear,
        f.filing_date,
        min(r.trading_day) as evt_tday
    from proj.apple_10k_list as f
    inner join proj.aapl_returns as r
        on r.date >= f.filing_date
    group by f.fyear, f.filing_date
    order by f.filing_date;
quit;

proc print data=work.filings_indexed;
    title2 "Filing Dates Mapped to Trading-Day Index";
run;

/*===========================================================================*/
/*  6.2 Build event panel: 120 pre + event window per filing                 */
/*===========================================================================*/
proc sql;
    create table work.event_panel as
    select 
        f.fyear,
        f.filing_date,
        r.date,
        r.ret_aapl,
        r.ret_mkt,
        (r.trading_day - f.evt_tday) as tau
    from work.filings_indexed as f
    inner join proj.aapl_returns as r
        on (r.trading_day - f.evt_tday) between &est_start and &evt_end
    order by f.fyear, tau;
quit;

/*===========================================================================*/
/*  6.3 Estimate Market Model per filing (OLS on estimation window)          */
/*===========================================================================*/
proc reg data=work.event_panel outest=work.params noprint;
    where tau between &est_start and &est_end;
    by fyear;
    model ret_aapl = ret_mkt;
run; quit;

data work.params_clean;
    set work.params;
    keep fyear alpha beta;
    rename Intercept = alpha  ret_mkt = beta;
run;

proc print data=work.params_clean;
    title2 "Market Model Parameters (alpha, beta) per Filing";
    format alpha 8.5 beta 6.3;
run;

/*===========================================================================*/
/*  6.4 Compute abnormal returns in the event window                         */
/*===========================================================================*/
proc sql;
    create table work.ar as
    select 
        p.fyear, p.filing_date, p.date, p.tau,
        p.ret_aapl, p.ret_mkt,
        (p.ret_aapl - (q.alpha + q.beta * p.ret_mkt)) as ar
    from work.event_panel as p
    inner join work.params_clean as q on p.fyear = q.fyear
    where p.tau between &evt_start and &evt_end
    order by p.fyear, p.tau;
quit;

/*===========================================================================*/
/*  6.5 Cumulative Abnormal Returns (CAR) per filing, per window             */
/*===========================================================================*/
proc sql;
    create table proj.apple_car as
    select 
        fyear,
        filing_date,
        sum(case when tau = 0                   then ar end) as AR_day0   format=percent8.3,
        sum(case when tau between  0 and  1     then ar end) as CAR_0_1   format=percent8.3,
        sum(case when tau between  0 and  3     then ar end) as CAR_0_3   format=percent8.3,
        sum(case when tau between  0 and  5     then ar end) as CAR_0_5   format=percent8.3,
        sum(case when tau between  1 and 10     then ar end) as CAR_1_10  format=percent8.3,
        sum(case when tau between -5 and -1     then ar end) as CAR_pre   format=percent8.3
    from work.ar
    group by fyear, filing_date
    order by fyear;
quit;

proc print data=proj.apple_car label;
    label AR_day0  = "AR[0]"
          CAR_0_1  = "CAR[0,+1]"
          CAR_0_3  = "CAR[0,+3]"
          CAR_0_5  = "CAR[0,+5]"
          CAR_1_10 = "CAR[+1,+10]"
          CAR_pre  = "CAR[-5,-1] (pre)";
    title2 "Cumulative Abnormal Returns by Filing";
run;

/*===========================================================================*/
/*  6.6 Test: are CARs significantly different from zero?                    */
/*===========================================================================*/
proc ttest data=proj.apple_car h0=0;
    var AR_day0 CAR_0_1 CAR_0_3 CAR_0_5 CAR_1_10 CAR_pre;
    title2 "T-Tests: Are CARs Significantly Different from Zero?";
run;

/*===========================================================================*/
/*  6.7 Average Abnormal Returns (AAR) and CAAR by event-day                 */
/*===========================================================================*/
proc means data=work.ar noprint nway;
    class tau;
    var ar;
    output out=work.aar(drop=_type_ _freq_)
           mean=AAR n=N stderr=SE;
run;

data proj.apple_aar;
    set work.aar;
    t_stat = AAR / SE;
    retain CAAR 0;
    CAAR + AAR;
    format AAR CAAR percent8.3 t_stat 6.2;
run;

proc print data=proj.apple_aar;
    title2 "AAR and CAAR by Event-Day (tau)";
run;

/*===========================================================================*/
/*  6.8 The headline chart: CAAR over event window                           */
/*===========================================================================*/
ods graphics on / width=9in height=5in;

title2 "Cumulative Average Abnormal Return Around Apple 10-K Filings";
title3 "N=15 filings | Event Day = 0 (filing day) | Market Model";
proc sgplot data=proj.apple_aar;
    series x=tau y=CAAR / lineattrs=(thickness=3 color=darkblue)
                        markers markerattrs=(symbol=circlefilled size=8);
    refline 0 / axis=x lineattrs=(pattern=dash color=red) 
                label="Filing Day" labelloc=inside;
    refline 0 / axis=y lineattrs=(pattern=dot color=gray);
    xaxis label="Trading Day Relative to Filing" values=(-5 to 10 by 1);
    yaxis label="CAAR" grid;
run;

title2 "Average Abnormal Return by Event-Day";
proc sgplot data=proj.apple_aar;
    vbar tau / response=AAR fillattrs=(color=steelblue);
    refline 0 / axis=y;
    xaxis label="Trading Day Relative to Filing";
    yaxis label="AAR" grid;
run;

title2 "CAR[0,+3] by Individual Filing (sorted)";
proc sgplot data=proj.apple_car;
    vbar fyear / response=CAR_0_3 datalabel
                 fillattrs=(color=darkorange);
    refline 0 / axis=y;
    xaxis label="Fiscal Year";
    yaxis label="CAR [0,+3]" grid;
run;

ods graphics off;
title;