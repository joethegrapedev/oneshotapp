import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  decide,
  SELF_HARM_THRESHOLD,
  SEXUAL_MINORS_THRESHOLD,
  OBJECTIONABLE_THRESHOLD,
  type ModerationResult,
  type PiiResult,
} from '../functions/_shared/moderation.ts';

// ---------------------------------------------------------------------------
// Fixture builders — construct ModerationResult directly (no OpenAI calls).
// ---------------------------------------------------------------------------
const ALL_CATS = [
  'sexual', 'sexual/minors', 'harassment', 'harassment/threatening',
  'hate', 'hate/threatening', 'illicit', 'illicit/violent',
  'self-harm', 'self-harm/intent', 'self-harm/instructions',
  'violence', 'violence/graphic',
];

function mod(
  scores: Record<string, number> = {},
  flags: Record<string, boolean> = {},
): ModerationResult {
  const category_scores: Record<string, number> = {};
  const categories: Record<string, boolean> = {};
  for (const c of ALL_CATS) {
    category_scores[c] = scores[c] ?? 0;
    categories[c] = flags[c] ?? false;
  }
  const flagged = Object.values(categories).some(Boolean);
  return { flagged, categories, category_scores };
}

const noPii: PiiResult = { hasPii: false, kinds: [] };
const withPii: PiiResult = { hasPii: true, kinds: ['email'] };

// ---------------------------------------------------------------------------
test('clean text -> clean + shareable', () => {
  const r = decide(mod(), noPii);
  assert.equal(r.decision, 'clean');
  assert.equal(r.isShareable, true);
});

test('empty string equivalent (all-zero scores) -> clean', () => {
  const r = decide(mod({}), noPii);
  assert.equal(r.decision, 'clean');
  assert.equal(r.isShareable, true);
});

test('self-harm phrasing (flag) -> held_selfharm, not shareable', () => {
  const r = decide(mod({}, { 'self-harm': true }), noPii);
  assert.equal(r.decision, 'held_selfharm');
  assert.equal(r.isShareable, false);
});

test('self-harm by score at threshold -> held_selfharm', () => {
  const r = decide(mod({ 'self-harm': SELF_HARM_THRESHOLD }), noPii);
  assert.equal(r.decision, 'held_selfharm');
});

test('self-harm/intent and self-harm/instructions each -> held_selfharm', () => {
  assert.equal(decide(mod({ 'self-harm/intent': 0.9 }), noPii).decision, 'held_selfharm');
  assert.equal(decide(mod({ 'self-harm/instructions': 0.9 }), noPii).decision, 'held_selfharm');
});

test('PRECEDENCE: self-harm chosen even when objectionable also present', () => {
  const r = decide(
    mod({ 'self-harm': 0.9, harassment: 0.99, 'violence/graphic': 0.99 },
        { 'self-harm': true, harassment: true }),
    noPii,
  );
  assert.equal(r.decision, 'held_selfharm');
  assert.equal(r.isShareable, false);
});

test('sexual/minors ALWAYS hard-reject, even if self-harm also present', () => {
  const r = decide(
    mod({ 'sexual/minors': 0.9, 'self-harm': 0.9 },
        { 'sexual/minors': true, 'self-harm': true }),
    noPii,
  );
  assert.equal(r.decision, 'rejected');
  assert.equal(r.isShareable, false);
});

test('sexual/minors by score threshold -> rejected', () => {
  const r = decide(mod({ 'sexual/minors': SEXUAL_MINORS_THRESHOLD }), noPii);
  assert.equal(r.decision, 'rejected');
});

test('generic sexual above threshold -> rejected_objectionable', () => {
  const r = decide(mod({ sexual: 0.95 }, { sexual: true }), noPii);
  assert.equal(r.decision, 'rejected_objectionable');
  assert.equal(r.isShareable, false);
});

test('violence/graphic above threshold -> rejected_objectionable', () => {
  assert.equal(decide(mod({ 'violence/graphic': 0.8 }), noPii).decision, 'rejected_objectionable');
});

test('harassment / hate / illicit above threshold -> rejected_objectionable', () => {
  assert.equal(decide(mod({ harassment: 0.7 }), noPii).decision, 'rejected_objectionable');
  assert.equal(decide(mod({ hate: 0.7 }), noPii).decision, 'rejected_objectionable');
  assert.equal(decide(mod({ illicit: 0.7 }), noPii).decision, 'rejected_objectionable');
  assert.equal(decide(mod({ 'illicit/violent': 0.7 }), noPii).decision, 'rejected_objectionable');
  assert.equal(decide(mod({ 'harassment/threatening': 0.7 }), noPii).decision, 'rejected_objectionable');
  assert.equal(decide(mod({ 'hate/threatening': 0.7 }), noPii).decision, 'rejected_objectionable');
});

test('borderline JUST BELOW threshold -> clean', () => {
  const eps = 0.0001;
  const r = decide(
    mod({
      sexual: OBJECTIONABLE_THRESHOLD - eps,
      harassment: OBJECTIONABLE_THRESHOLD - eps,
      'violence/graphic': OBJECTIONABLE_THRESHOLD - eps,
      'self-harm': SELF_HARM_THRESHOLD - eps,
      'sexual/minors': SEXUAL_MINORS_THRESHOLD - eps,
    }),
    noPii,
  );
  assert.equal(r.decision, 'clean');
  assert.equal(r.isShareable, true);
});

test('PII present but otherwise clean -> held_pii, not shareable', () => {
  const r = decide(mod(), withPii);
  assert.equal(r.decision, 'held_pii');
  assert.equal(r.isShareable, false);
});

test('objectionable outranks PII (order: objectionable before pii)', () => {
  const r = decide(mod({ hate: 0.9 }), withPii);
  assert.equal(r.decision, 'rejected_objectionable');
});

test('self-harm outranks PII', () => {
  const r = decide(mod({ 'self-harm': 0.9 }), withPii);
  assert.equal(r.decision, 'held_selfharm');
});
