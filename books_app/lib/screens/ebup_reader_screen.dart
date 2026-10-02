import 'package:flutter/material.dart';
import 'package:vocsy_epub_viewer/epub_viewer.dart';

class EpubReaderScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const EpubReaderScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  bool _opening = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openEpub();
    });
  }

  Future<void> _openEpub() async {
    try {
      if (!mounted) return;

      setState(() {
        _opening = true;
        _error = null;
      });

      VocsyEpub.open(
        widget.filePath,
      );

      if (!mounted) return;

      setState(() {
        _opening = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _opening = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: _buildError(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Vocsy opens its own EPUB viewer.
          const SizedBox.expand(),

          if (_opening) _buildLoading(),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 72,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Opening ${widget.title}…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to open EPUB',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openEpub,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
