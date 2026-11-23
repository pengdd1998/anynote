import '../../../l10n/app_localizations.dart';
import '../../publish/domain/publish_rules.dart';

/// What to call a compose target on screen.
///
/// The platform's own name when it is one the app knows; [platformId] itself
/// for anything else, which is what a session saved with an older style name
/// (`xhs`, `blog`) would otherwise show.
String platformLabel(
  AppLocalizations l10n,
  List<PlatformGuide> guides,
  String platformId,
) {
  if (platformId == 'generic') return l10n.platformGeneric;
  return guideFor(guides, platformId)?.name ?? platformId;
}
