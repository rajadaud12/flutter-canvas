import 'package:flutter/material.dart';
import '../models/widget_node.dart';
import '../state/canvas_controller.dart';

/// Recursively renders WidgetNode tree into real Flutter widgets.
/// Each widget is wrapped with selection handling and drop zone mechanics.
class CanvasRenderer extends StatelessWidget {
  final WidgetNode node;
  final CanvasController controller;
  final VoidCallback? onSchemaChanged;

  const CanvasRenderer({
    super.key,
    required this.node,
    required this.controller,
    this.onSchemaChanged,
  });

  Color _parseColor(String? hex, [Color fallback = Colors.transparent]) {
    if (hex == null || hex.isEmpty) return fallback;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try {
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  double _d(dynamic val, [double fallback = 0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return fallback;
  }

  String _s(dynamic val, [String fallback = '']) {
    if (val == null) return fallback;
    return val.toString();
  }

  BorderRadius _getBorderRadius(Map<String, dynamic> props) {
    final tl = _d(props['borderRadiusTL']);
    final tr = _d(props['borderRadiusTR']);
    final bl = _d(props['borderRadiusBL']);
    final br = _d(props['borderRadiusBR']);
    if (tl > 0 || tr > 0 || bl > 0 || br > 0) {
      return BorderRadius.only(
        topLeft: Radius.circular(tl),
        topRight: Radius.circular(tr),
        bottomLeft: Radius.circular(bl),
        bottomRight: Radius.circular(br),
      );
    }
    return BorderRadius.circular(_d(props['borderRadius']));
  }

  EdgeInsets _getPadding(Map<String, dynamic> props) {
    final pt = props['paddingTop'];
    final pr = props['paddingRight'];
    final pb = props['paddingBottom'];
    final pl = props['paddingLeft'];
    if (pt != null || pr != null || pb != null || pl != null) {
      return EdgeInsets.only(
        top: _d(pt),
        right: _d(pr),
        bottom: _d(pb),
        left: _d(pl),
      );
    }
    return EdgeInsets.all(_d(props['padding']));
  }

  MainAxisAlignment _mainAxis(String? val) {
    switch (val) {
      case 'center': return MainAxisAlignment.center;
      case 'end': return MainAxisAlignment.end;
      case 'space-between': return MainAxisAlignment.spaceBetween;
      case 'space-around': return MainAxisAlignment.spaceAround;
      case 'space-evenly': return MainAxisAlignment.spaceEvenly;
      default: return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _crossAxis(String? val) {
    switch (val) {
      case 'center': return CrossAxisAlignment.center;
      case 'end': return CrossAxisAlignment.end;
      case 'stretch': return CrossAxisAlignment.stretch;
      default: return CrossAxisAlignment.start;
    }
  }

  TextAlign _textAlign(String? val) {
    switch (val) {
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      default: return TextAlign.left;
    }
  }

  FontWeight _fontWeight(String? val) {
    switch (val) {
      case 'bold': return FontWeight.bold;
      case 'normal': return FontWeight.normal;
      case '100': return FontWeight.w100;
      case '200': return FontWeight.w200;
      case '300': return FontWeight.w300;
      case '400': return FontWeight.w400;
      case '500': return FontWeight.w500;
      case '600': return FontWeight.w600;
      case '700': return FontWeight.w700;
      case '800': return FontWeight.w800;
      case '900': return FontWeight.w900;
      default: 
        if (val == 'semibold' || val == 'SemiBold') return FontWeight.w600;
        if (val == 'medium' || val == 'Medium') return FontWeight.w500;
        if (val == 'light' || val == 'Light') return FontWeight.w300;
        return FontWeight.normal;
    }
  }

  EdgeInsets _getMargin(Map<String, dynamic> props) {
    final pt = props['marginTop'];
    final pr = props['marginRight'];
    final pb = props['marginBottom'];
    final pl = props['marginLeft'];
    if (pt != null || pr != null || pb != null || pl != null) {
      return EdgeInsets.only(
        top: _d(pt),
        right: _d(pr),
        bottom: _d(pb),
        left: _d(pl),
      );
    }
    if (props.containsKey('margin')) {
      return EdgeInsets.all(_d(props['margin']));
    }
    return EdgeInsets.zero;
  }


  /// Build the inner widget for a given node type
  Widget buildWidget(BuildContext context, WidgetNode node) {
    final props = node.properties;

    Widget innerWidget;

    switch (node.type) {
      case 'text': {
        final textWidget = Text(
          node.content ?? 'Text',
          textAlign: _textAlign(_s(props['textAlign'], 'left')),
          style: TextStyle(
            fontSize: _d(props['fontSize'], 14),
            fontWeight: _fontWeight(_s(props['fontWeight'])),
            fontFamily: props['fontFamily'] as String?,
            letterSpacing: _d(props['letterSpacing']),
            wordSpacing: _d(props['wordSpacing']),
            height: props['textHeightBehavior'] == true ? 1.0 : null,
            color: _parseColor(_s(props['color']), Colors.black),
          ),
        );
        final hasPadding = props['padding'] != null ||
            props['paddingTop'] != null || props['paddingBottom'] != null ||
            props['paddingLeft'] != null || props['paddingRight'] != null;
        innerWidget = Container(
          margin: _getMargin(props),
          child: hasPadding
              ? Padding(padding: _getPadding(props), child: textWidget)
              : textWidget,
        );
        break;
      }

      case 'text-button':
        final hasBg = props['backgroundColor'] != null && _s(props['backgroundColor']).trim().isNotEmpty;
        if (hasBg) {
          innerWidget = Container(
            margin: _getMargin(props),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _parseColor(_s(props['backgroundColor'])),
                foregroundColor: _parseColor(_s(props['color']), Colors.white),
                elevation: _d(props['elevation']),
                shape: RoundedRectangleBorder(
                  borderRadius: _getBorderRadius(props),
                  side: _d(props['borderWidth']) > 0
                      ? BorderSide(
                          color: _parseColor(_s(props['borderColor'])),
                          width: _d(props['borderWidth']),
                        )
                      : BorderSide.none,
                ),
                padding: _getPadding(props),
              ),
              child: Text(
                node.content ?? 'Button',
                textAlign: _textAlign(_s(props['textAlign'])),
                style: TextStyle(
                  fontSize: _d(props['fontSize'], 14),
                  fontWeight: _fontWeight(_s(props['fontWeight'])),
                  fontFamily: props['fontFamily'] as String?,
                ),
              ),
            )
          );
        } else {
          // Link-style: no background — use TextButton so link text doesn't get purple box
          innerWidget = Container(
            margin: _getMargin(props),
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: _parseColor(_s(props['color']), const Color(0xFF2563EB)),
                padding: _getPadding(props),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                node.content ?? 'Button',
                textAlign: _textAlign(_s(props['textAlign'])),
                style: TextStyle(
                  fontSize: _d(props['fontSize'], 14),
                  fontWeight: _fontWeight(_s(props['fontWeight'])),
                  fontFamily: props['fontFamily'] as String?,
                ),
              ),
            )
          );
        }
        break;

      case 'text-field':
        innerWidget = Container(
          margin: _getMargin(props),
          child: TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: _parseColor(_s(props['backgroundColor']), Colors.white),
              hintText: _s(props['placeholder'], 'Input'),
              contentPadding: _getPadding(props),
              border: OutlineInputBorder(
                borderRadius: _getBorderRadius(props),
                borderSide: BorderSide(
                  color: _parseColor(_s(props['borderColor']), const Color(0xFFCCCCCC)),
                  width: _d(props['borderWidth'], 1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: _getBorderRadius(props),
                borderSide: BorderSide(
                  color: _parseColor(_s(props['borderColor']), const Color(0xFFCCCCCC)),
                  width: _d(props['borderWidth'], 1),
                ),
              ),
            ),
            style: TextStyle(
              fontSize: _d(props['fontSize'], 14),
              color: _parseColor(_s(props['color']), Colors.black),
              fontFamily: props['fontFamily'] as String?,
              fontWeight: _fontWeight(_s(props['fontWeight'])),
            ),
            textAlign: _textAlign(_s(props['textAlign'])),
          )
        );
        break;

      case 'dropdown':
        innerWidget = Container(
          padding: EdgeInsets.symmetric(horizontal: _d(props['padding'], 12)),
          decoration: BoxDecoration(
            color: _parseColor(_s(props['backgroundColor']), Colors.white),
            borderRadius: _getBorderRadius(props),
            border: Border.all(
              color: _parseColor(_s(props['borderColor']), const Color(0xFFCCCCCC)),
              width: _d(props['borderWidth'], 1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select Option'),
              items: ((props['options'] as List<dynamic>?) ?? ['Option 1', 'Option 2'])
                  .map((o) => DropdownMenuItem(value: o.toString(), child: Text(o.toString())))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        );
        break;

      case 'checkbox':
        innerWidget = Container(
          margin: _getMargin(props),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: props['isChecked'] == true,
                activeColor: _parseColor(_s(props['color']), const Color(0xFF2196F3)),
                onChanged: (_) {},
              ),
              Flexible(
                child: Text(
                  node.content ?? 'Checkbox',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _d(props['fontSize'], 14),
                    fontWeight: _fontWeight(_s(props['fontWeight'])),
                    fontFamily: props['fontFamily'] as String?,
                    color: _parseColor(_s(props['color']), Colors.black),
                  ),
                ),
              ),
            ],
          )
        );
        break;

      case 'switch':
        innerWidget = Container(
          margin: _getMargin(props),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: props['isChecked'] == true,
                activeColor: _parseColor(_s(props['color']), const Color(0xFF2196F3)),
                onChanged: (_) {},
              ),
              Flexible(
                child: Text(
                  node.content ?? 'Switch',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _d(props['fontSize'], 14),
                    fontWeight: _fontWeight(_s(props['fontWeight'])),
                    fontFamily: props['fontFamily'] as String?,
                    color: _parseColor(_s(props['color']), Colors.black),
                  ),
                ),
              ),
            ],
          )
        );
        break;

      case 'icon':
        innerWidget = Icon(
          _getIconData(_s(props['iconName'], 'star')),
          size: _d(props['iconSize'], 24),
          color: _parseColor(_s(props['color']), Colors.black),
        );
        break;

      case 'image':
        innerWidget = Container(
          margin: _getMargin(props),
          child: ClipRRect(
            borderRadius: _getBorderRadius(props),
            child: Image.network(
              node.content ?? 'https://via.placeholder.com/150',
              fit: _getBoxFit(_s(props['imageFit'], 'cover')),
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image, size: 40, color: Colors.grey),
              ),
            ),
          )
        );
        break;

      case 'slider':
        innerWidget = Slider(
          value: 0.5,
          activeColor: _parseColor(_s(props['color']), const Color(0xFF2196F3)),
          onChanged: (_) {},
        );
        break;

      case 'container':
        final elevation = _d(props['elevation']);
        final shadowBlurVal = _d(props['shadowBlur'], elevation);
        final shadowSpreadVal = _d(props['shadowSpread']);
        final shadowOX = _d(props['shadowOffsetX']);
        final shadowOY = _d(props['shadowOffsetY'], elevation > 0 ? 2 : 0);
        final shadowCol = _parseColor(_s(props['shadowColor']), Colors.black26);
        List<BoxShadow>? shadow;
        if (elevation > 0 || shadowBlurVal > 0 || shadowSpreadVal > 0) {
          shadow = [BoxShadow(
            color: shadowCol,
            blurRadius: shadowBlurVal,
            spreadRadius: shadowSpreadVal,
            offset: Offset(shadowOX, shadowOY),
          )];
        }
        innerWidget = Container(
          margin: _getMargin(props),
          padding: _getPadding(props),
          clipBehavior: props['clipContent'] == true ? Clip.hardEdge : Clip.none,
          decoration: BoxDecoration(
            color: props['backgroundColor'] != null
                ? _parseColor(_s(props['backgroundColor']))
                : null,
            borderRadius: _getBorderRadius(props),
            border: _d(props['borderWidth']) > 0
                ? Border.all(
                    color: _parseColor(_s(props['borderColor']), const Color(0xFFCCCCCC)),
                    width: _d(props['borderWidth'], 1),
                  )
                : null,
            boxShadow: shadow,
          ),
          child: Column(
            crossAxisAlignment: _crossAxis(_s(props['crossAxisAlignment'])),
            mainAxisAlignment: _mainAxis(_s(props['mainAxisAlignment'])),
            children: _buildChildren(context, node),
          ),
        );
        break;

      case 'row':
        innerWidget = Container(
          margin: _getMargin(props),
          padding: _getPadding(props),
          clipBehavior: props['clipContent'] == true ? Clip.hardEdge : Clip.none,
          decoration: BoxDecoration(
            color: props['backgroundColor'] != null
                ? _parseColor(_s(props['backgroundColor']))
                : null,
            borderRadius: _getBorderRadius(props),
            border: _d(props['borderWidth']) > 0
                ? Border.all(
                    color: _parseColor(_s(props['borderColor']), const Color(0xFFCCCCCC)),
                    width: _d(props['borderWidth'], 1),
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: _mainAxis(_s(props['mainAxisAlignment'])),
            crossAxisAlignment: _crossAxis(_s(props['crossAxisAlignment'])),
            children: _buildChildren(context, node),
          ),
        );
        break;

      case 'column':
        innerWidget = Container(
          margin: _getMargin(props),
          padding: _getPadding(props),
          clipBehavior: props['clipContent'] == true ? Clip.hardEdge : Clip.none,
          decoration: BoxDecoration(
            color: props['backgroundColor'] != null
                ? _parseColor(_s(props['backgroundColor']))
                : null,
            borderRadius: _getBorderRadius(props),
            border: _d(props['borderWidth']) > 0
                ? Border.all(
                    color: _parseColor(_s(props['borderColor']), const Color(0xFFCCCCCC)),
                    width: _d(props['borderWidth'], 1),
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: _mainAxis(_s(props['mainAxisAlignment'])),
            crossAxisAlignment: _crossAxis(_s(props['crossAxisAlignment'])),
            children: _buildChildren(context, node),
          ),
        );
        break;

      case 'stack':
        innerWidget = Container(
          padding: _getPadding(props),
          clipBehavior: props['clipContent'] == true ? Clip.hardEdge : Clip.none,
          decoration: BoxDecoration(
            color: props['backgroundColor'] != null
                ? _parseColor(_s(props['backgroundColor']))
                : null,
            borderRadius: _getBorderRadius(props),
          ),
          child: Stack(
            children: _buildChildren(context, node),
          ),
        );
        break;

      case 'list-view':
        innerWidget = Container(
          padding: _getPadding(props),
          clipBehavior: props['clipContent'] == true ? Clip.hardEdge : Clip.none,
          decoration: BoxDecoration(
            color: props['backgroundColor'] != null
                ? _parseColor(_s(props['backgroundColor']))
                : null,
          ),
          child: ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _buildChildren(context, node),
          ),
        );
        break;

      case 'grid-view':
        final crossAxisCount = _d(props['crossAxisCount'], 2).toInt();
        final mainSpacing = _d(props['mainAxisSpacing'], 8);
        final crossSpacing = _d(props['crossAxisSpacing'], 8);
        final aspectRatio = _d(props['childAspectRatio'], 1.0);

        innerWidget = Container(
          padding: _getPadding(props),
          clipBehavior: props['clipContent'] == true ? Clip.hardEdge : Clip.none,
          decoration: BoxDecoration(
            color: props['backgroundColor'] != null
                ? _parseColor(_s(props['backgroundColor']))
                : null,
            borderRadius: _getBorderRadius(props),
            border: _d(props['borderWidth']) > 0
                ? Border.all(
                    color: _parseColor(_s(props['borderColor']), const Color(0xFFCCCCCC)),
                    width: _d(props['borderWidth'], 1),
                  )
                : null,
          ),
          child: GridView.count(
            crossAxisCount: crossAxisCount > 0 ? crossAxisCount : 2,
            mainAxisSpacing: mainSpacing,
            crossAxisSpacing: crossSpacing,
            childAspectRatio: aspectRatio > 0 ? aspectRatio : 1.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: _buildChildren(context, node),
          ),
        );
        break;

      case 'appbar':
        innerWidget = AppBar(
          backgroundColor: _parseColor(_s(props['backgroundColor']), Colors.white),
          elevation: _d(props['elevation']),
          title: Text(
            node.content ?? 'App Title',
            style: TextStyle(
              fontSize: _d(props['fontSize'], 18),
              fontWeight: _fontWeight(_s(props['fontWeight'], '600')),
              color: _parseColor(_s(props['color']), Colors.black),
              fontFamily: props['fontFamily'] as String?,
            ),
          ),
          centerTitle: _s(props['textAlign']) == 'center',
        );
        break;

      case 'navbar':
        final navItems = (props['navItems'] as List<dynamic>?) ??
            [{'icon': 'home', 'label': 'Home'}, {'icon': 'settings', 'label': 'Settings'}];
        innerWidget = BottomNavigationBar(
          backgroundColor: _parseColor(_s(props['backgroundColor']), Colors.white),
          selectedItemColor: props['color'] != null
              ? _parseColor(_s(props['color']))
              : Colors.grey,
          unselectedItemColor: props['color'] != null
              ? _parseColor(_s(props['color']))
              : Colors.grey,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          iconSize: 20,
          elevation: _d(props['elevation']),
          type: BottomNavigationBarType.fixed,
          items: navItems.map<BottomNavigationBarItem>((item) {
            final map = item as Map<String, dynamic>;
            return BottomNavigationBarItem(
              icon: Icon(_getIconData(map['icon']?.toString() ?? 'star')),
              label: map['label']?.toString() ?? '',
            );
          }).toList(),
          onTap: (_) {},
        );
        break;

      default:
        innerWidget = const SizedBox();
    }

    if (props['isExpanded'] == true && node.parentId != null) {
        if (props['flex'] != null) {
            return Expanded(flex: _d(props['flex']).toInt(), child: innerWidget);
        }
        return Expanded(child: innerWidget);
    }
    return innerWidget;
  }

  /// Build children widgets recursively
  List<Widget> _buildChildren(BuildContext context, WidgetNode parentNode) {
    if (parentNode.children.isEmpty) {
      return [
        // Empty drop zone placeholder
        DragTarget<DragPayload>(
          onAcceptWithDetails: (details) => _handleDrop(parentNode.id, details.data),
          builder: (context, candidateData, rejectedData) {
            return Container(
              width: double.infinity,
              height: 30,
              decoration: BoxDecoration(
                border: Border.all(
                  color: candidateData.isNotEmpty ? Colors.blue : Colors.grey.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(4),
                color: candidateData.isNotEmpty ? Colors.blue.withValues(alpha: 0.1) : null,
              ),
              child: Center(
                child: Text(
                  candidateData.isNotEmpty ? 'Drop here' : 'Drop widgets',
                  style: TextStyle(
                    fontSize: 10,
                    color: candidateData.isNotEmpty ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            );
          },
        ),
      ];
    }

    return parentNode.children.map((child) {
      return CanvasRenderer(
        key: ValueKey(child.id),
        node: child,
        controller: controller,
        onSchemaChanged: onSchemaChanged,
      );
    }).toList();
  }

  void _handleDrop(String parentId, DragPayload payload) {
    final newNode = WidgetNode(
      id: '${payload.type}-${DateTime.now().millisecondsSinceEpoch}',
      type: payload.type,
      parentId: parentId,
      content: payload.content,
      properties: Map.from(payload.properties),
      width: _getDefaultWidth(payload.type),
      height: _getDefaultHeight(payload.type),
    );
    controller.addNode(parentId: parentId, newNode: newNode);
    onSchemaChanged?.call();
  }

  double _getDefaultWidth(String type) {
    if (['text-button', 'text-field', 'dropdown', 'row', 'column', 'list-view', 'grid-view'].contains(type)) return 330;
    if (['checkbox', 'switch', 'slider'].contains(type)) return 200;
    if (['container', 'stack'].contains(type)) return 150;
    if (['navbar', 'appbar'].contains(type)) return 375;
    return 150;
  }

  double _getDefaultHeight(String type) {
    if (['row', 'column', 'list-view', 'grid-view', 'container', 'stack'].contains(type)) return 150;
    if (['navbar', 'appbar'].contains(type)) return 60;
    return 50;
  }

  BoxFit _getBoxFit(String val) {
    switch (val) {
      case 'contain': return BoxFit.contain;
      case 'fill': return BoxFit.fill;
      case 'none': return BoxFit.none;
      default: return BoxFit.cover;
    }
  }

  IconData _getIconData(String name) {
    const iconMap = {
      'home': Icons.home,
      'settings': Icons.settings,
      'person': Icons.person,
      'search': Icons.search,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'shopping_cart': Icons.shopping_cart,
      'mail': Icons.mail,
      'phone': Icons.phone,
      'camera': Icons.camera,
      'add': Icons.add,
      'edit': Icons.edit,
      'delete': Icons.delete,
      'close': Icons.close,
      'check': Icons.check,
      'arrow_back': Icons.arrow_back,
      'arrow_forward': Icons.arrow_forward,
      'menu': Icons.menu,
      'more_vert': Icons.more_vert,
      'notifications': Icons.notifications,
      'info': Icons.info,
      'warning': Icons.warning,
      'error': Icons.error,
      'visibility': Icons.visibility,
      'lock': Icons.lock,
      'bookmark': Icons.bookmark,
      'share': Icons.share,
      'download': Icons.download,
      'upload': Icons.upload,
      'refresh': Icons.refresh,
      'location_on': Icons.location_on,
      'calendar_today': Icons.calendar_today,
      'access_time': Icons.access_time,
    };
    return iconMap[name] ?? Icons.star;
  }

  /// The build method is intentionally minimal — main.dart handles layout.
  /// This widget is only instantiated to access buildWidget() as a factory.
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

