# Set error action preference and encoding
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Environment variables for build
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
$env:VCPKG_ROOT = "C:\vcpkg"
$env:RUSTFLAGS = "-C target-feature=+crt-static"
$env:VCPKG_DEFAULT_TRIPLET = "x64-windows-static"
$env:CARGO_REGISTRIES_CRATES_IO_PROTOCOL = "sparse"

# Increase memory limits
$env:DART_VM_OPTIONS = "--old_gen_heap_size=4096 --max_old_space_size=4096"
$env:NODE_OPTIONS = "--max_old_space_size=4096"

# Parse command line arguments
param(
    [switch]$portable,
    [switch]$flutter,
    [switch]$hwcodec,
    [switch]$vram,
    [switch]$feature,
    [string]$featureName = "",
    [switch]$skip_portable_pack
)

# Build command construction
$buildArgs = @("build.py")

if ($portable) {
    $buildArgs += "--portable"
}

if ($flutter) {
    $buildArgs += "--flutter"
}

if ($hwcodec) {
    $buildArgs += "--hwcodec"
}

if ($vram) {
    $buildArgs += "--vram"
}

if ($feature -and $featureName) {
    $buildArgs += "--feature"
    $buildArgs += $featureName
}

if ($skip_portable_pack) {
    $buildArgs += "--skip-portable-pack"
}

# Execute build
try {
    Write-Host "Starting build with arguments: $buildArgs"
    python $buildArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Build failed with exit code $LASTEXITCODE"
    }
    
    Write-Host "Build completed successfully"
} catch {
    Write-Warning "Build failed"
    Write-Warning $_.Exception.Message
    exit 1
}
