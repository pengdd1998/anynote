import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Put first among a long menu's items: it fades the bottom edge of the menu
/// while there is more below it.
///
/// A menu taller than the screen ends on a row sliced through its label, with
/// nothing to say that the list goes on. The SDK's popup menu gives its scroll
/// view no hook, so this entry sits inside it — it takes no height — and
/// puts a painter in the overlay above the menu. The painter finds the menu
/// where it is at the moment it paints, so the fade is on the menu's bottom
/// edge from the menu's first frame: a menu grows while it opens, and changes
/// height when a keyboard closes under it. Laid out from where the menu had
/// been at its last scroll, the fade had to wait for the menu to be at rest
/// before it could be shown — more than a second after the menu on a slow
/// phone, with the last row sliced as before for all of that second.
///
/// ```dart
/// PopupMenuButton<String>(
///   clipBehavior: Clip.antiAlias,
///   itemBuilder: (context) => const [
///     MenuScrollFade(),
///     PopupMenuItem(value: 'a', child: Text('A')),
///     // …
///   ],
/// );
/// ```
///
/// Give the menu [Clip.antiAlias]: with [Clip.none] a row can paint outside
/// the menu's rounded corner, where the fade does not reach.
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
  OverlayEntry? _fade;

  @override
  void initState() {
    super.initState();
    // The viewport above this entry exists once the menu has laid out once.
    SchedulerBinding.instance.addPostFrameCallback((_) => _attach());
  }

  void _attach() {
    if (!mounted) return;
    final scrollable = context.findAncestorStateOfType<ScrollableState>();
    // The overlay the menu is in, so the fade is above the menu and under
    // whatever is above the menu.
    final overlayState = Overlay.of(context);
    final overlay = overlayState.context.findRenderObject() as RenderBox?;
    if (scrollable == null || overlay == null) return;
    final viewport = scrollable.context.findRenderObject() as RenderBox;
    // Read from inside the menu: the painter is built in the overlay above,
    // where the route in scope is not the menu's.
    final opening = ModalRoute.of(context)?.animation;
    // Repainted whenever the menu animates or scrolls. A relayout, such as a
    // keyboard closing, repaints the overlay the menu is in, painter included.
    final changes = Listenable.merge([opening, scrollable.position]);

    overlayState.insert(
      _fade = OverlayEntry(
        builder: (context) {
          final theme = PopupMenuTheme.of(context);
          final shape = theme.shape;
          final radius = shape is RoundedRectangleBorder
              ? shape.borderRadius.resolve(TextDirection.ltr).bottomLeft
              : Radius.zero;
          return IgnorePointer(
            child: CustomPaint(
              key: const Key('menu-scroll-fade'),
              painter: MenuScrollFadePainter(
                viewport: viewport,
                overlay: overlay,
                position: scrollable.position,
                opening: opening,
                color: theme.color ?? Theme.of(context).colorScheme.surface,
                radius: radius,
                depth: widget.depth,
                repaint: changes,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Nothing in the menu itself: the fade is painted above it.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    // An entry that was never inserted, or whose overlay is already gone,
    // cannot be removed.
    if (_fade?.mounted ?? false) _fade!.remove();
    _fade = null;
    super.dispose();
  }
}

/// The fade, painted in the menu's own overlay, over the menu's bottom edge.
///
/// An entry of an overlay sits at the overlay's origin and fills it, and is
/// painted after the entries below it; so when this paints, the menu has been
/// laid out for this frame, and where its viewport says it is, is where it is.
class MenuScrollFadePainter extends CustomPainter {
  MenuScrollFadePainter({
    required this.viewport,
    required this.overlay,
    required this.position,
    required this.opening,
    required this.color,
    required this.radius,
    required this.depth,
    required super.repaint,
  });

  /// The menu's scroll view.
  final RenderBox viewport;

  /// The overlay the menu and this painter are both in.
  final RenderBox overlay;

  final ScrollPosition position;

  /// The menu route's animation, while it opens and while it closes.
  final Animation<double>? opening;

  /// The menu's surface colour.
  final Color color;

  /// The menu's bottom corner radius.
  final Radius radius;

  /// How far up from the menu's bottom edge the fade reaches.
  final double depth;

  double _opacity = 0;
  Rect _rect = Rect.zero;

  /// The fade as last painted: 0 when there is none.
  double get opacity => _opacity;

  /// The fade as last painted, in the overlay's coordinates.
  Rect get rect => _rect;

  @override
  void paint(Canvas canvas, Size size) {
    // The menu fades in over the first third of its route's animation, and
    // out again as it closes. The fade does the same, so the two are never
    // seen apart.
    final shown = const Interval(0, 1 / 3).transform(opening?.value ?? 1);

    // While the menu is taken down, its viewport leaves the tree before the
    // entry above it does: there is nothing left to place the fade against.
    if (!viewport.attached || !viewport.hasSize) {
      _opacity = 0;
      return;
    }
    _opacity = position.extentAfter > 0.5 ? shown : 0;

    final origin = viewport.localToGlobal(Offset.zero, ancestor: overlay);
    _rect = Rect.fromLTWH(
      origin.dx,
      origin.dy + viewport.size.height - depth,
      viewport.size.width,
      depth,
    );
    if (_opacity <= 0) return;

    // The menu's own bottom corners, so the fade ends where it does.
    canvas.clipRRect(
      RRect.fromRectAndCorners(
        _rect,
        bottomLeft: radius,
        bottomRight: radius,
      ),
    );
    canvas.drawRect(
      _rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: shown)],
        ).createShader(_rect),
    );
  }

  @override
  bool shouldRepaint(MenuScrollFadePainter oldDelegate) => true;
}
