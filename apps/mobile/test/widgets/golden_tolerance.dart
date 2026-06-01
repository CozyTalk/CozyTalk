import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installs a golden comparator that tolerates a small pixel diff for the
/// current test, restoring the previous comparator afterwards.
///
/// Golden images render with tiny font/anti-aliasing differences across
/// operating systems (developer macOS vs CI Linux), producing sub-1% diffs that
/// fail an exact comparison on whichever platform did not generate the
/// baseline. A small tolerance lets one committed baseline pass on both while
/// real visual regressions (far larger diffs) still fail.
///
/// [testFilePath] must be the path of the calling test file relative to the
/// package root (e.g. 'test/widgets/cozy_card_golden_test.dart'); the comparator
/// resolves `matchesGoldenFile` paths relative to that file's directory.
void useGoldenTolerance(String testFilePath, {double tolerance = 0.01}) {
  final previous = goldenFileComparator;
  goldenFileComparator = _TolerantGoldenFileComparator(
    Uri.parse(testFilePath),
    tolerance: tolerance,
  );
  addTearDown(() => goldenFileComparator = previous);
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile, {required this.tolerance});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
