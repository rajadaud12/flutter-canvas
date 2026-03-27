import 'package:flutter/material.dart';
import '../models/widget_node.dart';

/// Central state controller for the canvas widget tree.
/// Manages the flat list of nodes, active selection, and page properties.
class CanvasController extends ChangeNotifier {
  List<WidgetNode> _roots = [];
  List<Map<String, dynamic>> _flatSchema = [];
  String? _activeNodeId;
  Color _pageBackgroundColor = Colors.white;
  double _pagePadding = 0;
  double _pagePaddingTop = 0;
  double _pagePaddingRight = 0;
  double _pagePaddingBottom = 0;
  double _pagePaddingLeft = 0;
  bool _hasPerSidePadding = false;
  double _widgetGap = 0;

  List<WidgetNode> get roots => _roots;
  String? get activeNodeId => _activeNodeId;
  Color get pageBackgroundColor => _pageBackgroundColor;
  double get widgetGap => _widgetGap;
  EdgeInsets get pagePadding => _hasPerSidePadding
      ? EdgeInsets.fromLTRB(_pagePaddingLeft, _pagePaddingTop, _pagePaddingRight, _pagePaddingBottom)
      : EdgeInsets.all(_pagePadding);

  /// Load a full schema from React (flat CanvasElement[] list)
  void loadSchema(List<Map<String, dynamic>> flatSchema) {
    _flatSchema = flatSchema;
    _roots = buildTree(flatSchema);
    notifyListeners();
  }

  /// Update page properties from React
  void updatePageProperties(Map<String, dynamic> props) {
    final bgHex = props['backgroundColor'] as String? ?? '#ffffff';
    _pageBackgroundColor = _hexToColor(bgHex);
    _pagePadding = (props['padding'] as num?)?.toDouble() ?? 0;

    _hasPerSidePadding = props.containsKey('paddingTop') ||
        props.containsKey('paddingRight') ||
        props.containsKey('paddingBottom') ||
        props.containsKey('paddingLeft');

    if (_hasPerSidePadding) {
      _pagePaddingTop = (props['paddingTop'] as num?)?.toDouble() ?? 0;
      _pagePaddingRight = (props['paddingRight'] as num?)?.toDouble() ?? 0;
      _pagePaddingBottom = (props['paddingBottom'] as num?)?.toDouble() ?? 0;
      _pagePaddingLeft = (props['paddingLeft'] as num?)?.toDouble() ?? 0;
    }
    _widgetGap = (props['widgetGap'] as num?)?.toDouble() ?? 0;
    notifyListeners();
  }

  /// Set the currently selected node
  void setActiveNode(String? id) {
    _activeNodeId = id;
    notifyListeners();
  }

  /// Add a new node to the tree under a specific parent
  void addNode({required String parentId, required WidgetNode newNode, int? index}) {
    // Add to flat schema
    final newEntry = newNode.toJson();
    newEntry['parentId'] = parentId;
    newEntry['order'] = index ?? _flatSchema.where((e) => e['parentId'] == parentId).length;
    _flatSchema.add(newEntry);
    _roots = buildTree(_flatSchema);
    notifyListeners();
  }

  /// Add a root node
  void addRootNode(WidgetNode newNode) {
    final entry = newNode.toJson();
    // Set order to after the last root node
    final rootCount = _flatSchema.where((e) => e['parentId'] == null).length;
    entry['order'] = rootCount;
    _flatSchema.add(entry);
    _roots = buildTree(_flatSchema);
    notifyListeners();
  }

  /// Reorder root-level nodes (for ReorderableListView)
  void reorderRootNodes(int oldIndex, int newIndex) {
    // Get root node IDs in current order
    final rootNodes = _flatSchema
        .where((e) => e['parentId'] == null && e['type'] != 'appbar' && e['type'] != 'navbar')
        .toList()
      ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));

    if (oldIndex < 0 || oldIndex >= rootNodes.length || newIndex < 0 || newIndex >= rootNodes.length) return;

    final movedNode = rootNodes.removeAt(oldIndex);
    rootNodes.insert(newIndex, movedNode);

    // Update order fields
    for (int i = 0; i < rootNodes.length; i++) {
      final id = rootNodes[i]['id'];
      for (int j = 0; j < _flatSchema.length; j++) {
        if (_flatSchema[j]['id'] == id) {
          _flatSchema[j] = Map<String, dynamic>.from(_flatSchema[j]);
          _flatSchema[j]['order'] = i;
          break;
        }
      }
    }

    _roots = buildTree(_flatSchema);
    notifyListeners();
  }

  /// Update properties of a specific node
  void updateNodeProperties({required String nodeId, required Map<String, dynamic> newProperties}) {
    for (int i = 0; i < _flatSchema.length; i++) {
      if (_flatSchema[i]['id'] == nodeId) {
        final current = Map<String, dynamic>.from(_flatSchema[i]['properties'] ?? {});
        current.addAll(newProperties);
        _flatSchema[i] = Map<String, dynamic>.from(_flatSchema[i]);
        _flatSchema[i]['properties'] = current;
        break;
      }
    }
    _roots = buildTree(_flatSchema);
    notifyListeners();
  }

  /// Update root-level fields of a node (x, y, width, height, content)
  void updateNodeField({required String nodeId, required String field, required dynamic value}) {
    for (int i = 0; i < _flatSchema.length; i++) {
      if (_flatSchema[i]['id'] == nodeId) {
        _flatSchema[i] = Map<String, dynamic>.from(_flatSchema[i]);
        _flatSchema[i][field] = value;
        break;
      }
    }
    _roots = buildTree(_flatSchema);
    notifyListeners();
  }

  /// Delete a node and its children
  void deleteNode(String nodeId) {
    _deleteRecursive(nodeId);
    _roots = buildTree(_flatSchema);
    if (_activeNodeId == nodeId) _activeNodeId = null;
    notifyListeners();
  }

  void _deleteRecursive(String nodeId) {
    final childIds = _flatSchema
        .where((e) => e['parentId'] == nodeId)
        .map((e) => e['id'] as String)
        .toList();
    for (final childId in childIds) {
      _deleteRecursive(childId);
    }
    _flatSchema.removeWhere((e) => e['id'] == nodeId);
  }

  /// Duplicate the active node and add it as a sibling
  String? duplicateNode(String nodeId) {
    final idx = _flatSchema.indexWhere((e) => e['id'] == nodeId);
    if (idx == -1) return null;
    final original = Map<String, dynamic>.from(_flatSchema[idx]);
    final newId = '${original['type']}-${DateTime.now().millisecondsSinceEpoch}';
    final copy = Map<String, dynamic>.from(original);
    copy['id'] = newId;
    copy['order'] = (original['order'] as num? ?? 0) + 1;
    _flatSchema.add(copy);
    _roots = buildTree(_flatSchema);
    _activeNodeId = newId;
    notifyListeners();
    return newId;
  }

  /// Get sorted siblings of a node (same parentId, excluding appbar/navbar if root)
  List<Map<String, dynamic>> _getSiblings(String nodeId) {
    final node = _flatSchema.firstWhere((e) => e['id'] == nodeId, orElse: () => {});
    if (node.isEmpty) return [];
    final parentId = node['parentId'];
    return _flatSchema
        .where((e) => e['parentId'] == parentId && (parentId != null || (e['type'] != 'appbar' && e['type'] != 'navbar')))
        .toList()
      ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
  }

  /// Move node one step forward (higher order = renders later = visually on top)
  void moveNodeForward(String nodeId) {
    final siblings = _getSiblings(nodeId);
    final idx = siblings.indexWhere((e) => e['id'] == nodeId);
    if (idx == -1 || idx >= siblings.length - 1) return;
    _swapOrder(siblings[idx]['id'], siblings[idx + 1]['id']);
  }

  /// Move node one step backward
  void moveNodeBackward(String nodeId) {
    final siblings = _getSiblings(nodeId);
    final idx = siblings.indexWhere((e) => e['id'] == nodeId);
    if (idx <= 0) return;
    _swapOrder(siblings[idx]['id'], siblings[idx - 1]['id']);
  }

  /// Move node to front (last in render order)
  void moveNodeToFront(String nodeId) {
    final siblings = _getSiblings(nodeId);
    final idx = siblings.indexWhere((e) => e['id'] == nodeId);
    if (idx == -1 || idx >= siblings.length - 1) return;
    final removed = siblings.removeAt(idx);
    siblings.add(removed);
    _rewriteOrders(siblings);
  }

  /// Move node to back (first in render order)
  void moveNodeToBack(String nodeId) {
    final siblings = _getSiblings(nodeId);
    final idx = siblings.indexWhere((e) => e['id'] == nodeId);
    if (idx <= 0) return;
    final removed = siblings.removeAt(idx);
    siblings.insert(0, removed);
    _rewriteOrders(siblings);
  }

  void _swapOrder(String idA, String idB) {
    int? orderA, orderB;
    int? iA, iB;
    for (int i = 0; i < _flatSchema.length; i++) {
      if (_flatSchema[i]['id'] == idA) { orderA = (_flatSchema[i]['order'] as num?)?.toInt() ?? 0; iA = i; }
      if (_flatSchema[i]['id'] == idB) { orderB = (_flatSchema[i]['order'] as num?)?.toInt() ?? 0; iB = i; }
    }
    if (iA != null && iB != null) {
      _flatSchema[iA] = Map<String, dynamic>.from(_flatSchema[iA]);
      _flatSchema[iB] = Map<String, dynamic>.from(_flatSchema[iB]);
      _flatSchema[iA]['order'] = orderB;
      _flatSchema[iB]['order'] = orderA;
    }
    _roots = buildTree(_flatSchema);
    notifyListeners();
  }

  void _rewriteOrders(List<Map<String, dynamic>> siblings) {
    for (int i = 0; i < siblings.length; i++) {
      final id = siblings[i]['id'];
      for (int j = 0; j < _flatSchema.length; j++) {
        if (_flatSchema[j]['id'] == id) {
          _flatSchema[j] = Map<String, dynamic>.from(_flatSchema[j]);
          _flatSchema[j]['order'] = i;
          break;
        }
      }
    }
    _roots = buildTree(_flatSchema);
    notifyListeners();
  }

  /// Get the flat schema for sending back to React
  List<Map<String, dynamic>> getFlatSchema() {
    return List.from(_flatSchema);
  }

  /// Find a node by ID in the tree
  WidgetNode? findNode(String id) {
    return _findInTree(id, _roots);
  }

  WidgetNode? _findInTree(String id, List<WidgetNode> nodes) {
    for (final node in nodes) {
      if (node.id == id) return node;
      final found = _findInTree(id, node.children);
      if (found != null) return found;
    }
    return null;
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
