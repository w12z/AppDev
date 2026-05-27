import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Web-specific PDF viewer body using an iframe with Blob URL.
/// Uses Chrome's built-in PDF viewer — more reliable than pdf.js.
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
  String? _viewType;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.bytes == null) {
      _error = '没有 PDF 数据';
      return;
    }
    _viewType = 'pdf-iframe-${identityHashCode(this)}';
    final blob = html.Blob([widget.bytes!], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.grey)),
            )
          : _viewType != null
              ? HtmlElementView(viewType: _viewType!)
              : const Center(child: CircularProgressIndicator()),
    );
  }
}
