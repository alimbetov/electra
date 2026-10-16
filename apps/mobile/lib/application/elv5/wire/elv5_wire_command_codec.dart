import 'elv5_wire_command.dart';

/// Public P2 codec boundary. Structural and semantic validation is performed
/// before any repository/UoW is allowed to observe a command.
final class Elv5WireCommandCodec {
  const Elv5WireCommandCodec();

  Elv5WireCommandEnvelope decodeJson(String source) =>
      Elv5WireCommandEnvelope.fromJson(source);

  Elv5WireCommandEnvelope decodeMap(Map<String, Object?> value) =>
      Elv5WireCommandEnvelope.fromMap(value);

  String encode(Elv5WireCommandEnvelope command) => command.toJson();
}
