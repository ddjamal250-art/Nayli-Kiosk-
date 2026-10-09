import 'dart:io';
import 'dart:convert';
void main() async {
  final client = HttpClient();
  final req1 = await client.getUrl(Uri.parse('https://duckduckgo.com/?q=winston+red&iax=images&ia=images'));
  final res1 = await req1.close();
  final html = await res1.transform(utf8.decoder).join();
  final vqdMatch = RegExp(r'vqd=([\d-]+)').firstMatch(html);
  if (vqdMatch != null) {
    final vqd = vqdMatch.group(1);
    final req2 = await client.getUrl(Uri.parse('https://duckduckgo.com/i.js?l=us-en&o=json&q=winston+red&vqd=\'));
    req2.headers.set('User-Agent', 'Mozilla/5.0');
    final res2 = await req2.close();
    final json = await res2.transform(utf8.decoder).join();
    final data = jsonDecode(json);
    print(data['results'][0]['image']);
  }
}
