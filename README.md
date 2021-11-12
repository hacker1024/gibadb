# gibadb
A tool to easily install the Android SDK command-line and platform tools.

**For developers:**
_This README describes the CLI tool that ships with this Dart package. For package
documentation, consult the appropriate [README](README_PACKAGE.md)._

## Features
- [x] Cross-platform support
  - [x] Windows
  - [x] MacOS
  - [x] Linux
- [x] Upgradeable platform tools
- [x] Minimal, but a standard SDK installation (Android Studio compatible)

## Obtaining
Binaries can be found in the [releases](https://github.com/hacker1024/gibadb/releases) page.

<details>
<summary>
Alternatively, for those with the Dart SDK installed, pub can be used to activate
the package...
</summary>

```
$ dart pub global activate --source git https://github.com/hacker1024/gibadb.git
```
</details>

The following external tools are required:

- Java
- p7zip or `unzip` (macOS and Linux)
- PowerShell 5.0+ (Windows)

## Usage

1. Open a terminal (or command prompt)
2. Run `gibadb`
3. Add the required lines to your PATH

### Options

```
$ gibadb --help

Usage: gibadb.dart [options] [SDK installation directory]
Install the Android SDK command-line and platform tools.

If no SDK installation directory is provided, a common, platform-specific location is chosen.
-v, --verbose                                 Show more installation details.
    --[no-]launch-path-settings               Open the system path settings after installation.
                                              (defaults to on)
    --[no-]platform-tools                     Install the SDK platform tools as well as the base SDK command-line tools.
                                              (defaults to on)
-a, --archive=<command-line tools archive>    Use an existing SDK command-line tools archive, instead of downloading one.
    --keep-archive                            Don't delete the SDK command-line tools archive.
-h, --help                                    Show the usage information.
```
