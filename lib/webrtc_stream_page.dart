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
    // Define PC configuration
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ],
    };

    try {
      // Create the PeerConnection
      _peerConnection = await createPeerConnection(configuration);

      // Listen for incoming tracks
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video') {
          dev.log('Received remote video track');
          setState(() {
            _localRenderer.srcObject = event.streams[0];
          });
        }
      };

      // =======================================================================
      // THE REAL FIX: Create a transceiver, then set its codec preferences.
      // -----------------------------------------------------------------------

      // 1. Add a video transceiver that is set to receive-only.
      // This creates the channel for the video to come through.
      final transceiver = await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // 2. Get the full list of system-supported codecs.
      // Note: getCapabilities is a static method on the factory helper.
      final videoCodecs = await getRtpSenderCapabilities('video');

      for (var codec in videoCodecs.codecs!) {
        dev.log("Supported codec: ${codec.mimeType}");
      }

      // 3. Filter the list to find only the H264 codecs.
      final h264Codecs = videoCodecs.codecs!
          .where((codec) => codec.mimeType.toLowerCase() == 'video/h264')
          .toList();

      if (h264Codecs.isEmpty) {
        dev.log("H.264 codec not supported by this device.");
        return;
      }

      dev.log(
        "Found supported H264 codecs: ${h264Codecs.map((e) => e.toMap())}",
      );

      // 4. Call setCodecPreferences on the TRANSCEIVER INSTANCE.
      // This tells the WebRTC engine to only use H264 for this specific transceiver.
      await transceiver.setCodecPreferences(h264Codecs);

      // =======================================================================

      // 5. Now, create the offer. The SDP will be correctly generated based
      //    on the preferences we just set.
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      dev.log('Offer: ${offer.sdp}');
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
        dev.log('Received answer: ${answer.sdp}');
        await _peerConnection!.setRemoteDescription(answer);
        dev.log("Connection established!");
      } else {
        dev.log('Failed to connect to signaling server');
      }
    } catch (e) {
      dev.log("Error connecting: $e");
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
              child: const Text('Connect to Stream (H264)'),
            ),
          ),
        ],
      ),
    );
  }
}
