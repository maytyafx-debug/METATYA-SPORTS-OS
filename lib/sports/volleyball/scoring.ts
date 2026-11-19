export type VolleyballSetScore = Readonly<{ home: number; away: number }>;
export type VolleyballMatchScore = Readonly<{ sets: readonly VolleyballSetScore[]; bestOf?: 3 | 5 }>;
export type VolleyballScoreValidation =
  | Readonly<{ valid: true; homeSetsWon: number; awaySetsWon: number }>
  | Readonly<{ valid: false; errors: readonly string[] }>;

export function validateVolleyballMatchScore(match: VolleyballMatchScore): VolleyballScoreValidation {
  const errors: string[] = [];
  const bestOf = match.bestOf ?? 5;
  const setsToWin = Math.ceil(bestOf / 2);
  if (bestOf !== 3 && bestOf !== 5) return { valid: false, errors: ["فرمت مسابقه باید ۳ یا ۵ ستی باشد."] };
  if (!Array.isArray(match.sets) || match.sets.length === 0 || match.sets.length > bestOf) {
    return { valid: false, errors: ["تعداد ست‌ها با فرمت مسابقه سازگار نیست."] };
  }
  let homeSetsWon = 0;
  let awaySetsWon = 0;
  for (const [index, set] of match.sets.entries()) {
    const n = index + 1;
    if (!Number.isSafeInteger(set.home) || !Number.isSafeInteger(set.away) || set.home < 0 || set.away < 0) {
      errors.push(`امتیازهای ست ${n} باید عدد صحیح نامنفی باشند.`);
      continue;
    }
    if (set.home === set.away) {
      errors.push(`ست ${n} نمی‌تواند مساوی تمام شود.`);
      continue;
    }
    const target = n === bestOf ? 15 : 25;
    const high = Math.max(set.home, set.away);
    const low = Math.min(set.home, set.away);
    if (high < target || high - low < 2) {
      errors.push(`ست ${n} باید حداقل به ${target} امتیاز برسد و اختلاف حداقل ۲ باشد.`);
      continue;
    }
    if (set.home > set.away) homeSetsWon++; else awaySetsWon++;
    if ((homeSetsWon === setsToWin || awaySetsWon === setsToWin) && n !== match.sets.length) {
      errors.push("پس از قطعی‌شدن برد مسابقه، ثبت ست اضافه مجاز نیست.");
    }
  }
  if (errors.length) return { valid: false, errors };
  if (homeSetsWon !== setsToWin && awaySetsWon !== setsToWin) {
    return { valid: false, errors: [`مسابقه کامل باید با برد ${setsToWin} ست توسط یکی از تیم‌ها تمام شود.`] };
  }
  return { valid: true, homeSetsWon, awaySetsWon };
}
