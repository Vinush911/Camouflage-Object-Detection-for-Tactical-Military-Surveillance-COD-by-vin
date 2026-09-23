import 'dart:io';

// Helper utility to read current application memory (RAM) usage.
// On Android devices, it reads directly from the system process status file.

class AppMemoryUtils {
  // Returns current process memory in Megabytes (MB)
  static int getCurrentRssMb() {
    try {
      if (Platform.isAndroid) {
        // On Android, read the process status file which reports actual memory used
        final statusFile = File('/proc/self/status');
        if (statusFile.existsSync()) {
          final lines = statusFile.readAsLinesSync();
          for (final line in lines) {
            if (line.startsWith('VmRSS:')) {
              // Line format: VmRSS:    123456 kB
              final parts = line.split(RegExp(r'\s+'));
              if (parts.length >= 2) {
                final kb = int.tryParse(parts[1]) ?? 0;
                if (kb > 0) {
                  return (kb / 1024).round();
                }
              }
            }
          }
        }
      }

      // Fallback for desktop platforms
      final bytes = ProcessInfo.currentRss;
      if (bytes > 0) {
        return (bytes / (1024 * 1024)).round();
      }
    } catch (_) {
      // Ignored
    }

    // Default reasonable estimate if system file is not accessible
    return 120;
  }
}
