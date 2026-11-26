import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/animation_config.dart';

/// Put first among a long menu's items: it fades the bottom edge of the menu
/// while there is more below it.
///
/// A menu taller than the screen ends on a row sliced through its label, with
/// nothing to say that the list goes on. The SDK's popup menu gives its scroll
/// view no hook, so this entry sits inside it — it takes no height — finds
/// the viewport above it and paints a gradient of the menu's own colour over
/// its bottom edge. The gradient goes once the list is scrolled to its end.
///
/// ```dart
/// PopupMenuButton<String>(
///   itemBuilder: (context) => const [
///     MenuScrollFade(),
///     PopupMenuItem(value: 'a', child: Text('A')),
///     // …
///   ],
/// );
/// ```
class MenuScrollFade extends PopupMenuEntry<Never> {
  const MenuScrollFade({super.key, this.depth = 36});

  /// How far up from the menu's bottom edge the fade reaches.
  final double depth;

  /// The entry takes no height and stands for no value.
  @override
  double get height => 0;

  @override
  bool represents(Never? value) => false;

  @override
  State<MenuScrollFade> createState() => _MenuScrollFadeState();
}

class _MenuScrollFadeState extends State<MenuScrollFade> {
  static const _fadeKey = Key('menu-scroll-fade');

  OverlayEntry? _fade;
  ScrollPosition? _position;
  Animation<double>? _route;
  Rect _viewport = Rect.zero;
  bool _moreBelow = false;

  @override
  void initState() {
    super.initState();
    // The viewport above this entry exists once the menu has laid out once.
    SchedulerBinding.instance.addPostFrameCallback((_) => _attach());
  }

  void _attach() {
    if (!mounted) return;
    final scrollable = context.findAncestorStateOfType<ScrollableState>();
    if (scrollable == null) return;
    _position = scrollable.position..addListener(_update);
    // While the menu is still opening, or once it is closing, the fade stays
    // out of the way of the menu's own animation.
    _route = ModalRoute.of(context)?.animation;
    _route?.addListener(_update);
    _fade = OverlayEntry(builder: _buildFade);
    Overlay.of(context, rootOverlay: true).insert(_fade!);
    _update();
  }

  void _update() {
    if (_fade == null) return;
    final scrollable = context.findAncestorStateOfType<ScrollableState>();
    final viewport = scrollable?.context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject() as RenderBox?;
    if (viewport == null || overlay == null || !viewport.hasSize) return;

    final origin = viewport.localToGlobal(Offset.zero, ancestor: overlay);
    _viewport = origin & viewport.size;
    _moreBelow = (_position?.extentAfter ?? 0) > 0.5;
    _fade!.markNeedsBuild();
  }

  bool get _menuIsAtRest =>
      _route == null || (_route!.isCompleted && !_route!.isDismissed);

  Widget _buildFade(BuildContext context) {
    final theme = PopupMenuTheme.of(context);
    final color = theme.color ?? Theme.of(context).colorScheme.surface;
    final shape = theme.shape;
    final radius = shape is RoundedRectangleBorder
        ? (shape.borderRadius.resolve(TextDirection.ltr) as BorderRadius)
            .bottomLeft
        : Radius.zero;
    final motion = context.motion;

    return Positioned.fromRect(
      key: _fadeKey,
      rect: Rect.fromLTWH(
        _viewport.left,
        _viewport.bottom - widget.depth,
        _viewport.width,
        widget.depth,
      ),
      child: IgnorePointer(
        child: ClipRRect(
          // The menu's own bottom corners, so the fade ends where it does.
          borderRadius: BorderRadius.vertical(bottom: radius),
          child: AnimatedOpacity(
            duration: motion.standard,
            curve: motion.arrive,
            opacity: _menuIsAtRest && _moreBelow ? 1 : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withAlpha(0), color],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Nothing in the menu itself: the fade is painted above it.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    _position?.removeListener(_update);
    _route?.removeListener(_update);
    // An entry that was never mounted, or whose overlay is already gone,
    // cannot be removed.
    if (_fade?.mounted ?? false) _fade!.remove();
    _fade = null;
    super.dispose();
  }
}
