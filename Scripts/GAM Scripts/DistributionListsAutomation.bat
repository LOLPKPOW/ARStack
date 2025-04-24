@echo off
REM GAM Batch Export: Google Groups and Members

echo Exporting group metadata...
gam print groups name description email > groups_descriptions.csv

echo Exporting group members...
gam redirect csv ./group-members.csv multiprocess csv groups_descriptions.csv gam print group-members group ~email

echo All done. Output saved to groups_descriptions.csv and group-members.csv