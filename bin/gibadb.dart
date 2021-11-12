import 'dart:io';

import 'package:adb_tools/adb_tools.dart';
import 'package:android_platform_tools_installer_ui/android_platform_tools_installer_ui.dart';
import 'package:args/args.dart';

Future<void> main(List<String> arguments) async {
  final argParser = ArgParser()
    ..addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show more installation details.',
      negatable: false,
    )
    ..addFlag(
      'launch-path-settings',
      help: 'Open the system path settings after installation.',
      defaultsTo: true,
    )
    ..addFlag(
      'platform-tools',
      help:
          'Install the SDK platform tools as well as the base SDK command-line tools.',
      defaultsTo: true,
    )
    ..addOption(
      'archive',
      abbr: 'a',
      help:
          'Use an existing SDK command-line tools archive, instead of downloading one.',
      valueHelp: 'command-line tools archive',
    )
    ..addFlag(
      'keep-archive',
      help: "Don't delete the SDK command-line tools archive.",
      negatable: false,
    )
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Show the usage information.',
      negatable: false,
    );

  void printUsage(StringSink output) {
    output
      ..writeln(
        'Usage: ${Platform.script.pathSegments.last} [options] [SDK installation directory]',
      )
      ..writeln('Install the Android SDK command-line and platform tools.')
      ..writeln()
      ..writeln(
        'If no SDK installation directory is provided, a common, platform-specific location is chosen.',
      )
      ..writeln(argParser.usage);
  }

  final ArgResults argResults;
  try {
    argResults = argParser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln();
    printUsage(stderr);
    exitCode = 2;
    return;
  }

  final verbose = argResults['verbose']! as bool;
  final launchPathSettings = argResults['launch-path-settings']! as bool;
  final installPlatformTools = argResults['platform-tools']! as bool;
  final existingCmdlineToolsArchive = argResults['archive'] as String?;
  final keepCmdlineToolsArchive = argResults['keep-archive']! as bool;
  final showUsageInformation = argResults['help']! as bool;
  final sdkInstallationDirectoryPath =
      argResults.rest.isEmpty ? null : argResults.rest[0];

  if (showUsageInformation) {
    printUsage(stdout);
    return;
  }

  final File? existingArchiveFile;
  if (existingCmdlineToolsArchive != null) {
    existingArchiveFile = File(existingCmdlineToolsArchive);
    if (!existingArchiveFile.existsSync()) {
      stderr.writeln(
          'The specified commandline-tools archive file does not exist.');
      exitCode = -1;
      return;
    }
  } else {
    existingArchiveFile = null;
  }

  final Directory? sdkRoot;
  if (sdkInstallationDirectoryPath != null) {
    sdkRoot = Directory(sdkInstallationDirectoryPath);
    if (!sdkRoot.parent.existsSync()) {
      stderr.writeln(
          'The specified SDK installation parent directory does not exist.');
      exitCode = -1;
      return;
    }
    sdkRoot.createSync();
  } else {
    sdkRoot = null;
  }

  String formatMessage(String message, {required bool isError}) =>
      '${isError ? '!' : '*'} $message';
  void writeMessage(String message) =>
      stdout.writeln(formatMessage(message, isError: false));
  void writeError(String message) =>
      stderr.writeln(formatMessage(message, isError: true));

  try {
    await installAndroidSdk(
      sdkRoot: sdkRoot,
      existingArchiveFile: existingArchiveFile,
      deleteArchiveFile: !keepCmdlineToolsArchive,
      launchPathSettings: launchPathSettings,
      verbose: verbose,
      messageFormatter: formatMessage,
      installPlatformTools: installPlatformTools,
    );
  } on CmdlineToolsInstallUnsupportedPlatformException {
    writeError('Could not install command-line tools: Unsupported platform!');
    exitCode = -2;
    return;
  } on CmdlineToolsExtractFailedException catch (e) {
    writeError('Could not extract command-line tools: error ${e.errorCode}');
    exitCode = -3;
    return;
  } on CmdlineToolsPrepareFailedException catch (e) {
    writeError('Could not prepare command-line tools.');
    writeError(
      e.fileSystemException
          .toString()
          .substring('FileSystemException: '.length),
    );
    exitCode = -4;
    return;
  } on PlatformToolsInstallFailedException catch (e) {
    writeError('Could not install platform tools: error ${e.errorCode}');
    exitCode = -5;
    return;
  }
}
