
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
Param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,
    [Parameter(Mandatory = $false)]
    [string]$Project,
    [Parameter(Mandatory = $true)]
    [string]$PullRequestId,
    [Parameter(Mandatory = $true)]
    [string]$PAT,    
    [Parameter(Mandatory = $true)]
    [string]$ChartGPTAccountName,
    [Parameter(Mandatory = $true)]
    [string]$ChartGPTAccessKey,
    [Parameter(Mandatory = $true)]
    [string]$ChartGPTDeploymentName
)

$ErrorActionPreference = "Stop"

Function Get-Token {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $User,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $PAT
    )

    return "Basic " + [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($User):$($PAT)"))
}

Function Get-PullRequest {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Organization,
        [Parameter(Mandatory = $false)]
        [string]$Project,
        [Parameter(Mandatory = $true)]
        [string]$PullRequestId,
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    $url = "https://dev.azure.com/$Organization/$Project/_apis/git/pullrequests/$($PullRequestId)?api-version=7.0"
    Write-Host -ForegroundColor Yellow "Get-Build $url"
    $headers = @{ Authorization = $Token }

    $result = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

    return $result;
}

Function Get-PullRequestIteration {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Organization,
        [Parameter(Mandatory = $false)]
        [string]$Project,
        [Parameter(Mandatory = $false)]
        [string]$RepositoryId,
        [Parameter(Mandatory = $true)]
        [string]$PullRequestId,
        [Parameter(Mandatory = $false)]
        [string]$IterationId,
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    If ($null -eq $IterationId -or $IterationId.Length -eq 0) {
        $url = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullRequests/$PullRequestId/iterations?api-version=7.0"
    }
    else {
        $url = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullRequests/$PullRequestId/iterations/$($IterationId)?api-version=7.0"
    }
    Write-Host -ForegroundColor Yellow "Get-Build $url"
    $headers = @{ Authorization = $Token }

    $result = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

    return $result;
}

Function Get-PullRequestIterationChange {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Organization,
        [Parameter(Mandatory = $false)]
        [string]$Project,
        [Parameter(Mandatory = $false)]
        [string]$RepositoryId,
        [Parameter(Mandatory = $true)]
        [string]$PullRequestId,
        [Parameter(Mandatory = $false)]
        [string]$IterationId,
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    $url = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullRequests/$PullRequestId/iterations/$($IterationId)/changes?api-version=7.0"

    Write-Host -ForegroundColor Yellow "Get-Build $url"
    $headers = @{ Authorization = $Token }

    $result = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

    return $result;
}

Function New-PullRequestThread {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$Organization,
        [Parameter(Mandatory = $false)]
        [string]$Project,
        [Parameter(Mandatory = $false)]
        [string]$RepositoryId,
        [Parameter(Mandatory = $true)]
        [string]$PullRequestId,
        [Parameter(Mandatory = $false)]
        [string]$IterationId,
        [Parameter()]
        [string]$CompareToIterationId,
        [Parameter()]
        [string] $ChangeTrackingId,
        [Parameter()]
        [PSCustomObject]$Comment,
        [Parameter()]
        [PSCustomObject]$ThreadContext,
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    $payload = [PSCustomObject]@{
        "comments"                 = @($Comment)
        "status"                   = 1
        "threadContext"            = $ThreadContext
        "pullRequestThreadContext" = [PSCustomObject]@{
            "changeTrackingId" = $ChangeTrackingId
            "iterationContext" = [PSCustomObject]@{
                firstComparingIteration  = $IterationId
                secondComparingIteration = $CompareToIterationId
            }
        }
    }

    $url = "https://dev.azure.com/$Organization/$Project/_apis/git/repositories/$RepositoryId/pullRequests/$PullRequestId/threads?api-version=7.0"

    Write-Host -ForegroundColor Yellow "Get-Build $url"
    $headers = @{ Authorization = $Token }

    $body = ConvertTo-Json -InputObject $payload -Depth 10 -Compress

    Write-Host $body

    $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json'

    return $result;
}

Function Invoke-ChartGPTCompletion {
    Param(
        [Parameter(Mandatory = $true)]
        [string]$AccountName,
        [Parameter(Mandatory = $true)]
        [string]$AccessKey,
        [Parameter(Mandatory = $true)]
        [string]$DeploymentName,
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $url = "https://$AccountName.openai.azure.com/openai/deployments/$DeploymentName/chat/completions?api-version=2023-03-15-preview"
    Write-Host -ForegroundColor Yellow "Get-Build $url"
    $headers = @{
        "api-key" = $AccessKey
    }

    $promptPayload = [PSCustomObject]@{
        "content" = $Prompt
        "role"    = "system"
    }

    $messagePayload = [PSCustomObject]@{
        "content" = $Message
        "role"    = "user"
    }

    $payload = [PSCustomObject]@{
        "model"             = $DeploymentName
        "frequency_penalty" = 0
        "max_tokens"        = 4000
        "messages"          = @($promptPayload, $messagePayload)
        "presence_penalty"  = 0
        "stream"            = $false
        "temperature"       = 0.7
        "top_p"             = 0.95
    }

    # return $payload
    $body = ConvertTo-Json -InputObject $payload -Compress

    $body = $body -creplace '\P{IsBasicLatin}'
    $result = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ContentType 'application/json'

    return $result;
}

$token = Get-Token -User $PAT -PAT $PAT

$pullRequest = Get-PullRequest -Organization $Organization -Project $Project -PullRequestId $PullRequestId -Token $token

$iterations = Get-PullRequestIteration -Organization $Organization -Project $Project -PullRequestId $PullRequestId -Token $token -RepositoryId $pullRequest.repository.id

$iteration = $iterations.value[-1]
$firstIteration = $iterations.value[0]

$change = Get-PullRequestIterationChange -Organization $Organization -Project $Project -PullRequestId $PullRequestId -Token $token -RepositoryId $pullRequest.repository.id -IterationId $iteration.id

foreach ($entry in $change.changeEntries) {
    $item = $entry.item
    if ($entry.changeType -eq "edit") {
        $content = Invoke-Expression "git diff $($item.originalObjectId) $($item.objectId) "
        $content = $content -join "`n"
    }
    elseif ($entry.changeType -eq "add") {
        $filePath = Join-Path (Get-Location).Path  -ChildPath $item.path
        $content = Get-Content $filePath -Raw
    }
    elseif ($entry.changeType -eq "deleted") {
        $content = $null
    }
    else {
        $content = $null
    }

    if ($null -ne $content -and $content.Length -gt 0) {
        $chat = Invoke-ChartGPTCompletion -AccountName $ChartGPTAccountName -AccessKey $ChartGPTAccessKey -DeploymentName $ChartGPTDeploymentName -Prompt "This is a git diff patch file content, please help review the code change." -Message $content
        $suggestion = $chat.choices[0].message.content

        if ($null -ne $suggestion) {
            $comment = [PSCustomObject]@{
                "parentCommentId" = 0
                "content"         = $suggestion
                "commentType"     = 1
            }
                
            $threadContext = [PSCustomObject]@{
                "filePath"       = $item.path
                "leftFileEnd"    = $null
                "leftFileStart"  = $null
                "rightFileStart" = [PSCustomObject]@{
                    "line"   = 0
                    "offset" = 1
                }
                "rightFileEnd"   = [PSCustomObject]@{
                    "line"   = 1
                    "offset" = 0
                }
            }
            write-Host "Review comment: $suggestion"
            ## New-PullRequestThread -Organization $Organization -Project $Project -RepositoryId $pullRequest.repository.id -PullRequestId $PullRequestId -Token $token -IterationId $iteration.id -CompareToIterationId $firstIteration.id -Comment $comment -ThreadContext $threadContext -ChangeTrackingId $entry.changeTrackingId 
        }
    }
}

return $chat