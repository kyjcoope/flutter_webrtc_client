import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as dev;

class WebRTCStreamPage extends StatefulWidget {
  const WebRTCStreamPage({super.key});

  @override
  WebRTCStreamPageState createState() => WebRTCStreamPageState();
}

class WebRTCStreamPageState extends State<WebRTCStreamPage> {
  final _localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;

  // IMPORTANT: Make sure this is your computer's local IP
  final String _signalingServerUrl = "http://192.168.5.238:8080";

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

  Future<void> _connect() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ],
    };

    try {
      // 1. Request an offer from the server
      dev.log("Requesting offer from server...");
      final offerResponse = await http.get(
        Uri.parse('$_signalingServerUrl/request-offer'),
      );

      if (offerResponse.statusCode != 200) {
        dev.log("Failed to get offer from server");
        return;
      }

      final offerData = jsonDecode(offerResponse.body);
      final String pcId = offerData['id'];
      final String sdp = offerData['sdp'];
      final String type = offerData['type'];

      dev.log("Received offer with sdp:\n$sdp");

      // 2. Create the PeerConnection
      _peerConnection = await createPeerConnection(configuration);

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video') {
          dev.log('Received remote video track');
          setState(() {
            _localRenderer.srcObject = event.streams[0];
          });
        }
      };

      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, type),
      );

      final answer = await _peerConnection!.createAnswer();
      dev.log("answer:\n${answer.sdp}");
      await _peerConnection!.setLocalDescription(answer);

      dev.log("Created answer");

      // 5. Send the answer back to the server
      final answerResponse = await http.post(
        Uri.parse('$_signalingServerUrl/submit-answer'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({'id': pcId, 'sdp': answer.sdp, 'type': answer.type}),
      );

      if (answerResponse.statusCode == 200) {
        dev.log("Answer submitted successfully. Connection established!");
      } else {
        dev.log("Failed to submit answer to server");
      }
    } catch (e) {
      dev.log("Error during connection: $e");
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
              child: const Text('Connect to Stream (Server Offer)'),
            ),
          ),
        ],
      ),
    );
  }
}
