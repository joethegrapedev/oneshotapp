import { test } from 'node:test';
import assert from 'node:assert/strict';
import { detectPii } from '../functions/_shared/pii.ts';

// --- emails ----------------------------------------------------------------
test('detects a plain email', () => {
  const r = detectPii('reach me at jane.doe@example.com anytime');
  assert.equal(r.hasPii, true);
  assert.ok(r.kinds.includes('email'));
});

test('detects email with + tag', () => {
  assert.equal(detectPii('john+journal@gmail.com').hasPii, true);
});

// --- SG phone numbers ------------------------------------------------------
test('detects +65 spaced mobile', () => {
  const r = detectPii('call me on +65 9123 4567');
  assert.equal(r.hasPii, true);
  assert.ok(r.kinds.includes('phone'));
});

test('detects bare 8-digit SG mobile', () => {
  assert.equal(detectPii('my number is 91234567').kinds.includes('phone'), true);
});

test('detects dash-separated SG number', () => {
  assert.equal(detectPii('9123-4567').kinds.includes('phone'), true);
});

test('detects SG landline starting with 6', () => {
  assert.equal(detectPii('office 6221 1234').kinds.includes('phone'), true);
});

test('detects a general international number', () => {
  assert.equal(detectPii('+1 415 555 2671').kinds.includes('phone'), true);
});

// --- name + address --------------------------------------------------------
test('detects full name + Blk address', () => {
  const r = detectPii("I'm John Tan, Blk 123 Clementi Ave 3, Singapore 120123");
  assert.equal(r.hasPii, true);
  assert.ok(r.kinds.includes('name+address'));
});

test('detects name + unit number', () => {
  const r = detectPii('Mary Lim lives at #12-34 in that building');
  assert.ok(r.kinds.includes('name+address'));
});

test('detects name + street keyword', () => {
  const r = detectPii('Peter Wong, 5 Orchard Road');
  assert.ok(r.kinds.includes('name+address'));
});

// --- negative cases (no false positives on feelings text) ------------------
test('plain feelings text is NOT flagged', () => {
  const r = detectPii(
    'I feel so tired and lonely today. I wish things were different and that I could rest.',
  );
  assert.equal(r.hasPii, false);
  assert.deepEqual(r.kinds, []);
});

test('single first name mention is NOT flagged', () => {
  const r = detectPii('my friend sarah really listened to me and it helped');
  assert.equal(r.hasPii, false);
});

test('a full name WITHOUT any locator is NOT flagged', () => {
  const r = detectPii('I keep thinking about John Tan and how kind he was');
  assert.equal(r.hasPii, false);
});

test('a year-like 8-digit number is NOT a phone (starts with 2)', () => {
  const r = detectPii('the date code was 20231231 on the receipt');
  assert.equal(r.kinds.includes('phone'), false);
});

test('empty string -> no pii', () => {
  const r = detectPii('');
  assert.equal(r.hasPii, false);
});
