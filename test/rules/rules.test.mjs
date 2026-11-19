// ЕТАП 2 E1 — Firestore Rules v2 unit tests.
// Run from this folder:  npm install  &&  npm test
// (needs Java for the Firestore emulator; firebase.json is one level up).
import { readFileSync } from 'node:fs';
import { test, before, after } from 'node:test';
import assert from 'node:assert';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'navici-1969',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});
after(async () => { await env.cleanup(); });

// Alice signed-in (non-anonymous), Bob anonymous, Mallory a different uid.
const alice = () => env.authenticatedContext('alice').firestore();
const anon = () => env.authenticatedContext('bob', { firebase: { sign_in_provider: 'anonymous' } }).firestore();
const mallory = () => env.authenticatedContext('mallory').firestore();

test('old blob write to own users/{uid} is allowed (backward compatible)', async () => {
  await assertSucceeds(setDoc(doc(alice(), 'users/alice'), { progress: '{}' }));
});

test('new months/habits/meta under own uid are allowed', async () => {
  const db = alice();
  await assertSucceeds(setDoc(doc(db, 'users/alice/months/2026-11'), { '18': { a: 2 } }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/habits/a'), { name: 'Вода' }));
  await assertSucceeds(setDoc(doc(db, 'users/alice/meta/schema'), { version: 2 }));
});

test('an anonymous user may read/write ONLY its own subtree', async () => {
  const db = anon();
  await assertSucceeds(setDoc(doc(db, 'users/bob/months/2026-11'), { '18': { a: 1 } }));
  await assertSucceeds(getDoc(doc(db, 'users/bob/meta/schema')));
});

test('a foreign uid is denied (blob, subcollections, read)', async () => {
  const db = mallory();
  await assertFails(setDoc(doc(db, 'users/alice'), { progress: 'x' }));
  await assertFails(setDoc(doc(db, 'users/alice/months/2026-11'), { '18': { a: 9 } }));
  await assertFails(getDoc(doc(db, 'users/alice/habits/a')));
});

test('unauthenticated access is denied', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'users/alice/months/2026-11')));
});
