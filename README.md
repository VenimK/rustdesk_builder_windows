# RustDesk Custom Installer Builder for Windows 

This repository provides PowerShell scripts to build a custom RustDesk installer for Windows. The scripts allow you to compile RustDesk from source, with the flexibility to specify different versions or use a custom GitHub repository.

## Prerequisites

Before you begin, ensure you have the following installed on your system:

1. **Windows PowerShell**: The scripts are written in PowerShell, so you'll need a Windows environment to run them.
2. **Winget (Windows Package Manager)**: This is required to install some dependencies. Ensure that you have `winget` installed along with the **App Installer** package from [Microsoft Store](https://apps.microsoft.com/detail/9nblggh4nns1?hl=en-us&gl=US).
 
   - To check if `winget` is installed, open a PowerShell window and type:
     ```powershell
     winget --version
     ```

   - If `winget` is not installed or you encounter any issues, you can refer to the [Winget Troubleshooting Guide](https://github.com/microsoft/winget-cli/blob/d68a1a69346e7ca16a5d07eef38a2c93172eb991/doc/troubleshooting/README.md#executing-winget-doesnt-display-help) for assistance.

## Repository Contents

- **`tools.ps1`**: This script installs the necessary toolchain and dependencies:
  - Git (v2.41.0)
  - Visual Studio 2022 Build Tools
  - Rust (x86_64-pc-windows-msvc)
  - VCPKG with required libraries
  - LLVM (v15.0.6)
  - Flutter (v3.19.6)
  - Python (v3.11.4)

- **`build.ps1`**: This script handles the actual building process with the following configurations:
  - Flutter version: 3.19.6
  - Flutter Rust Bridge version: 1.80.1
  - Support for both RustDesk 1.2.X and 1.3.X build formats
  - Optional custom settings for `RS_PUB_KEY` and `RENDEZVOUS_SERVER`

## Usage

### Step 1: Set Up the Toolchain

1. **Run `tools.ps1`**:
   - This script sets up all necessary tools and dependencies for building RustDesk.
   - **Important**: After running this script, **CLOSE** and **REOPEN** your PowerShell session to reload the environment variables.

   ```powershell
   .\tools.ps1
   ```

### Step 2: Build the RustDesk Installer

1. **Run `build.ps1`**:
   ```powershell
   .\build.ps1
   ```

2. **Custom Settings** (Optional):
   - To use custom settings, uncomment and modify these lines in `build.ps1`:
     ```powershell
     # [System.Environment]::SetEnvironmentVariable('RS_PUB_KEY','<<key>>',"Machine");
     # [System.Environment]::SetEnvironmentVariable('RENDEZVOUS_SERVER','<<yourownserver>>',"Machine");
     ```

3. **Build Options**:
   - For RustDesk 1.3.X:
     ```powershell
     python.exe build.py --portable --flutter --feature IddDriver hwcodec
     ```
   - For RustDesk 1.2.X:
     ```powershell
     python.exe build.py --portable --hwcodec --flutter --feature IddDriver
     ```

### Output

The build process will create:
1. First run: Standard RustDesk installer
2. Second run: Portable version of RustDesk

## Directory Structure

The scripts use the following directory structure:
- `C:\download`: Temporary directory for downloaded files
- `C:\buildrustdesk`: Main build directory
- `C:\libs`: Directory for additional libraries

## Troubleshooting

1. **Environment Variables**: If you encounter path-related issues, ensure you've reopened PowerShell after running `tools.ps1`.

2. **Build Errors**: 
   - Ensure all dependencies are properly installed
   - Check if the correct Flutter version (3.19.6) is being used
   - Verify that VCPKG_ROOT and LIBCLANG_PATH are correctly set

3. **Winget Issues**: For winget-related problems, refer to the [Winget Troubleshooting Guide](https://github.com/microsoft/winget-cli/blob/d68a1a69346e7ca16a5d07eef38a2c93172eb991/doc/troubleshooting/README.md#executing-winget-doesnt-display-help).

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.
