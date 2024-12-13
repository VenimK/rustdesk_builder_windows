$download = 'C:\download'
$buildir = 'C:\buildrustdesk'
$sciterUrl = 'https://raw.githubusercontent.com/c-smile/sciter-sdk/master/bin.win/x64/sciter.dll' # Provide the URL where sciter.dll can be downloaded here

$CARGO_NDK_VERSION = "3.1.2"
$LLVM_VERSION= "15.0.6"
$FLUTTER_VERSION= "3.19.6"
$FLUTTER_RUST_BRIDGE_VERSION= "1.80.1"

# Custom settings, re-open your window after setting the variables or run the script twice to build rustdesk with custom settings
# [System.Environment]::SetEnvironmentVariable(‘RS_PUB_KEY’,'<<key>>',"Machine");
# [System.Environment]::SetEnvironmentVariable(‘RENDEZVOUS_SERVER’,'<<yourownserver>>',"Machine");

cd $buildir
##################Disable after 1st BUILD#################
echo "Checkout code"
git clone https://github.com/rustdesk/rustdesk.git --quiet
#################################################################
cd rustdesk
##################Disable after 1st BUILD#################
git reset --hard $buildcommit 
#################################################################

# Download sciter.dll
Write-Host "Downloading sciter.dll"
Invoke-WebRequest -Uri $sciterUrl -OutFile (Join-Path $download 'sciter.dll')

# Move sciter.dll to the source directory
Write-Host "Moving sciter.dll to the rustdesk source map"
$destPath = Join-Path $buildir 'rustdesk\sciter.dll'
if (Test-Path $destPath) {
    Remove-Item -Path $destPath -Force
}
Move-Item -Path (Join-Path $download 'sciter.dll') -Destination $destPath -Force

New-Item -ItemType SymbolicLink -Path (Join-Path ($buildir)('rustdesk\res\icon.ico')) -Target (Join-Path ($buildir)('rustdesk\flutter/windows/runner/resources/app_icon.ico')) -Force

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

# Generate Flutter-Rust bridge
Write-Host "Generating Flutter-Rust bridge..."
cd (Join-Path $rustdeskPath 'flutter')

# Downgrade extended_text package
Write-Host "Downgrading extended_text package..."
(Get-Content pubspec.yaml) -replace 'extended_text: \^14.0.0', 'extended_text: ^13.1.0' | Set-Content pubspec.yaml

flutter pub get
cd $rustdeskPath

Write-Host "Generating bridge code..."
flutter_rust_bridge_codegen generate `
    --rust-input src/flutter_ffi.rs `
    --dart-output flutter/lib/generated_bridge.dart `
    --dart-decl-output flutter/lib/bridge_generated.dart `
    --dart-definitions-output flutter/lib/bridge_definitions.dart `
    --c-output flutter/windows/flutter/generated_plugin_registrant.h
dart format flutter/lib/generated_bridge.dart
dart format flutter/lib/bridge_generated.dart
dart format flutter/lib/bridge_definitions.dart

# Build Rust library first
Write-Host "Building Rust library..."
cargo build --features flutter --lib --release --verbose

# Build Flutter Windows Application
Write-Host "Building Flutter Windows Application..."
cd (Join-Path $rustdeskPath 'flutter')
flutter config --enable-windows-desktop
flutter build windows --release
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
