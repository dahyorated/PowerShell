<#
.Synopsis
Set the platform-level service registration.

.Description
The Set-ServiceRegistration script sets the platform-level service registration.
- Updates the key vault with the service secrets; and
- If not a DR stage, updates the user service DB.

The current stage name is obtained from: $ENV:RELEASE_ENVIRONMENTNAME.

.Parameter KeyVault
This is the name of the key vault for the environment.

.Parameter Services
This is the set of services to be registered.

.Parameter UpdateSecret
If specified, the secret is updated even if it already exists in the -KeyVault key vault.

.Parameter VerifyOnly
If specified, no updates are made.

.Example
Set-ServiceRegistration -KeyVault EUWDGTP005AKV01 -Services @{xyzzyyservice = "XyzzyService-ServiceAuthSecret"};

If it is not already there, this:
- Will add the xyzzyyservice secret to the EUWDGTP005AKV01 key vault; and
- Will add the xyzzyyservice service to the user service DB.
This only happens if the value of $ENV:RELEASE_ENVIRONMENTNAME does not end in '-USE' which specifies a DR stage.

#>
[CmdletBinding(SupportsShouldProcess,ConfirmImpact='None')]
Param(
	[Parameter(Mandatory=$true)]
	[string]$KeyVault,
	[Parameter(Mandatory=$true)]
	[hashTable]$Services,
	[Parameter(Mandatory=$false)]
	[switch]$UpdateSecret,
	[Parameter(Mandatory=$false)]
	[switch]$VerifyOnly
)

Import-Module -Name $PSScriptRoot\DevOps -Force -Verbose:$False;
Initialize-Script $PSCmdlet.MyInvocation;
$stageName = $ENV:RELEASE_ENVIRONMENTNAME;
$isNotDr = $stageName -notlike '*-USE';
if ($VerifyOnly)
{
	Write-Output "Verifying Services for KeyVault: $KeyVault";
}
else
{
	Write-Output "Registering Services for KeyVault: $KeyVault UpdateSecret: $UpdateSecret";
}
$cnt=0;
$key = "connectionstring-userservicedb";
$current = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $key;
if ($null -eq $current)
{
	$errorMessage = "unable to get connection string for userservicedb";
	Stop-ProcessError -ErrorMessage $errorMessage;
}
$connString = $current.SecretValueText;
Write-Verbose "Conn-string: $connString";
if ($isNotDr)
{
	$sqlConnection = New-Object System.Data.SqlClient.SqlConnection;
	$sqlConnection.ConnectionString = $connString;
	$sqlConnection.Open();
}
foreach ($serviceId in $Services.Keys)
{
	$cnt++;
	$secretName = $Services[$serviceId];
	$secret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $secretName;
	if ($isNotDr)
	{
		$sqlText = "select * from [Common].[ServiceLogin] where [ServiceLoginId] = '$serviceId'";
		Write-Verbose "SQLText: $sqlText";
		$cmd = New-Object System.Data.SqlClient.SqlCommand($sqlText, $sqlConnection);
		$reader = $cmd.ExecuteReader()
		$found = $reader.Read()
		$reader.Close();
	}
	if ($VerifyOnly)
	{
		if ($null -eq $secret)
		{
			Write-Output "ServiceId: $serviceId SecretName: $secretName does not exist in key vault";
		}
		if (-not $found)
		{
			Write-Output "ServiceId: $serviceId does not exist in database";
		}
	}
	else
	{
		if (($null -eq $secret) -or $UpdateSecret)
		{
			$guid = [guid]::NewGuid();
			$value = ConvertTo-SecureString $guid -AsPlainText  -Force;
			if ($PSCmdlet.ShouldProcess($serviceId,"Key Vault Set"))
			{
				Write-Output "Creating/Updating Secret Name $secretName for Service $serviceId";
				$res = Set-AzKeyVaultSecret -VaultName $KeyVault -Name $secretName -SecretValue $value;
			}
		}
		if ($isNotDr -and (-not $found))
		{
			$date = (Get-Date).ToUniversalTime().ToString("o");
			$sqlText = "INSERT [Common].[ServiceLogin] ([ServiceLoginId], [CreatedDtm], [UpdatedDtm], [CreatedUser], [UpdatedUser]) VALUES (N'$serviceId', CAST(N'$date' AS DateTime2), CAST(N'$date' AS DateTime2), N'ServiceRegistration.ps1', N'ServiceRegistration.ps1')";
			Write-NameAndValue "SQLText" $sqlText;
			$cmd = New-Object System.Data.SqlClient.SqlCommand($sqlText, $sqlConnection);
			if ($PSCmdlet.ShouldProcess($serviceId,"DB Insert"))
			{
				$res = $cmd.ExecuteNonQuery();
			}
		}
	}
}
Write-Output "Completed, $cnt entries processed";
if ($isNotDr)
{
	$sqlConnection.Close();
}
