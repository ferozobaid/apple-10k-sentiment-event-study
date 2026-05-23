/*****************************************************************************
 *  MODULE 03 — LOAD LM DICTIONARY + SCORE SENTIMENT (fixed: reads from disk)
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 03: Sentiment Scoring with Loughran-McDonald Dictionary";

/*===========================================================================*/
/*  3.1 Import the LM dictionary from your uploaded CSV                      */
/*===========================================================================*/
proc import datafile="~/apple_sentiment_project/LM_MasterDictionary.csv"
            out=work.lm_raw
            dbms=csv replace;
    getnames=yes;
    guessingrows=max;
run;

/* Peek at structure */
proc contents data=work.lm_raw varnum; 
    title2 "LM Dictionary Structure (column names)"; 
run;

/*===========================================================================*/
/*  3.2 Build clean dictionary with sentiment flags                          */
/*===========================================================================*/
data proj.lm_dict;
    set work.lm_raw;
    length word $40;
    word = lowcase(strip(Word));
    
    /* In the LM file, category columns are YEAR-numeric.
       Non-zero value = word belongs to that category. */
    is_negative     = (Negative     ne 0);
    is_positive     = (Positive     ne 0);
    is_uncertainty  = (Uncertainty  ne 0);
    is_litigious    = (Litigious    ne 0);
    is_strongmodal  = (Strong_Modal ne 0);
    is_weakmodal    = (Weak_Modal   ne 0);
    is_constraining = (Constraining ne 0);
    
    keep word is_negative is_positive is_uncertainty is_litigious
         is_strongmodal is_weakmodal is_constraining;
run;

/*===========================================================================*/
/*  3.3 Sanity check — expected counts                                       */
/*  Real LM 2025 dictionary has ~86,000 words                                */
/*  Negative: ~2,350  Positive: ~350  Uncertainty: ~300  Litigious: ~730     */
/*===========================================================================*/
proc sql;
    select 
        count(*)             as total_words        format=comma10.,
        sum(is_negative)     as negative_count     format=comma10.,
        sum(is_positive)     as positive_count     format=comma10.,
        sum(is_uncertainty)  as uncertainty_count  format=comma10.,
        sum(is_litigious)    as litigious_count    format=comma10.,
        sum(is_strongmodal)  as strongmodal_count  format=comma10.,
        sum(is_weakmodal)    as weakmodal_count    format=comma10.,
        sum(is_constraining) as constraining_count format=comma10.
    from proj.lm_dict;
    title2 "LM Dictionary Sanity Check";
    title3 "Expect ~86,000 total / ~2,350 neg / ~350 pos / ~300 unc";
quit;

/*===========================================================================*/
/*  3.4 Join tokens to dictionary and score each filing                      */
/*===========================================================================*/
proc sql;
    create table proj.apple_sentiment as
    select 
        t.fyear,
        count(*) as total_words format=comma10.,
        sum(coalesce(d.is_negative,0))     as neg_count     format=comma8.,
        sum(coalesce(d.is_positive,0))     as pos_count     format=comma8.,
        sum(coalesce(d.is_uncertainty,0))  as unc_count     format=comma8.,
        sum(coalesce(d.is_litigious,0))    as lit_count     format=comma8.,
        sum(coalesce(d.is_strongmodal,0))  as strmod_count  format=comma8.,
        sum(coalesce(d.is_weakmodal,0))    as weakmod_count format=comma8.,
        sum(coalesce(d.is_constraining,0)) as constr_count  format=comma8.,
        
        100*sum(coalesce(d.is_negative,0))/count(*)     as neg_pct     format=8.3,
        100*sum(coalesce(d.is_positive,0))/count(*)     as pos_pct     format=8.3,
        100*sum(coalesce(d.is_uncertainty,0))/count(*)  as unc_pct     format=8.3,
        100*sum(coalesce(d.is_litigious,0))/count(*)    as lit_pct     format=8.3,
        100*sum(coalesce(d.is_strongmodal,0))/count(*)  as strmod_pct  format=8.3,
        100*sum(coalesce(d.is_weakmodal,0))/count(*)    as weakmod_pct format=8.3,
        100*sum(coalesce(d.is_constraining,0))/count(*) as constr_pct  format=8.3,
        
        100*(sum(coalesce(d.is_positive,0)) - sum(coalesce(d.is_negative,0)))/count(*) 
            as net_tone format=8.3
    from proj.apple_10k_tokens as t
    left join proj.lm_dict as d on t.word = d.word
    group by t.fyear
    order by t.fyear;
quit;

/*===========================================================================*/
/*  3.5 Display final sentiment scores                                       */
/*===========================================================================*/
proc print data=proj.apple_sentiment label;
    var fyear total_words neg_pct pos_pct unc_pct lit_pct net_tone;
    label fyear       = "Fiscal Year"
          total_words = "Total Words"
          neg_pct     = "Negative %"
          pos_pct     = "Positive %"
          unc_pct     = "Uncertainty %"
          lit_pct     = "Litigious %"
          net_tone    = "Net Tone (Pos-Neg)";
    title2 "Apple 10-K Sentiment Scores by Year";
run;

/*===========================================================================*/
/*  3.6 Visuals — sentiment over time                                        */
/*===========================================================================*/
ods graphics on / width=9in height=5in;

title2 "Apple 10-K Negative Sentiment Over Time";
proc sgplot data=proj.apple_sentiment;
    series x=fyear y=neg_pct / lineattrs=(thickness=3 color=darkred) 
                              markers markerattrs=(symbol=circlefilled size=10);
    xaxis label="Fiscal Year" values=(2010 to 2024 by 2);
    yaxis label="Negative Word %" grid;
run;

title2 "Apple 10-K Uncertainty Sentiment Over Time";
proc sgplot data=proj.apple_sentiment;
    series x=fyear y=unc_pct / lineattrs=(thickness=3 color=darkorange) 
                              markers markerattrs=(symbol=circlefilled size=10);
    xaxis label="Fiscal Year" values=(2010 to 2024 by 2);
    yaxis label="Uncertainty Word %" grid;
run;

title2 "Apple 10-K Net Tone (Positive - Negative) Over Time";
proc sgplot data=proj.apple_sentiment;
    series x=fyear y=net_tone / lineattrs=(thickness=3 color=darkblue) 
                               markers markerattrs=(symbol=circlefilled size=10);
    refline 0 / axis=y lineattrs=(pattern=dash color=gray);
    xaxis label="Fiscal Year" values=(2010 to 2024 by 2);
    yaxis label="Net Tone (%)" grid;
run;

ods graphics off;
title;