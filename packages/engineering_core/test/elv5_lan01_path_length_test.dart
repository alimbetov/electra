import 'package:engineering_core/engineering_core_elv5.dart'
    show
        Elv5Rational,
        Lan01ExplicitAllowance,
        Lan01Input,
        Lan01LengthInterval,
        Lan01MaximumPolicy,
        Lan01PathLengthKernel,
        Lan01Policy,
        Lan01RealizedSection,
        Lan01SectionClass,
        Length;
import 'package:test/test.dart';

Length _m(String value) => Length(Elv5Rational.parseDecimal(value));
Lan01LengthInterval _exact(String value) =>
    Lan01LengthInterval.exact(_m(value));

void main() {
  group('LAN-01 installed path length', () {
    test('28 m permanent plus 2 m patch yields zero margins', () {
      final result = const Lan01PathLengthKernel().evaluate(
        Lan01Input(
          linkId: 'link-1',
          orderedSections: <Lan01RealizedSection>[
            Lan01RealizedSection(
              sectionId: 'perm-a',
              sectionClass: Lan01SectionClass.permanent,
              installedLength: _exact('28'),
            ),
            Lan01RealizedSection(
              sectionId: 'patch-a',
              sectionClass: Lan01SectionClass.patch,
              installedLength: _exact('2'),
            ),
          ],
          policy: Lan01Policy(
            permanentMaximum: Lan01MaximumPolicy(limit: _m('28')),
            channelMaximum: Lan01MaximumPolicy(limit: _m('30')),
          ),
        ),
      );

      expect(result.permanent.length.upper, _m('28'));
      expect(result.channel.length.upper, _m('30'));
      expect(result.permanent.margin, _m('0'));
      expect(result.channel.margin, _m('0'));
      expect(result.permanent.passes, isTrue);
      expect(result.channel.passes, isTrue);
    });

    test('uses upper bound for conservative maximum comparison', () {
      final pass = const Lan01PathLengthKernel().evaluate(
        Lan01Input(
          linkId: 'link-1',
          orderedSections: <Lan01RealizedSection>[
            Lan01RealizedSection(
              sectionId: 'perm-a',
              sectionClass: Lan01SectionClass.permanent,
              installedLength: Lan01LengthInterval(
                lower: _m('27.999'),
                upper: _m('28.000'),
              ),
            ),
          ],
          policy: Lan01Policy(
            permanentMaximum: Lan01MaximumPolicy(limit: _m('28')),
          ),
        ),
      );
      expect(pass.permanent.margin, _m('0'));
      expect(pass.permanent.passes, isTrue);

      final fail = const Lan01PathLengthKernel().evaluate(
        Lan01Input(
          linkId: 'link-2',
          orderedSections: <Lan01RealizedSection>[
            Lan01RealizedSection(
              sectionId: 'perm-a',
              sectionClass: Lan01SectionClass.permanent,
              installedLength: Lan01LengthInterval(
                lower: _m('28'),
                upper: _m('28.000001'),
              ),
            ),
          ],
          policy: Lan01Policy(
            permanentMaximum: Lan01MaximumPolicy(limit: _m('28')),
          ),
        ),
      );
      expect(fail.permanent.margin, _m('-0.000001'));
      expect(fail.permanent.passes, isFalse);
    });

    test('channel fails independently while permanent still passes', () {
      final result = const Lan01PathLengthKernel().evaluate(
        Lan01Input(
          linkId: 'link-1',
          orderedSections: <Lan01RealizedSection>[
            Lan01RealizedSection(
              sectionId: 'perm-a',
              sectionClass: Lan01SectionClass.permanent,
              installedLength: _exact('28'),
            ),
            Lan01RealizedSection(
              sectionId: 'patch-a',
              sectionClass: Lan01SectionClass.patch,
              installedLength: _exact('3'),
            ),
          ],
          policy: Lan01Policy(
            permanentMaximum: Lan01MaximumPolicy(limit: _m('28')),
            channelMaximum: Lan01MaximumPolicy(limit: _m('30')),
          ),
        ),
      );

      expect(result.permanent.passes, isTrue);
      expect(result.channel.passes, isFalse);
      expect(result.channel.margin, _m('-1'));
    });

    test('does not double-add allowance already included upstream', () {
      final result = const Lan01PathLengthKernel().evaluate(
        Lan01Input(
          linkId: 'link-1',
          orderedSections: <Lan01RealizedSection>[
            Lan01RealizedSection(
              sectionId: 'perm-a',
              sectionClass: Lan01SectionClass.permanent,
              installedLength: _exact('28'),
            ),
          ],
          allowances: <Lan01ExplicitAllowance>[
            Lan01ExplicitAllowance(
              allowanceId: 'service-loop',
              length: _exact('1'),
              appliesToPermanent: true,
              appliesToChannel: true,
              alreadyIncludedInInstalledLength: true,
            ),
          ],
        ),
      );

      expect(result.permanent.length.upper, _m('28'));
      expect(result.channel.length.upper, _m('28'));
    });

    test('rejects duplicate canonical section identity', () {
      expect(
        () => const Lan01PathLengthKernel().evaluate(
          Lan01Input(
            linkId: 'link-1',
            orderedSections: <Lan01RealizedSection>[
              Lan01RealizedSection(
                sectionId: 'dup',
                sectionClass: Lan01SectionClass.permanent,
                installedLength: _exact('10'),
              ),
              Lan01RealizedSection(
                sectionId: 'dup',
                sectionClass: Lan01SectionClass.patch,
                installedLength: _exact('1'),
              ),
            ],
          ),
        ),
        throwsStateError,
      );
    });
  });
}
