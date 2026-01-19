import { Firestore, Timestamp } from '@google-cloud/firestore';

const db = new Firestore();
const usersCollection = db.collection('users');

export function userKey(email: string, provider: Provider): string {
  return `${email}_${provider}`;
}

export interface EmailData {
  sender: string;
  subject: string;
  timestamp: Date;
}

export type Provider = 'gmail' | 'outlook';

export interface UserData {
  deviceToken: string;
  provider: Provider;
  pendingEmails: EmailData[];
  // Gmail-specific
  refreshToken?: string;
  historyId?: string;
  watchExpiry?: Date;
  // Outlook-specific
  msRefreshToken?: string;
  subscriptionId?: string;
  subscriptionExpiry?: Date;
}

function toDate(value: Date | Timestamp): Date {
  return value instanceof Timestamp ? value.toDate() : value;
}

export async function getUser(email: string, provider: Provider): Promise<UserData | null> {
  const doc = await usersCollection.doc(userKey(email, provider)).get();
  if (!doc.exists) return null;
  const data = doc.data()!;
  return {
    ...data,
    watchExpiry: data.watchExpiry ? toDate(data.watchExpiry) : undefined,
    subscriptionExpiry: data.subscriptionExpiry ? toDate(data.subscriptionExpiry) : undefined,
    pendingEmails: (data.pendingEmails || []).map((e: EmailData & { timestamp: Date | Timestamp }) => ({
      ...e,
      timestamp: toDate(e.timestamp)
    }))
  } as UserData;
}

export async function getUserByKey(key: string): Promise<UserData | null> {
  const doc = await usersCollection.doc(key).get();
  if (!doc.exists) return null;
  const data = doc.data()!;
  return {
    ...data,
    watchExpiry: data.watchExpiry ? toDate(data.watchExpiry) : undefined,
    subscriptionExpiry: data.subscriptionExpiry ? toDate(data.subscriptionExpiry) : undefined,
    pendingEmails: (data.pendingEmails || []).map((e: EmailData & { timestamp: Date | Timestamp }) => ({
      ...e,
      timestamp: toDate(e.timestamp)
    }))
  } as UserData;
}

export async function setUser(email: string, provider: Provider, data: Partial<UserData>): Promise<void> {
  await usersCollection.doc(userKey(email, provider)).set({ ...data, provider }, { merge: true });
}

export async function addPendingEmail(email: string, provider: Provider, emailData: EmailData): Promise<EmailData[]> {
  const userRef = usersCollection.doc(userKey(email, provider));
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

export async function clearPendingEmails(email: string, provider: Provider): Promise<void> {
  await usersCollection.doc(userKey(email, provider)).set({ pendingEmails: [] }, { merge: true });
}

export async function getPendingEmails(email: string, provider: Provider): Promise<EmailData[]> {
  const user = await getUser(email, provider);
  return user?.pendingEmails || [];
}

export async function getUsersWithExpiringWatch(hoursUntilExpiry: number): Promise<Array<{ email: string } & UserData>> {
  const cutoff = new Date(Date.now() + hoursUntilExpiry * 60 * 60 * 1000);
  const snapshot = await usersCollection
    .where('provider', '==', 'gmail')
    .where('watchExpiry', '<', cutoff)
    .get();
  return snapshot.docs.map(doc => {
    const key = doc.id;
    const email = key.replace(/_gmail$/, '');
    return { email, ...doc.data() as UserData };
  });
}

export async function getUserBySubscriptionId(subscriptionId: string): Promise<{ email: string, userData: UserData } | null> {
  const snapshot = await usersCollection
    .where('subscriptionId', '==', subscriptionId)
    .limit(1)
    .get();

  if (snapshot.empty) return null;

  const doc = snapshot.docs[0];
  const key = doc.id;
  const email = key.replace(/_outlook$/, '');
  return { email, userData: doc.data() as UserData };
}

export async function getUsersWithExpiringSubscription(hoursUntilExpiry: number): Promise<Array<{ email: string } & UserData>> {
  const cutoff = new Date(Date.now() + hoursUntilExpiry * 60 * 60 * 1000);
  const snapshot = await usersCollection
    .where('provider', '==', 'outlook')
    .where('subscriptionExpiry', '<', cutoff)
    .get();
  return snapshot.docs.map(doc => {
    const key = doc.id;
    const email = key.replace(/_outlook$/, '');
    return { email, ...doc.data() as UserData };
  });
}
