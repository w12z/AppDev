import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Native PDF viewer body using pdfx PdfViewPinch.
/// Self-contained with page controls and zoom.
class PdfViewerBody extends StatefulWidget {
  final String? filePath;
  final Uint8List? bytes;
  final String fileName;

  const PdfViewerBody({
    super.key,
    this.filePath,
    this.bytes,
    required this.fileName,
  });

  @override
  State<PdfViewerBody> createState() => _PdfViewerBodyState();
}

class _PdfViewerBodyState extends State<PdfViewerBody> {
  PdfControllerPinch? _controller;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initController() {
    if (widget.filePath == null) {
      setState(() { _loading = false; _error = '没有文件路径'; });
      return;
    }
    final file = File(widget.filePath!);
    if (!file.existsSync()) {
      setState(() { _loading = false; _error = '文件不存在: ${widget.filePath}'; });
      return;
    }
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath!),
    );
  }

  void goToPreviousPage() {
    _controller?.previousPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void goToNextPage() {
    _controller?.nextPage(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void setZoom(double level) {
    if (_controller == null) return;
    final current = _controller!.value;
    final tx = current.getTranslation().x;
    final ty = current.getTranslation().y;
    final newMatrix = Matrix4.diagonal3Values(level, level, 1)
      ..setTranslationRaw(tx, ty, 0);
    _controller!.value = newMatrix;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
        actions: _totalPages > 0
            ? [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '上一页',
                  onPressed: _totalPages > 1 ? goToPreviousPage : null,
                ),
                SizedBox(
                  width: 72,
                  child: Center(
                    child: Text('$_currentPage / $_totalPages',
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '下一页',
                  onPressed: _totalPages > 1 ? goToNextPage : null,
                ),
                const VerticalDivider(),
                PopupMenuButton<double>(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: '缩放',
                  onSelected: setZoom,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 1.0, child: Text('100%')),
                    PopupMenuItem(value: 1.5, child: Text('150%')),
                    PopupMenuItem(value: 2.0, child: Text('200%')),
                    PopupMenuItem(value: 3.0, child: Text('300%')),
                  ],
                ),
              ]
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _initController();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        PdfViewPinch(
          controller: _controller!,
          padding: 0,
          onPageChanged: (page) {
            setState(() => _currentPage = page);
          },
          onDocumentLoaded: (doc) {
            setState(() {
              _totalPages = doc.pagesCount;
              _loading = false;
            });
          },
          onDocumentError: (error) {
            setState(() => _error = '加载页面出错: $error');
          },
        ),
        if (_totalPages > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
