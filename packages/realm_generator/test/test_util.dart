import 'dart:io';

import 'package:build_test/build_test.dart';
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:realm_generator/realm_generator.dart';
import 'package:test/test.dart';
import 'package:pub_semver/pub_semver.dart';

final _formatter = DartFormatter(
  languageVersion: Version(3, 7, 0),
  lineEnding: '\n',
);

/// Used to test both correct an erroneous compilation.
/// [source] can be a [File] or a [String].
/// [matcher] can be a [File], [String] or a [Matcher].
/// Both expected and actual output will be formatted with [DartFormatter].
@isTest
void testCompile(
  String description,
  dynamic source,
  dynamic matcher, {
  dynamic skip,
  void Function(LogRecord)? onLog,
  bool verbose = false,
}) {
  if (source is Iterable) {
    testCompileMany(description, source, matcher);
    return;
  }

  final assetName = source is File ? source.path : 'source.dart';
  source = source is File ? source.readAsStringSync() : source;
  if (source is! String) throw ArgumentError.value(source, 'source');

  matcher = matcher is File ? matcher.readAsStringSync() : matcher;
  if (matcher is String) {
    final source = _stripFormatMarker(_formatter.format(matcher));
    matcher = completion(equals(source));
  }
  if (matcher is! Matcher) throw ArgumentError.value(matcher, 'matcher');

  test(description, () async {
    generate() async {
      final readerWriter = TestReaderWriter(rootPackage: 'pkg');
      await readerWriter.testing.loadIsolateSources();
      final result = await testBuilder(
        generateRealmObjects(),
        {'pkg|$assetName': '$source'},
        readerWriter: readerWriter,
        onLog: onLog,
        flattenOutput: true,
        verbose: verbose,
      );
      if (!result.succeeded) {
        throw BuildError(result.errors.join('\n'));
      }
      return _stripFormatMarker(_formatter.format(
        result.readerWriter.testing.readString(result.outputs.single),
      ));
    }

    expect(generate(), matcher);
  }, skip: skip);
}

@isTest
void testCompileMany(
  String description,
  Iterable<dynamic> sources,
  dynamic matcher,
) async {
  final inputs = switch (sources) {
    Iterable<File> files => files.map((file) {
        return ('pkg|${file.path}', _formatter.format(file.readAsStringSync()));
      }),
    Iterable<String> strings => strings.indexed.map((x) {
        final (index, text) = x;
        return ('pkg|source_$index.dart', _formatter.format(text));
      }),
    _ => throw ArgumentError.value(sources, 'sources'),
  };

  matcher = switch (matcher) {
    Matcher m => m,
    Iterable<String> strings => completion(
        equals(strings.map((e) => _stripFormatMarker(_formatter.format(e)))),
      ),
    Iterable<File> files => completion(
        equals(files.map((x) => _stripFormatMarker(_formatter.format(x.readAsStringSync())))),
      ),
    _ => throw ArgumentError.value(matcher, 'matcher'),
  };

  test(description, () {
    generate() async {
      final readerWriter = TestReaderWriter(rootPackage: 'pkg');
      await readerWriter.testing.loadIsolateSources();
      final result = await testBuilder(
        generateRealmObjects(),
        Map<String, Object>.fromEntries(
          inputs.map((x) {
            final (id, source) = x;
            return MapEntry(id, source);
          }),
        ),
        readerWriter: readerWriter,
        flattenOutput: true,
      );
      if (!result.succeeded) {
        throw Exception(result.errors.join('\n'));
      }
      return result.outputs.map(
        (id) => _stripFormatMarker(result.readerWriter.testing.readString(id)),
      );
    }

    expect(generate(), matcher);
  });
}

/// Strips the `// dart format width=80` marker line inserted by DartFormatter
/// to avoid comparing formatting artifacts.
String _stripFormatMarker(String source) =>
    source.replaceFirst(RegExp(r'// dart format width=\d+\n'), '');

final _endOfLine = RegExp(r'\r\n?|\n');

extension StringX on String {
  String normalizeLineEndings() => replaceAll(_endOfLine, '\n');
}

/// Error thrown when a build fails.
/// Contains the rendered error messages from the build.
class BuildError extends Error {
  final String message;
  BuildError(this.message);

  @override
  String toString() => message;
}
