$ErrorActionPreference = 'Stop'
$archive = @(Get-ChildItem build/deskflow-*-portable.zip)
$msi = @(Get-ChildItem build/deskflow-*.msi)
if ($archive.Count -ne 1 -or $msi.Count -ne 1) { throw 'Expected one ZIP and one MSI' }
$root = Join-Path $env:RUNNER_TEMP 'deskflow-package-test'
Expand-Archive $archive[0].FullName -DestinationPath $root -Force
# Remove Qt/vcpkg from PATH to test only the packaged DLLs and Windows runtime.
$env:PATH = "$env:SystemRoot\System32;$env:SystemRoot;$env:SystemRoot\System32\Wbem"
Remove-Item Env:QT_PLUGIN_PATH -ErrorAction SilentlyContinue
Remove-Item Env:QML2_IMPORT_PATH -ErrorAction SilentlyContinue
Remove-Item Env:QT_QPA_PLATFORM -ErrorAction SilentlyContinue
$core = Get-ChildItem $root -Recurse -Filter deskflow-core.exe | Select-Object -First 1
if (!$core) { throw 'Portable core executable missing' }
& $core.FullName --version
if ($LASTEXITCODE -ne 0) { throw "Portable core failed: $LASTEXITCODE" }
$gui = Join-Path $core.DirectoryName 'deskflow.exe'
$process = Start-Process $gui -ArgumentList '--version' -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Portable GUI failed: $($process.ExitCode)" }
$install = Join-Path $env:RUNNER_TEMP 'deskflow-msi-test'
$log = Join-Path $env:RUNNER_TEMP 'deskflow-msi.log'
$arguments = "/i `"$($msi[0].FullName)`" /qn /norestart INSTALL_ROOT=`"$install`" /L*v `"$log`""
try {
    $process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -notin @(0, 3010)) {
        Get-Content $log -Tail 100
        throw "MSI installation failed: $($process.ExitCode)"
    }
    # CPack's WiX installer may use its default Program Files location.
    $candidates = @($install, (Join-Path $env:ProgramFiles 'Deskflow'))
    $installed = $candidates | Where-Object { Test-Path $_ } | ForEach-Object {
        Get-ChildItem $_ -Recurse -Filter deskflow-core.exe
    } | Select-Object -First 1
    if (!$installed) { throw 'MSI did not install deskflow-core.exe' }
    & $installed.FullName --version
    if ($LASTEXITCODE -ne 0) { throw "Installed core failed: $LASTEXITCODE" }
} finally {
    $uninstall = Start-Process msiexec.exe -ArgumentList "/x `"$($msi[0].FullName)`" /qn /norestart" -Wait -PassThru
    if ($uninstall.ExitCode -notin @(0, 3010, 1605)) { throw "MSI uninstall failed: $($uninstall.ExitCode)" }
}
