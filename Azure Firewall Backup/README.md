# SYNOPSIS
	This Azure Automation runbook automates Azure Firewall backup to Blob storage and deletes old backups from blob storage. 

# DESCRIPTION
	You should use this Runbook if you want manage Azure Firewall backups in Blob storage. 
	This is a PowerShell runbook.

# PARAMETERS
## ResourceGroupName
	Specifies the name of the resource group where the Azure Firewall is located
	
## AzureFirewallName
	Specifies the name of the Azure Firewall which script will backup
	
## StorageAccountName
	Specifies the name of the storage account where backup file will be uploaded

## StorageKey
	Specifies the storage key of the storage account

## BlobContainerName
	Specifies the container name of the storage account where backup file will be uploaded. Container will be created if it does not exist.

## RetentionDays
	Specifies the number of days how long backups are kept in blob storage. Script will remove all older files from container. 
	For this reason dedicated container must be only used for this script.

# OUTPUTS
	Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.

# NOTES
    AUTHOR: Francesco Molfese
    LASTEDIT: Jul 10, 2019 
