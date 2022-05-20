# Create globals
# Define all area IDs as global
# https://docs.microsoft.com/en-us/azure/devops/extend/develop/work-with-urls?view=azure-devops&tabs=http&viewFallbackFrom=vsts#resource-area-ids-reference
$global:coreAreaId = "79134c72-4a58-4b42-976c-04e7115f32bf";
$global:releaseManagementAreaId = "efc2f575-36ef-48e9-b672-0c6fb4a48ac5";
$global:buildAreaId = "5d6898bb-45ec-463f-95f9-54d49c71752e";
$global:witAreaId = "5264459e-e5e0-4bd8-b118-0985e68a4ec5";
# export all functions
Get-ChildItem -Path $PSScriptRoot\Functions\*.ps1 |
	ForEach-Object {
		. $_.FullName;
		Export-ModuleMember -Function ([IO.PATH]::GetFileNameWithoutExtension($_.FullName));
}
