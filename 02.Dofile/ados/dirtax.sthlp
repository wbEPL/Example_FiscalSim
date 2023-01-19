{smcl}
{* *! version 1.0.0  23December2018}{...}
{cmd:help dirtax}
{hline}

{title:Title}

{p2colset 5 24 26 2}{...}
{p2col :{cmd:dirtax} {hline 1} Command useful for backing out net and gross incomes}{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 23 2}
{opt dirtax} {varlist max=1 numeric} {ifin} {cmd:,} 
{opt Rates(numlist >=0 min=1)}
{opt GENerate(newvarname)}
[{opt THolds(numlist >=0 min=1)}
{opt NETinput}
{opt GROSSinput}
{opt taxfree(varlist max=1 numeric)}
]


{title:Description}


{pstd}
{cmd:dirtax} Takes a vector of incomes, rates, and thresholds and outputs a vector with either gross or net incomes.

{title:Options}

{phang}
{opt rates} Numlist of tax rates which apply to every threshold specified in the tholds option. Note that the command, by default, will sort the list. 

{phang}
{opt generate} Name of new variable which will contain the output vector of incomes.

{phang}
{opt tholds} Numlist with thresholds indicating where each tax bracket begins. Note that the command, by default, will sort the list. 

{phang}
{opt netinput} Indicates to the command that the variable specified in varlist is in NET terms, and thus the command will gross this up.

{phang}
{opt grossinput} Indicates to the command that the variable specified in varlist is in GROSS terms, and thus the command will net this down.

{phang}
{opt taxfree} Variable specified here will be subtracted from the varlist to be processed, before the net or grossing of income is done. Final output will include this in its calculation.

{title:Example}
sysuse auto, clear
rename price income

//Assume income variable is in net, we want to gross it up

dirtax income, netinput rates(5 8 14 20) tholds(0 4200 7000 13000) gen(gross_income)
sum income gross_income

//Convert it back to net incomes

dirtax gross_income, grossinput rates(5 8 14 20) tholds(0 4200 7000 13000) gen(net_income)
sum income gross_income net_income

//Assume a 1000 unit, tax free exemption
gen tfree=1000
dirtax income, netinput taxfree(tfree) rates(5 8 14 20) tholds(0 4200 7000 13000) gen(gross_income2)
sum income gross_income2

//Convert the same vector back to net incomes
dirtax gross_income2, grossinput taxfree(tfree) rates(5 8 14 20) tholds(0 4200 7000 13000) gen(net_income2)
sum income gross_income2 net_income2

{title:Author:}

{pstd}
Paul Corral{break}
The World Bank - Poverty and Equity Global Practice {break}
Washington, DC{break}
pcorralrodas@worldbank.org{p_end}


{pstd}
Any error or omission is the author's responsibility alone.

 