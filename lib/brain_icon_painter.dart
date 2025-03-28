import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_drawing/path_drawing.dart';

// 修改后的 CustomPaint 使用示例
class BrainIconWithText extends StatelessWidget {
  final Color? color;

   const BrainIconWithText({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    // 获取当前文本样式
    final textStyle = DefaultTextStyle.of(context).style;
    // 获取字体大小
    final fontSize = textStyle.fontSize ?? 16.0; // 如果 fontSize 为 null，则使用默认值 16.0

    return Row(
      mainAxisSize: MainAxisSize.min, // 使 Row 尽可能小
      children: [
        CustomPaint(
          painter: BrainIconPainter(color: color ?? Colors.grey.shade700, fontSize: fontSize),
          size: Size(fontSize, fontSize), // 使用字体大小作为图标大小
        ),
        const SizedBox(width: 4),
        // 这里可以添加你的文本组件，文本的字体大小会自动与图标大小同步
        // Text("Brain", style: textStyle), // 示例：取消注释以查看效果
      ],
    );
  }
}

class BrainIconPainter extends CustomPainter {
  final Color color;
  final double fontSize; // 添加 fontSize 属性

  BrainIconPainter({required this.color, required this.fontSize}); // 更新构造函数

  @override
  void paint(Canvas canvas, Size size) {
    // 提取的 path data
    const String pathData1 =
        "M2.656 17.344c-1.016-1.015-1.15-2.75-.313-4.925.325-.825.73-1.617 1.205-2.365L3.582 10l-.033-.054c-.5-.799-.91-1.596-1.206-2.365-.836-2.175-.703-3.91.313-4.926.56-.56 1.364-.86 2.335-.86 1.425 0 3.168.636 4.957 1.756l.053.034.053-.034c1.79-1.12 3.532-1.757 4.957-1.757.972 0 1.776.3 2.335.86 1.014 1.015 1.148 2.752.312 4.926a13.892 13.892 0 0 1-1.206 2.365l-.034.054.034.053c.5.8.91 1.596 1.205 2.365.837 2.175.704 3.911-.311 4.926-.56.56-1.364.861-2.335.861-1.425 0-3.168-.637-4.957-1.757L10 16.415l-.053.033c-1.79 1.12-3.532 1.757-4.957 1.757-.972 0-1.776-.3-2.335-.86zm13.631-4.399c-.187-.488-.429-.988-.71-1.492l-.075-.132-.092.12a22.075 22.075 0 0 1-3.968 3.968l-.12.093.132.074c1.308.734 2.559 1.162 3.556 1.162.563 0 1.006-.138 1.298-.43.3-.3.436-.774.428-1.346-.008-.575-.159-1.264-.449-2.017zm-6.345 1.65l.058.042.058-.042a19.881 19.881 0 0 0 4.551-4.537l.043-.058-.043-.058a20.123 20.123 0 0 0-2.093-2.458 19.732 19.732 0 0 0-2.458-2.08L10 5.364l-.058.042A19.883 19.883 0 0 0 5.39 9.942L5.348 10l.042.059c.631.874 1.332 1.695 2.094 2.457a19.74 19.74 0 0 0 2.458 2.08zm6.366-10.902c-.293-.293-.736-.431-1.298-.431-.998 0-2.248.429-3.556 1.163l-.132.074.12.092a21.938 21.938 0 0 1 3.968 3.968l.092.12.074-.132c.282-.504.524-1.004.711-1.492.29-.753.442-1.442.45-2.017.007-.572-.129-1.045-.429-1.345zM3.712 7.055c.202.514.44 1.013.712 1.493l.074.13.092-.119a21.94 21.94 0 0 1 3.968-3.968l.12-.092-.132-.074C7.238 3.69 5.987 3.262 4.99 3.262c-.563 0-1.006.138-1.298.43-.3.301-.436.774-.428 1.346.007.575.159 1.264.448 2.017zm0 5.89c-.29.753-.44 1.442-.448 2.017-.008.572.127 1.045.428 1.345.293.293.736.431 1.298.431.997 0 2.247-.428 3.556-1.162l.131-.074-.12-.093a21.94 21.94 0 0 1-3.967-3.968l-.093-.12-.074.132a11.712 11.712 0 0 0-.71 1.492z";
    const String pathData2 =
        "M10.706 11.704A1.843 1.843 0 0 1 8.155 10a1.845 1.845 0 1 1 2.551 1.704z";

    // 创建 Path 对象
    Path path1 = Path()..addPath(parseSvgPathData(pathData1), Offset.zero);
    Path path2 = Path()..addPath(parseSvgPathData(pathData2), Offset.zero);

    // 创建 Paint 对象
    Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    //  使用传入的 fontSize 作为图标的大小
    double scaleX = fontSize / 20;
    double scaleY = fontSize / 20;
    double scale = scaleX < scaleY ? scaleX : scaleY;

    // 创建转换矩阵
    Matrix4 matrix = Matrix4.identity();
    matrix.scale(scale, scale, 1);
    matrix.translate(
        0, 0);  // 根据需要调整对齐方式

    // Apply the transformation to the paths
    Path scaledPath1 = path1.transform(matrix.storage);
    Path scaledPath2 = path2.transform(matrix.storage);

    // 绘制路径
    canvas.drawPath(scaledPath1, paint);
    canvas.drawPath(scaledPath2, paint);
  }

  @override
  bool shouldRepaint(covariant BrainIconPainter oldDelegate) {
    // 如果颜色或 fontSize 发生变化，则重绘
    return oldDelegate.color != color || oldDelegate.fontSize != fontSize;
  }
}