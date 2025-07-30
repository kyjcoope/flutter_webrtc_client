import 'package:flutter/material.dart';
import 'package:flutter_webrtc_client/webrtc_stream_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Client',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WebRTCStreamPage(),
    );
  }
}
