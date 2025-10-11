import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? localMediaStream;
  final StreamController<MediaStream> _remoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;

  String? currentRoomId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  Future<void> initialize() async {
    localMediaStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        }
      }
    });
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(_configuration, _constraints);

    // Add local tracks to peer connection
    localMediaStream?.getTracks().forEach((track) {
      pc.addTrack(track, localMediaStream!);
    });

    // CRITICAL: Handle incoming remote tracks
    pc.onTrack = (RTCTrackEvent event) {
      print('🎥 Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStreamController.add(event.streams[0]);
      }
    };

    // Monitor connection state
    pc.onConnectionState = (RTCPeerConnectionState state) {
      print('🔗 Connection state: $state');
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      print('🧊 ICE connection state: $state');
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      print('🧊 New ICE candidate: ${candidate.candidate}');
      _onIceCandidate(candidate);
    };

    return pc;
  }

  Future<String> createOffer() async {
    _peerConnection = await _createPeerConnection();

    final roomRef = _firestore.collection('rooms').doc();
    currentRoomId = roomRef.id;

    // Create offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Store offer in Firestore
    await roomRef.set({
      'offer': {
        'type': offer.type,
        'sdp': offer.sdp,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('✅ Room created: $currentRoomId');

    // Listen for answer
    roomRef.snapshots().listen((snapshot) async {
      final data = snapshot.data();
      if (data != null && data['answer'] != null) {
        final answer = data['answer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
        print('✅ Answer received and set');
      }
    });

    // Listen for caller ICE candidates
    roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
          print('🧊 Callee candidate added');
        }
      }
    });

    return currentRoomId!;
  }

  Future<void> joinRoom(String roomId) async {
    currentRoomId = roomId;
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final roomSnapshot = await roomRef.get();

    if (!roomSnapshot.exists) {
      throw Exception('Room not found');
    }

    _peerConnection = await _createPeerConnection();

    // Get and set offer
    final data = roomSnapshot.data()!;
    final offer = data['offer'];
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );
    print('✅ Offer received and set');

    // Create answer
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    // Store answer
    await roomRef.update({
      'answer': {
        'type': answer.type,
        'sdp': answer.sdp,
      }
    });
    print('✅ Answer created and sent');

    // Listen for caller ICE candidates
    roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _peerConnection!.addCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
          print('🧊 Caller candidate added');
        }
      }
    });
  }

  void _onIceCandidate(RTCIceCandidate candidate) {
    if (currentRoomId == null) return;

    final roomRef = _firestore.collection('rooms').doc(currentRoomId);
    final collection = _peerConnection!.signalingState == RTCSignalingState.RTCSignalingStateStable
        ? 'calleeCandidates'
        : 'callerCandidates';

    roomRef.collection(collection).add({
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  void toggleAudio() {
    localMediaStream?.getAudioTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }

  void toggleVideo() {
    localMediaStream?.getVideoTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }

  Future<void> switchCamera() async {
    final videoTrack = localMediaStream?.getVideoTracks().first;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> hangUp() async {
    localMediaStream?.getTracks().forEach((track) => track.stop());
    await _peerConnection?.close();
    _peerConnection = null;
    localMediaStream = null;
    currentRoomId = null;
  }

  void dispose() {
    _remoteStreamController.close();
    hangUp();
  }
}
