import 'dart:io';
import 'dart:convert';
void main() async {
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse('https://www.google.com/search?tbm=isch&q=winston+red'));
  final response = await request.close();
  final html = await response.transform(utf8.decoder).join();
  print(html.substring(0, 500));
}
