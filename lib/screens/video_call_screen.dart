import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import 'firestore_test_screen.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webRTCService = WebRTCService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController _roomIdController = TextEditingController();

  bool _isInitialized = false;
  bool _inCall = false;
  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    setState(() {});
  }

  Future<void> _initializeMedia() async {
    try {
      await _webRTCService.initialize();
      _localRenderer.srcObject = _webRTCService.localMediaStream;

      // Listen for remote stream
      _webRTCService.remoteStream.listen((stream) {
        _remoteRenderer.srcObject = stream;
        setState(() {});
      });

      setState(() {
        _isInitialized = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Media initialized successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing media: $e')),
      );
    }
  }

  Future<void> _createRoom() async {
    if (!_isInitialized) {
      await _initializeMedia();
    }

    try {
      final roomId = await _webRTCService.createOffer();
      setState(() {
        _inCall = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room created: $roomId'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: roomId));
            },
          ),
        ),
      );
    } catch (e) {
      String errorMessage = e.toString();
      String displayMessage = 'Error creating room: $errorMessage';

      if (errorMessage.contains('permission-denied') || errorMessage.contains('permission denied')) {
        displayMessage = 'Firestore permission denied!\n\nPlease update your security rules.\nTap "Test Firestore" for help.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Help',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FirestoreTestScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _joinRoom() async {
    if (_roomIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room ID')),
      );
      return;
    }

    if (!_isInitialized) {
      await _initializeMedia();
    }

    try {
      await _webRTCService.joinRoom(_roomIdController.text);
      setState(() {
        _inCall = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined room successfully')),
      );
    } catch (e) {
      String errorMessage = e.toString();
      String displayMessage = 'Error joining room: $errorMessage';

      if (errorMessage.contains('permission-denied') || errorMessage.contains('permission denied')) {
        displayMessage = 'Firestore permission denied!\n\nPlease update your security rules.\nTap "Test Firestore" for help.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Help',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FirestoreTestScreen()),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _hangUp() async {
    await _webRTCService.hangUp();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    setState(() {
      _inCall = false;
      _isInitialized = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call ended')),
    );
  }

  void _toggleAudio() {
    _webRTCService.toggleAudio();
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });
  }

  void _toggleVideo() {
    _webRTCService.toggleVideo();
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
  }

  void _switchCamera() {
    _webRTCService.switchCamera();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webRTCService.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebRTC Video Call'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _inCall ? _buildCallView() : _buildLobbyView(),
    );
  }

  Widget _buildLobbyView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_call,
              size: 100,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 32),
            const Text(
              'Start or Join a Video Call',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 300,
              child: ElevatedButton.icon(
                onPressed: _createRoom,
                icon: const Icon(Icons.add),
                label: const Text('Create New Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'OR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _roomIdController,
                decoration: const InputDecoration(
                  labelText: 'Room ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.meeting_room),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 300,
              child: ElevatedButton.icon(
                onPressed: _joinRoom,
                icon: const Icon(Icons.login),
                label: const Text('Join Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 48),
            const Divider(),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FirestoreTestScreen()),
                );
              },
              icon: const Icon(Icons.settings_suggest),
              label: const Text('Test Firestore Setup'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallView() {
    return Stack(
      children: [
        // Remote video (full screen)
        Container(
          color: Colors.black,
          child: Center(
            child: _remoteRenderer.srcObject != null
                ? RTCVideoView(_remoteRenderer, mirror: false)
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Waiting for remote stream...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),

        // Local video (small preview)
        Positioned(
          top: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 120,
              height: 160,
              color: Colors.black,
              child: _localRenderer.srcObject != null
                  ? RTCVideoView(_localRenderer, mirror: true)
                  : const Center(
                      child: Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),

        // Room ID display
        if (_webRTCService.currentRoomId != null)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Room: ${_webRTCService.currentRoomId}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _webRTCService.currentRoomId!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Room ID copied')),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

        // Control buttons
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: _toggleAudio,
                backgroundColor: _isAudioEnabled ? Colors.white : Colors.red,
                child: Icon(
                  _isAudioEnabled ? Icons.mic : Icons.mic_off,
                  color: _isAudioEnabled ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              FloatingActionButton(
                onPressed: _hangUp,
                backgroundColor: Colors.red,
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
              const SizedBox(width: 16),
              FloatingActionButton(
                onPressed: _toggleVideo,
                backgroundColor: _isVideoEnabled ? Colors.white : Colors.red,
                child: Icon(
                  _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                  color: _isVideoEnabled ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              FloatingActionButton(
                onPressed: _switchCamera,
                backgroundColor: Colors.white,
                child: const Icon(Icons.flip_camera_ios, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
