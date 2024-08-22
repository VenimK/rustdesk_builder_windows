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

- **`tools.ps1`**: This script installs the necessary toolchain and dependencies required for building the RustDesk installer.
- **`build.ps1`**: This script handles the actual building process, allowing you to compile a specific version of RustDesk or use a different repository.

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
   - By default, this script is configured to build RustDesk version 1.2.6. However, you can modify the script to build a different version or use a different repository (explained below).

   ```powershell
   .\build.ps1
   ```

2. **Modify the Version or Repository** (Optional):
   - **To build a different version of RustDesk**:
     - Open `build.ps1` in a text editor.
     - Locate the following section and change `v1.2.6` to your desired version tag:
       ```powershell
       git checkout v1.2.6
       ```
   - **To use a different GitHub repository**:
     - Replace the original repository URL with your desired repository URL in the `git clone` command:
       ```powershell
       git clone https://github.com/rustdesk/rustdesk.git
       cd rustdesk
       git checkout v1.2.6
       ```

3. **Run the Script Again**:
   - If you made changes to the script, save it and run the `build.ps1` script again to compile your custom version of RustDesk.

### Output

The output of the build process will be a RustDesk installer for Windows. The first run of the script creates the standard installer, and the second run generates a portable version of RustDesk.

## Troubleshooting

- **Winget Issues**: If you encounter any issues with `winget`, such as it not displaying help or not being recognized, please refer to the official [Winget Troubleshooting Guide](https://github.com/microsoft/winget-cli/blob/d68a1a69346e7ca16a5d07eef38a2c93172eb991/doc/troubleshooting/README.md#executing-winget-doesnt-display-help).

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes.

This `README.md` covers everything needed to set up the environment, run the scripts, customize the build, and troubleshoot potential issues. It also includes references to the necessary prerequisites and resources for resolving issues with `winget`.
