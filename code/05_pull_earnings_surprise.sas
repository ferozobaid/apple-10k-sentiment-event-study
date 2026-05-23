/*****************************************************************************
 *  MODULE 05 — PULL EARNINGS SURPRISE FROM IBES
 *  ---------------------------------------------------------------------------
 *  Data: IBES Summary (consensus) + IBES Actuals
 *  Apple IBES ticker = "AAPL" (IBES uses tickers, not PERMNO)
 *  ---------------------------------------------------------------------------
 *  Output: proj.aapl_surprise — one row per fiscal year with:
 *    - consensus EPS estimate
 *    - actual EPS reported
 *    - surprise (actual - consensus)
 *    - SUE (surprise scaled by price)
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 05: Pulling Apple Earnings Surprise from IBES";

/*===========================================================================*/
/*  5.1 Confirm Apple's IBES ticker                                          */
/*===========================================================================*/
proc sql;
    create table work.aapl_ibes as
    select distinct ticker, cname, cusip
    from ibes.idsum
    where upcase(cname) contains "APPLE INC"
      and ticker = "AAPL";
quit;

proc print data=work.aapl_ibes;
    title2 "AAPL IBES Ticker Confirmation";
run;

/*===========================================================================*/
/*  5.2 Pull actual EPS from IBES actuals file                               */
/*  measure='EPS', fiscal period='ANN' = annual EPS (for 10-K match)         */
/*===========================================================================*/
proc sql;
    create table work.aapl_actuals as
    select 
        ticker,
        pends          as fiscal_period_end   format=yymmdd10.,
        anndats        as announce_date       format=yymmdd10.,
        value          as eps_actual,
        pdicity        as periodicity,
        measure
    from ibes.act_epsus
    where ticker = "AAPL"
      and measure = "EPS"
      and pdicity = "ANN"      /* annual EPS */
      and year(pends) between 2010 and 2024
    order by pends;
quit;

proc print data=work.aapl_actuals;
    title2 "Apple Annual Actual EPS by Fiscal Year";
run;

/*===========================================================================*/
/*  5.3 Pull consensus (analyst mean) EPS estimates                          */
/*  statpers = statistical period (monthly snapshots)                        */
/*  We want the consensus from the month BEFORE the earnings announcement    */
/*===========================================================================*/
proc sql;
    create table work.aapl_consensus as
    select 
        ticker,
        statpers       as consensus_date      format=yymmdd10.,
        fpedats        as fiscal_period_end   format=yymmdd10.,
        meanest        as eps_consensus,
        medest         as eps_median,
        numest         as num_analysts,
        stdev          as eps_stdev,
        fpi
    from ibes.statsum_epsus
    where ticker = "AAPL"
      and measure = "EPS"
      and fpi = "1"            /* 1 = next annual estimate */
      and year(fpedats) between 2010 and 2024
    order by fpedats, statpers;
quit;

/*===========================================================================*/
/*  5.4 For each fiscal year, keep the LAST consensus before actual announce */
/*===========================================================================*/
proc sql;
    create table work.consensus_final as
    select c.*
    from work.aapl_consensus as c
    inner join (
        select fiscal_period_end, max(consensus_date) as latest_consensus
        from work.aapl_consensus as c2
        inner join work.aapl_actuals as a on c2.fiscal_period_end = a.fiscal_period_end
        where c2.consensus_date < a.announce_date
        group by fiscal_period_end
    ) as m 
    on c.fiscal_period_end = m.fiscal_period_end 
    and c.consensus_date = m.latest_consensus
    order by fiscal_period_end;
quit;

/*===========================================================================*/
/*  5.5 Merge consensus + actual + compute surprise                          */
/*===========================================================================*/
proc sql;
    create table work.surprise as
    select 
        a.ticker,
        a.fiscal_period_end,
        a.announce_date,
        a.eps_actual,
        c.eps_consensus,
        c.num_analysts,
        c.eps_stdev,
        (a.eps_actual - c.eps_consensus)           as eps_surprise,
        case when c.eps_stdev > 0 
             then (a.eps_actual - c.eps_consensus) / c.eps_stdev 
             else . end                            as sue_stdev   
             label="SUE (scaled by analyst dispersion)",
        case when abs(c.eps_consensus) > 0
             then (a.eps_actual - c.eps_consensus) / abs(c.eps_consensus)
             else . end                            as surprise_pct
             label="Surprise as % of consensus"
    from work.aapl_actuals as a
    inner join work.consensus_final as c 
        on a.fiscal_period_end = c.fiscal_period_end
    order by fiscal_period_end;
quit;

/*===========================================================================*/
/*  5.6 Add AAPL price on the announcement date (for price-scaled SUE)       */
/*===========================================================================*/
proc sql;
    create table proj.aapl_surprise as
    select 
        s.*,
        year(s.fiscal_period_end) as fyear,
        r.adj_price               as price_at_announce,
        (s.eps_actual - s.eps_consensus) / r.adj_price as sue_price
            label="SUE (surprise / price)"
    from work.surprise as s
    left join proj.aapl_returns as r
        on s.announce_date = r.date
    order by fiscal_period_end;
quit;

/*===========================================================================*/
/*  5.7 Final display                                                        */
/*===========================================================================*/
proc print data=proj.aapl_surprise label;
    var fyear fiscal_period_end announce_date 
        eps_consensus eps_actual eps_surprise surprise_pct sue_stdev sue_price
        num_analysts;
    title2 "Apple Earnings Surprise by Fiscal Year (2010-2024)";
run;

/*===========================================================================*/
/*  5.8 Summary                                                              */
/*===========================================================================*/
proc sql;
    select 
        count(*)             as n_obs,
        mean(eps_surprise)   as mean_surprise    format=8.3,
        mean(surprise_pct)   as mean_pct         format=percent8.2,
        sum(eps_surprise>0)  as n_beats          label="Quarters Beat",
        sum(eps_surprise<0)  as n_miss           label="Quarters Missed"
    from proj.aapl_surprise;
    title2 "Earnings Surprise Summary Stats";
quit;

/*===========================================================================*/
/*  5.9 Chart                                                                */
/*===========================================================================*/
ods graphics on / width=9in height=5in;
title2 "Apple Earnings Surprise by Fiscal Year (% of Consensus)";
proc sgplot data=proj.aapl_surprise;
    vbar fyear / response=surprise_pct datalabel 
                 fillattrs=(color=darkblue);
    refline 0 / axis=y lineattrs=(pattern=dash color=gray);
    xaxis label="Fiscal Year";
    yaxis label="Surprise % (Actual vs Consensus)" grid;
run;
ods graphics off;

title;