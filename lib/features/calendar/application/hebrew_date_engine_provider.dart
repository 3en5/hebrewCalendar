import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/hebrew_date/hebrew_date_engine.dart';

/// Shares a single stateless [HebrewDateEngine] instance across the
/// calendar feature.
final Provider<HebrewDateEngine> hebrewDateEngineProvider =
    Provider<HebrewDateEngine>((Ref ref) => const HebrewDateEngine());
