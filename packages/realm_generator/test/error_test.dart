import 'dart:io';

import 'package:test/test.dart';
import 'package:term_glyph/term_glyph.dart';
import 'test_util.dart';

void main() async {
  const directory = 'test/error_test_data';
  ascii = false; // force unicode glyphs

  await for (final errorFile in Directory(directory).list(recursive: true).where((f) => f.path.endsWith('.expected')).cast<File>()) {
    final sourceFile = File(errorFile.path.replaceFirst('.expected', '.dart'));
    final expectedError = (await errorFile.readAsString()).trim().normalizeLineEndings();
    testCompile(
      'compile $sourceFile',
      sourceFile,
      throwsA(
        isA<BuildError>().having(
          (e) => _matchesExpectedError(e.toString(), expectedError),
          'toString',
          isTrue,
        ),
      ),
    );
  }
}

bool _matchesExpectedError(String actual, String expected) {
  final normalizedActual = actual.trim().normalizeLineEndings();
  if (normalizedActual == expected) {
    return true;
  }
  // build_test may reduce some errors to `message + todo`.
  return normalizedActual == _summarizeExpectedError(expected);
}

String _summarizeExpectedError(String expected) {
  final lines = expected.split('\n');
  final nonEmpty = lines.where((line) => line.trim().isNotEmpty).toList();
  if (nonEmpty.isEmpty) return '';
  if (nonEmpty.length == 1) return nonEmpty.first;
  return '${nonEmpty.first}\n${nonEmpty.last}';
}
