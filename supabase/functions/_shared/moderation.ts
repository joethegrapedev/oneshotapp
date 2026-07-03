// _shared/moderation.ts — PURE decision logic per CONTRACTS §5.
//
// This file has NO imports (no Deno, no URL imports) so Node can import it
// directly for unit tests. Keep it that way.

export type Category =
  | 'sexual' | 'sexual/minors' | 'harassment' | 'harassment/threatening'
  | 'hate' | 'hate/threatening' | 'illicit' | 'illicit/violent'
  | 'self-harm' | 'self-harm/intent' | 'self-harm/instructions'
  | 'violence' | 'violence/graphic';

export interface ModerationResult {
  flagged: boolean;
  categories: Record<string, boolean>;
  category_scores: Record<string, number>;
}

export interface PiiResult {
  hasPii: boolean;
  kinds: string[];
}

export type Decision =
  | 'clean' | 'held_selfharm' | 'held_pii'
  | 'rejected' | 'rejected_objectionable';

export interface DecisionOutput {
  decision: Decision;
  isShareable: boolean;
  reason: string;
}

// ---------------------------------------------------------------------------
// Thresholds — single place to tune. Scores are OpenAI category_scores (0..1).
// ---------------------------------------------------------------------------

/** sexual/minors is a hard reject; very low bar. */
export const SEXUAL_MINORS_THRESHOLD = 0.2;

/** self-harm* routes to crisis; conservative (lower = safer, holds more). */
export const SELF_HARM_THRESHOLD = 0.5;

/** Generic objectionable categories share this score bar. */
export const OBJECTIONABLE_THRESHOLD = 0.5;

/** Categories that (when flagged or over OBJECTIONABLE_THRESHOLD) → rejected_objectionable. */
export const OBJECTIONABLE_CATEGORIES: Category[] = [
  'sexual',
  'violence/graphic',
  'harassment',
  'harassment/threatening',
  'hate',
  'hate/threatening',
  'illicit',
  'illicit/violent',
];

/** All self-harm sub-categories. */
export const SELF_HARM_CATEGORIES: Category[] = [
  'self-harm',
  'self-harm/intent',
  'self-harm/instructions',
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function score(m: ModerationResult, cat: string): number {
  const v = m.category_scores?.[cat];
  return typeof v === 'number' && Number.isFinite(v) ? v : 0;
}

function flagged(m: ModerationResult, cat: string): boolean {
  return m.categories?.[cat] === true;
}

/** A category "trips" if it is flagged OR its score is at/over the threshold. */
function trips(m: ModerationResult, cat: string, threshold: number): boolean {
  return flagged(m, cat) || score(m, cat) >= threshold;
}

// ---------------------------------------------------------------------------
// decide — order of checks matters (first match wins). See CONTRACTS §5.
// Self-harm is checked BEFORE generic objectionable so it always routes to
// crisis, never to a plain reject — even when other categories also trip.
// ---------------------------------------------------------------------------

export function decide(m: ModerationResult, pii: PiiResult): DecisionOutput {
  // 1. sexual/minors → hard reject.
  if (trips(m, 'sexual/minors', SEXUAL_MINORS_THRESHOLD)) {
    return {
      decision: 'rejected',
      isShareable: false,
      reason: 'Content involving minors is not permitted.',
    };
  }

  // 2. self-harm* → held for crisis routing (precedence over objectionable).
  for (const cat of SELF_HARM_CATEGORIES) {
    if (trips(m, cat, SELF_HARM_THRESHOLD)) {
      return {
        decision: 'held_selfharm',
        isShareable: false,
        reason:
          'This entry mentions self-harm. It was not shared. Support resources are available.',
      };
    }
  }

  // 3. generic objectionable → rejected_objectionable.
  for (const cat of OBJECTIONABLE_CATEGORIES) {
    if (trips(m, cat, OBJECTIONABLE_THRESHOLD)) {
      return {
        decision: 'rejected_objectionable',
        isShareable: false,
        reason: 'This entry breaks the community guidelines and was not shared.',
      };
    }
  }

  // 4. PII present → held.
  if (pii?.hasPii) {
    return {
      decision: 'held_pii',
      isShareable: false,
      reason:
        'This entry appears to contain personal information (' +
        (pii.kinds ?? []).join(', ') +
        '). It was not shared.',
    };
  }

  // 5. clean.
  return {
    decision: 'clean',
    isShareable: true,
    reason: 'Cleared for the shared pool.',
  };
}
