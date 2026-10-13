import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A local receipt may be retired by reconciliation while its sheet stays open.
/// Fall back to its confirmed remote image, then the caller's unavailable state.
class TransactionReceiptImage extends StatelessWidget {
  const TransactionReceiptImage({
    super.key,
    this.localImagePath,
    this.imageUrl,
    this.width,
    this.height,
    required this.fit,
    required this.placeholder,
    required this.unavailable,
  });

  final String? localImagePath;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder placeholder;
  final WidgetBuilder unavailable;

  Widget _remoteOrUnavailable(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return unavailable(context);
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, _) => placeholder(context),
      errorWidget: (context, _, __) => unavailable(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = localImagePath;
    if (path == null || path.isEmpty) return _remoteOrUnavailable(context);
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, _, __) => _remoteOrUnavailable(context),
    );
  }
}
