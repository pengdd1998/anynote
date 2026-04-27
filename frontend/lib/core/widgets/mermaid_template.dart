/// Generates HTML templates for rendering mermaid diagrams in a WebView.
///
/// The template loads mermaid.js from a CDN, initializes it with a theme
/// matching the app's brightness, and renders the provided diagram code.
/// If rendering fails, an error message is shown inside the WebView.
library;

/// Builds a complete HTML document that renders a mermaid diagram.
///
/// [code] is the raw mermaid diagram source code.
/// [isDark] controls the mermaid theme ('dark' vs 'default') and the
/// background/foreground colors.
String buildMermaidHtml(String code, {required bool isDark}) {
  // Escape the mermaid code for safe embedding inside a JS template literal.
  // We handle backticks and dollar signs which are special in template literals.
  final escapedCode = code
      .replaceAll('\\', '\\\\')
      .replaceAll('`', '\\`')
      .replaceAll('\$', '\\\$');

  final backgroundColor = isDark ? '#1A1614' : '#FFFFFF';
  final textColor = isDark ? '#F5F0EB' : '#2C2520';
  final errorColor = isDark ? '#FF6B6B' : '#D32F2F';
  final mermaidTheme = isDark ? 'dark' : 'default';

  return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      background-color: $backgroundColor;
      color: $textColor;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      overflow-x: auto;
      overflow-y: hidden;
      -webkit-overflow-scrolling: touch;
    }
    #container {
      display: flex;
      justify-content: center;
      align-items: flex-start;
      padding: 16px 8px;
      min-height: 100px;
    }
    #diagram-output {
      max-width: 100%;
      overflow: auto;
    }
    #diagram-output svg {
      max-width: 100%;
      height: auto;
    }
    #error-output {
      display: none;
      color: $errorColor;
      padding: 16px;
      font-size: 14px;
      line-height: 1.5;
      text-align: center;
    }
    #error-output pre {
      text-align: left;
      margin-top: 8px;
      padding: 8px;
      background: ${isDark ? '#2C2826' : '#F5F0EB'};
      border-radius: 6px;
      font-size: 12px;
      overflow-x: auto;
      white-space: pre-wrap;
      word-break: break-word;
    }
    #loading {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100px;
      color: ${isDark ? '#A3988E' : '#6B5E54'};
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div id="loading">Rendering diagram...</div>
  <div id="container">
    <div id="diagram-output"></div>
  </div>
  <div id="error-output"></div>

  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';

    const diagramCode = `$escapedCode`;

    mermaid.initialize({
      startOnLoad: false,
      theme: '$mermaidTheme',
      securityLevel: 'loose',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    });

    async function renderDiagram() {
      const loadingEl = document.getElementById('loading');
      const outputEl = document.getElementById('diagram-output');
      const errorEl = document.getElementById('error-output');

      try {
        const { svg } = await mermaid.render('mermaid-svg', diagramCode);
        outputEl.innerHTML = svg;
        loadingEl.style.display = 'none';

        // Notify Flutter that rendering is complete and send the content height.
        const height = Math.max(
          document.documentElement.scrollHeight,
          document.body.scrollHeight
        );
        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            type: 'renderComplete',
            height: height
          }));
        }
      } catch (err) {
        loadingEl.style.display = 'none';
        outputEl.parentElement.style.display = 'none';
        errorEl.style.display = 'block';
        errorEl.innerHTML = 'Failed to render diagram<pre>' + escapeHtml(err.message || String(err)) + '</pre>';

        if (window.FlutterChannel) {
          window.FlutterChannel.postMessage(JSON.stringify({
            type: 'renderError',
            error: err.message || String(err)
          }));
        }
      }
    }

    function escapeHtml(text) {
      const div = document.createElement('div');
      div.appendChild(document.createTextNode(text));
      return div.innerHTML;
    }

    renderDiagram();
  </script>
</body>
</html>''';
}
