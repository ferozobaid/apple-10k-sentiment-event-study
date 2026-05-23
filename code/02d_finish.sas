/*****************************************************************************
 *  MODULE 02d — FINISH STEP 2 (stack clean datasets + tokenize)
 *****************************************************************************/

libname proj "~/apple_sentiment_project";
title "MODULE 02d: Finishing Text Extraction";

/*===========================================================================*/
/*  Stack all clean_1 through clean_15 into one dataset                      */
/*===========================================================================*/
data proj.apple_10k_clean;
    set work.clean_1  work.clean_2  work.clean_3  work.clean_4  work.clean_5
        work.clean_6  work.clean_7  work.clean_8  work.clean_9  work.clean_10
        work.clean_11 work.clean_12 work.clean_13 work.clean_14 work.clean_15;
run;

/*===========================================================================*/
/*  Tokenize — extract one word per row                                      */
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
/*  Word counts per year — sanity check                                      */
/*===========================================================================*/
proc sql;
    create table work.wc_check as
    select fyear, count(*) as word_count format=comma10.
    from proj.apple_10k_tokens
    group by fyear
    order by fyear;
quit;

proc print data=work.wc_check;
    title2 "Word Count per 10-K";
    title3 "Expect 30,000 to 100,000 words per filing";
run;

title;