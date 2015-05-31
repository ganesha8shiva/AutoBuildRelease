:: Enter Branch Name
set /p branch="Enter Branch Name: "

:: Execute ps1 file and pass parameters
Powershell.exe -executionpolicy remotesigned -File prepareRelease.ps1 %branch%

:: To keep console open
PAUSE