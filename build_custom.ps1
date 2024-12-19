Clear-Host

# Set environment variables
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
$download = 'C:\download'
$buildir = 'C:\buildrustdesk'
$rustdeskPath = Join-Path $buildir "rustdesk"
$releasePath = Join-Path $rustdeskPath "flutter\build\windows\x64\runner\Release"

# Increase memory limits
$env:DART_VM_OPTIONS = "--old_gen_heap_size=4096 --max_old_space_size=4096"
$env:NODE_OPTIONS = "--max_old_space_size=4096"

# Clean up temporary files
Write-Host "Cleaning up temporary files..."
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
[System.GC]::Collect()

# Create necessary directories
Write-Host "Creating necessary directories..."
@($download, $buildir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        try {
            New-Item -ItemType Directory -Force -Path $_
            Write-Host "Created directory: $_"
        } catch {
            Write-Warning "Failed to create directory: $_"
            Write-Warning $_.Exception.Message
            exit 1
        }
    }
}

# Clone RustDesk if not exists
if (-not (Test-Path $rustdeskPath)) {
    Write-Host "Cloning RustDesk repository..."
    git clone https://github.com/rustdesk/rustdesk.git $rustdeskPath
}

# Change to rustdesk directory
Set-Location $rustdeskPath

# Install and configure Rust toolchain
Write-Host "Installing and configuring Rust toolchain..."
rustup toolchain install 1.75 --target x86_64-pc-windows-msvc --component rustfmt --profile minimal --no-self-update
rustup default 1.75

# Display Rust version information
Write-Host "Rust version information:"
rustc +1.75 --version --verbose
rustup show

# Check vcpkg dependencies
$vcpkgPath = "C:\libs\vcpkg\vcpkg.exe"
$installRoot = "C:\libs\vcpkg\installed"

if (!(Test-Path $vcpkgPath)) {
    Write-Host "Error: vcpkg executable not found at $vcpkgPath"
    exit 1
}

# List of packages to check
$packagesToCheck = @(
    "openssl",
    "libvpx",
    "libyuv",
    "opus"
    # Add other specific packages RustDesk might need
)

$needsInstall = $false

foreach ($package in $packagesToCheck) {
    $packagePath = Join-Path $installRoot "x64-windows-static\include\$package"
    if (!(Test-Path $packagePath)) {
        Write-Host "Package $package is missing. Needs installation."
        $needsInstall = $true
        break
    }
}

if ($needsInstall) {
    Write-Host "Installing vcpkg dependencies..."
    & $vcpkgPath install --triplet x64-windows-static --x-install-root="$installRoot"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "vcpkg installation failed. Checking log files..."
        Get-ChildItem -Path "C:\libs\vcpkg" -Recurse -Filter "*.log" | ForEach-Object {
            Write-Host "Log file: $($_.FullName)"
            Write-Host "======"
            Get-Content $_.FullName
            Write-Host "======"
            Write-Host ""
        }
        exit 1
    }
} else {
    Write-Host "All required vcpkg packages are already installed."
}

# Clean and prepare Flutter environment
Write-Host "Preparing Flutter environment..."
Set-Location (Join-Path $rustdeskPath "flutter")
flutter clean
Remove-Item -Path ".dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "build" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "lib/generated_bridge*" -Force -ErrorAction SilentlyContinue
flutter pub cache clean


# Install flutter_rust_bridge_codegen
Write-Host "Installing flutter_rust_bridge_codegen..."
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features "uuid" --force --locked

Push-Location "C:\buildrustdesk\rustdesk\flutter"
flutter pub get
Pop-Location

# Generate bridge code
Write-Host "Generating bridge code..."
flutter_rust_bridge_codegen --rust-input ..\src\flutter_ffi.rs --dart-output .\lib\generated_bridge.dart



# Extract and copy WindowInjection.dll
Write-Host "Extracting WindowInjection.dll..."
$windowsDllZipPath = "f:\rustdesk_builder_windows\WindowInjection.zip"
$windowsDllPath = Join-Path $download "WindowInjection.dll"

try {
    # Ensure the download directory exists
    if (-not (Test-Path $download)) {
        New-Item -ItemType Directory -Force -Path $download
    }

    # Extract the DLL
    Write-Host "Extracting from: $windowsDllZipPath"
    Write-Host "Extracting to: $download"
    Expand-Archive -Path $windowsDllZipPath -DestinationPath $download -Force
    
    # Create release directory structure
    New-Item -ItemType Directory -Force -Path $releasePath
    
    # Copy WindowInjection.dll
    Write-Host "Copying WindowInjection.dll to: $releasePath"
    Copy-Item -Path $windowsDllPath -Destination $releasePath -Force
} catch {
    Write-Warning "Failed to extract or copy WindowInjection.dll"
    Write-Warning $_.Exception.Message
    exit 1
}

# Run build script
Write-Host "Running build script..."
$env:RUST_BACKTRACE = "full"
$env:RUST_LOG = "debug"
Set-Location $rustdeskPath
python build.py --portable --flutter

# Copy debug DLLs
Write-Host "Copying debug DLLs..."
$debugDlls = @(
    "vcruntime140.dll",
    "vcruntime140_1.dll",
    "msvcp140.dll"
)

foreach ($dll in $debugDlls) {
    $sourcePath = "C:\Windows\System32\$dll"
    if (Test-Path $sourcePath) {
        Copy-Item -Path $sourcePath -Destination "$releasePath" -Force
        Write-Host "Copied $dll"
    }
}

Write-Host "Build process completed! The executable should be in: $releasePath"
Write-Host "Try running the executable with: Start-Process '$releasePath\rustdesk.exe' -NoNewWindow -Wait"