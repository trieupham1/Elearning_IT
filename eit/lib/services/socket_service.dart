// services/socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../config/api_config.dart';
import 'dart:async';

enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  IO.Socket? _socket;
  String? _currentUserId;
  
  // Support multiple message listeners
  final List<Function(dynamic)> _messageCallbacks = [];
  
  // Connection state management
  final StreamController<SocketConnectionState> _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();
  Stream<SocketConnectionState> get connectionState => _connectionStateController.stream;
  SocketConnectionState _currentState = SocketConnectionState.disconnected;

  // Reconnection configuration
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 2);
  Timer? _reconnectTimer;

  bool get isConnected => _socket?.connected ?? false;
  SocketConnectionState get currentState => _currentState;

  /// Update connection state and notify listeners
  void _updateConnectionState(SocketConnectionState state) {
    if (_currentState != state) {
      _currentState = state;
      _connectionStateController.add(state);
      _logger.d('Connection state changed to: $state');
    }
  }

  /// Initialize socket connection with user authentication
  Future<void> connect(String userId, {bool autoReconnect = true}) async {
    if (_socket?.connected == true) {
      _logger.i('Socket already connected');
      return;
    }

    _currentUserId = userId;
    _shouldReconnect = autoReconnect;
    _reconnectAttempts = 0;

    await _initializeSocket(userId);
  }

  /// Internal socket initialization
  Future<void> _initializeSocket(String userId) async {
    try {
      _updateConnectionState(SocketConnectionState.connecting);
      _logger.i('Connecting to socket server at ${ApiConfig.baseUrl}');

      // Dispose existing socket if any
      _socket?.dispose();

      _socket = IO.io(
        ApiConfig.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'userId': userId})
            .setTimeout(10000) // 10 second timeout
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(_shouldReconnect ? 5 : 0)
            .build(),
      );

      _setupSocketListeners(userId);
      _socket!.connect();

    } catch (e) {
      _logger.e('Error initializing socket: $e');
      _updateConnectionState(SocketConnectionState.error);
      _handleReconnection();
    }
  }

  /// Setup all socket event listeners
  void _setupSocketListeners(String userId) {
    _socket!.onConnect((_) {
      _logger.i('Socket connected successfully');
      _updateConnectionState(SocketConnectionState.connected);
      _reconnectAttempts = 0; // Reset on successful connection
      
      // Register user with their socket
      _socket!.emit('register', userId);
      _logger.i('Registered user: $userId');
    });

    _socket!.onDisconnect((_) {
      _logger.w('Socket disconnected');
      _updateConnectionState(SocketConnectionState.disconnected);
      _handleReconnection();
    });

    _socket!.onConnectError((error) {
      _logger.e('Socket connection error: $error');
      _updateConnectionState(SocketConnectionState.error);
      _handleReconnection();
    });

    _socket!.onError((error) {
      _logger.e('Socket error: $error');
      _updateConnectionState(SocketConnectionState.error);
    });

    _socket!.onReconnect((attempt) {
      _logger.i('Socket reconnected after $attempt attempts');
      _updateConnectionState(SocketConnectionState.connected);
      _reconnectAttempts = 0;
    });

    _socket!.onReconnectAttempt((attempt) {
      _logger.i('Attempting to reconnect... (attempt $attempt)');
      _updateConnectionState(SocketConnectionState.reconnecting);
    });

    _socket!.onReconnectError((error) {
      _logger.e('Reconnection error: $error');
    });

    _socket!.onReconnectFailed((_) {
      _logger.e('Failed to reconnect after maximum attempts');
      _updateConnectionState(SocketConnectionState.error);
    });

    // Listen for new messages
    _socket!.on('new_message', (data) {
      _logger.d('New message received: $data');
      _notifyMessageListeners(data);
    });
  }

  /// Handle reconnection logic
  void _handleReconnection() {
    if (!_shouldReconnect || _currentUserId == null) {
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.e('Max reconnection attempts reached');
      _updateConnectionState(SocketConnectionState.error);
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    
    final delay = _reconnectDelay * _reconnectAttempts; // Exponential backoff
    _logger.i('Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s');
    
    _reconnectTimer = Timer(delay, () {
      _logger.i('Attempting manual reconnection...');
      _initializeSocket(_currentUserId!);
    });
  }

  /// Notify all message listeners
  void _notifyMessageListeners(dynamic data) {
    for (var callback in _messageCallbacks) {
      try {
        callback(data);
      } catch (e) {
        _logger.e('Error in message callback: $e');
      }
    }
  }

  /// Emit a custom event with optional acknowledgment
  void emit(String event, dynamic data, {Function(dynamic)? ack}) {
    if (_socket?.connected == true) {
      if (ack != null) {
        _socket!.emitWithAck(event, data, ack: ack);
      } else {
        _socket!.emit(event, data);
      }
      _logger.d('Emitted event: $event with data: $data');
    } else {
      _logger.w('Cannot emit event - socket not connected');
    }
  }

  /// Listen to a custom event
  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
    _logger.d('Registered listener for event: $event');
  }

  /// Remove listener for an event
  void off(String event, {Function(dynamic)? handler}) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
    _logger.d('Removed listener for event: $event');
  }

  /// Listen for new messages (supports multiple listeners)
  void onNewMessage(Function(dynamic) callback) {
    if (!_messageCallbacks.contains(callback)) {
      _messageCallbacks.add(callback);
      _logger.d('Registered new message callback (total: ${_messageCallbacks.length})');
    }
  }

  /// Remove specific new message listener
  void offNewMessage(Function(dynamic)? callback) {
    if (callback != null) {
      _messageCallbacks.remove(callback);
      _logger.d('Removed message callback (remaining: ${_messageCallbacks.length})');
    } else {
      _messageCallbacks.clear();
      _logger.d('Cleared all message callbacks');
    }
  }

  /// Disconnect socket and cancel reconnection
  void disconnect({bool permanent = false}) {
    _reconnectTimer?.cancel();
    _shouldReconnect = !permanent;
    
    if (_socket?.connected == true) {
      _socket!.disconnect();
      _logger.i('Socket disconnected ${permanent ? "(permanent)" : ""}');
    }
    
    if (permanent) {
      _currentUserId = null;
      _messageCallbacks.clear();
      _updateConnectionState(SocketConnectionState.disconnected);
    }
  }

  /// Force reconnect
  Future<void> reconnect() async {
    if (_currentUserId != null) {
      _logger.i('Forcing reconnection...');
      disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
      await _initializeSocket(_currentUserId!);
    } else {
      _logger.w('Cannot reconnect - no user ID available');
    }
  }

  /// Get current socket connection status
  String getConnectionStatus() {
    final statusIcon = {
      SocketConnectionState.connected: '✅',
      SocketConnectionState.connecting: '🔄',
      SocketConnectionState.reconnecting: '🔄',
      SocketConnectionState.disconnected: '❌',
      SocketConnectionState.error: '⚠️',
    };

    if (_socket == null) {
      return '❌ Socket not initialized';
    }

    return '${statusIcon[_currentState]} ${_currentState.toString().split('.').last} ${_currentUserId != null ? "(User: $_currentUserId)" : ""}';
  }

  /// Get current user ID
  String? getCurrentUserId() => _currentUserId;

  /// Check if currently reconnecting
  bool get isReconnecting => _currentState == SocketConnectionState.reconnecting;

  /// Get number of active message listeners
  int get messageListenerCount => _messageCallbacks.length;

  /// Dispose of resources
  void dispose() {
    _reconnectTimer?.cancel();
    _socket?.dispose();
    _messageCallbacks.clear();
    _connectionStateController.close();
    _logger.i('SocketService disposed');
  }
}