// Firestore Security Rules tests for firebase/firestore.rules.
// The event fixture mirrors lib/data/event_firestore_mapper.dart's
// eventToFirestoreData output, so a rules change that rejects what the app
// actually writes fails here before it is deployed.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc, doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hebrewcalendar',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env?.cleanup());
beforeEach(async () => env.clearFirestore());

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const anon = () => env.unauthenticatedContext().firestore();

function event(overrides = {}) {
  const now = Timestamp.fromDate(new Date('2026-10-10T10:00:00Z'));
  return {
    ownerUid: 'alice',
    calendarId: 'default',
    title: 'יום הולדת',
    description: '',
    location: '',
    hebrewDate: { year: 5787, month: 'tishrei', day: 15 },
    gregorianStart: now,
    gregorianEnd: now,
    allDay: true,
    startTime: null,
    endTime: null,
    reminderMinutesBefore: [60],
    recurrence: { type: 'hebrewYearly', until: null, exceptions: [] },
    isRecurring: true,
    createdAt: now,
    updatedAt: now,
    source: 'app',
    googleSync: { googleEventId: null, etag: null, lastSyncedAt: null, dirty: true },
    googleInstanceSync: {},
    ...overrides,
  };
}

async function seed(path, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));
}

describe('users/{uid}', () => {
  const profile = { displayName: 'Alice', email: 'a@example.com', photoUrl: null, createdAt: serverTimestamp() };

  test('owner can create and read their profile', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice'), profile));
    await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
  });

  test('owner can merge Google sync settings', async () => {
    await seed('users/alice', { ...profile, createdAt: Timestamp.now() });
    await assertSucceeds(updateDoc(doc(alice(), 'users/alice'), {
      googleSyncEnabled: true, googleSyncToken: 'tok', googleLastSyncedAt: Timestamp.now(), googleLastSyncError: null,
    }));
  });

  test('another user cannot read or write it', async () => {
    await seed('users/alice', { ...profile, createdAt: Timestamp.now() });
    await assertFails(getDoc(doc(bob(), 'users/alice')));
    await assertFails(setDoc(doc(bob(), 'users/alice'), profile));
  });

  test('unknown fields are rejected', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), { ...profile, isAdmin: true }));
  });

  test('profile cannot be deleted', async () => {
    await seed('users/alice', { ...profile, createdAt: Timestamp.now() });
    await assertFails(deleteDoc(doc(alice(), 'users/alice')));
  });

  test('pendingGoogleDeletions is owner-only', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/pendingGoogleDeletions/e1'), { googleEventId: 'g1' }));
    await assertFails(getDoc(doc(bob(), 'users/alice/pendingGoogleDeletions/e1')));
  });
});

describe('events/{eventId}', () => {
  test('owner can create, read, update and delete an app-shaped event', async () => {
    const ref = doc(alice(), 'events/e1');
    await assertSucceeds(setDoc(ref, event()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(updateDoc(ref, { title: 'חדש', updatedAt: Timestamp.now() }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('non-recurring timed event with null until is valid', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'events/e2'), event({
      allDay: false, startTime: { hour: 9, minute: 30 }, endTime: { hour: 10, minute: 0 },
      recurrence: { type: 'none', until: null, exceptions: [] }, isRecurring: false,
    })));
  });

  test('another user cannot read, update or delete it', async () => {
    await seed('events/e1', event());
    await assertFails(getDoc(doc(bob(), 'events/e1')));
    await assertFails(updateDoc(doc(bob(), 'events/e1'), { title: 'x' }));
    await assertFails(deleteDoc(doc(bob(), 'events/e1')));
  });

  test('cannot create an event owned by someone else', async () => {
    await assertFails(setDoc(doc(bob(), 'events/e1'), event()));
  });

  test('owner cannot transfer ownership', async () => {
    await seed('events/e1', event());
    await assertFails(updateDoc(doc(alice(), 'events/e1'), { ownerUid: 'bob' }));
  });

  test('field validation', async () => {
    const ref = doc(alice(), 'events/bad');
    await assertFails(setDoc(ref, event({ title: '' })));
    await assertFails(setDoc(ref, event({ title: 'x'.repeat(201) })));
    await assertFails(setDoc(ref, event({ description: 'x'.repeat(2001) })));
    await assertFails(setDoc(ref, event({ hebrewDate: { year: 5787, month: 'tishrei', day: 31 } })));
    await assertFails(setDoc(ref, event({ recurrence: { type: 'yearly', until: null, exceptions: [] } })));
    await assertFails(setDoc(ref, event({ source: 'other' })));
  });

  test('unauthenticated access is denied', async () => {
    await seed('events/e1', event());
    await assertFails(getDoc(doc(anon(), 'events/e1')));
  });
});

test('any other collection is denied', async () => {
  await assertFails(setDoc(doc(alice(), 'other/x'), { a: 1 }));
  await assertFails(getDoc(doc(alice(), 'other/x')));
});
