Introduce TVD$XTAT
https://antognini.ch/2008/10/introduce-tvdxtat/
24 October 2008 13 Comments Written by Christian Antognini
Trivadis Extended Tracefile Analysis Tool (TVD$XTAT) is a command-line tool. Like TKPROF, its main purpose is to take a raw SQL trace file as input and generate a formatted file as output.

Why Is TKPROF Not Enough?

In late 1999, I had my first encounter with extended SQL trace, through MetaLink note Interpreting Raw SQL_TRACE and DBMS_SUPPORT.START_TRACE output (39817.1). From the beginning, it was clear that the information it provided was essential for understanding what an application is doing when it is connected to an Oracle database engine. At the same time, I was very disappointed that no tool was available for analyzing extended SQL trace files for the purpose of leveraging their content. I should note that TKPROF at that time did not provide information about wait events. After spending too much time manually extracting information from the raw trace files, I decided to write my own analysis tool: TVD$XTAT.

Currently, TKPROF provides information about wait events, but it still has three major problems that are addressed in TVD$XTAT:

As soon as the argument sort is specified, the relationship between SQL statements is lost.
Data is provided only in aggregated form. Consequently, useful information is lost.
No information about bind variables is provided.
TVD$XTAT is freeware. You can download it (presently, version 4.0 beta 7) from this page(https://antognini.ch/top/downloadable-files/). TOP(https://antognini.ch/top/) fully describes how to use it to identify performance problems. The installation is documented in the README file.

It goes without saying that all feedbacks about TVD$XTAT are highly welcome.

