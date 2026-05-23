/*****************************************************************************
 *  MODULE 01 — APPLE 10-K FILINGS LIST (hardcoded from SEC EDGAR)
 *  ---------------------------------------------------------------------------
 *  Manually hardcoded from SEC EDGAR public records.
 *  Verified URLs, one 10-K per fiscal year 2010-2024.
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 01: Apple 10-K Filings List";

/*===========================================================================*/
/*  Hardcoded list of Apple 10-K filings                                     */
/*===========================================================================*/
data proj.apple_10k_list;
    length accession_clean $25 primaryDocument $50 filing_url $300;
    input fyear filing_date :yymmdd10. report_date :yymmdd10. 
          accession_clean $ primaryDocument $;
    
    filing_url = cats(
        "https://www.sec.gov/Archives/edgar/data/320193/",
        accession_clean, "/", primaryDocument);
    
    format filing_date report_date yymmdd10.;
    
    datalines;
2010 2010-10-27 2010-09-25 000119312510238044 d10k.htm
2011 2011-10-26 2011-09-24 000119312511282113 d220209d10k.htm
2012 2012-10-31 2012-09-29 000119312512444068 d411355d10k.htm
2013 2013-10-30 2013-09-28 000119312513416534 d590790d10k.htm
2014 2014-10-27 2014-09-27 000119312514383437 d783162d10k.htm
2015 2015-10-28 2015-09-26 000119312515356351 d17062d10k.htm
2016 2016-10-26 2016-09-24 000162828016020309 a201610-k9242016.htm
2017 2017-11-03 2017-09-30 000032019317000070 a10-k20179302017.htm
2018 2018-11-05 2018-09-29 000032019318000145 a10-k20189292018.htm
2019 2019-10-31 2019-09-28 000032019319000119 a10-k20199282019.htm
2020 2020-10-30 2020-09-26 000032019320000096 aapl-20200926.htm
2021 2021-10-29 2021-09-25 000032019321000105 aapl-20210925.htm
2022 2022-10-28 2022-09-24 000032019322000108 aapl-20220924.htm
2023 2023-11-03 2023-09-30 000032019323000106 aapl-20230930.htm
2024 2024-11-01 2024-09-28 000032019324000123 aapl-20240928.htm
;
run;

proc sort data=proj.apple_10k_list; by filing_date; run;

/*===========================================================================*/
/*  Summary                                                                  */
/*===========================================================================*/
proc sql;
    select count(*)         as n_10ks         label="Total 10-K Filings",
           min(filing_date) as first_filing   format=yymmdd10.,
           max(filing_date) as last_filing    format=yymmdd10.
    from proj.apple_10k_list;
    title2 "Sample Coverage";
quit;

proc print data=proj.apple_10k_list;
    var fyear filing_date report_date primaryDocument;
    title2 "All Apple 10-K Filings (2010-2024)";
run;

proc print data=proj.apple_10k_list (obs=3);
    var filing_date filing_url;
    title2 "Sample URLs - paste one into browser to verify";
run;

title;