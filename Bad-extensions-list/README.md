List over bad extensions to Chrome/Edge. Bad because they have malware or potential dangerous code in the luggage. These should be added to Policy in Azure that restrict users from 

I made this based on https://github.com/palant/malicious-extensions-list
Credit to https://github.com/palant

I then added to the list extensions, that was listed at various security companies listings. 
So the list.txt is a combination of what i found and the list from palant. The PS Script will
extract unique values from the list and ignore empty rows and rows starting with #

Keep in mind, one value per row.

The output is a list that will include extensions that might have been removed from Chrome store. 
I will use this list to blacklist extensions, using a policy, from being installed to any company device

Feel free to use/modify script

Trond Hoiberg, 30 sept 2025
