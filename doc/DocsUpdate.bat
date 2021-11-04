@echo off

REM Write the git short hash in the doxygen version number
git rev-parse --short HEAD > temp.txt
set /p HASH=<temp.txt
del temp.txt
set PROJECT_NUMBER="Git version: %HASH%"

REM Create the documentation
doxygen Doxyfile

REM Update the html version of the documentation repository
REM rm -r ../../ixpesw.bitbucket.io/egsesw/*
REM cp -r html/* ../../ixpesw.bitbucket.io/egsesw/

REM Commit the new version of the documentation and go back to the previous directory
REM cd ../../ixpesw.bitbucket.io/
REM git commit -am "Commit %HASH% of EGSE sw"
REM git push

REM cd -