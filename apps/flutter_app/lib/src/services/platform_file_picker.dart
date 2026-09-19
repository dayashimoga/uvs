import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformFilePicker {
  static const MethodChannel _channel = MethodChannel('com.universalvideostudio.uvs/platform');

  // Test override hook for automated headless testing
  @visibleForTesting
  static List<String>? mockPickedFiles;

  @visibleForTesting
  static String? mockPickedFolder;

  @visibleForTesting
  static Future<ProcessResult> Function(String, List<String>)? mockProcessRunner;

  static Future<ProcessResult> _runProcess(String executable, List<String> arguments) {
    if (mockProcessRunner != null) {
      return mockProcessRunner!(executable, arguments);
    }
    return Process.run(executable, arguments);
  }

  /// Supported video and audio file extensions
  static const List<String> supportedMediaExtensions = [
    'mp4',
    'mov',
    'mkv',
    'avi',
    'webm',
    'm4v',
    'mp3',
    'wav',
    'aac',
    'flac',
    'ogg',
    'png',
    'jpg',
    'jpeg',
  ];

  /// Supported project file extensions
  static const List<String> supportedProjectExtensions = [
    'uvsp',
    'json',
  ];

  /// Pick one or more media files using the native platform file dialog.
  static Future<List<String>> pickMediaFiles({
    bool allowMultiple = true,
    String dialogTitle = "Open Media File",
  }) async {
    if (mockPickedFiles != null) {
      return List<String>.from(mockPickedFiles!);
    }

    if (kIsWeb) {
      return [];
    }

    if (Platform.isWindows) {
      return _pickFilesWindows(
        allowMultiple: allowMultiple,
        title: dialogTitle,
        filter: "Media Files (*.mp4, *.mov, *.mkv, *.avi, *.webm, *.mp3, *.wav, *.png, *.jpg)|*.mp4;*.mov;*.mkv;*.avi;*.webm;*.m4v;*.mp3;*.wav;*.aac;*.flac;*.ogg;*.png;*.jpg;*.jpeg|Video Files (*.mp4, *.mov, *.mkv)|*.mp4;*.mov;*.mkv;*.avi;*.webm|Audio Files (*.mp3, *.wav, *.aac)|*.mp3;*.wav;*.aac;*.flac;*.ogg|All Files (*.*)|*.*",
      );
    } else if (Platform.isLinux) {
      return _pickFilesLinux(
        allowMultiple: allowMultiple,
        title: dialogTitle,
      );
    } else if (Platform.isMacOS) {
      return _pickFilesMacOS(
        allowMultiple: allowMultiple,
        title: dialogTitle,
      );
    } else if (Platform.isAndroid) {
      return _pickFilesAndroid(allowMultiple: allowMultiple);
    }

    return [];
  }

  /// Pick a project file (.uvsp)
  static Future<String?> pickProjectFile({
    String dialogTitle = "Open Project File",
  }) async {
    if (mockPickedFiles != null && mockPickedFiles!.isNotEmpty) {
      return mockPickedFiles!.first;
    }

    if (Platform.isWindows) {
      final res = await _pickFilesWindows(
        allowMultiple: false,
        title: dialogTitle,
        filter: "Universal Video Studio Project (*.uvsp)|*.uvsp|JSON Files (*.json)|*.json|All Files (*.*)|*.*",
      );
      return res.isNotEmpty ? res.first : null;
    } else if (Platform.isLinux) {
      final res = await _pickFilesLinux(allowMultiple: false, title: dialogTitle);
      return res.isNotEmpty ? res.first : null;
    } else if (Platform.isMacOS) {
      final res = await _pickFilesMacOS(allowMultiple: false, title: dialogTitle);
      return res.isNotEmpty ? res.first : null;
    } else if (Platform.isAndroid) {
      final res = await _pickFilesAndroid(allowMultiple: false);
      return res.isNotEmpty ? res.first : null;
    }
    return null;
  }

  /// Pick a folder using the native platform folder dialog.
  static Future<String?> pickFolder({
    String dialogTitle = "Select Media Folder",
  }) async {
    if (mockPickedFolder != null) {
      return mockPickedFolder;
    }

    if (Platform.isWindows) {
      return _pickFolderWindows(title: dialogTitle);
    } else if (Platform.isLinux) {
      return _pickFolderLinux(title: dialogTitle);
    } else if (Platform.isMacOS) {
      return _pickFolderMacOS(title: dialogTitle);
    }
    return null;
  }

  // --- Windows Implementation via PowerShell System.Windows.Forms ---
  static Future<List<String>> _pickFilesWindows({
    required bool allowMultiple,
    required String title,
    required String filter,
  }) async {
    try {
      final multiselectVal = allowMultiple ? '\$true' : '\$false';
      final escapedFilter = filter.replaceAll('"', '`"');
      final script = '''
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
\$dlg = New-Object System.Windows.Forms.OpenFileDialog
\$dlg.Title = "$title"
\$dlg.Filter = "$escapedFilter"
\$dlg.Multiselect = $multiselectVal
\$dlg.RestoreDirectory = \$true
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    \$dlg.FileNames | ForEach-Object { Write-Output \$_ }
}
''';
      final result = await _runProcess('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .split(RegExp(r'\r?\n'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && File(s).existsSync())
            .toList();
        return lines;
      }
    } catch (e) {
      debugPrint("PlatformFilePicker Windows error: $e");
    }
    return [];
  }

  static Future<String?> _pickFolderWindows({required String title}) async {
    try {
      final script = '''
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
\$dlg = New-Object System.Windows.Forms.FolderBrowserDialog
\$dlg.Description = "$title"
\$dlg.ShowNewFolderButton = \$false
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$dlg.SelectedPath
}
''';
      final result = await _runProcess('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty && Directory(path).existsSync()) {
          return path;
        }
      }
    } catch (e) {
      debugPrint("PlatformFilePicker Windows folder error: $e");
    }
    return null;
  }

  // --- Linux Implementation via Zenity / KDialog ---
  static Future<List<String>> _pickFilesLinux({
    required bool allowMultiple,
    required String title,
  }) async {
    try {
      final args = ['--file-selection', '--title=$title'];
      if (allowMultiple) args.add('--multiple');
      args.add('--file-filter=Media Files | *.mp4 *.mov *.mkv *.avi *.webm *.mp3 *.wav *.png *.jpg');
      args.add('--file-filter=All Files | *');

      final result = await _runProcess('zenity', args);
      if (result.exitCode == 0) {
        final out = (result.stdout as String).trim();
        final files = out.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty && File(s).existsSync()).toList();
        return files;
      }
    } catch (_) {
      try {
        final args = ['--getopenfilename', '.', '*.mp4 *.mov *.mkv *.avi *.webm *.mp3 *.wav *.png *.jpg'];
        if (allowMultiple) args.add('--multiple');
        final res = await _runProcess('kdialog', args);
        if (res.exitCode == 0) {
          final out = (res.stdout as String).trim();
          return out.split(' ').where((s) => s.isNotEmpty && File(s).existsSync()).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static Future<String?> _pickFolderLinux({required String title}) async {
    try {
      final res = await _runProcess('zenity', ['--file-selection', '--directory', '--title=$title']);
      if (res.exitCode == 0) {
        final p = (res.stdout as String).trim();
        if (p.isNotEmpty && Directory(p).existsSync()) return p;
      }
    } catch (_) {}
    return null;
  }

  // --- macOS Implementation via osascript ---
  static Future<List<String>> _pickFilesMacOS({
    required bool allowMultiple,
    required String title,
  }) async {
    try {
      final mult = allowMultiple ? 'multiple selections allowed true' : 'multiple selections allowed false';
      final script = 'choose file with prompt "$title" $mult';
      final res = await _runProcess('osascript', ['-e', script]);
      if (res.exitCode == 0) {
        final out = (res.stdout as String).trim();
        final paths = <String>[];
        for (final item in out.split(',')) {
          final pRes = await _runProcess('osascript', ['-e', 'POSIX path of ($item as alias)']);
          if (pRes.exitCode == 0) {
            final p = (pRes.stdout as String).trim();
            if (p.isNotEmpty && File(p).existsSync()) paths.add(p);
          }
        }
        return paths;
      }
    } catch (e) {
      debugPrint("PlatformFilePicker macOS error: $e");
    }
    return [];
  }

  static Future<String?> _pickFolderMacOS({required String title}) async {
    try {
      final script = 'POSIX path of (choose folder with prompt "$title")';
      final res = await _runProcess('osascript', ['-e', script]);
      if (res.exitCode == 0) {
        final p = (res.stdout as String).trim();
        if (p.isNotEmpty && Directory(p).existsSync()) return p;
      }
    } catch (_) {}
    return null;
  }

  // --- Android Implementation via SAF MethodChannel ---
  static Future<List<String>> _pickFilesAndroid({required bool allowMultiple}) async {
    try {
      final dynamic result = await _channel.invokeMethod('pickMediaFiles', {
        'allowMultiple': allowMultiple,
      });
      if (result is List) {
        return result.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
    } catch (e) {
      debugPrint("PlatformFilePicker Android channel error: $e");
    }
    return [];
  }

  @visibleForTesting
  static Future<List<String>> pickFilesWindowsForTesting({required bool allowMultiple, required String title, required String filter}) =>
      _pickFilesWindows(allowMultiple: allowMultiple, title: title, filter: filter);

  @visibleForTesting
  static Future<String?> pickFolderWindowsForTesting({required String title}) =>
      _pickFolderWindows(title: title);

  @visibleForTesting
  static Future<List<String>> pickFilesLinuxForTesting({required bool allowMultiple, required String title}) =>
      _pickFilesLinux(allowMultiple: allowMultiple, title: title);

  @visibleForTesting
  static Future<String?> pickFolderLinuxForTesting({required String title}) =>
      _pickFolderLinux(title: title);

  @visibleForTesting
  static Future<List<String>> pickFilesMacOSForTesting({required bool allowMultiple, required String title}) =>
      _pickFilesMacOS(allowMultiple: allowMultiple, title: title);

  @visibleForTesting
  static Future<String?> pickFolderMacOSForTesting({required String title}) =>
      _pickFolderMacOS(title: title);

  @visibleForTesting
  static Future<List<String>> pickFilesAndroidForTesting({required bool allowMultiple}) =>
      _pickFilesAndroid(allowMultiple: allowMultiple);
}
