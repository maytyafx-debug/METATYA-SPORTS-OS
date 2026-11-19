/**
 * Volleyball-only domain primitives.
 *
 * This module is intentionally isolated from shared sports operations and
 * from every other sport module. It contains no persistence, user, athlete,
 * organization, or equipment integrations.
 */

export type VolleyballSetScore = Readonly<{
  home: number;
  away: number;
}>;

export type VolleyballMatchScore = Readonly<{
  sets: readonly VolleyballSetScore[];
}>;

export type VolleyballScoreValidation =
  | Readonly<{ valid: true; homeSetsWon: number; awaySetsWon: number }>
  | Readonly<{ valid: false; errors: readonly string[] }>;

const SETS_TO_WIN_MATCH = 3;
const REGULAR_SET_TARGET = 25;
const DECIDING_SET_TARGET = 15;
const MAX_SETS_PER_MATCH = 5;

function isNonNegativeInteger(value: number): boolean {
  return Number.isInteger(value) && value >= 0;
}

/**
 * Validates a completed indoor-volleyball match score under the standard
 * best-of-five set format: sets 1–4 to 25, deciding set to 15, win by two.
 *
 * This validates score data only; it does not determine eligibility,
 * officiating decisions, competition rules, or official result approval.
 */
export function validateVolleyballMatchScore(
  match: VolleyballMatchScore,
): VolleyballScoreValidation {
  const errors: string[] = [];

  if (!Array.isArray(match.sets) || match.sets.length === 0) {
    return { valid: false, errors: ["A completed match must contain at least one set."] };
  }

  if (match.sets.length > MAX_SETS_PER_MATCH) {
    return { valid: false, errors: ["A best-of-five match cannot contain more than five sets."] };
  }

  let homeSetsWon = 0;
  let awaySetsWon = 0;

  match.sets.forEach((set, index) => {
    const setNumber = index + 1;
    const label = `Set ${setNumber}`;

    if (!isNonNegativeInteger(set.home) || !isNonNegativeInteger(set.away)) {
      errors.push(`${label} scores must be non-negative integers.`);
      return;
    }

    if (set.home === set.away) {
      errors.push(`${label} cannot end in a tie.`);
      return;
    }

    const target = setNumber === 5 ? DECIDING_SET_TARGET : REGULAR_SET_TARGET;
    const winner = Math.max(set.home, set.away);
    const loser = Math.min(set.home, set.away);

    if (winner < target || winner - loser < 2) {
      errors.push(
        `${label} must reach at least ${target} points and be won by two points.`,
      );
      return;
    }

    if (set.home > set.away) {
      homeSetsWon += 1;
    } else {
      awaySetsWon += 1;
    }

    if (
      (homeSetsWon === SETS_TO_WIN_MATCH || awaySetsWon === SETS_TO_WIN_MATCH) &&
      setNumber < match.sets.length
    ) {
      errors.push("No additional sets may be recorded after a team wins the match.");
    }
  });

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  if (
    homeSetsWon !== SETS_TO_WIN_MATCH &&
    awaySetsWon !== SETS_TO_WIN_MATCH
  ) {
    return {
      valid: false,
      errors: ["A completed best-of-five match must have a team win three sets."],
    };
  }

  return { valid: true, homeSetsWon, awaySetsWon };
}
