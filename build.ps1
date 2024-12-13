$download = 'C:\download'
$buildir = 'C:\buildrustdesk'

$CARGO_NDK_VERSION = "3.1.2"
$LLVM_VERSION= "15.0.6"
$FLUTTER_VERSION= "3.22.3"
$FLUTTER_RUST_BRIDGE_VERSION= "1.80.1"

# Custom settings, re-open your window after setting the variables or run the script twice to build rustdesk with custom settings
# [System.Environment]::SetEnvironmentVariable('RS_PUB_KEY','<<key>>',"Machine");
# [System.Environment]::SetEnvironmentVariable('RENDEZVOUS_SERVER','<<yourownserver>>',"Machine");

cd $buildir
##################Disable after 1st BUILD#################
echo "Checkout code"
git clone https://github.com/rustdesk/rustdesk.git --quiet
#################################################################
cd rustdesk
##################Disable after 1st BUILD#################
git reset --hard $buildcommit 
#################################################################

# Set environment variables
$env:VCPKG_ROOT = "C:\libs\vcpkg"
$env:RUSTFLAGS = "-C target-feature=+crt-static"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows-static"
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
$env:CARGO_REGISTRIES_CRATES_IO_PROTOCOL = "sparse"
$env:CMAKE_GENERATOR = "Ninja"

# Clone RustDesk if not exists
$rustdeskPath = Join-Path $buildir 'rustdesk'
if (-not (Test-Path $rustdeskPath)) {
    Write-Host "Cloning RustDesk repository..."
    git clone https://github.com/rustdesk/rustdesk.git $rustdeskPath
}

# Change to rustdesk directory
cd $rustdeskPath

# Ensure Rust toolchain is correct
Write-Host "Verifying Rust toolchain..."
rustup default 1.75-msvc
rustup component add rustfmt

# Apply Flutter patch
Write-Host "Applying Flutter patch to Flutter SDK..."
$flutterPath = (Get-Command flutter).Path
$flutterSdkPath = (Get-Item (Get-Item $flutterPath).Directory.Parent.FullName).FullName
$patchUrl = "https://raw.githubusercontent.com/rustdesk/rustdesk/master/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
$patchFile = Join-Path $flutterSdkPath "flutter_3.24.4_dropdown_menu_enableFilter.diff"

Write-Host "Downloading Flutter patch..."
Invoke-WebRequest -Uri $patchUrl -OutFile $patchFile

Write-Host "Applying patch to Flutter SDK at: $flutterSdkPath"
Push-Location $flutterSdkPath
git apply $patchFile
Pop-Location

# Clean up and prepare repository
Write-Host "Preparing repository..."
if (Test-Path $rustdeskPath) {
    cd $rustdeskPath
    git reset --hard HEAD
    git clean -fd
    git pull origin master
} else {
    git clone https://github.com/rustdesk/rustdesk.git $rustdeskPath
}

# Generate Flutter-Rust bridge
Write-Host "Generating Flutter-Rust bridge..."
cd $rustdeskPath

# Ensure the output directories exist
$dartOutputDir = Join-Path $rustdeskPath "flutter\lib"
$rustOutputDir = Join-Path $rustdeskPath "src"
New-Item -ItemType Directory -Force -Path $dartOutputDir
New-Item -ItemType Directory -Force -Path $rustOutputDir

# Ensure the Rust source file exists
$rustSourceFile = Join-Path $rustdeskPath "src/flutter_ffi.rs"
if (-not (Test-Path $rustSourceFile)) {
    Write-Error "Rust source file not found: $rustSourceFile"
    exit 1
}

Write-Host "Generating bridge code..."
flutter_rust_bridge_codegen generate `
    --rust-input src/flutter_ffi.rs `
    --dart-output flutter/lib/generated_bridge.dart `
    --rust-output src/bridge_generated.rs `
    --c-output flutter/windows/flutter/generated_plugin_registrant.h

# Verify bridge files were generated
if (-not (Test-Path (Join-Path $dartOutputDir "generated_bridge.dart"))) {
    Write-Error "Bridge generation failed: generated_bridge.dart not found"
    exit 1
}

# Update pubspec.yaml to use compatible package versions
Write-Host "Updating pubspec dependencies..."
cd (Join-Path $rustdeskPath 'flutter')
$pubspecContent = Get-Content pubspec.yaml -Raw
$pubspecContent = $pubspecContent -replace 'extended_text: \^13.0.0', 'extended_text: ^11.0.1'
$pubspecContent = $pubspecContent -replace 'extended_text: 13.0.0', 'extended_text: 11.0.1'
Set-Content pubspec.yaml $pubspecContent

# Clean and get dependencies
flutter clean
flutter pub get

Write-Host "Formatting generated files..."
if (Test-Path "flutter/lib/generated_bridge.dart") {
    dart format flutter/lib/generated_bridge.dart
}

# Verify all tools are available
Write-Host "Verifying build tools..."
cmake --version
ninja --version
cargo --version
flutter --version

# Build Rust library first with all required features
Write-Host "Building Rust library..."
cargo build --features "flutter" --no-default-features --lib --release

# Build Flutter Windows Application
Write-Host "Building Flutter Windows Application..."
cd (Join-Path $rustdeskPath 'flutter')
flutter config --enable-windows-desktop
flutter build windows --release

# Create the release directory if it doesn't exist
$releaseDir = Join-Path $rustdeskPath 'flutter\build\windows\x64\runner\Release'
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Force -Path $releaseDir
}

cd $rustdeskPath

# Download USB MMIDD driver
Write-Host "Downloading USB MMIDD driver..."
$mmidd_url = "https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip"
Invoke-WebRequest -Uri $mmidd_url -OutFile (Join-Path $download 'usbmmidd_v2.zip')
Expand-Archive -Path (Join-Path $download 'usbmmidd_v2.zip') -DestinationPath $buildir -Force

# Move the built files
Write-Host "Moving built files..."
$releasePath = Join-Path $rustdeskPath 'flutter\build\windows\x64\runner\Release'

if (Test-Path $releasePath) {
    Write-Host "Moving Release folder to rustdesk directory..."
    if (Test-Path (Join-Path $rustdeskPath 'Release')) {
        Remove-Item -Path (Join-Path $rustdeskPath 'Release') -Recurse -Force
    }
    Move-Item -Path $releasePath -Destination $rustdeskPath -Force
} else {
    Write-Host "Error: Release folder not found at $releasePath"
    Write-Host "Build might have failed. Please check the build output above."
    exit 1
}

# Move USB MMIDD files
$usbmmiddPath = Join-Path $buildir 'usbmmidd_v2'
if (Test-Path $usbmmiddPath) {
    Write-Host "Moving USB MMIDD files..."
    Remove-Item -Path (Join-Path $usbmmiddPath 'Win32') -Recurse -ErrorAction SilentlyContinue
    $filesToRemove = @(
        "deviceinstaller64.exe",
        "deviceinstaller.exe",
        "usbmmidd.bat"
    )
    foreach ($file in $filesToRemove) {
        Remove-Item -Path (Join-Path $usbmmiddPath $file) -ErrorAction SilentlyContinue
    }
    
    $targetUsbmmiddPath = Join-Path $rustdeskPath 'usbmmidd_v2'
    if (Test-Path $targetUsbmmiddPath) {
        Remove-Item -Path $targetUsbmmiddPath -Recurse -Force
    }
    Move-Item -Path $usbmmiddPath -Destination $rustdeskPath -Force
} else {
    Write-Host "Warning: USB MMIDD folder not found at $usbmmiddPath"
}

Write-Host "Build completed successfully!"
