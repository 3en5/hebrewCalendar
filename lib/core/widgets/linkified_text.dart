import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/text/text_links.dart';
import '../../l10n/app_localizations.dart';
import '../theme/dimens.dart';

/// [text] with its phone numbers, emails and web links tappable (owner
/// request 2026-10-15). A phone number offers call, WhatsApp and copy; an
/// email offers mail and copy; a web link opens in the browser.
///
/// Stateful only to own the tap recognizers, which are disposed with it.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(this.text, {this.style, this.maxLines, super.key});

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  void _clearRecognizers() {
    for (final TapGestureRecognizer r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final List<TextLink> links = findTextLinks(widget.text);
    final TextStyle base = widget.style ?? DefaultTextStyle.of(context).style;
    if (links.isEmpty) {
      return Text(widget.text, style: base, maxLines: widget.maxLines);
    }
    final TextStyle linkStyle = base.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );
    final List<InlineSpan> spans = <InlineSpan>[];
    int at = 0;
    for (final TextLink link in links) {
      if (link.start > at) {
        spans.add(TextSpan(text: widget.text.substring(at, link.start)));
      }
      final TapGestureRecognizer tap = TapGestureRecognizer()
        ..onTap = () => _onTap(link);
      _recognizers.add(tap);
      spans.add(TextSpan(text: link.text, style: linkStyle, recognizer: tap));
      at = link.end;
    }
    if (at < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(at)));
    }
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: widget.maxLines,
    );
  }

  void _onTap(TextLink link) {
    switch (link.kind) {
      case TextLinkKind.url:
        final String raw = link.text;
        unawaited(
          _launch(Uri.parse(raw.startsWith('www.') ? 'https://$raw' : raw)),
        );
      case TextLinkKind.phone:
        unawaited(_phoneSheet(link.text));
      case TextLinkKind.email:
        unawaited(_emailSheet(link.text));
    }
  }

  Future<void> _launch(Uri uri) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final String failed = AppLocalizations.of(context).linkOpenFailed;
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _copy(String value) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final String copied = AppLocalizations.of(context).linkCopied;
    await Clipboard.setData(ClipboardData(text: value));
    messenger?.showSnackBar(SnackBar(content: Text(copied)));
  }

  Future<void> _phoneSheet(String phone) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return _actionsSheet(phone, <_LinkAction>[
      _LinkAction(
        key: 'link-call',
        icon: Icons.call_outlined,
        label: l10n.linkCall,
        run: () => _launch(Uri(scheme: 'tel', path: dialableNumber(phone))),
      ),
      _LinkAction(
        key: 'link-whatsapp',
        icon: Icons.chat_outlined,
        label: l10n.linkWhatsApp,
        run: () => _launch(Uri.https('wa.me', '/${whatsAppNumber(phone)}')),
      ),
      _LinkAction(
        key: 'link-copy',
        icon: Icons.copy_outlined,
        label: l10n.linkCopy,
        run: () => _copy(phone),
      ),
    ]);
  }

  Future<void> _emailSheet(String email) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return _actionsSheet(email, <_LinkAction>[
      _LinkAction(
        key: 'link-mail',
        icon: Icons.mail_outline,
        label: l10n.linkSendEmail,
        run: () => _launch(Uri(scheme: 'mailto', path: email)),
      ),
      _LinkAction(
        key: 'link-copy',
        icon: Icons.copy_outlined,
        label: l10n.linkCopy,
        run: () => _copy(email),
      ),
    ]);
  }

  Future<void> _actionsSheet(String value, List<_LinkAction> actions) async {
    final _LinkAction? chosen = await showModalBottomSheet<_LinkAction>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: spacingMd,
                end: spacingMd,
                bottom: spacingSm,
              ),
              // The value reads left to right, aligned with the Hebrew
              // labels on the right.
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            for (final _LinkAction action in actions)
              ListTile(
                key: ValueKey<String>(action.key),
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () => Navigator.of(sheetContext).pop(action),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      await chosen.run();
    }
  }
}

class _LinkAction {
  const _LinkAction({
    required this.key,
    required this.icon,
    required this.label,
    required this.run,
  });

  final String key;
  final IconData icon;
  final String label;
  final Future<void> Function() run;
}
