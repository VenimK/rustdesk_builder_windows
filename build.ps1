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

Start-Process cargo.exe -ArgumentList 'install flutter_rust_bridge_codegen --version 1.80.1' -Wait
cd flutter
Start-Process flutter -ArgumentList 'pub get' -Wait
cd ../

flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart

# Update src/main.rs
Write-Host "Edit and adjust the src/main.rs to load the sciter.dll correctly"
$mainRSPath = Join-Path $buildir 'rustdesk/src/main.rs'

$mainRSContent = Get-Content $mainRSPath -Raw
$updatedMainRSContent = $mainRSContent -replace 'let bytes = std::include_bytes\("..\\sciter.dll"\);', 'let bytes = std::include_bytes!("../sciter.dll");'
Set-Content -Path $mainRSPath -Value $updatedMainRSContent

# Download and extract USB MMIDD driver
Write-Host "Downloading USB MMIDD driver"
$mmidd_url = "https://github.com/rustdesk-org/rdev/releases/download/usbmmidd_v2/usbmmidd_v2.zip"
Invoke-WebRequest -Uri $mmidd_url -OutFile (Join-Path $download 'usbmmidd_v2.zip')
Expand-Archive -Path (Join-Path $download 'usbmmidd_v2.zip') -DestinationPath $buildir -Force

cd (Join-Path ($buildir)('rustdesk'))
Remove-Item -Path "flutter\build" -Recurse -ErrorAction SilentlyContinue

# Set environment variables
$env:VCPKG_ROOT = "C:\libs\vcpkg"
$env:RUSTFLAGS = "-C target-feature=+crt-static"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows-static"
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"

# Build the application
Write-Host "Building RustDesk..."
python.exe build.py --portable --flutter --hwcodec

# Only proceed with file operations if build succeeded
if ($LASTEXITCODE -eq 0) {
    # Clean up and organize files
    $releasePath = Join-Path $buildir 'rustdesk\flutter\build\windows\x64\runner\Release'
    $usbmmiddPath = Join-Path $buildir 'usbmmidd_v2'
    $rustdeskPath = Join-Path $buildir 'rustdesk'

    if (Test-Path $releasePath) {
        Write-Host "Moving Release folder..."
        if (Test-Path (Join-Path $rustdeskPath 'Release')) {
            Remove-Item -Path (Join-Path $rustdeskPath 'Release') -Recurse -Force
        }
        Move-Item -Path $releasePath -Destination $rustdeskPath -Force
    } else {
        Write-Host "Warning: Release folder not found at $releasePath"
        Write-Host "Build might have failed. Please check if all dependencies are installed:"
        Write-Host "- libvpx"
        Write-Host "- libyuv"
        Write-Host "- opus"
        Write-Host "- ffmpeg[core,avcodec,avformat,swscale,swresample]"
    }

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
} else {
    Write-Host "Build failed. Please check the error messages above."
    Write-Host "Make sure all dependencies are properly installed using tools.ps1"
    exit 1
}
