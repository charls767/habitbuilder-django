param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedRoot = 'C:\Users\USER\Desktop\DPPF\HabitBuilder\habitbuilder-mobile-hbm14'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($root -ne $expectedRoot) {
    throw "Android acceptance must run from $expectedRoot (actual: $root)"
}
Set-Location -LiteralPath $root

if ((git branch --show-current).Trim() -ne 'HBM-14/local-notifications') {
    throw 'Android acceptance refused to run on the wrong branch.'
}

$sdkRoot = if ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} elseif ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} else {
    'C:\Users\USER\AppData\Local\Android\Sdk'
}
$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
$emulator = Join-Path $sdkRoot 'emulator\emulator.exe'
$flutter = 'C:\Users\USER\flutter\bin\flutter.bat'
$target = 'integration_test/reminder_android_smoke_test.dart'
$packageName = 'com.habitbuilder.habitbuilder_mobile'
$activity = "$packageName/.MainActivity"
$evidenceRoot = Join-Path $root 'build\reminder-acceptance'
$null = New-Item -ItemType Directory -Force -Path $evidenceRoot

foreach ($required in @($adb, $emulator, $flutter)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required Android acceptance tool is missing: $required"
    }
}
if (-not ((& $emulator -list-avds) -contains 'Pixel_6')) {
    throw 'Required Android AVD Pixel_6 is unavailable.'
}

$script:ownedEmulator = $false
$script:serial = $null
$script:emulatorProcess = $null

function Get-RunningPixelSerial {
    $deviceLines = & $adb devices
    foreach ($line in $deviceLines) {
        if ($line -notmatch '^(emulator-\d+)\s+device') {
            continue
        }
        $candidate = $Matches[1]
        $avdName = (& $adb -s $candidate shell getprop ro.boot.qemu.avd_name).Trim()
        if ($avdName -eq 'Pixel_6') {
            return $candidate
        }
    }
    return $null
}

function Wait-ForBoot {
    param([Parameter(Mandatory)][string]$DeviceSerial)

    & $adb -s $DeviceSerial wait-for-device | Out-Null
    $deadline = [DateTime]::UtcNow.AddMinutes(4)
    do {
        $booted = (& $adb -s $DeviceSerial shell getprop sys.boot_completed).Trim()
        if ($booted -eq '1') {
            return
        }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Pixel_6 did not report sys.boot_completed=1: $DeviceSerial"
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$LogName
    )

    $logPath = Join-Path $evidenceRoot $LogName
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $rawOutput = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $output = @($rawOutput | ForEach-Object { $_.ToString() })
    $output | Tee-Object -FilePath $logPath
    if ($exitCode -ne 0) {
        throw "$FilePath failed with exit code $exitCode. Evidence: $logPath"
    }
    return ($output -join "`n")
}

function Build-And-Install {
    param([Parameter(Mandatory)][ValidateSet('full', 'verify')][string]$Mode)

    Invoke-Checked -FilePath $flutter -Arguments @(
        'build', 'apk', '--debug', '--no-pub',
        '--target', $target,
        "--dart-define=REMINDER_ACCEPTANCE_MODE=$Mode"
    ) -LogName "build-$Mode.log" | Out-Null
    $apk = Join-Path $root 'build\app\outputs\flutter-apk\app-debug.apk'
    if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) {
        throw "Flutter did not produce the expected APK: $apk"
    }
    Invoke-Checked -FilePath $adb -Arguments @(
        '-s', $script:serial, 'install', '-r', $apk
    ) -LogName "install-$Mode.log" | Out-Null
}

function Set-NotificationPermission {
    param([Parameter(Mandatory)][ValidateSet('grant', 'deny')][string]$State)

    if ($State -eq 'grant') {
        Invoke-Checked -FilePath $adb -Arguments @(
            '-s', $script:serial, 'shell', 'pm', 'grant', $packageName,
            'android.permission.POST_NOTIFICATIONS'
        ) -LogName 'permission-notifications-grant.log' | Out-Null
    } else {
        Invoke-Checked -FilePath $adb -Arguments @(
            '-s', $script:serial, 'shell', 'pm', 'revoke', $packageName,
            'android.permission.POST_NOTIFICATIONS'
        ) -LogName 'permission-notifications-deny.log' | Out-Null
    }
}

function Set-ExactAlarmPermission {
    param([Parameter(Mandatory)][ValidateSet('allow', 'deny')][string]$State)

    Invoke-Checked -FilePath $adb -Arguments @(
        '-s', $script:serial, 'shell', 'appops', 'set', $packageName,
        'SCHEDULE_EXACT_ALARM', $State
    ) -LogName "permission-exact-$State.log" | Out-Null
}

function Invoke-AcceptanceApp {
    param(
        [Parameter(Mandatory)][string]$EvidenceName,
        [Parameter(Mandatory)][string]$ExpectedPattern
    )

    & $adb -s $script:serial logcat -c
    & $adb -s $script:serial shell am force-stop $packageName | Out-Null
    Invoke-Checked -FilePath $adb -Arguments @(
        '-s', $script:serial, 'shell', 'am', 'start', '-W', '-n', $activity
    ) -LogName "$EvidenceName-start.log" | Out-Null

    $deadline = [DateTime]::UtcNow.AddSeconds(60)
    do {
        $logcat = & $adb -s $script:serial logcat -d -v time
        $joined = $logcat -join "`n"
        if ($joined -match 'REMINDER_ACCEPTANCE:FAIL') {
            $joined | Set-Content -LiteralPath (
                Join-Path $evidenceRoot "$EvidenceName-logcat.log"
            )
            throw "Android acceptance app reported failure: $EvidenceName"
        }
        if ($joined -match $ExpectedPattern) {
            $joined | Set-Content -LiteralPath (
                Join-Path $evidenceRoot "$EvidenceName-logcat.log"
            )
            Write-Host "PASS $EvidenceName :: $($Matches[0])"
            return
        }
        Start-Sleep -Seconds 2
    } while ([DateTime]::UtcNow -lt $deadline)

    $joined | Set-Content -LiteralPath (
        Join-Path $evidenceRoot "$EvidenceName-logcat.log"
    )
    throw "Missing fail-closed PASS marker for $EvidenceName"
}

try {
    $script:serial = Get-RunningPixelSerial
    if (-not $script:serial) {
        $before = @(
            (& $adb devices) |
                Where-Object { $_ -match '^(emulator-\d+)\s+' } |
                ForEach-Object { $Matches[1] }
        )
        $script:emulatorProcess = Start-Process -FilePath $emulator -ArgumentList @(
            '-avd', 'Pixel_6', '-no-snapshot-save', '-no-boot-anim'
        ) -WindowStyle Hidden -PassThru
        $script:ownedEmulator = $true
        $deadline = [DateTime]::UtcNow.AddMinutes(2)
        do {
            Start-Sleep -Seconds 2
            $candidate = Get-RunningPixelSerial
            if ($candidate -and $candidate -notin $before) {
                $script:serial = $candidate
                break
            }
        } while ([DateTime]::UtcNow -lt $deadline)
        if (-not $script:serial) {
            throw 'Runner-owned Pixel_6 did not register with adb.'
        }
    }

    Wait-ForBoot -DeviceSerial $script:serial
    Write-Host "Pixel_6 ready: $($script:serial); owned=$script:ownedEmulator"

    Build-And-Install -Mode full

    Set-NotificationPermission -State deny
    Invoke-AcceptanceApp -EvidenceName 'notification-denied' `
        -ExpectedPattern 'REMINDER_ACCEPTANCE:PASS mode=full permission=denied'

    Set-NotificationPermission -State grant
    Set-ExactAlarmPermission -State allow
    Invoke-AcceptanceApp -EvidenceName 'exact-granted-edit-deactivate-delete' `
        -ExpectedPattern 'REMINDER_ACCEPTANCE:PASS mode=full permission=granted precision=exact payload=habit-reminder:v1:'

    Set-ExactAlarmPermission -State deny
    Invoke-AcceptanceApp -EvidenceName 'exact-denied-inexact-fallback' `
        -ExpectedPattern 'REMINDER_ACCEPTANCE:PASS mode=full permission=granted precision=inexact payload=habit-reminder:v1:'

    Build-And-Install -Mode verify
    Invoke-AcceptanceApp -EvidenceName 'package-replace-restore' `
        -ExpectedPattern 'REMINDER_ACCEPTANCE:PASS mode=verify pending=1 payload=habit-reminder:v1:'

    & $adb -s $script:serial shell am force-stop $packageName | Out-Null
    Invoke-AcceptanceApp -EvidenceName 'process-restart-restore' `
        -ExpectedPattern 'REMINDER_ACCEPTANCE:PASS mode=verify pending=1 payload=habit-reminder:v1:'

    Invoke-Checked -FilePath $adb -Arguments @(
        '-s', $script:serial, 'reboot'
    ) -LogName 'reboot.log' | Out-Null
    Wait-ForBoot -DeviceSerial $script:serial
    Invoke-AcceptanceApp -EvidenceName 'reboot-restore' `
        -ExpectedPattern 'REMINDER_ACCEPTANCE:PASS mode=verify pending=1 payload=habit-reminder:v1:'

    Write-Host "ANDROID_REMINDER_ACCEPTANCE=PASS evidence=$evidenceRoot"
} finally {
    if ($script:ownedEmulator -and $script:serial) {
        try {
            & $adb -s $script:serial emu kill | Out-Null
            Write-Host "Stopped runner-owned emulator $($script:serial)"
        } catch {
            Write-Warning "Could not stop runner-owned emulator: $_"
        }
    }
}
