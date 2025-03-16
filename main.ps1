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
        [bool]$IsRetired,
        [Parameter(Mandatory = $true)]
        $Position
    )
    
    if ($null -eq $TierValue) { return "N/A" }
    
    $prefix = if ($Position -eq 0) { "ht" } else { "lt" }
    
    if ($IsRetired) {
        return "r$($prefix)$TierValue"
    } else {
        return "$($prefix)$TierValue"
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
    
    $modes = @()
    
    foreach ($p in $TiersData.PSObject.Properties) {
        if ($p.Name -in @('player', 'name', 'uuid')) { continue }
        
        $mode = $p.Name
        $data = $p.Value
        
        if ($data.PSObject.Properties.Name -contains 'tier') {
            $cTier = $data.tier
            $pTier = $data.peak_tier
            if ($null -eq $pTier) { $pTier = $cTier }
            
            $pos = $data.pos
            $peakPos = $data.peak_pos
            if ($null -eq $peakPos) { $peakPos = $pos }
            
            $retired = $data.retired
            if ($null -eq $retired) { $retired = $false }
            
            $modes += [PSCustomObject]@{
                Mode = $mode
                CurrTier = $cTier
                PeakTier = $pTier
                Pos = $pos
                PeakPos = $peakPos
                Retired = $retired
                Date = $data.attained
                FormattedPeakTier = Format-Tier -TierValue $pTier -IsRetired $retired -Position $peakPos
                FormattedCurrTier = Format-Tier -TierValue $cTier -IsRetired $retired -Position $pos
            }
        }
    }
    
    $sorted = $modes | Sort-Object -Property @{Expression = "PeakTier"; Descending = $true}, Mode
    
    if ($sorted.Count -gt 0) {
        Write-Host "GAME MODES BY PEAK TIER:" -ForegroundColor Yellow
        Write-Host ""
        
        $sorted | ForEach-Object {
            $modeDisplay = $_.Mode.ToUpper()
            
            $date = if ($null -ne $_.Date) {
                try {
                    $dt = [DateTimeOffset]::FromUnixTimeSeconds($_.Date).LocalDateTime
                    $dt.ToString("yyyy-MM-dd")
                } catch {
                    "Unknown Date"
                }
            } else {
                "Unknown Date"
            }
            
            Write-Host "▶ $modeDisplay" -ForegroundColor Magenta
            Write-Host "  Peak Tier: " -NoNewline -ForegroundColor Green
            
            $color = switch ($_.PeakTier) {
                5 { "Magenta" }
                4 { "Cyan" }
                3 { "Green" }
                2 { "Yellow" }
                default { "Gray" }
            }
            
            Write-Host $_.FormattedPeakTier -ForegroundColor $color
            
            if ($_.CurrTier -ne $_.PeakTier) {
                Write-Host "  Current Tier: " -NoNewline -ForegroundColor DarkGreen
                
                $currColor = switch ($_.CurrTier) {
                    5 { "Magenta" }
                    4 { "Cyan" }
                    3 { "Green" }
                    2 { "Yellow" }
                    default { "Gray" }
                }
                
                Write-Host $_.FormattedCurrTier -ForegroundColor $currColor
            }
            
            Write-Host "  Attained: $date" -ForegroundColor DarkGray
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
    $data = Get-MCTiers -UUID $uuid
    Show-Tiers -TiersData $data -PlayerName $PlayerIGN
}
