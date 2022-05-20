$header = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($personalAccessToken)"))}
$definitions = Invoke-RestMethod -Uri "https://devops.domain.com/Collection/Project/_apis/build/definitions" -Method GET -Header $header
$branchNames = 'master', 'feature'

ForEach ($definition in $definitions.value) {
    $definitionToUpdate = Invoke-RestMethod -Uri "$($collection)$($project.name)/_apis/build/definitions/$($definition.id)" -Method GET -Header $header
    $trigger = $definitionToUpdate.triggers | Where {$_.triggerType -eq 'continuousIntegration'}

    if ($trigger) {
        $trigger.branchFilters = $branchNames | % {"+refs/heads/$_/*"}
        Invoke-RestMethod -Uri "https://devops.domain.com/Collection/Project/_apis/build/definitions/$($definition.id)?api-version=5.0" -Method PUT -ContentType application/json -Body ($definitionToUpdate | ConvertTo-Json -Depth 100) -Header $header
    }
}
