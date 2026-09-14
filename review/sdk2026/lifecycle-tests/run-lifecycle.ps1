param(
 [string]$Image = 'local/otbr-sdk2026:encrypted',
 [string]$OutputDirectory = (Join-Path $PSScriptRoot ('run-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))),
 [string]$FinishOverride = ''
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$imageId = (& docker image inspect $Image --format '{{.Id}}')
$results = @()
foreach ($case in @('missing','malformed')) {
 $name = 'sdk2026-lifecycle-' + $case + '-' + (Get-Date -Format 'HHmmss')
 $caseDir = Join-Path $OutputDirectory $case
 New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
 & docker create --name $name --network none --env "KEY_CASE=$case" --entrypoint python3 $imageId /fixture.py | Out-Null
 if ($LASTEXITCODE) { throw 'container creation failed' }
 & docker cp (Join-Path $PSScriptRoot 'fixture.py') "${name}:/fixture.py"
 if ($FinishOverride) { & docker cp $FinishOverride "${name}:/etc/s6-overlay/s6-rc.d/cpcd/finish" }
 & docker start $name | Out-Null
 try {
  for ($i=0; $i -lt 8; $i++) {
   Start-Sleep -Seconds 1
   $state = (& docker inspect $name --format '{{json .State}}') | ConvertFrom-Json
   if (-not $state.Running) { break }
  }
  $log = (& docker logs $name 2>&1 | Out-String)
  $log | Set-Content -LiteralPath (Join-Path $caseDir 'container.log') -Encoding utf8
  $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $caseDir 'state.json') -Encoding utf8
  & docker cp "${name}:/lifecycle-before.json" (Join-Path $caseDir 'key-before.json')
  $before = Get-Content -Raw -LiteralPath (Join-Path $caseDir 'key-before.json') | ConvertFrom-Json
  $copy = Join-Path $caseDir 'synthetic-data'
  & docker cp "${name}:/data/cpc" $copy
  $key = Join-Path $copy 'binding.key'
  $exists = Test-Path -LiteralPath $key
  $hash = if ($exists) { (Get-FileHash -LiteralPath $key -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
  if ($exists) { Remove-Item -LiteralPath $key }
  Remove-Item -LiteralPath $copy
  $refusals = ([regex]::Matches($log,'refusing encrypted startup')).Count
  $leaked = $log.Contains('SYNTHETIC-NONHEX-KEY-DO-NOT-LOG')
  $started = $log.Contains('Starting cpcd...')
  $unchanged = ($exists -eq $before.exists) -and ($hash -eq $before.sha256)
  $pass = (-not $state.Running) -and ($state.ExitCode -ne 0) -and ($refusals -eq 1) -and (-not $leaked) -and (-not $started) -and $unchanged
  $results += [pscustomobject]@{case=$case; image=$imageId; fixture_finish_override=[bool]$FinishOverride; pass=$pass; running_after_8_seconds=$state.Running; exit_code=$state.ExitCode; preflight_refusal_count=$refusals; synthetic_key_logged=$leaked; cpcd_start_logged=$started; key_unchanged=$unchanged; key_sha256=$hash; container=$name}
 } finally {
  & docker stop --timeout 3 $name | Out-Null
 }
}
$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'results.json') -Encoding utf8
$results | Format-Table case,pass,running_after_8_seconds,exit_code,preflight_refusal_count,key_unchanged
if ($results | Where-Object { -not $_.pass }) { exit 1 }

