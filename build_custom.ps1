Clear-Host

# Set environment variables
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
$download = 'C:\download'
$buildir = 'C:\buildrustdesk'
$rustdeskPath = Join-Path $buildir "rustdesk"
$releasePath = Join-Path $rustdeskPath "flutter\build\windows\x64\runner\Release"

# Create download directory if it doesn't exist
if (-not (Test-Path $download)) {
    New-Item -ItemType Directory -Force -Path $download
}

# Change to RustDesk directory
Set-Location $rustdeskPath

# Install and configure Rust toolchain
Write-Host "Installing and configuring Rust toolchain..."
rustup toolchain install 1.75 --target x86_64-pc-windows-msvc --component rustfmt --profile minimal --no-self-update
rustup default 1.75

# Display Rust version information
Write-Host "Rust version information:"
rustc +1.75 --version --verbose
rustup show

# Prepare Release directory
Write-Host "Preparing Release directory..."
if (Test-Path $releasePath) {
    Remove-Item -Path $releasePath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $releasePath

# Install flutter_rust_bridge_codegen
Write-Host "Installing flutter_rust_bridge_codegen..."
cargo install flutter_rust_bridge_codegen --version 1.80.1 --features "uuid" --force

# Generate bridge code
Write-Host "Generating bridge code..."
flutter_rust_bridge_codegen --rust-input .\src\flutter_ffi.rs --dart-output .\flutter\lib\generated_bridge.dart

# Copy WindowInjection.dll
Write-Host "Copying WindowInjection.dll..."
Copy-Item -Path "C:\download\WindowInjection.dll" -Destination $releasePath -Force

# Run build script
Write-Host "Running build script..."
python .\build.py --portable --hwcodec --flutter --vram --virtual-display

Write-Host "Build process completed!"
