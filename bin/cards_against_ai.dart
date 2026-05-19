import 'package:cards_against_ai/cards_against_ai.dart' as app;

void main(List<String> arguments) {
  bool ansi = false;

  if (arguments.contains('--no-ansi')) {
    ansi = true;
  }

  final server = app.Server();

  server.start(ansi);

  app.terminal.endOfFile();
}
