import { setUser, getUsersWithExpiringWatch, getUsersWithExpiringSubscription } from './firestore';
import { setupWatch } from './gmail';
import { refreshMsToken, renewSubscription } from './outlook';
import { sendNotification } from './apns';

const REMINDER_TITLE = 'Reconnect email';
const REMINDER_BODY = 'Open Sweep to re-enable email notifications.';
const REMINDER_OPTIONS = { category: 'SWEEP_REMINDER', collapseId: 'sweep-reminder' };
const EXPIRY_WINDOW_HOURS = 24;

export interface RenewResult {
  renewed: number;
  reminded: number;
  failed: number;
}

async function sendReminderIfExpired(email: string, deviceToken: string | undefined, expiry: Date, apnsSandbox: boolean | undefined, now: number): Promise<boolean> {
  if (expiry.getTime() >= now || !deviceToken) return false;
  try {
    await sendNotification(deviceToken, REMINDER_TITLE, REMINDER_BODY, 0, apnsSandbox, REMINDER_OPTIONS);
    console.log(`Sent renewal reminder to ${email}`);
    return true;
  } catch (pushErr) {
    console.error(`Reminder push failed for ${email}:`, pushErr);
    return false;
  }
}

async function renewGmailWatches(now: number, result: RenewResult): Promise<void> {
  const users = await getUsersWithExpiringWatch(EXPIRY_WINDOW_HOURS);
  for (const user of users) {
    if (!user.refreshToken || !user.watchExpiry) continue;
    try {
      const { historyId, expiration } = await setupWatch(user.refreshToken);
      await setUser(user.email, 'gmail', { historyId, watchExpiry: expiration });
      result.renewed++;
      console.log(`Renewed Gmail watch for ${user.email}, new expiry ${expiration.toISOString()}`);
    } catch (error) {
      result.failed++;
      console.error(`Gmail renewal failed for ${user.email}:`, error);
      if (await sendReminderIfExpired(user.email, user.deviceToken, user.watchExpiry, user.apnsSandbox, now)) {
        result.reminded++;
      }
    }
  }
}

async function renewOutlookSubscriptions(now: number, result: RenewResult): Promise<void> {
  const users = await getUsersWithExpiringSubscription(EXPIRY_WINDOW_HOURS);
  for (const user of users) {
    if (!user.msRefreshToken || !user.subscriptionId || !user.subscriptionExpiry) continue;
    try {
      const { accessToken, refreshToken: newRefresh } = await refreshMsToken(user.msRefreshToken);
      if (newRefresh !== user.msRefreshToken) {
        await setUser(user.email, 'outlook', { msRefreshToken: newRefresh });
      }
      const { expiration } = await renewSubscription(accessToken, user.subscriptionId);
      await setUser(user.email, 'outlook', { subscriptionExpiry: expiration });
      result.renewed++;
      console.log(`Renewed Outlook subscription for ${user.email}, new expiry ${expiration.toISOString()}`);
    } catch (error) {
      result.failed++;
      console.error(`Outlook renewal failed for ${user.email}:`, error);
      if (await sendReminderIfExpired(user.email, user.deviceToken, user.subscriptionExpiry, user.apnsSandbox, now)) {
        result.reminded++;
      }
    }
  }
}

export async function renewAllExpiringWatches(): Promise<RenewResult> {
  const now = Date.now();
  const result: RenewResult = { renewed: 0, reminded: 0, failed: 0 };
  await renewGmailWatches(now, result);
  await renewOutlookSubscriptions(now, result);
  return result;
}
