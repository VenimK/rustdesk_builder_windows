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
echo "Checking Git installation..."
$gitInstalled = $null
try {
    $gitVersion = (git --version) 2>&1
    if ($gitVersion -match "git version (\d+\.\d+\.\d+)") {
        $installedVersion = $Matches[1]
        $requiredVersion = "2.41.0"
        if ([Version]$installedVersion -ge [Version]$requiredVersion) {
            Write-Host "Git $installedVersion is already installed and meets minimum version requirement ($requiredVersion)"
            $gitInstalled = $true
        } else {
            Write-Host "Git $installedVersion is installed but needs upgrade to $requiredVersion"
        }
    }
} catch {
    Write-Host "Git is not installed"
}

if (-not $gitInstalled) {
    echo "Installing Git..."
    $git_url = 'https://github.com/git-for-windows/git/releases/download/v2.41.0.windows.1/Git-2.41.0-64-bit.exe'
    Start-BitsTransfer -Source $git_url -Destination $download 
    $git_installerPath = Join-Path ($download) ([System.IO.Path]::GetFileName($git_url) );
    Start-Process $git_installerPath -ArgumentList '/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"' -Wait
    Add-Path 'C:\Program Files\Git\bin'
    Reload-Env;
}

# Install Rust and required components
Write-Host "Installing Rust..."
Invoke-WebRequest -Uri https://win.rustup.rs/x86_64 -OutFile "$download\rustup-init.exe"
Start-Process -FilePath "$download\rustup-init.exe" -ArgumentList "-y" -Wait
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Set up Rust toolchain
Write-Host "Setting up Rust toolchain..."
rustup set profile minimal
rustup default 1.75-msvc

# Install specific components
Write-Host "Installing Rust components..."
rustup component add cargo
rustup component add rust-std
rustup component add rustc
rustup component add rustfmt
rustup target add x86_64-pc-windows-msvc

# Install Visual Studio Build Tools
Write-Host "Checking Visual Studio Build Tools..."
$vsInstalled = $null
try {
    $vsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWhere) {
        $vsInstallation = & $vsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vsInstallation) {
            Write-Host "Visual Studio Build Tools are already installed"
            $vsInstalled = $true
        }
    }
} catch {
    Write-Host "Visual Studio Build Tools not found"
}

if (-not $vsInstalled) {
    Write-Host "Installing Visual Studio Build Tools..."
    winget install Microsoft.VisualStudio.2022.BuildTools --silent --override "--wait --quiet --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
}

# Install LLVM
Write-Host "Checking LLVM installation..."
$llvmInstalled = $null
try {
    $llvmVersion = (clang --version) 2>&1
    if ($llvmVersion -match "clang version (\d+\.\d+\.\d+)") {
        $installedVersion = $Matches[1]
        $requiredVersion = "15.0.6"
        if ([Version]$installedVersion -ge [Version]$requiredVersion) {
            Write-Host "LLVM $installedVersion is already installed and meets minimum version requirement ($requiredVersion)"
            $llvmInstalled = $true
        }
    }
} catch {
    Write-Host "LLVM not found"
}

if (-not $llvmInstalled) {
    Write-Host "Installing LLVM..."
    winget install LLVM.LLVM
}

# Install additional build tools
Write-Host "Checking Ninja installation..."
$ninjaInstalled = $null
try {
    $ninjaVersion = (ninja --version) 2>&1
    if ($ninjaVersion -match "(\d+\.\d+\.\d+)") {
        Write-Host "Ninja $ninjaVersion is already installed"
        $ninjaInstalled = $true
    }
} catch {
    Write-Host "Ninja not found"
}

if (-not $ninjaInstalled) {
    Write-Host "Installing Ninja..."
    winget install Ninja-build.Ninja
}

Write-Host "Checking CMake installation..."
$cmakeInstalled = $null
try {
    $cmakeVersion = (cmake --version) 2>&1
    if ($cmakeVersion -match "cmake version (\d+\.\d+\.\d+)") {
        Write-Host "CMake $($Matches[1]) is already installed"
        $cmakeInstalled = $true
    }
} catch {
    Write-Host "CMake not found"
}

if (-not $cmakeInstalled) {
    Write-Host "Installing CMake..."
    winget install Kitware.CMake
}

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

Write-Host "Installing vcpkg packages..."
$vcpkgPackages = @(
    "libvpx:x64-windows-static",
    "opus:x64-windows-static",
    "brotli:x64-windows-static"
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
[System.Environment]::SetEnvironmentVariable("LIBCLANG_PATH", "C:\Program Files\LLVM\bin", "Machine")
[System.Environment]::SetEnvironmentVariable("CARGO_REGISTRIES_CRATES_IO_PROTOCOL", "sparse", "Machine")

# Install Chocolatey and required packages
Write-Host "Installing Chocolatey..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco install ninja cmake -y

# Reload environment variables
Reload-Env

cd $libdir
Write-Host "Checking/Updating rustdesk_thirdpary_lib..."
if (Test-Path "rustdesk_thirdpary_lib") {
    cd rustdesk_thirdpary_lib
    git pull --quiet
    cd ..
} else {
    git clone https://github.com/Kingtous/rustdesk_thirdpary_lib --depth=1 --quiet
}
[System.Environment]::SetEnvironmentVariable("VCPKG_ROOT",(Join-Path ($libdir) ('rustdesk_thirdpary_lib\vcpkg')),"Machine");

#Flutter 
echo "Install flutter"
$flutter_url = 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.4-stable.zip'
Start-BitsTransfer -Source $flutter_url -Destination $download 
$flutter_source = Join-Path ($download) ([System.IO.Path]::GetFileName($flutter_url) );
$flutter_dest = Join-Path ($buildir) ('flutter');
Expand-Archive -Path $flutter_source -DestinationPath $buildir -Force
Add-Path (Join-Path ($flutter_dest) ('bin'))

# Set Flutter environment variables
[System.Environment]::SetEnvironmentVariable("FLUTTER_ROOT", $flutter_dest, "Machine")
[System.Environment]::SetEnvironmentVariable("PATH", $env:PATH + ";" + (Join-Path $flutter_dest 'bin'), "Machine")

# Initialize Flutter and install bridge
Write-Host "Initializing Flutter..."
flutter doctor
flutter config --enable-windows-desktop

# Modify pubspec.yaml
Write-Host "Modifying pubspec.yaml..."
$content = Get-Content "flutter/pubspec.yaml" -Raw
$content = $content -replace 'extended_text: 14.0.0', 'extended_text: 13.0.0'
Set-Content "flutter/pubspec.yaml" $content

# Install Flutter-Rust bridge generator
Write-Host "Installing Flutter-Rust bridge..."
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features "uuid" --locked

# Reload environment variables
Reload-Env

#python
Write-Host "Checking Python installation..."
$pythonInstalled = $null
try {
    $pythonVersion = (python --version) 2>&1
    if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
        $installedVersion = $Matches[1]
        $requiredVersion = "3.11.4"
        if ([Version]$installedVersion -ge [Version]$requiredVersion) {
            Write-Host "Python $installedVersion is already installed and meets minimum version requirement ($requiredVersion)"
            $pythonInstalled = $true
            $python_path = (Get-Command python).Path | Split-Path -Parent
            Add-Path $python_path
        }
    }
} catch {
    Write-Host "Python not found"
}

if (-not $pythonInstalled) {
    echo "Installing Python..."
    $python_url = 'https://www.python.org/ftp/python/3.11.4/python-3.11.4-amd64.exe'
    Start-BitsTransfer -Source $python_url -Destination $download 
    $python_installerPath = Join-Path ($download) ([System.IO.Path]::GetFileName($python_url) );
    Start-Process $python_installerPath -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait
    $python_path = 'C:\Program Files\Python311'

    Add-Path $python_path
    cd $python_path
    New-Item -ItemType SymbolicLink -Path "python3.exe" -Target "python.exe" -Force

    # Clean up python aliases if they exist
    $pythonAliases = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\python3.exe")
    )

    foreach ($alias in $pythonAliases) {
        if (Test-Path $alias) {
            Remove-Item $alias -Force
        }
    }
}

Reload-Env;
