import 'dart:io';

import 'package:term_glyph/term_glyph.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() async {
  const directory = 'test/info_test_data';
  ascii = false; // force unicode glyphs

  await for (final infoFile in Directory(directory).list(recursive: true).where((f) => f.path.endsWith('.expected')).cast<File>()) {
    final sourceFile = File(infoFile.path.replaceFirst('.expected', '.dart'));
    final expectedContent = infoFile.readAsStringSync().normalizeLineEndings();
    String? capturedLog;
    testCompile(
      'log from compile $sourceFile',
      sourceFile,
      completion(predicate((_) {
        return capturedLog != null;
      })),
      verbose: true,
      onLog: (record) {
        if (capturedLog != null) return;
        // In build_test 3.5.0+, generator-level log.info() messages are prefixed
        // with "Generating .realm.dart: RealmObjectGenerator on <file>:\n"
        // Extract the generator's message content after the prefix.
        final message = record.message;
        final prefixEnd = message.indexOf('\n');
        if (prefixEnd >= 0 && message.startsWith('Generating ')) {
          final content = message.substring(prefixEnd + 1);
          if (content.normalizeLineEndings() == expectedContent) {
            capturedLog = content;
          }
        }
      },
    );
  }
}
