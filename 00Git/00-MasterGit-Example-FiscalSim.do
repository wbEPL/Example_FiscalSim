//  Program:    00-MasterGit-Example_FiscalSim.do
**#  Task:      Running Git from within Stata  
//  Project:    GitHub
//  Author:     Yared Seid - 2023Feb04


*===============================================================================
**# Preamble
*===============================================================================	
	version 17
	clear all
	set more off
	macro drop _all
	set linesize 200	
	set type double, permanently
	
	*****************************
	local currDir: sysdir STATA				// change the directory to "...Stata\Data"
	cd "`currDir'Data"

global EPL_training_GitHub_url "https://github.com/wbEPL/Example_FiscalSim/"

global ys_pathProject	 "C:\Users\wb484182\OneDrive - WBG\1ys_EPL\EPL-Trainings\2023-January-March-everyMonday\ExampleCodesOnGitHub"

global EPL_training_egPath "${ys_pathProject}\Example_FiscalSim"
	*****************************



*===============================================================================

**# Running Yared's basic GitHub batch files  
*! "`pathGitGlobalCode'\\01-Git-globalProfile.bat" // needs to be run only once
*===============================================================================

**# Initializing a directory to Git repository
cd "${ys_pathProject}"
*! git init 				// needs to be done only once 

**# Cloning EPL 2023 example files to my Git repository
*! git clone "${EPL_training_GitHub_url}"  // needs to be done only once  

* Now the project folder is cloned from the EPL GitHub website 
cd "${EPL_training_egPath}"
*! .gitignore 00Git/				// ignoring my 00Git folder 




*===============================================================================

	local currDir: sysdir STATA				
	cd "`currDir'Data"
*===============================================================================

exit 

