import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../coming_soon.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) => ComingSoon(
    title: AppLocalizations.of(context).navEvents,
    icon: Icons.event_repeat,
  );
}
