rem Batch script to build zip and store it to ../depls2.zip
rem Requires 7za

del ..\livesim3.zip
7za a -mx=9 ../livesim3.zip assets flash fonts game libs sound *.lua LIVESIM2_LOGLEVEL