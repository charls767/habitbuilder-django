$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
  param(
    [Parameter(Mandatory)]
    [scriptblock] $Command,
    [Parameter(Mandatory)]
    [string] $Description
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Description falló con código $LASTEXITCODE."
  }
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCommand) {
  throw 'Flutter 3.44.x no está disponible en PATH.'
}

$versionJson = & flutter --version --machine
if ($LASTEXITCODE -ne 0) {
  throw "No se pudo consultar la versión de Flutter (código $LASTEXITCODE)."
}
$flutterVersion = $versionJson | ConvertFrom-Json
if ($flutterVersion.frameworkVersion -notlike '3.44.*') {
  throw "Se requiere Flutter 3.44.x; se encontró $($flutterVersion.frameworkVersion)."
}

$projectRoot = Split-Path $PSScriptRoot -Parent
$platforms = @('android', 'ios', 'web', 'windows')
$missingPlatforms = @(
  $platforms | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $projectRoot $_))
  }
)

if ($missingPlatforms.Count -gt 0) {
  $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  $tempScaffold = Join-Path $tempBase (
    'habitbuilder_flutter_scaffold_' + [guid]::NewGuid().ToString('N')
  )
  New-Item -ItemType Directory -Path $tempScaffold | Out-Null

  try {
    Invoke-NativeCommand `
      -Description 'Generación de plataformas Flutter' `
      -Command {
        flutter create `
          --platforms=android,ios,web,windows `
          --org com.habitbuilder `
          --project-name habitbuilder_mobile `
          $tempScaffold
      }

    foreach ($platform in $missingPlatforms) {
      Copy-Item `
        -LiteralPath (Join-Path $tempScaffold $platform) `
        -Destination (Join-Path $projectRoot $platform) `
        -Recurse
    }

    $metadataPath = Join-Path $projectRoot '.metadata'
    if (-not (Test-Path -LiteralPath $metadataPath)) {
      Copy-Item `
        -LiteralPath (Join-Path $tempScaffold '.metadata') `
        -Destination $metadataPath
    }
  }
  finally {
    $resolvedScaffold = [IO.Path]::GetFullPath($tempScaffold)
    if (
      $resolvedScaffold.StartsWith(
        $tempBase,
        [StringComparison]::OrdinalIgnoreCase
      ) -and
      (Test-Path -LiteralPath $resolvedScaffold)
    ) {
      Remove-Item -LiteralPath $resolvedScaffold -Recurse -Force
    }
  }
}

Push-Location $projectRoot
try {
  Invoke-NativeCommand -Description 'flutter pub get' -Command {
    flutter pub get
  }
  Invoke-NativeCommand -Description 'Riverpod code generation' -Command {
    dart run build_runner build
  }
  Invoke-NativeCommand -Description 'flutter analyze' -Command {
    flutter analyze
  }
  Invoke-NativeCommand -Description 'flutter test with coverage' -Command {
    flutter test --coverage
  }
}
finally {
  Pop-Location
}
