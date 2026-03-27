import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Bridge for communicating between React (parent window) and Flutter (iframe).
/// Uses window.postMessage for bidirectional messaging.
class JsBridge {
  Function(List<Map<String, dynamic>>)? onSchemaReceived;
  Function(Map<String, dynamic>)? onPagePropertiesReceived;
  Function(String?)? onSelectionReceived;
  Function(Map<String, dynamic>)? onDropReceived;
  Function(Map<String, dynamic>)? onPropsUpdateReceived;
  Function(Map<String, dynamic>)? onNodeUpdateReceived;
  Function(String action, String? nodeId)? onActionReceived;

  JsBridge() {
    _listenForMessages();
  }

  /// Listen for postMessage events from React parent
  void _listenForMessages() {
    web.window.addEventListener('message', (web.Event event) {
      final msgEvent = event as web.MessageEvent;
      final data = msgEvent.data;

      if (data == null) return;

      try {
        late final Map<String, dynamic> parsed;

        if (data is JSString) {
          parsed = jsonDecode(data.toDart) as Map<String, dynamic>;
        } else {
          final dartified = (data as JSAny).dartify();
          if (dartified is Map) {
            parsed = Map<String, dynamic>.from(dartified);
          } else if (dartified is String) {
            parsed = jsonDecode(dartified) as Map<String, dynamic>;
          } else {
            return;
          }
        }

        final type = parsed['type'] as String?;
        final payload = parsed['payload'];

        switch (type) {
          case 'schema:update':
            if (payload is List && onSchemaReceived != null) {
              final list = payload.map((item) {
                if (item is Map) {
                  return Map<String, dynamic>.from(item);
                }
                return <String, dynamic>{};
              }).toList();
              onSchemaReceived!(list);
            }
            break;
          case 'page:update':
            if (payload is Map && onPagePropertiesReceived != null) {
              onPagePropertiesReceived!(Map<String, dynamic>.from(payload));
            }
            break;
          case 'selection:set':
            if (onSelectionReceived != null) {
              if (payload is Map) {
                onSelectionReceived!(payload['id'] as String?);
              } else {
                onSelectionReceived!(null);
              }
            }
            break;
          case 'drop:widget':
            if (payload is Map && onDropReceived != null) {
              onDropReceived!(Map<String, dynamic>.from(payload));
            }
            break;
          case 'props:update':
            if (payload is Map && onPropsUpdateReceived != null) {
              onPropsUpdateReceived!(Map<String, dynamic>.from(payload));
            }
            break;
          case 'node:update':
            if (payload is Map && onNodeUpdateReceived != null) {
              onNodeUpdateReceived!(Map<String, dynamic>.from(payload));
            }
            break;
          case 'action:perform':
            if (payload is Map && onActionReceived != null) {
              final action = payload['action'] as String? ?? '';
              final nodeId = payload['nodeId'] as String?;
              onActionReceived!(action, nodeId);
            }
            break;
          case 'ping:ready':
            sendReady();
            break;
        }
      } catch (e) {
        // Silently ignore non-JSON messages (e.g. webpack HMR)
      }
    }.toJS);
  }

  /// Send message to React parent
  void sendToReact(String type, [dynamic payload]) {
    final message = jsonEncode({
      'type': type,
      'payload': payload,
    });
    web.window.parent?.postMessage(message.toJS, '*'.toJS);
  }

  void sendReady() => sendToReact('ready');

  void sendSchemaChanged(List<Map<String, dynamic>> flatSchema) =>
      sendToReact('schema:changed', flatSchema);

  void sendSelectionChanged(String? nodeId) =>
      sendToReact('selection:changed', {'id': nodeId});

  /// Send context menu request to React
  void sendContextMenu(String nodeId, double x, double y) =>
      sendToReact('context-menu:show', {'id': nodeId, 'x': x, 'y': y});

  void sendPositionUpdate(String nodeId, double x, double y) =>
      sendToReact('position:changed', {'id': nodeId, 'x': x, 'y': y});

  void sendSizeUpdate(String nodeId, double width, double height) =>
      sendToReact('size:changed', {'id': nodeId, 'width': width, 'height': height});
}
