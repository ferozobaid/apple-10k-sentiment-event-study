libname proj "~/apple_sentiment_project";

/* Force SAS to write images to a folder we own */
ods listing gpath="~/apple_sentiment_project" image_dpi=150;
ods graphics on / width=9in height=5in imagefmt=png reset=index;

/*===========================================================================*/
/*  Chart 1: THE MONEY CHART — CAAR over the event window                    */
/*===========================================================================*/
title "Cumulative Average Abnormal Return Around Apple 10-K Filings";
title2 "N=15 filings | Event Day = 0 | Market Model";
proc sgplot data=proj.apple_aar;
    series x=tau y=CAAR / lineattrs=(thickness=3 color=darkblue)
                        markers markerattrs=(symbol=circlefilled size=8);
    refline 0 / axis=x lineattrs=(pattern=dash color=red) 
                label="Filing Day" labelloc=inside;
    refline 0 / axis=y lineattrs=(pattern=dot color=gray);
    xaxis label="Trading Day Relative to Filing" values=(-5 to 10 by 1);
    yaxis label="CAAR" grid;
run;

/*===========================================================================*/
/*  Chart 2: Daily AAR bars                                                  */
/*===========================================================================*/
title "Average Abnormal Return by Event-Day";
proc sgplot data=proj.apple_aar;
    vbar tau / response=AAR fillattrs=(color=steelblue);
    refline 0 / axis=y;
    xaxis label="Trading Day Relative to Filing" values=(-5 to 10 by 1);
    yaxis label="AAR" grid;
run;

/*===========================================================================*/
/*  Chart 3: Per-filing CAR                                                  */
/*===========================================================================*/
title "CAR[0,+3] by Individual Filing";
proc sgplot data=proj.apple_car;
    vbar fyear / response=CAR_0_3 datalabel
                 fillattrs=(color=darkorange);
    refline 0 / axis=y;
    xaxis label="Fiscal Year" values=(2010 to 2024 by 1);
    yaxis label="CAR [0,+3]" grid;
run;

ods graphics off;
title;