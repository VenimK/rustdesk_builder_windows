# rustdesk_build_windows

Two powershell scripts to build your own rustdesk installer for windows.

The process is splitted in two: first installing the toolchain, second is cloning the rustdesk repo and checkout the current nightly. Do not forget to closing and reopening the shell to also reload the created environment variables. After that the installer is built. In the build.ps1 file you can set your server settings.

I've tested this in a hyper-v instance of windows 10.
