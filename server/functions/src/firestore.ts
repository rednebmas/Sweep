import { Firestore } from '@google-cloud/firestore';

const db = new Firestore();
const usersCollection = db.collection('users');

export interface EmailData {
  sender: string;
  subject: string;
  timestamp: Date;
}

export interface UserData {
  deviceToken: string;
  refreshToken: string;
  watchExpiry: Date;
  historyId: string;
  pendingEmails: EmailData[];
}

export async function getUser(email: string): Promise<UserData | null> {
  const doc = await usersCollection.doc(email).get();
  return doc.exists ? (doc.data() as UserData) : null;
}

export async function setUser(email: string, data: Partial<UserData>): Promise<void> {
  await usersCollection.doc(email).set(data, { merge: true });
}

export async function addPendingEmail(email: string, emailData: EmailData): Promise<EmailData[]> {
  const userRef = usersCollection.doc(email);
  let updatedPending: EmailData[] = [];

  await db.runTransaction(async (tx) => {
    const doc = await tx.get(userRef);
    const pending = doc.exists ? (doc.data()?.pendingEmails || []) : [];
    pending.push(emailData);
    updatedPending = pending;
    tx.set(userRef, { pendingEmails: pending }, { merge: true });
  });

  return updatedPending;
}

export async function clearPendingEmails(email: string): Promise<void> {
  await usersCollection.doc(email).set({ pendingEmails: [] }, { merge: true });
}

export async function getPendingEmails(email: string): Promise<EmailData[]> {
  const user = await getUser(email);
  return user?.pendingEmails || [];
}

export async function getUsersWithExpiringWatch(hoursUntilExpiry: number): Promise<Array<{ email: string } & UserData>> {
  const cutoff = new Date(Date.now() + hoursUntilExpiry * 60 * 60 * 1000);
  const snapshot = await usersCollection
    .where('watchExpiry', '<', cutoff)
    .get();
  return snapshot.docs.map(doc => ({ email: doc.id, ...doc.data() as UserData }));
}
