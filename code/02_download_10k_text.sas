/*****************************************************************************
 *  MODULE 02 — DOWNLOAD ALL 15 APPLE 10-K DOCUMENTS FROM SEC EDGAR
 *  ---------------------------------------------------------------------------
 *  For each URL in proj.apple_10k_list:
 *    1. Download the 10-K HTML file
 *    2. Strip HTML tags -> plain text
 *    3. Save to disk as a .txt file
 *    4. Also concatenate into a single SAS dataset with one row per filing
 *  
 *  Output:
 *    - Text files in ~/apple_sentiment_project/texts/
 *    - proj.apple_10k_text  (one row per 10-K with extracted text)
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 02: Downloading Apple 10-K Documents";

/*===========================================================================*/
/*  2.0 Create text output folder                                            */
/*===========================================================================*/
options dlcreatedir;
libname textout "~/apple_sentiment_project/texts";
libname textout clear;

/*===========================================================================*/
/*  2.1 Loop through each filing and download                                */
/*===========================================================================*/
/* Read the 10-K list into macro variables */
data _null_;
    set proj.apple_10k_list end=last;
    call symputx(cats('url',_n_),    filing_url);
    call symputx(cats('fyear',_n_),  fyear);
    if last then call symputx('n_filings', _n_);
run;

%put NOTE: Will download &n_filings filings;

/*===========================================================================*/
/*  2.2 Macro to download one filing                                         */
/*===========================================================================*/
%macro download_one(i);
    %put NOTE: Downloading filing &i of &n_filings (FY &&fyear&i);
    
    filename htmlin "~/apple_sentiment_project/texts/aapl_10k_&&fyear&i...html";
    
    proc http
        url="&&url&i"
        method="GET"
        out=htmlin;
        headers
            "User-Agent"="Matthieu Lafont matthieu.lafont@mail.mcgill.ca"
            "Accept-Encoding"="identity";
    run;
    
    %put NOTE: Filing &i HTTP status: &SYS_PROCHTTP_STATUS_CODE;
    
    filename htmlin clear;
    
    /* Small delay to respect SEC rate limit (10 req/sec) */
    data _null_;
        rc = sleep(0.2, 1);  /* 0.2 seconds */
    run;
%mend;

/*===========================================================================*/
/*  2.3 Run the loop                                                         */
/*===========================================================================*/
%macro download_all;
    %do i = 1 %to &n_filings;
        %download_one(&i);
    %end;
%mend;

%download_all;

/*===========================================================================*/
/*  2.4 Now read each downloaded HTML file and strip HTML tags               */
/*===========================================================================*/
data proj.apple_10k_text;
    length fyear 8 filing_date 8 raw_chunk $32000 clean_text $32000;
    format filing_date yymmdd10.;
    
    set proj.apple_10k_list;
    
    /* Build the local path */
    local_path = cats("~/apple_sentiment_project/texts/aapl_10k_", 
                      put(fyear,4.), ".html");
    
    /* Initialize concatenated text holder */
    length full_text $32000;  /* Will grow per observation via buffer */
    
    keep fyear filing_date report_date local_path;
run;

/*===========================================================================*/
/*  2.5 Read each HTML file and extract plain text                           */
/*  Strategy: stream file line-by-line, strip tags, keep word count          */
/*===========================================================================*/

/* Delete if exists */
proc datasets library=proj nolist;
    delete text_tokens;
quit;

%macro extract_text;
    %do i = 1 %to &n_filings;
        
        filename htmlfile 
            "~/apple_sentiment_project/texts/aapl_10k_&&fyear&i...html";
        
        /* Read file line-by-line, strip tags, keep only word content */
        data work.lines_&i;
            length fyear 8 line_text $2000;
            fyear = &&fyear&i;
            infile htmlfile lrecl=32000 truncover end=eof encoding="utf-8";
            input line_text $char2000.;
            
            /* Remove HTML tags */
            line_text = prxchange('s/<[^>]+>/ /', -1, line_text);
            /* Decode common HTML entities */
            line_text = tranwrd(line_text, '&nbsp;', ' ');
            line_text = tranwrd(line_text, '&amp;',  '&');
            line_text = tranwrd(line_text, '&lt;',   '<');
            line_text = tranwrd(line_text, '&gt;',   '>');
            line_text = tranwrd(line_text, '&#160;', ' ');
            line_text = tranwrd(line_text, '&#8217;', "'");
            line_text = tranwrd(line_text, '&#8220;', '"');
            line_text = tranwrd(line_text, '&#8221;', '"');
            /* Strip non-printable chars */
            line_text = compress(line_text, , 'cntrl');
            /* Lowercase */
            line_text = lowcase(line_text);
            
            if length(strip(line_text)) > 0 then output;
        run;
        
        filename htmlfile clear;
    %end;
%mend;

%extract_text;

/*===========================================================================*/
/*  2.6 Stack all yearly line-datasets into one big dataset of text lines    */
/*===========================================================================*/
data proj.apple_10k_lines;
    set 
    %do i = 1 %to &n_filings;
        work.lines_&i
    %end;
    ;
run;

/*===========================================================================*/
/*  2.7 Tokenize — split lines into individual words                         */
/*===========================================================================*/
data proj.apple_10k_tokens;
    set proj.apple_10k_lines;
    length word $40;
    
    /* Keep only alphabetic words */
    clean_line = prxchange('s/[^a-z ]/ /', -1, line_text);
    
    n_words = countw(clean_line, ' ');
    do i = 1 to n_words;
        word = scan(clean_line, i, ' ');
        if length(word) >= 2 then output;
    end;
    
    keep fyear word;
run;

/*===========================================================================*/
/*  2.8 Word counts per filing (sanity check)                                */
/*===========================================================================*/
proc sql;
    create table work.wc_check as
    select fyear, count(*) as word_count
    from proj.apple_10k_tokens
    group by fyear
    order by fyear;
quit;

proc print data=work.wc_check;
    title2 "Word Count per 10-K (sanity check)";
    title3 "Expect 30,000-80,000 words per filing";
run;

title;