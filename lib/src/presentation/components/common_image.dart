import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/theme.dart';

class CommonImage extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double radius;

  const CommonImage({
    super.key,
    required this.imageUrl,
    this.width = double.infinity,
    this.height = 50,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.r),
      child: CachedNetworkImage(
        imageUrl: '$imageUrl',
        width: width.r,
        height: height.r,
        fit: BoxFit.cover,
        progressIndicatorBuilder: (context, url, progress) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              color: AppStyle.mainBack,
            ),
          );
        },
        errorWidget: (context, url, error) {
          return Container(
            height: height.r,
            width: width.r,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius.r),
              border: Border.all(color: AppStyle.border),
              color: AppStyle.mainBack,
            ),
            alignment: Alignment.center,
            child: Icon(
              FlutterRemix.image_line,
              color: AppStyle.black.withOpacity(0.5),
              size: 20.r,
            ),
          );
        },
      ),
    );
  }
}
