import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../coming_soon.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => ComingSoon(
    title: AppLocalizations.of(context).navCalendar,
    icon: Icons.calendar_month,
  );
}
