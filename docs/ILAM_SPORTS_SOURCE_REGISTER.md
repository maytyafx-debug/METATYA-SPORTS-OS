# Ilam Sports Source Register

**Destination repository:** maytyafx-debug/METATYA-SPORTS-OS  
**Prepared:** 2026-11-19

This register records which earlier sports materials were reviewed and how they are represented in this repository.

| Source material | Reusable content | Handling |
|---|---|---|
| Historical project master brief | Organization administration, event planning, results, rankings, communication | Generalized into `ILAM_SPORTS_SYSTEMS_REFERENCE.md`; discipline-specific sections excluded |
| Annual competition calendar (1405) | Year calendar, recurring event planning, event metadata form | Structure generalized; exact dates and discipline-specific schedule not adopted |
| First/second/third-place certificate templates | Award/certificate fields, signatures, event and athlete identity | Generic configurable certificate requirements documented |
| Modern certificate variants | Certificate numbering, QR authenticity area, signature blocks | Design pattern noted; original sport-specific assets not copied |
| Sports performance landing page | Consent, privacy, qualified support, limits on sharing | Privacy and safeguarding requirements generalized |
| METATYA SPORTS OS README | Product boundary, architecture, implementation baseline | Existing source of truth; not duplicated |
| METATYA SPORTS OS production backlog | Production readiness and security tasks | Existing source of truth; not duplicated |

## Exclusions

- Sport-specific technical rules, equipment specifications, scoring procedures, and venue-specific safety forms are not part of the cross-sport core.
- Historical schedules and dates are not treated as current official schedules.
- Secrets, tokens, credentials, personal athlete data, and private operational records are never copied into this repository.
- No external database, deployment, or other repository has been modified by this documentation import.

## Source of truth and follow-up

The current implementation status remains defined by the repository code, migrations, CI evidence, README, and production backlog. Imported documents are requirements/reference material only. Before converting any requirement into a feature, verify the applicable organization policy, sport rules, privacy requirements, and owner approval.
