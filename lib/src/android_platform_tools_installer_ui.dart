import 'dart:async';
import 'dart:io';

import 'package:adb_tools/adb_tools.dart';
import 'package:path/path.dart';
import 'package:progressbar2/progressbar2.dart';

/// Installs the Android SDK, and, if [installPlatformTools] is true, the SDK
/// platform tools, to the given [sdkRoot] directory.
///
/// Returns a [Future] that completes when the installation finishes.
///
/// If [output] is given, messages will be logged to it. Otherwise, standard I/O
/// will be used. If standard I/O is used, subprocess output will not be
/// streamed as messages and will instead be sent directly to standard output.
/// If an [existingArchiveFile] is provided, it will be used instead of
/// downloading the latest one available.
/// If [deleteArchiveFile] is true, the downloaded SDK archive file will be
/// deleted as soon as it is no longer needed.
/// If a [messageFormatter] is provided, messages will be sent through it before
/// being outputted.
/// If [verbose] is true, subprocess will be run with verbose flags, and
/// output from more subprocesses will be shown. Note that the latter cannot be
/// prevented at all when no [output] sink is provided, even if [verbose] is
/// false.
///
/// [launchPathSettings] and [installPlatformTools] are passed directly to
/// [installCmdlineTools].
///
/// This function relies on the same external tools as [installCmdlineTools].
Future<void> installAndroidSdk({
  StringSink? output,
  Directory? sdkRoot,
  File? existingArchiveFile,
  bool deleteArchiveFile = true,
  bool launchPathSettings = true,
  bool verbose = false,
  String Function(String message, {required bool isError}) messageFormatter =
      _unitMessageFormatter,
  bool installPlatformTools = true,
}) async {
  // Set up output channels.
  final messageSink = output ?? stdout;
  final errorSink = output ?? stderr;
  void writeMessage(String message) =>
      messageSink.writeln(messageFormatter(message, isError: false));
  void writeError(String message) =>
      errorSink.writeln(messageFormatter(message, isError: true));

  // Use the provided SDK root, or determine a platform-appropriate one if none
  // is provided.
  sdkRoot ??= _determineSdkRoot();

  // Download the command-line tools archive if required, using a pretty
  // progress bar if outputting to a terminal.
  final File archiveFile;
  if (existingArchiveFile == null) {
    final ProgressCallback onReceiveProgress;
    if (output == null && stdout.hasTerminal) {
      writeMessage('Downloading SDK command-line tools:');
      final progressBar = ProgressBar(
        formatter: (current, total, progress, elapsed) =>
            '[$current/$total] ${ProgressBar.formatterBarToken} [${(progress * 100).floor()}%]',
        total: 0,
      );
      onReceiveProgress = (count, total) {
        progressBar.total = total;
        progressBar.value = count;
        progressBar.render();
      };
    } else {
      String format(int count, int total) =>
          'Downloading SDK command-line tools: $count/$total (${((count / total) * 100).floor()}%)';
      onReceiveProgress = output == null
          ? (count, total) => writeMessage(format(count, total))
          : (count, total) => writeMessage(format(count, total));
    }
    archiveFile = await downloadCmdlineToolsArchive(
      sdkRoot,
      onReceiveProgress: onReceiveProgress,
    );
  } else {
    archiveFile = existingArchiveFile;
  }

  late final List<Directory> pathEntries;
  Type? currentProgressStage;
  await for (final progress in installCmdlineTools(
    sdkRoot,
    archiveFile,
    deleteArchiveFile: deleteArchiveFile,
    launchPathSettings: launchPathSettings,
    verbose: verbose,
    installPlatformTools: installPlatformTools,
    inheritStdio: output == null,
  )) {
    final isNewProgressStage = progress.runtimeType != currentProgressStage;
    if (isNewProgressStage) currentProgressStage = progress.runtimeType;
    final bool messageIsVerbose;

    if (progress is CmdlineToolsInstallExtracting) {
      if (isNewProgressStage) {
        writeMessage('Extracting SDK tools...');
      }
      if (!progress.usingNativeUnzip) {
        writeError('Could not use native unzip tool');
      }
      messageIsVerbose = true; // Classify extraction output as verbose.
    } else if (progress is CmdlineToolsInstallInstallingPlatformTools) {
      if (isNewProgressStage) {
        writeMessage('Installing platform tools...');
      }
      messageIsVerbose = false;
    } else if (progress is CmdlineToolsInstallCompleted) {
      pathEntries = progress.directPathEntries.toList(growable: false);
      messageIsVerbose = false;
    } else {
      messageIsVerbose = false;
    }

    final message = progress.message;
    if (message != null && (verbose || !messageIsVerbose)) {
      message.isError ? writeError(message.text) : writeMessage(message.text);
    }
  }

  writeMessage(
    'Android SDK installed. Remember to add the following directories to your PATH:',
  );
  for (final path in pathEntries) {
    messageSink.write('  ');
    messageSink.writeln(path.path);
  }
}

Directory _determineSdkRoot() {
  final Directory sdkRoot;
  if (Platform.isMacOS) {
    sdkRoot = Directory(
        join(Platform.environment['HOME']!, 'Library', 'Android', 'Sdk'));
  } else if (Platform.isLinux) {
    sdkRoot = Directory(join(Platform.environment['HOME']!, 'Android', 'Sdk'));
  } else if (Platform.isWindows) {
    sdkRoot = Directory(
        join(Platform.environment['LOCALAPPDATA']!, 'Android', 'Sdk'));
  } else {
    throw const CmdlineToolsInstallUnsupportedPlatformException();
  }
  sdkRoot.createSync(recursive: true);
  return sdkRoot;
}

String _unitMessageFormatter(String message, {required bool isError}) =>
    message;
