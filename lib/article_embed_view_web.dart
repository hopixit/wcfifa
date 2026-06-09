import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _nextArticleViewId = 0;

Widget buildArticleEmbedView({
  required BuildContext context,
  required String url,
  required String title,
}) {
  return _ArticleIframeView(url: url, title: title);
}

class _ArticleIframeView extends StatefulWidget {
  const _ArticleIframeView({required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<_ArticleIframeView> createState() => _ArticleIframeViewState();
}

class _ArticleIframeViewState extends State<_ArticleIframeView> {
  late final String _viewType = 'article-iframe-${_nextArticleViewId++}';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return web.HTMLIFrameElement()
        ..src = widget.url
        ..title = widget.title
        ..allow = 'fullscreen'
        ..referrerPolicy = 'origin-when-cross-origin'
        ..style.border = '0'
        ..style.display = 'block'
        ..style.height = '100%'
        ..style.width = '100%';
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
