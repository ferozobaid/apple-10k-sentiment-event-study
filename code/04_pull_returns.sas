/*****************************************************************************
 *  MODULE 04 — PULL APPLE DAILY RETURNS FROM CRSP (with split-adjusted price)
 *  ---------------------------------------------------------------------------
 *  Data: CRSP daily stock file (crsp.dsf) + market returns (crsp.dsi)
 *  Apple PERMNO = 14593
 *  Period: 2009-01-01 through 2025-06-30
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 04: Pulling Apple Returns from CRSP";

/*===========================================================================*/
/*  4.1 Confirm Apple's PERMNO in CRSP                                       */
/*===========================================================================*/
proc sql;
    create table work.aapl_permno as
    select distinct permno, permco, ticker, comnam, namedt, nameendt
    from crsp.dsenames
    where ticker = "AAPL"
      and upcase(comnam) contains "APPLE INC"
    order by namedt;
quit;

proc print data=work.aapl_permno;
    title2 "AAPL PERMNO lookup - confirm permno = 14593";
run;

/*===========================================================================*/
/*  4.2 Pull AAPL daily returns                                              */
/*===========================================================================*/
proc sql;
    create table proj.aapl_daily as
    select 
        date,
        permno,
        prc as price,
        ret as ret_aapl,
        vol as volume,
        shrout as shares_outstanding
    from crsp.dsf
    where permno = 14593
      and date between '01JAN2009'd and '30JUN2025'd
    order by date;
quit;

/*===========================================================================*/
/*  4.3 Pull CRSP value-weighted market return                               */
/*===========================================================================*/
proc sql;
    create table work.market as
    select 
        date,
        vwretd as ret_mkt,
        sprtrn as ret_sp500
    from crsp.dsi
    where date between '01JAN2009'd and '30JUN2025'd
    order by date;
quit;

/*===========================================================================*/
/*  4.4 Merge AAPL + market                                                  */
/*===========================================================================*/
proc sql;
    create table work.aapl_returns as
    select 
        a.date,
        a.ret_aapl,
        m.ret_mkt,
        m.ret_sp500,
        a.price,
        a.volume
    from proj.aapl_daily as a
    inner join work.market as m on a.date = m.date
    order by a.date;
quit;

/*===========================================================================*/
/*  4.5 Build split-adjusted price series                                    */
/*  CRSP returns are split-adjusted; raw prices are not.                     */
/*  We back-compound returns from the most recent price.                     */
/*===========================================================================*/
proc sort data=work.aapl_returns out=work.rev; 
    by descending date; 
run;

data work.rev_adj;
    set work.rev;
    retain adj_price;
    if _n_ = 1 then adj_price = price;
    else adj_price = lag(adj_price) / (1 + lag(ret_aapl));
run;

proc sort data=work.rev_adj out=proj.aapl_returns; 
    by date; 
run;

/* Add trading-day index (needed for event windows) */
data proj.aapl_returns;
    set proj.aapl_returns;
    trading_day + 1;
run;

/*===========================================================================*/
/*  4.6 Summary statistics                                                   */
/*===========================================================================*/
proc sql;
    select 
        count(*)                as n_days        format=comma10.,
        min(date)               as start_date    format=yymmdd10.,
        max(date)               as end_date      format=yymmdd10.,
        mean(ret_aapl)          as mean_aapl     format=percent8.3,
        std(ret_aapl)           as std_aapl      format=percent8.3,
        mean(ret_mkt)           as mean_mkt      format=percent8.3,
        corr(ret_aapl, ret_mkt) as corr_aapl_mkt format=5.3
    from proj.aapl_returns;
    title2 "AAPL Returns Summary";
quit;

proc print data=proj.aapl_returns (obs=5);
    var date price adj_price ret_aapl ret_mkt;
    title2 "First 5 trading days (check adj_price is much lower than price)";
run;

/*===========================================================================*/
/*  4.7 Charts                                                               */
/*===========================================================================*/
ods graphics on / width=9in height=5in;

title2 "Apple Stock - Split-Adjusted Price (2009-2025)";
proc sgplot data=proj.aapl_returns;
    series x=date y=adj_price / lineattrs=(thickness=2 color=darkgreen);
    xaxis label="Date";
    yaxis label="Split-Adjusted Price ($)" grid;
run;

title2 "Apple Stock - Raw (Unadjusted) Price for Reference";
proc sgplot data=proj.aapl_returns;
    series x=date y=price / lineattrs=(thickness=1 color=gray);
    xaxis label="Date";
    yaxis label="Raw Price ($)" grid;
run;

ods graphics off;
title;