enum Elv5Discipline { cctv, lan, acs, fireAlarm }

enum Elv5ProcessCode {
  cctv01,
  cctv02,
  cctv03,
  cctv04,
  cctv05,
  cctv06,
  lan01,
  lan02,
  lan03,
  lan04,
  lan05,
  lan06,
  lan07,
  acs01,
  acs02,
  acs03,
  acs04,
  acs05,
  acs06,
  fa01,
  fa02,
  fa03,
  fa04,
  fa05,
  fa06,
  fa07,
  fa08;

  String get wireCode {
    final name = this.name;
    if (name.startsWith('cctv')) {
      return 'CCTV-${name.substring(4).padLeft(2, '0')}';
    }
    if (name.startsWith('lan')) {
      return 'LAN-${name.substring(3).padLeft(2, '0')}';
    }
    if (name.startsWith('acs')) {
      return 'ACS-${name.substring(3).padLeft(2, '0')}';
    }
    return 'FA-${name.substring(2).padLeft(2, '0')}';
  }

  Elv5Discipline get discipline {
    if (name.startsWith('cctv')) return Elv5Discipline.cctv;
    if (name.startsWith('lan')) return Elv5Discipline.lan;
    if (name.startsWith('acs')) return Elv5Discipline.acs;
    return Elv5Discipline.fireAlarm;
  }

  static Elv5ProcessCode parse(String value) {
    for (final code in values) {
      if (code.wireCode == value) return code;
    }
    throw FormatException('Unknown ELV5 process code.', value);
  }
}
