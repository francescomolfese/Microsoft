<#
.SYNOPSIS
	This Azure Automation runbook automates Azure Firewall backup to Blob storage and deletes old backups from blob storage. 
.DESCRIPTION
	You should use this Runbook if you want manage Azure Firewall backups in Blob storage. 
	This is a PowerShell runbook.
.PARAMETER ResourceGroupName
	Specifies the name of the resource group where the Azure Firewall is located
	
.PARAMETER AzureFirewallName
	Specifies the name of the Azure Firewall which script will backup
	
.PARAMETER StorageAccountName
	Specifies the name of the storage account where backup file will be uploaded
.PARAMETER StorageKey
	Specifies the storage key of the storage account
.PARAMETER BlobContainerName
	Specifies the container name of the storage account where backup file will be uploaded. Container will be created if it does not exist.
.PARAMETER RetentionDays
	Specifies the number of days how long backups are kept in blob storage. Script will remove all older files from container. 
	For this reason dedicated container must be only used for this script.
.OUTPUTS
	Human-readable informational and error messages produced during the job. Not intended to be consumed by another runbook.
.NOTES
    AUTHOR: Francesco Molfese
    LASTEDIT: Sep 09, 2021 
    VERSION: 2.0
#>

param(
    [parameter(Mandatory=$true)]
	[String] $ResourceGroupName,
    [parameter(Mandatory=$true)]
	[String] $AzureFirewallName,
    [parameter(Mandatory=$true)]
    [String]$StorageAccountName,
    [parameter(Mandatory=$true)]
    [String]$StorageKey,
	[parameter(Mandatory=$true)]
    [string]$BlobContainerName,
	[parameter(Mandatory=$true)]
    [Int32]$RetentionDays
)

$ErrorActionPreference = 'stop'

function Login() {
	$connectionName = "AzureRunAsConnection"
	try
	{
		$servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

		Write-Verbose "Logging in to Azure..." -Verbose

		Add-AzAccount `
			-ServicePrincipal `
			-TenantId $servicePrincipalConnection.TenantId `
			-ApplicationId $servicePrincipalConnection.ApplicationId `
			-CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
	}
	catch {
		if (!$servicePrincipalConnection)
		{
			$ErrorMessage = "Connection $connectionName not found."
			throw $ErrorMessage
		} else{
			Write-Error -Message $_.Exception
			throw $_.Exception
		}
	}
}

function Create-Blob-Container([string]$blobContainerName, $storageContext) {
	Write-Verbose "Checking if blob container '$blobContainerName' already exists" -Verbose
	if (Get-AzStorageContainer -ErrorAction "Stop" -Context $storageContext | Where-Object { $_.Name -eq $blobContainerName }) {
		Write-Verbose "Container '$blobContainerName' already exists" -Verbose
	} else {
		New-AzStorageContainer -ErrorAction "Stop" -Name $blobContainerName -Permission Off -Context $storageContext
		Write-Verbose "Container '$blobContainerName' created" -Verbose
	}
}

function Export-To-Blob-Storage([string]$resourceGroupName, [string]$AzureFirewallName, [string]$storageKey, [string]$blobContainerName,$storageContext) {
	Write-Verbose "Starting Azure Firewall export" -Verbose
    
    $BackupFilename = $AzureFirewallName + (Get-Date).ToString("yyyyMMddHHmm") + ".json"
    $BackupFilePath = ($env:TEMP + "\" + $BackupFilename)
    $AzureFirewallId = (Get-AzFirewall -Name $AzureFirewallName -ResourceGroupName $resourceGroupName).id
    Export-AzResourceGroup -ResourceGroupName $resourceGroupName -Resource $AzureFirewallId -SkipAllParameterization -Path $BackupFilePath

    Write-Output "Creating request to copy Azure Firewall configuration"
    $blobname = $BackupFilename
    $output = Set-AzStorageBlobContent -File $BackupFilePath -Blob $blobname -Container $blobContainerName -Context $storageContext -Force -ErrorAction SilentlyContinue

}

function Delete-Old-Backups([int]$retentionDays, [string]$blobContainerName, $storageContext) {
	Write-Output "Removing backups older than '$retentionDays' days from blob: '$blobContainerName'"
	$isOldDate = [DateTime]::UtcNow.AddDays(-$retentionDays)
	$blobs = Get-AzStorageBlob -Container $blobContainerName -Context $storageContext
	foreach ($blob in ($blobs | Where-Object { $_.LastModified.UtcDateTime -lt $isOldDate -and $_.BlobType -eq "BlockBlob" })) {
		Write-Verbose ("Removing blob: " + $blob.Name) -Verbose
		Remove-AzStorageBlob -Blob $blob.Name -Container $blobContainerName -Context $storageContext
	}
}

Write-Verbose "Starting database backup" -Verbose

$StorageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

Login
Import-Module Az.Network
Import-Module Az.Resources

Create-Blob-Container `
	-blobContainerName $blobContainerName `
	-storageContext $storageContext
	
Export-To-Blob-Storage `
	-resourceGroupName $ResourceGroupName `
	-AzureFirewallName $AzureFirewallName `
	-storageKey $StorageKey `
	-blobContainerName $BlobContainerName `
	-storageContext $storageContext
	
Delete-Old-Backups `
	-retentionDays $RetentionDays `
	-storageContext $StorageContext `
	-blobContainerName $BlobContainerName
	
Write-Verbose "Azure Firewall backup script finished." -Verbose
