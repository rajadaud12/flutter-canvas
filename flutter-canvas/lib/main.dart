import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state/canvas_controller.dart';
import 'renderer/canvas_renderer.dart';
import 'bridge/js_bridge.dart';
import 'models/widget_node.dart';

void main() {
  runApp(const FlutterCanvasApp());
}

class FlutterCanvasApp extends StatelessWidget {
  const FlutterCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
      home: const CanvasShell(),
    );
  }
}

class CanvasShell extends StatefulWidget {
  const CanvasShell({super.key});

  @override
  State<CanvasShell> createState() => _CanvasShellState();
}

class _CanvasShellState extends State<CanvasShell> {
  final CanvasController _controller = CanvasController();
  late final JsBridge _bridge;
  final FocusNode _focusNode = FocusNode();
  Map<String, dynamic>? _clipboard;

  @override
  void initState() {
    super.initState();
    _bridge = JsBridge();
    _bridge.onSchemaReceived = (flatSchema) {
      setState(() => _controller.loadSchema(flatSchema));
    };
    _bridge.onPagePropertiesReceived = (props) {
      setState(() => _controller.updatePageProperties(props));
    };
    _bridge.onSelectionReceived = (id) {
      setState(() => _controller.setActiveNode(id));
    };
    _bridge.onPropsUpdateReceived = (data) {
      final nodeId = data['id'] as String?;
      final props = data['properties'] as Map<String, dynamic>?;
      if (nodeId != null && props != null) {
        setState(() => _controller.updateNodeProperties(nodeId: nodeId, newProperties: props));
        _notifySchemaChanged();
      }
    };
    _bridge.onNodeUpdateReceived = (data) {
      final nodeId = data['id'] as String?;
      if (nodeId == null) return;
      setState(() {
        final width = data['width'];
        final height = data['height'];
        if (width != null) _controller.updateNodeField(nodeId: nodeId, field: 'width', value: (width as num).toDouble());
        if (height != null) _controller.updateNodeField(nodeId: nodeId, field: 'height', value: (height as num).toDouble());
      });
    };
    _bridge.onDropReceived = (data) {
      final type = data['type'] as String?;
      if (type == null) return;
      final content = data['content'] as String?;
      final props = (data['properties'] as Map<String, dynamic>?) ?? {};

      final newNode = WidgetNode(
        id: '$type-${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        width: _defaultW(type),
        height: _defaultH(type),
        content: content ?? _defaultContent(type),
        properties: Map.from(props.isNotEmpty ? props : _defaultProps(type)),
      );

      // If a container-type widget is selected, nest inside it
      final activeId = _controller.activeNodeId;
      if (activeId != null) {
        final activeNode = _controller.findNode(activeId);
        if (activeNode != null && _isContainerType(activeNode.type)) {
          setState(() => _controller.addNode(parentId: activeId, newNode: newNode));
          _notifySchemaChanged();
          return;
        }
      }
      setState(() => _controller.addRootNode(newNode));
      _notifySchemaChanged();
    };

    // Handle actions from React context menu
    _bridge.onActionReceived = (action, nodeId) {
      final targetId = nodeId ?? _controller.activeNodeId;
      if (targetId == null) return;
      setState(() {
        switch (action) {
          case 'delete':
            _controller.deleteNode(targetId);
            break;
          case 'duplicate':
            _controller.duplicateNode(targetId);
            break;
          case 'moveForward':
            _controller.moveNodeForward(targetId);
            break;
          case 'moveBackward':
            _controller.moveNodeBackward(targetId);
            break;
          case 'moveToFront':
            _controller.moveNodeToFront(targetId);
            break;
          case 'moveToBack':
            _controller.moveNodeToBack(targetId);
            break;
        }
      });
      _notifySchemaChanged();
      _notifySelectionChanged();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) => _bridge.sendReady());
    _controller.addListener(() { if (mounted) setState(() {}); });
  }

  void _notifySchemaChanged() => _bridge.sendSchemaChanged(_controller.getFlatSchema());
  void _notifySelectionChanged() => _bridge.sendSelectionChanged(_controller.activeNodeId);

  bool _isContainerType(String type) =>
      ['container', 'column', 'row', 'stack', 'list-view', 'grid-view'].contains(type);

  double _defaultW(String t) => ['navbar', 'appbar'].contains(t) ? 375 : (['text', 'icon'].contains(t) ? 150 : 330);
  double _defaultH(String t) {
    if (_isContainerType(t)) return 120;
    if (['navbar', 'appbar'].contains(t)) return 56;
    if (t == 'image') return 150;
    return 44;
  }

  String? _defaultContent(String t) {
    switch (t) {
      case 'text': return 'Hello World';
      case 'text-button': return 'Button';
      case 'checkbox': return 'Checkbox';
      case 'switch': return 'Switch';
      default: return null;
    }
  }

  Map<String, dynamic> _defaultProps(String t) {
    switch (t) {
      case 'text-button': return {'backgroundColor': '#4F46E5', 'color': '#ffffff', 'borderRadius': 8, 'fontSize': 14, 'paddingTop': 12, 'paddingBottom': 12, 'paddingLeft': 24, 'paddingRight': 24};
      case 'text-field': return {'backgroundColor': '#ffffff', 'borderRadius': 8, 'borderWidth': 1, 'borderColor': '#e5e7eb', 'padding': 12, 'placeholder': 'Enter text...'};
      case 'dropdown': return {'backgroundColor': '#ffffff', 'borderRadius': 8, 'borderWidth': 1, 'borderColor': '#e5e7eb', 'padding': 12, 'options': ['Option 1', 'Option 2']};
      default: return {};
    }
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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard events when the Flutter canvas has focus
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    final activeId = _controller.activeNodeId;

    // Delete / Backspace
    if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      if (activeId != null) {
        setState(() => _controller.deleteNode(activeId));
        _notifySchemaChanged();
        _notifySelectionChanged();
        return KeyEventResult.handled;
      }
    }

    // Ctrl+D → Duplicate
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyD) {
      if (activeId != null) {
        setState(() => _controller.duplicateNode(activeId));
        _notifySchemaChanged();
        _notifySelectionChanged();
        return KeyEventResult.handled;
      }
    }

    // Ctrl+C → Copy
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (activeId != null) {
        final idx = _controller.getFlatSchema().indexWhere((e) => e['id'] == activeId);
        if (idx != -1) {
          _clipboard = Map<String, dynamic>.from(_controller.getFlatSchema()[idx]);
        }
        return KeyEventResult.handled;
      }
    }

    // Ctrl+V → Paste
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      if (_clipboard != null) {
        final newId = '${_clipboard!['type']}-${DateTime.now().millisecondsSinceEpoch}';
        final copy = Map<String, dynamic>.from(_clipboard!);
        copy['id'] = newId;
        copy['parentId'] = null;
        final newNode = WidgetNode.fromJson(copy);
        setState(() => _controller.addRootNode(newNode));
        _notifySchemaChanged();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    WidgetNode? rootAppbar;
    WidgetNode? rootNavbar;
    final bodyRoots = <WidgetNode>[];

    for (final node in _controller.roots) {
      if (node.type == 'appbar' && node.parentId == null) rootAppbar = node;
      else if (node.type == 'navbar' && node.parentId == null) rootNavbar = node;
      else bodyRoots.add(node);
    }

    final renderer = CanvasRenderer(
      node: const WidgetNode(id: '_root', type: 'root'),
      controller: _controller,
      onSchemaChanged: () { _notifySchemaChanged(); _notifySelectionChanged(); },
    );

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Scaffold(
          backgroundColor: _controller.pageBackgroundColor,

          appBar: rootAppbar != null ? PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: _selectableWrapper(rootAppbar, renderer.buildWidget(context, rootAppbar)),
          ) : null,

          bottomNavigationBar: rootNavbar != null
              ? _selectableWrapper(rootNavbar, renderer.buildWidget(context, rootNavbar))
              : null,

          body: GestureDetector(
            onTap: () { _controller.setActiveNode(null); _notifySelectionChanged(); _focusNode.requestFocus(); },
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
              padding: _controller.pagePadding,
              child: bodyRoots.isEmpty
                  ? _emptyState()
                  : _buildBody(context, bodyRoots, renderer),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<WidgetNode> bodyRoots, CanvasRenderer renderer) {
    // Widget spacing from page properties
    final widgetGap = _controller.widgetGap;

    return ReorderableListView(
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        setState(() => _controller.reorderRootNodes(oldIndex, newIndex));
        _notifySchemaChanged();
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 8,
          shadowColor: Colors.blue.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(6),
          child: child,
        );
      },
      children: [
        for (int i = 0; i < bodyRoots.length; i++)
          Padding(
            key: ValueKey(bodyRoots[i].id),
            padding: EdgeInsets.only(bottom: widgetGap),
            child: ReorderableDelayedDragStartListener(
              index: i,
              child: _buildNodeWidget(
                context: context,
                node: bodyRoots[i],
                renderer: renderer,
              ),
            ),
          ),
      ],
    );
  }

  /// Build a single node widget — label only on selected, long-press to reorder
  Widget _buildNodeWidget({
    required BuildContext context,
    required WidgetNode node,
    required CanvasRenderer renderer,
  }) {
    final isSelected = _controller.activeNodeId == node.id;
    final isContainer = _isContainerType(node.type);
    final isInfWidth = node.properties['widthType'] == 'inf' || node.properties['isResponsive'] == true;

    // Build the actual widget
    Widget child;
    if (isContainer) {
      child = _buildContainerWidget(context, node, renderer);
    } else {
      child = renderer.buildWidget(context, node);
    }

    // Disable widget interactivity (buttons, inputs, etc.) — but NOT containers
    // so that children inside containers remain clickable for nested selection
    if (!isContainer) {
      child = IgnorePointer(child: child);
    }

    // Sizing
    if (isInfWidth) {
      child = SizedBox(width: double.infinity, height: isContainer ? null : node.height, child: child);
    } else if (!isContainer) {
      child = SizedBox(width: node.width, height: node.height, child: child);
    }

    // Alignment
    Alignment align = Alignment.centerLeft;
    switch (node.properties['alignment']?.toString()) {
      case 'center': align = Alignment.center; break;
      case 'right': align = Alignment.centerRight; break;
    }

    // Tap to select + right-click for context menu + visual border
    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _controller.setActiveNode(node.id);
        _notifySelectionChanged();
        _focusNode.requestFocus();
      },
      onSecondaryTapUp: (details) {
        _controller.setActiveNode(node.id);
        _notifySelectionChanged();
        _focusNode.requestFocus();
        // Send context menu request to React with position
        _bridge.sendContextMenu(node.id, details.globalPosition.dx, details.globalPosition.dy);
      },
      child: Container(
        decoration: BoxDecoration(
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : Border.all(color: Colors.transparent, width: 0),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            // Type label — ONLY when selected
            if (isSelected)
              Positioned(
                top: -14,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    node.type.replaceAll('-', ' ').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600, height: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Alignment wrapper
    if (!isInfWidth) {
      child = Align(alignment: align, child: child);
    }

    return child;
  }

  /// Build container with proper axis alignments and nested children
  Widget _buildContainerWidget(BuildContext context, WidgetNode node, CanvasRenderer renderer) {
    final props = node.properties;
    final isRow = node.type == 'row';
    final isInfWidth = props['widthType'] == 'inf' || props['isResponsive'] == true;

    final bgColor = props['backgroundColor'] != null ? _parseHexColor(props['backgroundColor'].toString()) : Colors.grey.withValues(alpha: 0.05);

    // Per-corner borderRadius support
    BorderRadius borderRad;
    final tl = (props['borderRadiusTL'] as num?)?.toDouble() ?? 0;
    final tr = (props['borderRadiusTR'] as num?)?.toDouble() ?? 0;
    final bl = (props['borderRadiusBL'] as num?)?.toDouble() ?? 0;
    final br = (props['borderRadiusBR'] as num?)?.toDouble() ?? 0;
    if (tl > 0 || tr > 0 || bl > 0 || br > 0) {
      borderRad = BorderRadius.only(
        topLeft: Radius.circular(tl),
        topRight: Radius.circular(tr),
        bottomLeft: Radius.circular(bl),
        bottomRight: Radius.circular(br),
      );
    } else {
      borderRad = BorderRadius.circular((props['borderRadius'] as num?)?.toDouble() ?? 0);
    }

    final borderWidth = (props['borderWidth'] as num?)?.toDouble() ?? 0;
    final borderColor = props['borderColor'] != null ? _parseHexColor(props['borderColor'].toString()) : Colors.grey;

    // Per-side padding support
    EdgeInsets pad;
    final pt = props['paddingTop'];
    final pr = props['paddingRight'];
    final pb = props['paddingBottom'];
    final pl = props['paddingLeft'];
    if (pt != null || pr != null || pb != null || pl != null) {
      pad = EdgeInsets.only(
        top: (pt as num?)?.toDouble() ?? 0,
        right: (pr as num?)?.toDouble() ?? 0,
        bottom: (pb as num?)?.toDouble() ?? 0,
        left: (pl as num?)?.toDouble() ?? 0,
      );
    } else {
      pad = EdgeInsets.all((props['padding'] as num?)?.toDouble() ?? 8);
    }

    // Shadow support
    final elevation = (props['elevation'] as num?)?.toDouble() ?? 0;
    final shadowBlur = (props['shadowBlur'] as num?)?.toDouble() ?? elevation;
    final shadowSpread = (props['shadowSpread'] as num?)?.toDouble() ?? 0;
    final shadowOffsetX = (props['shadowOffsetX'] as num?)?.toDouble() ?? 0;
    final shadowOffsetY = (props['shadowOffsetY'] as num?)?.toDouble() ?? (elevation > 0 ? 2 : 0);
    final shadowColor = props['shadowColor'] != null
        ? _parseHexColor(props['shadowColor'].toString())
        : Colors.black26;
    List<BoxShadow>? boxShadow;
    if (elevation > 0 || shadowBlur > 0 || shadowSpread > 0) {
      boxShadow = [BoxShadow(
        color: shadowColor,
        blurRadius: shadowBlur,
        spreadRadius: shadowSpread,
        offset: Offset(shadowOffsetX, shadowOffsetY),
      )];
    }

    // Clip behavior
    final clipContent = props['clipContent'] == true;

    // *** Axis alignments ***
    final mainAxisAlign = _mainAxis(props['mainAxisAlignment']?.toString());
    final crossAxisAlign = _crossAxis(props['crossAxisAlignment']?.toString());

    final containerDecoration = BoxDecoration(
      color: bgColor,
      borderRadius: borderRad,
      border: borderWidth > 0 ? Border.all(color: borderColor, width: borderWidth) : null,
      boxShadow: boxShadow,
    );

    List<Widget> childWidgets;
    if (node.children.isEmpty) {
      childWidgets = [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.withValues(alpha: 0.05),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_box_outlined, size: 14, color: Colors.grey[400]),
                const SizedBox(height: 4),
                Text(
                  'Select → drop to nest',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ];
    } else {
      childWidgets = node.children.map((child) {
        return _buildNodeWidget(context: context, node: child, renderer: renderer);
      }).toList();
    }

    double parseNum(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }
    final gapRaw = parseNum(props['gap']) > 0 ? parseNum(props['gap']) : parseNum(props['spacing']);
    final gap = gapRaw > 0 ? gapRaw : (isRow ? 12.0 : 8.0);

    List<Widget> withGap(List<Widget> list, bool horizontal) {
      if (gap <= 0 || list.length < 2) return list;
      final result = <Widget>[];
      for (int i = 0; i < list.length; i++) {
        result.add(list[i]);
        if (i < list.length - 1) {
          result.add(horizontal ? SizedBox(width: gap) : SizedBox(height: gap));
        }
      }
      return result;
    }

    Widget content;
    if (node.type == 'grid-view') {
      final crossAxisCount = (props['crossAxisCount'] as num?)?.toInt() ?? 2;
      final mainSpacing = (props['mainAxisSpacing'] as num?)?.toDouble() ?? 8;
      final crossSpacing = (props['crossAxisSpacing'] as num?)?.toDouble() ?? 8;
      final mainAxisExtent = parseNum(props['mainAxisExtent']) > 0 ? parseNum(props['mainAxisExtent']) : null;
      final aspectRatio = (props['childAspectRatio'] as num?)?.toDouble() ?? 1.0;
      final delegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount > 0 ? crossAxisCount : 2,
        mainAxisSpacing: mainSpacing,
        crossAxisSpacing: crossSpacing,
        mainAxisExtent: mainAxisExtent,
        childAspectRatio: mainAxisExtent == null && aspectRatio > 0 ? aspectRatio : 1.0,
      );
      content = GridView.custom(
        gridDelegate: delegate,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childrenDelegate: SliverChildListDelegate(childWidgets),
      );
    } else if (node.type == 'list-view') {
      content = ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: childWidgets,
      );
    } else if (node.type == 'stack') {
      content = Stack(
        clipBehavior: clipContent ? Clip.hardEdge : Clip.none,
        children: childWidgets,
      );
    } else if (isRow) {
      final rowChild = Row(
        mainAxisAlignment: mainAxisAlign,
        crossAxisAlignment: crossAxisAlign,
        mainAxisSize: MainAxisSize.min,
        children: withGap(childWidgets, true),
      );
      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: rowChild,
      );
    } else {
      final columnChild = Column(
        mainAxisAlignment: mainAxisAlign,
        crossAxisAlignment: crossAxisAlign,
        mainAxisSize: MainAxisSize.min,
        children: withGap(childWidgets, false),
      );
      content = SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: columnChild,
      );
    }

    // For Column/Row/Container, use loose minHeight so large gaps aren't clipped
    final isFlexLayout = isRow || node.type == 'column' || node.type == 'container';
    final minH = isFlexLayout ? 40.0 : node.height.clamp(40.0, 400.0);

    // Avoid clipping Column/Row with large gaps: use Clip.none unless clipContent is explicitly on
    final shouldClip = clipContent && !isFlexLayout;

    return Container(
      width: isInfWidth ? double.infinity : node.width,
      constraints: BoxConstraints(minHeight: minH),
      padding: pad,
      clipBehavior: shouldClip ? Clip.hardEdge : Clip.none,
      decoration: containerDecoration,
      child: content,
    );
  }

  Widget _selectableWrapper(WidgetNode node, Widget child) {
    final isSelected = _controller.activeNodeId == node.id;
    return GestureDetector(
      onTap: () { _controller.setActiveNode(node.id); _notifySelectionChanged(); },
      child: IgnorePointer(
        child: Container(
          decoration: isSelected ? BoxDecoration(border: Border.all(color: Colors.blue, width: 2)) : null,
          child: child,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.widgets_outlined, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('DRAG & DROP', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text('Drop widgets from the sidebar', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    try { return Color(int.parse(hex, radix: 16)); } catch (_) { return Colors.transparent; }
  }
}
