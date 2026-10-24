// READ-ONLY. Lists MemoLens accounts whose stored `name` is longer than the
// app's username limit (lib/services/username.dart). It never writes, edits
// or deletes anything, and reads only the `name` field.
//
//   cd tool && npm install firebase-admin
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node find_long_usernames.mjs            # LIMIT=30 by default
//
// Create the key in Firebase console → Project settings → Service accounts
// (keep it out of git).
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const LIMIT = Number(process.env.LIMIT ?? 30);
initializeApp({
  credential: applicationDefault(),
  projectId: 'memories-through-lenses',
});

const snap = await getFirestore().collection('users').select('name').get();
const rows = snap.docs
  .map((d) => ({ uid: d.id, name: d.get('name') }))
  .filter((r) => typeof r.name === 'string' && [...r.name].length > LIMIT)
  .sort((a, b) => [...b.name].length - [...a.name].length);

for (const r of rows) {
  const chars = [...r.name];
  const preview = JSON.stringify(chars.slice(0, 40).join(''));
  console.log(`${r.uid}\t${chars.length} chars\t${preview}${chars.length > 40 ? '…' : ''}`);
}
console.log(`${rows.length} account(s) with names over ${LIMIT} characters`);
