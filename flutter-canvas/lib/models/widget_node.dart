/// AST Data Model — maps 1-to-1 with the React CanvasElement schema.
class WidgetNode {
  final String id;
  final String type; // 'text', 'text-button', 'container', 'row', 'column', etc.
  final String? parentId;
  final int order;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? content;
  final Map<String, dynamic> properties;
  final List<WidgetNode> children;

  const WidgetNode({
    required this.id,
    required this.type,
    this.parentId,
    this.order = 0,
    this.x = 0,
    this.y = 0,
    this.width = 150,
    this.height = 50,
    this.content,
    this.properties = const {},
    this.children = const [],
  });

  WidgetNode copyWith({
    String? id,
    String? type,
    String? parentId,
    int? order,
    double? x,
    double? y,
    double? width,
    double? height,
    String? content,
    Map<String, dynamic>? properties,
    List<WidgetNode>? children,
  }) {
    return WidgetNode(
      id: id ?? this.id,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      order: order ?? this.order,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      content: content ?? this.content,
      properties: properties ?? this.properties,
      children: children ?? this.children,
    );
  }

  /// Parse from React CanvasElement JSON (flat list → tree)
  factory WidgetNode.fromJson(Map<String, dynamic> json) {
    return WidgetNode(
      id: json['id'] as String,
      type: json['type'] as String,
      parentId: json['parentId'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 150,
      height: (json['height'] as num?)?.toDouble() ?? 50,
      content: json['content'] as String?,
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      children: const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'parentId': parentId,
      'order': order,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'content': content,
      'properties': properties,
    };
  }
}

/// Drag payload for widgets being dropped onto the canvas
class DragPayload {
  final String type;
  final String? content;
  final Map<String, dynamic> properties;

  const DragPayload({
    required this.type,
    this.content,
    this.properties = const {},
  });
}

/// Convert flat CanvasElement[] list from React to a tree of WidgetNodes
List<WidgetNode> buildTree(List<Map<String, dynamic>> flatList) {
  final nodes = <String, WidgetNode>{};
  final childrenMap = <String, List<WidgetNode>>{};

  // First pass: create all nodes
  for (final json in flatList) {
    final node = WidgetNode.fromJson(json);
    nodes[node.id] = node;
  }

  // Second pass: group children by parentId
  for (final node in nodes.values) {
    if (node.parentId != null) {
      childrenMap.putIfAbsent(node.parentId!, () => []);
      childrenMap[node.parentId!]!.add(node);
    }
  }

  // Sort children by order
  for (final key in childrenMap.keys) {
    childrenMap[key]!.sort((a, b) => a.order.compareTo(b.order));
  }

  // Third pass: attach children recursively
  WidgetNode attachChildren(WidgetNode node) {
    final kids = childrenMap[node.id] ?? [];
    return node.copyWith(
      children: kids.map(attachChildren).toList(),
    );
  }

  // Return root nodes (no parentId) with children attached
  return nodes.values
      .where((n) => n.parentId == null)
      .map(attachChildren)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
}

/// Flatten a tree back to a flat list (for sending back to React)
List<Map<String, dynamic>> flattenTree(List<WidgetNode> roots) {
  final result = <Map<String, dynamic>>[];
  
  void flatten(WidgetNode node) {
    result.add(node.toJson());
    for (final child in node.children) {
      flatten(child);
    }
  }
  
  for (final root in roots) {
    flatten(root);
  }
  return result;
}
