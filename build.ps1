$download = 'C:\download'
$buildir = 'C:\buildrustdesk'

$CARGO_NDK_VERSION = "3.1.2"
$LLVM_VERSION= "15.0.6"
$FLUTTER_VERSION= "3.10.5"
$FLUTTER_RUST_BRIDGE_VERSION= "1.75.3"

# Custom settings, re-open your window after setting the variables or run the script twice to build rustdesk with custom settings
# [System.Environment]::SetEnvironmentVariable(‘RS_PUB_KEY’,'<<key>>',"Machine");
# [System.Environment]::SetEnvironmentVariable(‘RENDEZVOUS_SERVER’,'<<yourownserver>>',"Machine");

cd $buildir
echo "Checkout code"
git clone https://github.com/rustdesk/rustdesk.git --quiet
cd rustdesk
git reset --hard $buildcommit 

New-Item -ItemType SymbolicLink -Path (Join-Path ($buildir)('rustdesk\res\icon.ico')) -Target (Join-Path ($buildir)('rustdesk\flutter/windows/runner/resources/app_icon.ico')) -Force

Start-Process cargo.exe -ArgumentList 'install flutter_rust_bridge_codegen --version 1.75.3' -Wait
cd flutter
Start-Process flutter -ArgumentList 'pub get' -Wait
cd ../

flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart

cd (Join-Path ($buildir)('rustdesk'))
Remove-Item –path flutter\build –recurse
python.exe build.py --portable --hwcodec --flutter --feature IddDriver
