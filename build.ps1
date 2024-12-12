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
Move-Item -Path (Join-Path $download 'sciter.dll') -Destination (Join-Path $buildir 'rustdesk')

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

cd (Join-Path ($buildir)('rustdesk'))
Remove-Item –path flutter\build –recurse
# Thx CH4RG3MENT
python.exe build.py --portable --flutter --feature IddDriver hwcodec #1.3.X
#python.exe build.py --portable --hwcodec --flutter --feature IddDriver #1.2.X
