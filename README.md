New-AzureTestVM - Add a new VM to your Domain on Azure
======================================================

            

I wanted to deploy Server 10 VM joined to my domain and leveraged Azure Automation to do that. So now when I need a new VM, just have to invoke the Runbook and a domain joined new server is ready in well over 10 minutes.


I have a blog post explaining how this works here :


 


http://www.dexterposh.com/2014/10/azure-automation-deploy-domain-join-vm.html


I have changed the parameter $AzureConnectionString to $AzureSubscriptionName based on Joe Levy's feedback on the gist.


[UPDATE] : Server 2016 TP 3 was released yesterday and I have updated the Script to expose few more parameters e.g. DomainCredName , DomainName etc.


Snippet of the Workflow parameters.


 

 
 


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
