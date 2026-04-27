/// Converts a file path to a human-readable title by extracting the filename
/// and removing the extension.
String filenameToTitle(String filePath) {
  final name = filePath.split('/').last;
  final dotIndex = name.lastIndexOf('.');
  return dotIndex > 0 ? name.substring(0, dotIndex) : name;
}
