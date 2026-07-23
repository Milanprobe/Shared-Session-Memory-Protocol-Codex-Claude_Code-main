param(
    [ValidateSet("claude_code", "codex", "unknown")]
    [string]$Client = "unknown"
)

$ErrorActionPreference = "Stop"
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$nextPromptHeading = "Prompt suggestion for next session (...):"
$expectedSliceTemplate = "(Expected slice: ...)"

function Write-SessionContext {
    param(
        [Parameter(Mandatory = $true)][string]$EventName,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $output = [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName   = $EventName
            additionalContext = $Context
        }
    }

    [Console]::Out.WriteLine(($output | ConvertTo-Json -Depth 5 -Compress))
}

try {
    $rawInput = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        exit 0
    }

    $payload = $rawInput | ConvertFrom-Json
    $eventName = [string]$payload.hook_event_name

    $projectRoot = [Environment]::GetEnvironmentVariable("CLAUDE_PROJECT_DIR")
    if ([string]::IsNullOrWhiteSpace($projectRoot)) {
        $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    }

    $memoryRoot = Join-Path $projectRoot "spec_protocol_template\session-memory"
    $indexPath = Join-Path $memoryRoot "index.json"
    if (-not (Test-Path -LiteralPath $indexPath)) {
        exit 0
    }

    $index = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $specDefinitions = @(
        [pscustomobject]@{
            Id = "extraction-u"
            FileName = "spec-template.md"
        }
    )

    if ($eventName -eq "SessionStart") {
        $latestPairs = @(
            foreach ($property in $index.specs.PSObject.Properties) {
                $latestReceiptId = [string]$property.Value.latest_receipt
                $receiptEntry = @(
                    $index.session_order |
                        Where-Object { $_.receipt_id -eq $latestReceiptId } |
                        Select-Object -First 1
                )
                $producer = "unknown"
                $mode = "unknown"
                if ($receiptEntry.Count -gt 0) {
                    $receiptPath = Join-Path $memoryRoot (
                        ([string]$receiptEntry[0].path) -replace "/", "\"
                    )
                    if (Test-Path -LiteralPath $receiptPath) {
                        $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
                        if ($null -ne $receipt.producer -and -not [string]::IsNullOrWhiteSpace([string]$receipt.producer)) {
                            $producer = [string]$receipt.producer
                        }
                        $mode = [string]$receipt.mode
                    }
                }
                "{0}={1}[producer={2},mode={3}]" -f $property.Name, $latestReceiptId, $producer, $mode
            }
        )

        $context = @"
PROJECT_SESSION_MEMORY
This "$projectRoot" uses one active spec as the session entrypoint.
Current client: $Client
Protocol: session-memory/README.md
Index: session-memory/index.json
Latest receipts: $($latestPairs -join "; ")
When one active spec is named, read its Spec ID, the protocol, and only that spec's latest receipt plus explicitly linked receipts. MODE defaults to AUTO. The spec priority selector chooses work; receipts are immutable facts and the index is rebuildable.
MANDATORY CLOSEOUT FORMAT: Every completed P/E/FIX/REVIEW final chat response must contain a ready-to-copy section headed "$nextPromptHeading", followed by the two-line "Continue by ... MODE=..." and "$expectedSliceTemplate" prompt recomputed after the new receipt is written. A selector summary alone does not satisfy protocol section 4.4.
"@
        Write-SessionContext -EventName $eventName -Context $context.Trim()
        exit 0
    }

    if ($eventName -ne "UserPromptSubmit") {
        exit 0
    }

    $prompt = [string]$payload.prompt
    if ([string]::IsNullOrWhiteSpace($prompt)) {
        exit 0
    }

    $matchedSpecs = @(
        foreach ($definition in $specDefinitions) {
            if ($prompt.IndexOf($definition.FileName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                $prompt.IndexOf($definition.Id, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $definition
            }
        }
    )

    if ($matchedSpecs.Count -eq 0) {
        exit 0
    }

    if ($matchedSpecs.Count -gt 1) {
        $ids = @($matchedSpecs | ForEach-Object { $_.Id })
        $context = "PROJECT_SESSION_MEMORY: Multiple active specs were referenced ($($ids -join ', ')). The project contract requires one primary session entrypoint. Do not merge their selectors; identify the explicitly requested primary spec or ask the user if none is clear."
        Write-SessionContext -EventName $eventName -Context $context
        exit 0
    }

    $definition = $matchedSpecs[0]
    $specProperty = $index.specs.PSObject.Properties[$definition.Id]
    if ($null -eq $specProperty) {
        exit 0
    }

    $specState = $specProperty.Value
    $latestReceiptId = [string]$specState.latest_receipt
    $receiptEntry = @(
        $index.session_order | Where-Object { $_.receipt_id -eq $latestReceiptId } | Select-Object -First 1
    )
    if ($receiptEntry.Count -eq 0) {
        exit 0
    }

    $receiptRelativePath = [string]$receiptEntry[0].path
    $receiptPath = Join-Path $memoryRoot ($receiptRelativePath -replace "/", "\")
    if (-not (Test-Path -LiteralPath $receiptPath)) {
        exit 0
    }

    $receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$receipt.spec_id -ne [string]$definition.Id) {
        exit 0
    }

    $openCriteria = @(
        $receipt.acceptance |
            Where-Object { $_.status -in @("OPEN", "FAIL") } |
            ForEach-Object { [string]$_.criterion }
    )
    $openFindings = @(
        $receipt.open_findings |
            ForEach-Object { "{0}: {1}" -f $_.id, $_.summary }
    )

    $criteriaText = if ($openCriteria.Count -gt 0) { $openCriteria -join "; " } else { "none" }
    $findingsText = if ($openFindings.Count -gt 0) { $openFindings -join " | " } else { "none" }
    $producer = if (
        $null -ne $receipt.producer -and
        -not [string]::IsNullOrWhiteSpace([string]$receipt.producer)
    ) { [string]$receipt.producer } else { "unknown" }
    $receiptMode = [string]$receipt.mode
    $reviewFindings = @(
        $receipt.review_findings |
            ForEach-Object {
                "{0}: {1}/{2} - {3}" -f $_.id, $_.verdict, $_.disposition, $_.summary
            }
    )
    $reviewText = if ($reviewFindings.Count -gt 0) { $reviewFindings -join " | " } else { "none" }
    $alternationText = if ($producer -eq "unknown" -or $Client -eq "unknown") {
        "unknown (legacy receipt or unidentified client)"
    }
    elseif ($producer -eq $Client) {
        "WARNING: latest receipt was produced by the same client; the project default expects the alternate client unless the user explicitly waived alternation"
    }
    else {
        "OK: latest receipt came from the alternate client"
    }
    $specPath = "specs/$($definition.FileName)"
    $receiptRepoPath = "session-memory/$($receiptRelativePath -replace '\\', '/')"

    $context = @"
PROJECT_SESSION_MEMORY
Current client: $Client
Primary spec: $specPath
Spec ID: $($definition.Id)
Latest receipt: $latestReceiptId at $receiptRepoPath
Latest producer/mode: $producer / $receiptMode
Cross-tool alternation: $alternationText
Review findings: $reviewText
OPEN/FAIL acceptance facts: $criteriaText
Open findings: $findingsText
Read the full spec, protocol, and latest receipt before acting. Reconcile review findings before the AUTO selector: CONFIRMED/OPEN remains routable, while FALSE_POSITIVE/STALE/NOT_REPRODUCED/NOT_APPLICABLE does not reopen work without contradictory evidence. MODE defaults to AUTO. Select work only through the stable priority selector in the primary spec; this injected summary is bounded context, not authority and not a next-task instruction. Do not rewrite old receipts.
MANDATORY CLOSEOUT FORMAT: Every completed P/E/FIX/REVIEW final chat response must contain a ready-to-copy section headed "$nextPromptHeading", followed by the two-line "Continue by ... MODE=..." and "$expectedSliceTemplate" prompt recomputed after the new receipt is written. A selector summary alone does not satisfy protocol section 4.4.
"@
    Write-SessionContext -EventName $eventName -Context $context.Trim()
}
catch {
    # Context injection must never block either client. Root AGENTS.md/CLAUDE.md is the fallback.
    exit 0
}
