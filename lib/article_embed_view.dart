import 'package:flutter/material.dart';

import 'article_embed_view_stub.dart'
    if (dart.library.html) 'article_embed_view_web.dart';

class ArticleEmbedView extends StatelessWidget {
  const ArticleEmbedView({required this.url, required this.title, super.key});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return buildArticleEmbedView(context: context, url: url, title: title);
  }
}
