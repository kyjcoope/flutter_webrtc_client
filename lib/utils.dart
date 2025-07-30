import 'dart:io';

bool isH264(String sdp) =>
    RegExp(r'\bH264/90000\b', caseSensitive: false).hasMatch(sdp);

String mungeSdp(String sdp) {
  const iosAllowed = {'640c2a', '42e02a', '42e01f'};
  final defaultId = Platform.isIOS ? '42e02a' : '42e01f';

  // Fix profile‑level‑id
  sdp = sdp.replaceAllMapped(RegExp(r'profile-level-id=([0-9A-Fa-f]{6})'), (m) {
    final id = m[1]!.toLowerCase();
    final goodId = Platform.isIOS
        ? (iosAllowed.contains(id) ? id : defaultId)
        : defaultId; // always 42e01f on Android
    return 'profile-level-id=$goodId';
  });

  // Ensure level‑asymmetry‑allowed=1
  if (!sdp.toLowerCase().contains('level-asymmetry-allowed')) {
    sdp = sdp.replaceFirst(
      'packetization-mode=1;',
      'level-asymmetry-allowed=1;packetization-mode=1;',
    );
  }

  return sdp;
}
