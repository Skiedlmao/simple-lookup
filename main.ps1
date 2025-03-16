param(
    [string]$PlayerIGN
)

function Get-MinecraftUUID {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.mojang.com/users/profiles/minecraft/$Username" -Method Get
        return $response.id
    }
    catch {
        Write-Error "Failed to retrieve UUID for $Username. Error: $_"
        exit
    }
}

function Get-MCTiers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UUID
    )
    
    try {
        $UUID = $UUID -replace '-', ''
        $response = Invoke-RestMethod -Uri "https://mctiers.io/api/rankings/$UUID" -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to retrieve MCTiers data. Error: $_"
        exit
    }
}

function Format-Tier {
    param(
        [Parameter(Mandatory = $true)]
        $TierValue,
        
        [Parameter(Mandatory = $true)]
        [bool]$IsRetired
    )
    
    if ($null -eq $TierValue) {
        return "N/A"
    }
    
    $tierPrefix = if ($TierValue -ge 3) { "ht" } else { "lt" }
    
    if ($IsRetired) {
        return "r$($tierPrefix)$TierValue"
    } else {
        return "$($tierPrefix)$TierValue"
    }
}

function Show-Tiers {
    param(
        [Parameter(Mandatory = $true)]
        $TiersData,
        
        [Parameter(Mandatory = $true)]
        [string]$PlayerName
    )
    
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host "MCTiers Rankings for $PlayerName" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    
    $gameModeTable = @()
    
    foreach ($prop in $TiersData.PSObject.Properties) {
        if ($prop.Name -in @('player', 'name', 'uuid')) { continue }
        
        $gameMode = $prop.Name
        $data = $prop.Value
        
        if ($data.PSObject.Properties.Name -contains 'tier') {
            $currentTier = $data.tier
            $peakTier = $data.peak_tier
            if ($null -eq $peakTier) { $peakTier = $currentTier }
            
            $retired = $data.retired
            if ($null -eq $retired) { $retired = $false }
            
            $gameModeTable += [PSCustomObject]@{
                GameMode = $gameMode
                CurrentTier = $currentTier
                PeakTier = $peakTier
                Position = $data.pos
                PeakPosition = $data.peak_pos
                Retired = $retired
                Attained = $data.attained
                FormattedPeakTier = Format-Tier -TierValue $peakTier -IsRetired $retired
            }
        }
    }
    
    $sortedGameModes = $gameModeTable | Sort-Object -Property @{Expression = "PeakTier"; Descending = $true}, GameMode
    
    if ($sortedGameModes.Count -gt 0) {
        Write-Host "GAME MODES BY PEAK TIER:" -ForegroundColor Yellow
        Write-Host ""
        
        $sortedGameModes | ForEach-Object {
            $gameModeDisplay = $_.GameMode.ToUpper()
            $posInfo = if ($null -ne $_.Position) { "Pos #$($_.Position)" } else { "Pos N/A" }
            $peakPosInfo = if ($null -ne $_.PeakPosition) { "Peak Pos #$($_.PeakPosition)" } else { "Peak Pos N/A" }
            
            $attainedDate = if ($null -ne $_.Attained) {
                try {
                    $dateTime = [DateTimeOffset]::FromUnixTimeSeconds($_.Attained).LocalDateTime
                    $dateTime.ToString("yyyy-MM-dd")
                } catch {
                    "Unknown Date"
                }
            } else {
                "Unknown Date"
            }
            
            Write-Host "▶ $gameModeDisplay" -ForegroundColor Magenta
            Write-Host "  Peak Tier: " -NoNewline -ForegroundColor Green
            
            $tierColor = switch ($_.PeakTier) {
                {$_ -ge 4} { "Cyan" }
                {$_ -ge 3} { "Green" }
                {$_ -ge 2} { "Yellow" }
                default { "Gray" }
            }
            
            Write-Host $_.FormattedPeakTier -ForegroundColor $tierColor
            
            if ($_.CurrentTier -ne $_.PeakTier) {
                Write-Host "  Current Tier: " -NoNewline -ForegroundColor DarkGreen
                $currentTierFormatted = Format-Tier -TierValue $_.CurrentTier -IsRetired $_.Retired
                Write-Host $currentTierFormatted -ForegroundColor $tierColor
            }
            
            Write-Host "  $posInfo, $peakPosInfo" -ForegroundColor White
            Write-Host "  Attained: $attainedDate" -ForegroundColor DarkGray
            Write-Host ""
        }
    } else {
        Write-Host "No tier rankings found for this player." -ForegroundColor Red
    }
}

Clear-Host
Write-Host "====================================" -ForegroundColor Magenta
Write-Host "        MCTiers Lookup Tool        " -ForegroundColor Magenta
Write-Host "====================================" -ForegroundColor Magenta
Write-Host ""

if (-not $PlayerIGN) {
    $PlayerIGN = Read-Host -Prompt "Enter Minecraft IGN"
}

Write-Host "Looking up UUID for $PlayerIGN..." -ForegroundColor Gray
$uuid = Get-MinecraftUUID -Username $PlayerIGN

if ($uuid) {
    Write-Host "Found UUID: $uuid" -ForegroundColor Gray
    Write-Host "Retrieving MCTiers data..." -ForegroundColor Gray
    $tiersData = Get-MCTiers -UUID $uuid
    Show-Tiers -TiersData $tiersData -PlayerName $PlayerIGN
}
