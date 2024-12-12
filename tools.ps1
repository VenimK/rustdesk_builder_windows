#Following https://rustdesk.com/docs/en/dev/build/windows/

$download = 'C:\download'
$buildir = 'C:\buildrustdesk'
$libdir = 'C:\libs'

function Add-Path($Path) {
    $Path = [Environment]::GetEnvironmentVariable("PATH", "Machine") + [IO.Path]::PathSeparator + $Path
    [Environment]::SetEnvironmentVariable( "Path", $Path, "Machine" )
}

function Reload-Env {
   foreach($level in "Machine","User") {
      [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
         # For Path variables, append the new values, if they're not already in there
         if($_.Name -match 'Path$') { 
            $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
         }
         $_
      } | Set-Content -Path { "Env:$($_.Name)" }
   }
}

New-Item -ItemType Directory -Force -Path $download
New-Item -ItemType Directory -Force -Path $buildir
New-Item -ItemType Directory -Force -Path $libdir

#git
echo "Install Git"
$git_url = 'https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.1/Git-2.41.0-64-bit.exe'
Start-BitsTransfer -Source $git_url -Destination $download 
$git_installerPath = Join-Path ($download) ([System.IO.Path]::GetFileName($git_url) );
Start-Process $git_installerPath -ArgumentList '/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"' -Wait
Add-Path 'C:\Program Files\Git\bin'
Reload-Env;

#buildtools
echo "Install buildtools"
winget install --accept-source-agreements --accept-package-agreements -e --id Microsoft.VisualStudio.2022.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools;includeRecommended"

#rust-up
echo "Install rustup"
$rust_url = 'https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe'
Start-BitsTransfer -Source $rust_url -Destination $download 
$rust_installerPath = Join-Path ($download) ([System.IO.Path]::GetFileName($rust_url) );
Start-Process $rust_installerPath -ArgumentList '--default-host x86_64-pc-windows-msvc --profile complete -y' -Wait

#vcpkg
echo "Install vcpkg"
cd $libdir
git clone https://github.com/microsoft/vcpkg --quiet
cd vcpkg
git checkout --quiet
cd ..
$vcpkgPath = Join-Path $libdir 'vcpkg'
& "$vcpkgPath/bootstrap-vcpkg.bat"
[System.Environment]::SetEnvironmentVariable("VCPKG_ROOT",$vcpkgPath,"Machine");
Reload-Env;

$vcpkgExe = Join-Path $vcpkgPath 'vcpkg.exe'

Write-Host "Installing LLVM..."
winget install LLVM.LLVM

Write-Host "Installing vcpkg packages..."
$vcpkgPackages = @(
    "libvpx:x64-windows-static",
    "libyuv:x64-windows-static",
    "opus:x64-windows-static",
    "aom:x64-windows-static",
    "libwebp:x64-windows-static",
    "brotli:x64-windows-static",
    "ffmpeg[core,avcodec,avformat,swscale,swresample]:x64-windows-static"
)

foreach ($package in $vcpkgPackages) {
    Write-Host "Installing $package..."
    & $vcpkgExe install $package
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to install $package"
        exit 1
    }
}

Write-Host "Running vcpkg integrate install..."
& $vcpkgExe integrate install

# Set environment variables for build
[System.Environment]::SetEnvironmentVariable("VCPKG_ROOT", $vcpkgPath, "Machine")
[System.Environment]::SetEnvironmentVariable("RUSTFLAGS", "-C target-feature=+crt-static", "Machine")
[System.Environment]::SetEnvironmentVariable("VCPKG_DEFAULT_TRIPLET", "x64-windows-static", "Machine")

# Reload environment variables
Reload-Env

cd $libdir
git clone https://github.com/Kingtous/rustdesk_thirdpary_lib --depth=1  --quiet
[System.Environment]::SetEnvironmentVariable("VCPKG_ROOT",(Join-Path ($libdir) ('rustdesk_thirdpary_lib\vcpkg')),"Machine");

#Flutter 
echo "Install flutter"
$flutter_url = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.6-stable.zip'
Start-BitsTransfer -Source $flutter_url -Destination $download 
$flutter_source = Join-Path ($download) ([System.IO.Path]::GetFileName($flutter_url) );
Expand-Archive -Path $flutter_source -DestinationPath $buildir -Force
$flutter_dest = Join-Path ($buildir) ('flutter');
Add-Path (Join-Path ($flutter_dest) ('bin'))

#python
echo "Install Python"
$python_url = 'https://www.python.org/ftp/python/3.11.4/python-3.11.4-amd64.exe'
Start-BitsTransfer -Source $python_url -Destination $download 
$python_installerPath = Join-Path ($download) ([System.IO.Path]::GetFileName($python_url) );
Start-Process $python_installerPath -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait
$python_path = 'C:\Program Files\Python311'

Add-Path $python_path
cd $python_path
New-Item -ItemType SymbolicLink -Path "python3.exe" -Target "python.exe" -Force

Remove-Item $env:LOCALAPPDATA\Microsoft\WindowsApps\python.exe
Remove-Item $env:LOCALAPPDATA\Microsoft\WindowsApps\python3.exe

Reload-Env;
