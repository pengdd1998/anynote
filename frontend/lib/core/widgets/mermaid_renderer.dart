import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../constants/app_durations.dart';
import '../theme/app_theme.dart';
import 'mermaid_template.dart';

/// Detects and extracts ```mermaid code blocks from markdown content.
///
/// Returns a list of [MermaidBlock] instances representing each mermaid
/// diagram found in the source text. Each block records the diagram source
/// code and the character offsets where it appears so callers can split
/// the surrounding markdown.
class MermaidBlock {
  /// Zero-based start offset in the original markdown (includes the opening
  /// fence line).
  final int start;

  /// Zero-based end offset in the original markdown (includes the closing
  /// fence line).
  final int end;

  /// Raw mermaid diagram source code (between the fences).
  final String code;

  const MermaidBlock({
    required this.start,
    required this.end,
    required this.code,
  });
}

/// Scans [markdown] for ```mermaid ... ``` fenced code blocks and returns
/// them in document order.
List<MermaidBlock> extractMermaidBlocks(String markdown) {
  final blocks = <MermaidBlock>[];

  // Match ```mermaid ... ``` including the fence lines.
  final regex = RegExp(
    r'```mermaid\s*\n([\s\S]*?)```',
    multiLine: true,
  );

  for (final match in regex.allMatches(markdown)) {
    blocks.add(
      MermaidBlock(
        start: match.start,
        end: match.end,
        code: match.group(1)?.trim() ?? '',
      ),
    );
  }

  return blocks;
}

/// Whether [kIsWeb] is true, indicating the web platform where WebView
/// is unavailable.
bool get _isWeb => kIsWeb;

/// A widget that renders a mermaid diagram using WebView.
///
/// On platforms where WebView is available (Android, iOS, macOS), the widget
/// loads a local HTML page with mermaid.js from CDN and renders the diagram
/// as SVG. On web platform or when WebView fails, it falls back to showing
/// the source code with a copy button.
///
/// A "View Source" toggle button allows switching between the rendered
/// diagram and the raw mermaid code.
class MermaidRenderer extends StatefulWidget {
  /// The raw mermaid diagram source code.
  final String code;

  const MermaidRenderer({super.key, required this.code});

  @override
  State<MermaidRenderer> createState() => _MermaidRendererState();
}

class _MermaidRendererState extends State<MermaidRenderer> {
  /// Whether to show the source code view instead of the rendered diagram.
  bool _showSource = false;

  /// Whether the WebView failed and we should show the fallback source view.
  bool _webViewFailed = false;

  /// Whether the WebView is currently loading.
  bool _isLoading = true;

  /// The rendered content height reported by the WebView.
  double _contentHeight = 300;

  /// The WebView controller.
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (!_isWeb) {
      _initWebView();
    }
  }

  void _initWebView() {
    final isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
        isDark ? const Color(0xFF1A1614) : Colors.white,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (_) {
            if (mounted && !_webViewFailed) {
              setState(() {
                _webViewFailed = true;
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (message) {
          try {
            final data = message.message;
            // Simple JSON parsing without dart:convert dependency.
            if (data.contains('"renderComplete"')) {
              // Extract height value.
              final heightMatch =
                  RegExp(r'"height"\s*:\s*(\d+)').firstMatch(data);
              if (heightMatch != null) {
                final height = double.parse(heightMatch.group(1)!);
                if (mounted && height > 0) {
                  setState(() {
                    _contentHeight = height.clamp(100.0, 800.0);
                  });
                }
              }
            } else if (data.contains('"renderError"')) {
              if (mounted && !_webViewFailed) {
                setState(() {
                  _webViewFailed = true;
                  _isLoading = false;
                });
              }
            }
          } catch (e) {
            // Ignore malformed messages.
            debugPrint(
                '[MermaidRenderer] failed to parse JS channel message: $e');
          }
        },
      );

    // Load the mermaid HTML template.
    final html = buildMermaidHtml(widget.code, isDark: isDark);
    _controller!.loadHtmlString(html);
  }

  @override
  void didUpdateWidget(MermaidRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.code != oldWidget.code && _controller != null) {
      setState(() {
        _isLoading = true;
        _webViewFailed = false;
        _contentHeight = 300;
      });
      final isDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      final html = buildMermaidHtml(widget.code, isDark: isDark);
      _controller!.loadHtmlString(html);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final bgColor = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textColor =
        isDark ? const Color(0xFFF5F0EB) : const Color(0xFF2C2520);
    final secondaryColor =
        isDark ? const Color(0xFFA3988E) : const Color(0xFF6B5E54);

    // Decide which body to show.
    final bool showWebView = !_isWeb && !_webViewFailed && !_showSource;
    final bool showSourceView = _showSource || _isWeb || _webViewFailed;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with icon, label, and action buttons.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 18,
                  color: secondaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.mermaidDiagram,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                // View Source / View Diagram toggle (only when WebView is
                // available and has not failed).
                if (!_isWeb && !_webViewFailed)
                  _ToggleSourceButton(
                    showSource: _showSource,
                    onToggle: () {
                      setState(() => _showSource = !_showSource);
                    },
                  ),
                const SizedBox(width: 4),
                _CopyButton(code: widget.code),
              ],
            ),
          ),

          // Diagram body.
          if (showWebView)
            _buildWebViewBody(isDark)
          else if (showSourceView)
            _buildSourceBody(textColor),
        ],
      ),
    );
  }

  /// Builds the WebView body for rendering the mermaid diagram.
  Widget _buildWebViewBody(bool isDark) {
    return Stack(
      children: [
        AnimatedOpacity(
          opacity: _isLoading ? 0.0 : 1.0,
          duration: AppDurations.shortAnimation,
          child: SizedBox(
            height: _contentHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.radiusMedium),
              ),
              child: WebViewWidget(controller: _controller!),
            ),
          ),
        ),
        if (_isLoading)
          SizedBox(
            height: 200,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark
                      ? const Color(0xFFA3988E)
                      : const Color(0xFF6B5E54),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the source code fallback view.
  Widget _buildSourceBody(Color textColor) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          widget.code,
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'monospace',
            height: 1.5,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

/// Toggle button to switch between rendered diagram and source code view.
class _ToggleSourceButton extends StatelessWidget {
  final bool showSource;
  final VoidCallback onToggle;

  const _ToggleSourceButton({
    required this.showSource,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? const Color(0xFFA3988E) : const Color(0xFF6B5E54);

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Tooltip(
        message: l10n.viewSource,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showSource ? Icons.image_outlined : Icons.code,
                size: 16,
                color: secondaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                showSource ? l10n.viewDiagram : l10n.viewSource,
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon button that copies the mermaid code to the clipboard and shows
/// a brief confirmation via a [SnackBar].
class _CopyButton extends StatefulWidget {
  final String code;

  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryColor =
        isDark ? const Color(0xFFA3988E) : const Color(0xFF6B5E54);

    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: widget.code));
        setState(() => _copied = true);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.diagramCopied),
            duration: AppDurations.snackbarDuration,
          ),
        );
        // Reset the icon after a short delay.
        Future.delayed(AppDurations.snackbarDuration, () {
          if (mounted) setState(() => _copied = false);
        });
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Tooltip(
        message: l10n.copyDiagramSource,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(
            _copied ? Icons.check : Icons.copy,
            size: 16,
            color: _copied ? theme.colorScheme.primary : secondaryColor,
          ),
        ),
      ),
    );
  }
}
