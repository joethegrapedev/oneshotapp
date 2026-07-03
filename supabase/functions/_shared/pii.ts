// _shared/pii.ts — PURE PII detection. NO imports (Node imports it for tests).
//
// Goal: catch obvious direct identifiers (email, phone) and a lightweight
// "full name + locator" heuristic, while keeping false positives on ordinary
// feelings-journaling text low. This is a safety net feeding decide()'s
// held_pii branch, not a compliance-grade scrubber.

export interface PiiResult {
  hasPii: boolean;
  kinds: string[];
}

// ---------------------------------------------------------------------------
// Email — standard local@domain.tld shape.
// ---------------------------------------------------------------------------
const EMAIL_RE = /[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}/i;

// ---------------------------------------------------------------------------
// Phone
//  - SG local: optional +65/65 prefix, then 8 digits starting 3/6/8/9
//    (SG landline 3/6, mobile 8/9), optional space/dash splitting 4+4.
//    e.g. "+65 9123 4567", "91234567", "9123-4567".
//  - International: a leading "+" and 8–15 total digits with separators.
// ---------------------------------------------------------------------------
const SG_PHONE_RE = /(?:\+?65[\s-]?)?(?<!\d)[3689]\d{3}[\s-]?\d{4}(?!\d)/;
const INTL_PHONE_RE = /\+\d(?:[\s-]?\d){7,14}(?!\d)/;

// ---------------------------------------------------------------------------
// Name + locator heuristic
//  A "full name" is two adjacent Capitalized words ("John Tan"). Alone this is
//  too weak (sentence starts, proper nouns), so we ONLY flag it when a nearby
//  locator signal is also present:
//    - a unit number  (#12-34)
//    - "Blk <n>" / "Block <n>"
//    - "Singapore <6-digit postal>"
//    - "<n> <Name> Street/Road/Ave/..." style address lines
//    - an explicit street/road/avenue/postal-code keyword
//  Requiring BOTH keeps ordinary emotional text ("I feel sad and lonely",
//  "my friend Sarah listened") from tripping, while catching self-doxxing like
//  "I'm John Tan, Blk 123 Clementi Ave 3, Singapore 120123".
// ---------------------------------------------------------------------------
const FULL_NAME_RE = /\b[A-Z][a-z]+\s+[A-Z][a-z]+\b/;
const LOCATOR_RES: RegExp[] = [
  /#\d{1,3}-\d{1,4}\b/,                                     // unit e.g. #12-34
  /\bblk\.?\s*\d+/i,                                        // Blk 123
  /\bblock\s+\d+/i,                                         // Block 123
  /\bsingapore\s+\d{6}\b/i,                                 // Singapore 120123
  /\b\d{1,4}\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\s+(?:street|st|road|rd|avenue|ave|lane|ln|drive|dr|crescent|cres|close|walk|way|boulevard|blvd)\b/i,
  /\b(?:street|road|avenue|postal\s*code|zip\s*code)\b/i,
];

function hasNameLocator(text: string): boolean {
  if (!FULL_NAME_RE.test(text)) return false;
  return LOCATOR_RES.some((re) => re.test(text));
}

// ---------------------------------------------------------------------------
export function detectPii(text: string): PiiResult {
  const kinds: string[] = [];
  const t = text ?? '';

  if (EMAIL_RE.test(t)) kinds.push('email');
  if (SG_PHONE_RE.test(t) || INTL_PHONE_RE.test(t)) kinds.push('phone');
  if (hasNameLocator(t)) kinds.push('name+address');

  return { hasPii: kinds.length > 0, kinds };
}
