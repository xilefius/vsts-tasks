Trace-VstsEnteringInvocation $MyInvocation
Import-VstsLocStrings "$PSScriptRoot\Task.json"

try{

    $ServiceName = Get-VstsInput -Name ServiceName -Require
    $ServiceLocation = Get-VstsInput -Name ServiceLocation
    $StorageAccount = Get-VstsInput -Name StorageAccount -Require
    $CsPkg = Get-VstsInput -Name CsPkg -Require
    $CsCfg = Get-VstsInput -Name CsCfg -Require
    $Slot = Get-VstsInput -Name Slot -Require
    $DeploymentLabel = Get-VstsInput -Name DeploymentLabel
    $AppendDateTimeToLabel = Get-VstsInput -Name AppendDateTimeToLabel -Require
    $AllowUpgrade = Get-VstsInput -Name AllowUpgrade -Require -AsBool
    $NewServiceAdditionalArguments = Get-VstsInput -Name NewServiceAdditionalArguments
    $NewServiceAffinityGroup = Get-VstsInput -Name NewServiceAffinityGroup

    # Load all dependent files for execution
    . $PSScriptRoot/Utility.ps1

    Write-Host "Find-VstsFiles -LegacyPattern $CsCfg"
    $serviceConfigFile = Find-VstsFiles -LegacyPattern "$CsCfg"
    Write-Host "serviceConfigFile= $serviceConfigFile"
    $serviceConfigFile = Get-SingleFile $serviceConfigFile $CsCfg

    Write-Host "Find-VstsFiles -LegacyPattern $CsPkg"
    $servicePackageFile = Find-VstsFiles -LegacyPattern "$CsPkg"
    Write-Host "servicePackageFile= $servicePackageFile"
    $servicePackageFile = Get-SingleFile $servicePackageFile $CsPkg

    Write-Host "Get-AzureService -ServiceName $ServiceName -ErrorAction SilentlyContinue  -ErrorVariable azureServiceError"
    $azureService = Get-AzureService -ServiceName $ServiceName -ErrorAction SilentlyContinue  -ErrorVariable azureServiceError

    if($azureServiceError){
       $azureServiceError | ForEach-Object { Write-Warning $_.Exception.ToString() }
    }   

   
    if (!$azureService)
    {    
        $azureService = "New-AzureService -ServiceName `"$ServiceName`""
        if($NewServiceAffinityGroup) {
            $azureService += " -AffinityGroup `"$NewServiceAffinityGroup`""
        }
        elseif($ServiceLocation) {
             $azureService += " -Location `"$ServiceLocation`""
        }
        else {
            throw "Either AffinityGroup or ServiceLocation must be specified"
        }
        $azureService += " $NewServiceAdditionalArguments"
        Write-Host "$azureService"
        $azureService = Invoke-Expression -Command $azureService
    }

    $diagnosticExtensions = Get-DiagnosticsExtensions $StorageAccount $serviceConfigFile

    $label = $DeploymentLabel

    if ($label -and $appendDateTime)
    {
	    $label += " "
	    $label += Get-Date
    }

    Write-Host "Get-AzureDeployment -ServiceName $ServiceName -Slot $Slot -ErrorAction SilentlyContinue -ErrorVariable azureDeploymentError"
    $azureDeployment = Get-AzureDeployment -ServiceName $ServiceName -Slot $Slot -ErrorAction SilentlyContinue -ErrorVariable azureDeploymentError

    if($azureDeploymentError) {
       $azureDeploymentError | ForEach-Object { Write-Warning $_.Exception.ToString() }
    }

    if (!$azureDeployment)
    {
	    if ($label)
	    {
		    Write-Host "New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -Label $label -ExtensionConfiguration <extensions>"
		    $azureDeployment = New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -Label $label -ExtensionConfiguration $diagnosticExtensions
	    }
	    else
	    {
		    Write-Host "New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -ExtensionConfiguration <extensions>"
		    $azureDeployment = New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -ExtensionConfiguration $diagnosticExtensions
	    }
    } 
    elseif ($allowUpgrade -eq $true)
    {
        #Use -Upgrade
	    if ($label)
	    {
		    Write-Host "Set-AzureDeployment -Upgrade -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -Label $label -ExtensionConfiguration <extensions>"
		    $azureDeployment = Set-AzureDeployment -Upgrade -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -Label $label -ExtensionConfiguration $diagnosticExtensions
	    }
	    else
	    {
		    Write-Host "Set-AzureDeployment -Upgrade -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -ExtensionConfiguration <extensions>"
		    $azureDeployment = Set-AzureDeployment -Upgrade -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -ExtensionConfiguration $diagnosticExtensions
	    }
    }
    else
    {
        #Remove and then Re-create
        Write-Host "Remove-AzureDeployment -ServiceName $ServiceName -Slot $Slot -Force"
        $azureOperationContext = Remove-AzureDeployment -ServiceName $ServiceName -Slot $Slot -Force
	    if ($label)
	    {
		    Write-Host "New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -Label $label -ExtensionConfiguration <extensions>"
		    $azureDeployment = New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -Label $label -ExtensionConfiguration $diagnosticExtensions
	    }
	    else
	    {
		    Write-Host "New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -ExtensionConfiguration <extensions>"
		    $azureDeployment = New-AzureDeployment -ServiceName $ServiceName -Package $servicePackageFile -Configuration $serviceConfigFile -Slot $Slot -ExtensionConfiguration $diagnosticExtensions
	    }
    }

    Write-Verbose "Leaving script Publish-AzureCloudDeployment.ps1"

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}

