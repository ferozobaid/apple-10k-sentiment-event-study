/*****************************************************************************
 *  MODULE 02c — ROBUST TEXT EXTRACTION (handles iXBRL filings 2016+)
 *  ---------------------------------------------------------------------------
 *  Issue: Post-2015 Apple 10-Ks use iXBRL with very long single-line HTML.
 *  Fix:   Read raw bytes into chunks, strip tags, re-split on whitespace.
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 02c: Robust Text Extraction";

/* Rebuild macro variables from the filings list */
data _null_;
    set proj.apple_10k_list end=last;
    call symputx(cats('fyear',_n_), fyear);
    if last then call symputx('n_filings', _n_);
run;

%put NOTE: Processing &n_filings filings;

/*===========================================================================*/
/*  2c.1 Read each HTML as raw 32K chunks, then extract words                */
/*===========================================================================*/
%macro extract_v2;
    %do i = 1 %to &n_filings;
        
        %put NOTE: --- Extracting FY &&fyear&i ---;
        
        filename htmlfile 
            "~/apple_sentiment_project/texts/aapl_10k_&&fyear&i...html" 
            recfm=n;   /* read as stream, not by line */
        
        /* Read file in 32K chunks */
        data work.chunks_&i;
            length fyear 8 chunk $32000;
            fyear = &&fyear&i;
            infile htmlfile recfm=n lrecl=32000;
            input chunk $char32000.;
            output;
        run;
        
        /* Clean each chunk: strip HTML tags, keep only letters */
        data work.clean_&i;
            set work.chunks_&i;
            length cleaned $32000;
            
            /* Strip HTML tags */
            cleaned = prxchange('s/<[^>]*>/ /', -1, chunk);
            /* Strip HTML entities like &nbsp; &amp; &#160; */
            cleaned = prxchange('s/&[a-zA-Z#0-9]+;/ /', -1, cleaned);
            /* Keep only letters and spaces, lowercase */
            cleaned = lowcase(cleaned);
            cleaned = prxchange('s/[^a-z ]/ /', -1, cleaned);
            /* Collapse multiple spaces */
            cleaned = prxchange('s/\s+/ /', -1, cleaned);
            
            keep fyear cleaned;
        run;
        
        filename htmlfile clear;
    %end;
%mend;

%extract_v2;

/*===========================================================================*/
/*  2c.2 Stack all cleaned chunks into one dataset                           */
/*===========================================================================*/
data proj.apple_10k_clean;
    set 
    %do i = 1 %to &n_filings;
        work.clean_&i
    %end;
    ;
run;

/*===========================================================================*/
/*  2c.3 Tokenize — extract one word per row                                 */
/*===========================================================================*/
data proj.apple_10k_tokens;
    set proj.apple_10k_clean;
    length word $40;
    n_words = countw(cleaned, ' ');
    do i = 1 to n_words;
        word = scan(cleaned, i, ' ');
        if length(word) >= 2 then output;
    end;
    keep fyear word;
run;

/*===========================================================================*/
/*  2c.4 Word counts per year — the key sanity check                         */
/*===========================================================================*/
proc sql;
    create table work.wc_check as
    select fyear, count(*) as word_count format=comma10.
    from proj.apple_10k_tokens
    group by fyear
    order by fyear;
quit;

proc print data=work.wc_check;
    title2 "Word Count per 10-K (expect 30,000 - 100,000 each)";
run;

title;