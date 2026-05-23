/*****************************************************************************
 *  MODULE 05b — FIX THE CONSENSUS MERGE (explicit aliases)
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 05b: Computing Earnings Surprise";

/*===========================================================================*/
/*  5b.1 Build link table: for each fiscal year, find the latest consensus   */
/*       that was issued BEFORE the announcement                             */
/*===========================================================================*/
proc sql;
    create table work.latest_date as
    select 
        a.fiscal_period_end      as fpe   format=yymmdd10.,
        a.announce_date          as ann   format=yymmdd10.,
        max(c.consensus_date)    as latest_consensus format=yymmdd10.
    from work.aapl_actuals as a
    inner join work.aapl_consensus as c
        on a.fiscal_period_end = c.fiscal_period_end
       and c.consensus_date < a.announce_date
    group by a.fiscal_period_end, a.announce_date
    order by fpe;
quit;

proc print data=work.latest_date;
    title2 "Latest Pre-Announcement Consensus Date per Fiscal Year";
run;

/*===========================================================================*/
/*  5b.2 Join back to get consensus VALUES on that date                      */
/*===========================================================================*/
proc sql;
    create table work.consensus_final as
    select 
        c.ticker,
        c.fiscal_period_end,
        c.consensus_date,
        c.eps_consensus,
        c.eps_median,
        c.num_analysts,
        c.eps_stdev
    from work.aapl_consensus as c
    inner join work.latest_date as l
        on c.fiscal_period_end = l.fpe
       and c.consensus_date    = l.latest_consensus
    order by c.fiscal_period_end;
quit;

proc print data=work.consensus_final;
    title2 "Final Consensus per Fiscal Year (15 rows expected)";
run;

/*===========================================================================*/
/*  5b.3 Compute surprise                                                    */
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
        (a.eps_actual - c.eps_consensus) as eps_surprise,
        case when c.eps_stdev > 0 
             then (a.eps_actual - c.eps_consensus) / c.eps_stdev 
             else . end as sue_stdev,
        case when abs(c.eps_consensus) > 0
             then (a.eps_actual - c.eps_consensus) / abs(c.eps_consensus)
             else . end as surprise_pct
    from work.aapl_actuals as a
    inner join work.consensus_final as c 
        on a.fiscal_period_end = c.fiscal_period_end
    order by a.fiscal_period_end;
quit;

/*===========================================================================*/
/*  5b.4 Add price at announcement for price-scaled SUE                      */
/*===========================================================================*/
proc sql;
    create table proj.aapl_surprise as
    select 
        s.*,
        year(s.fiscal_period_end) as fyear,
        r.adj_price               as price_at_announce,
        case when r.adj_price > 0
             then (s.eps_actual - s.eps_consensus) / r.adj_price
             else . end as sue_price
    from work.surprise as s
    left join proj.aapl_returns as r
        on s.announce_date = r.date
    order by s.fiscal_period_end;
quit;

/*===========================================================================*/
/*  5b.5 Display final surprise table                                        */
/*===========================================================================*/
proc print data=proj.aapl_surprise label;
    var fyear fiscal_period_end announce_date 
        eps_consensus eps_actual eps_surprise surprise_pct sue_stdev
        num_analysts;
    format eps_consensus eps_actual eps_surprise 8.3
           surprise_pct sue_stdev 8.3;
    label fyear             = "FY"
          fiscal_period_end = "FY End"
          announce_date     = "Announcement"
          eps_consensus     = "Consensus EPS"
          eps_actual        = "Actual EPS"
          eps_surprise      = "Surprise $"
          surprise_pct      = "Surprise %"
          sue_stdev         = "SUE (scaled)"
          num_analysts      = "# Analysts";
    title2 "Apple Earnings Surprise by Fiscal Year (2010-2024)";
run;

/*===========================================================================*/
/*  5b.6 Summary stats                                                       */
/*===========================================================================*/
proc sql;
    select 
        count(*)             as n_obs              label="N Observations",
        mean(eps_surprise)   as mean_surprise_dol  format=8.3,
        mean(surprise_pct)   as mean_surprise_pct  format=percent8.2,
        sum(case when eps_surprise>0 then 1 else 0 end) as n_beats label="N Beats",
        sum(case when eps_surprise<0 then 1 else 0 end) as n_miss  label="N Misses"
    from proj.aapl_surprise;
    title2 "Earnings Surprise Summary Stats";
quit;

/*===========================================================================*/
/*  5b.7 Bar chart                                                           */
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