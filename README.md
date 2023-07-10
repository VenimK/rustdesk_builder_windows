# rustdesk_build_windows

Two powershell scripts to build your own rustdesk installer for windows.

The process is splitted in two: first installing the toolchain (tools.ps1), second is building the official 1.2.0 version (build.ps1). Do not forget to closing and reopening the shell to also reload the created environment variables. In the build.ps1 file you can set your server settings.

I've tested this on a hyper-v instance of windows 10.
