import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../constants/changelog.dart';
import '../main.dart';

class ChangelogDialog extends StatelessWidget {
  const ChangelogDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Dialog(
      backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Changelog',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Divider(color: themeProvider.isDarkMode ? Colors.white24 : Colors.black12),
            Flexible(
              child: Markdown(
                data: changelogContent,
                styleSheet: MarkdownStyleSheet(
                  h1: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  h2: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  h3: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                  ),
                  p: TextStyle(
                    fontSize: 14,
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                    height: 1.5,
                  ),
                  listBullet: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  strong: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  code: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.blue[200] : Colors.blue[700],
                    backgroundColor: themeProvider.isDarkMode ? Colors.black26 : Colors.blue[50],
                    fontSize: 14,
                  ),
                  blockquote: TextStyle(
                    color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  em: const TextStyle(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                selectable: true,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}