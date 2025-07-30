import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class WebRTCStreamPage extends StatefulWidget {
  const WebRTCStreamPage({super.key});

  @override
  WebRTCStreamPageState createState() => WebRTCStreamPageState();
}

class WebRTCStreamPageState extends State<WebRTCStreamPage> {
  final _localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;

  // IMPORTANT: REPLACE WITH YOUR COMPUTER'S LOCAL IP
  final String _signalingServerUrl =
      "http://192.168.5.238:8080"; //192.168.5.238

  @override
  void initState() {
    super.initState();
    initRenderers();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _peerConnection?.dispose();
    super.dispose();
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
  }

  Future<void> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ],
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {"OfferToReceiveAudio": false, "OfferToReceiveVideo": true},
      "optional": [],
    };

    _peerConnection = await createPeerConnection(
      configuration,
      offerSdpConstraints,
    );

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video') {
        setState(() {
          _remoteStream = event.streams[0];
          _localRenderer.srcObject = _remoteStream;
        });
      }
    };
  }

  Future<void> _connect() async {
    await _createPeerConnection();

    try {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      final response = await http.post(
        Uri.parse('$_signalingServerUrl/offer'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'sdp': offer.sdp, 'type': offer.type}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final answer = RTCSessionDescription(body['sdp'], body['type']);
        await _peerConnection!.setRemoteDescription(answer);
        print("Connection established!");
      } else {
        print('Failed to connect to signaling server');
      }
    } catch (e) {
      print("Error connecting: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("WebRTC H.264 Stream")),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: RTCVideoView(_localRenderer, mirror: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _connect,
              child: const Text('Connect to Stream'),
            ),
          ),
        ],
      ),
    );
  }
}
