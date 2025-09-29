Most of the pattern list is from https://github.com/secprentice/PowerShellWatchlist/blob/master/badshell.txt
Credits to:
https://github.com/secprentice

And i made this inspired by https://github.com/YossiSassi

This script is reading all logs and search for expressions collected from the pattern list. It will display all findings in a Gridview and create a Result.csv file. It then moves all inspected logs to a folder Checked and zip them into one file and store it in folder that has name = current date