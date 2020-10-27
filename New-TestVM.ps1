workflow New-TestVM
{
    param(
        # Sepcify the Azure Subscription Name
		[parameter(Mandatory)] 
        [String] 
        $AzureSubscriptionName,

		# Sepcify the Azure Storage Account Name to be used to store VM VHDs.
		[parameter(Mandatory)] 
        [String] 
        $StorageAccountName,
        
		# Mention the Azure Cloud Service
        [parameter(Mandatory)] 
        [String] 
        $ServiceName, 
        
		# Specfiy the name to be given to the VM 
        [parameter(Mandatory)] 
        [String] 
        $VMName,   
        
		# Specify the instance size of the VM to be deployed                 
        [parameter()] 
        [String] 
        $InstanceSize = "Medium",
		
		# Specify the name of the Automation Credential asset for Azure Authentication
		[Parameter()]
		[String] 
		$AzureCredName,

		# Specify the name of the Automation Credential asset for Local Credentials
		[Parameter()]
		[String] 
		$LocalCredName,

		# Specify the name of Automation Credential asset for Domain Credentials
		[Parameter()]
		[String] 
		$DomainCredName,

		# Specify the Domain name, the New VM will joined to this Domain.
		# Provided that the Credential Asset for Domain Cred
		[Parameter()]
		[String]
		$DomainName,

		# Exposing the Image Name here, so that you can deploy specific machines. [Default - Image Name for Server 2016 TP3 Core]
		[Paramter()]
		[String]
		$ImageName='a699494373c04fc0bc8f2bb1389d6106__WindowsServer_en-us_TP3_Container_VHD_Azure-20150819.vhd'

        
    )
    $verbosepreference = 'continue'
    
    #Get the Credentials to authenticate agains Azure
    Write-Verbose -Message "Getting the required Credentials"
    $Cred = Get-AutomationPSCredential -Name $AzureCredName
    $LocalCred = Get-AutomationPSCredential -Name $LocalCredName 
    
	# Azure Credentials and Local Credentials are a must to Authenticate to Azure and then set the local Username & Password respectively
	if ((-not $cred) -or (-not $LocalCred)) {
		Throw "Azure Credential assets with either the $AzureCredName or $LocalCredName does not exist. Check again"
	}
	
	if ($DomainName -and $DomainCredName) {
		$DomainCred = Get-AutomationPSCredential -Name $DomainCredName
		# Check if able to retrieve the Domain Cred
		if (-not $DomainCred) {
			Write-Warning -Message "As you have specfied the -DomainName & -DomainCredName parameters, You want to add the VM to domain. Check that the VM
									is placed in a VNet which can reach your AD and also DNS Setting for the VNet."
			Throw "Azure Credential assets $DomainCredName does not exist. Check again."
		}
	}
	    
    #Add the Account to the Workflow
    Write-Verbose -Message "Adding the $AzureCredName Credentials to Authenticate to Azure" 
    Add-AzureAccount -Credential $Cred 
    
    #select the Subscription
    Write-Verbose -Message "Selecting the $AzureSubscriptionName Subscription"
    Select-AzureSubscription -SubscriptionName $AzureSubscriptionName
    
    #Set the Storage for the Subscrption
    Write-Verbose -Message "Setting the Storage Account for the Subscription" 
    Set-AzureSubscription -SubscriptionName $AzureSubscriptionName -CurrentStorageAccountName $StorageAccountName       
   
        
    #use the above Image selected to build a new VM and wait for it to Boot
    $Username = $LocalCred.UserName
    $Password = $LocalCred.GetNetworkCredential().Password
    New-AzureQuickVM -Windows -ServiceName $ServiceName -Name $VMName -ImageName $imagename -Password $Password -AdminUsername $Username -SubnetNames "Rest_LAB" -InstanceSize $InstanceSize  -WaitForBoot
    Write-Verbose -Message "The VM is created and booted up now..Doing a checkpoint"
    
    #CheckPoint the workflow
    Write-Verbose -Message "Reached CheckPoint after creating the VM"
	CheckPoint-WorkFlow    
    
	if ($DomainName) {
		#Call the Function Connect-VM to import the Certificate and give back the WinRM uri
		$WinRMURi = Get-AzureWinRMUri -ServiceName $ServiceName -Name $VMName | Select-Object -ExpandProperty AbsoluteUri
    

		InlineScript 
		{ 
			$RetryCounter = 0 # Variable to store how many times the Script tries 
			do
			{
				#open a PSSession to the VM
				$Session = New-PSSession -ConnectionUri $Using:WinRMURi -Credential $Using:LocalCred -Name $using:VMName -SessionOption (New-PSSessionOption -SkipCACheck ) -ErrorAction SilentlyContinue 
				Write-Verbose -Message "Trying to open a PSSession to the VM $Using:VMName "
				Start-Sleep -Seconds 2
				$RetryCounter++
				if ($RetryCounter -ge 200) {
					Write-Warning -Message " Opening PSSession failed 200 times for the VM"
					break					
				} else {
					Write-Warning -Message "Opening PSSession to the VM failed $RetryCounter times. Trying again"
				}
			} While (! $Session)
       
			#Once the Session is opened, first step is to join the new VM to the domain
			if ($Session)
			{
				Write-Verbose -Message "Found a Session opened to VM $using:VMname. Now will try to add it to the domain"
                                    
				Invoke-command -Session $Session -ArgumentList $Using:DomainCred -ScriptBlock { 
					param($cred) 
					Add-Computer -DomainName $Using:DomainName -DomainCredential $cred
					Restart-Computer -Force
				} 
			} # end if($session)    
		} # end InlineScript
	} # end if($domainname)      
} #Workflow end


