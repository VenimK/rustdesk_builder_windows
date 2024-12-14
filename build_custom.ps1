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

# Clean Flutter environment
Write-Host "Cleaning Flutter environment..."
flutter clean
Remove-Item -Path (Join-Path $rustdeskPath "flutter\.dart_tool") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $rustdeskPath "flutter\build") -Recurse -Force -ErrorAction SilentlyContinue
flutter pub cache clean
flutter pub get

# Install and configure Rust toolchain
Write-Host "Installing and configuring Rust toolchain..."
rustup toolchain install 1.75 --target x86_64-pc-windows-msvc --component rustfmt --profile minimal --no-self-update
rustup default 1.75

# Display Rust version information
Write-Host "Rust version information:"
rustc +1.75 --version --verbose
rustup show

# Install flutter_rust_bridge_codegen
Write-Host "Installing flutter_rust_bridge_codegen..."
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features "uuid" --force --locked

# Generate bridge code
Write-Host "Generating bridge code..."
Set-Location $rustdeskPath
flutter_rust_bridge_codegen --rust-input src/flutter_ffi.rs --dart-output flutter/lib/generated_bridge.dart

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
Set-Location $rustdeskPath
python build.py --portable --hwcodec --flutter --vram --virtual-display

Write-Host "Build process completed!"
