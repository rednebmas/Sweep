import * as functions from '@google-cloud/functions-framework';
import { getUser, setUser, addPendingEmail, clearPendingEmails, getPendingEmails, getUserBySubscriptionId, getIMAPUsers, Provider } from './firestore';
import { setupWatch, getEmailMetadata as getGmailMetadata, getNewMessages, exchangeAuthCode } from './gmail';
import { exchangeMsAuthCode, createMailSubscription, renewSubscription, refreshMsToken, getMessageMetadata as getOutlookMetadata } from './outlook';
import { pollNewMessages } from './imap';
import { encrypt, decrypt } from './kms';
import { sendNotification } from './apns';
import { formatNotification } from './notifications';

const API_KEY = process.env.SWEEP_API_KEY;
const OUTLOOK_CLIENT_STATE = process.env.OUTLOOK_CLIENT_STATE;

function validateRequest(req: functions.Request, res: functions.Response): boolean {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return false;
  }
  if (req.headers['x-sweep-key'] !== API_KEY) {
    res.status(401).send('Unauthorized');
    return false;
  }
  return true;
}

interface PubSubMessage {
  data: string;
  attributes?: Record<string, string>;
}

interface GmailPushData {
  emailAddress: string;
  historyId: string;
}

functions.cloudEvent('onGmailNotification', async (event: functions.CloudEvent<{ message: PubSubMessage }>) => {
  const message = event.data?.message;
  if (!message?.data) {
    console.log('No message data');
    return;
  }

  const decoded = Buffer.from(message.data, 'base64').toString();
  const pushData: GmailPushData = JSON.parse(decoded);
  const { emailAddress } = pushData;

  const user = await getUser(emailAddress, 'gmail');
  if (!user || !user.refreshToken || !user.historyId) {
    console.log(`Unknown Gmail user: ${emailAddress}`);
    return;
  }

  const { messageIds, latestHistoryId } = await getNewMessages(
    user.refreshToken,
    user.historyId
  );

  if (messageIds.length === 0) {
    console.log('No new inbox messages');
    return;
  }

  if (latestHistoryId) {
    await setUser(emailAddress, 'gmail', { historyId: latestHistoryId });
  }

  for (const messageId of messageIds) {
    try {
      const metadata = await getGmailMetadata(user.refreshToken, messageId);
      await addPendingEmail(emailAddress, 'gmail', metadata);
    } catch (error) {
      console.log(`Skipping message ${messageId}: ${error}`);
    }
  }

  const pendingEmails = await getPendingEmails(emailAddress, 'gmail');
  const { title, body } = formatNotification(pendingEmails);

  await sendNotification(user.deviceToken, title, body, pendingEmails.length, user.apnsSandbox);
  console.log(`Sent Gmail notification to ${emailAddress}: ${pendingEmails.length} emails`);
});

interface OutlookNotification {
  subscriptionId: string;
  clientState: string;
  changeType: string;
  resource: string;
  resourceData?: {
    id: string;
    '@odata.type': string;
    '@odata.id': string;
    '@odata.etag': string;
  };
}

interface OutlookWebhookBody {
  value: OutlookNotification[];
}

functions.http('onOutlookNotification', async (req: functions.Request, res: functions.Response) => {
  if (req.query.validationToken) {
    res.set('Content-Type', 'text/plain');
    res.status(200).send(req.query.validationToken);
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const body = req.body as OutlookWebhookBody;
  const notifications = body.value || [];

  for (const notification of notifications) {
    if (notification.clientState !== OUTLOOK_CLIENT_STATE) {
      console.log('Invalid client state, skipping notification');
      continue;
    }

    const result = await getUserBySubscriptionId(notification.subscriptionId);
    if (!result) {
      console.log(`Unknown subscription: ${notification.subscriptionId}`);
      continue;
    }

    const { email, userData: user } = result;

    if (!user.msRefreshToken) {
      console.log(`No refresh token for Outlook user: ${email}`);
      continue;
    }

    try {
      const { accessToken, refreshToken: newRefreshToken } = await refreshMsToken(user.msRefreshToken);

      if (newRefreshToken !== user.msRefreshToken) {
        await setUser(email, 'outlook', { msRefreshToken: newRefreshToken });
      }

      if (notification.resourceData?.id) {
        const metadata = await getOutlookMetadata(accessToken, notification.resourceData.id);
        await addPendingEmail(email, 'outlook', metadata);
      }

      const pendingEmails = await getPendingEmails(email, 'outlook');
      const { title, body } = formatNotification(pendingEmails);

      await sendNotification(user.deviceToken, title, body, pendingEmails.length, user.apnsSandbox);
      console.log(`Sent Outlook notification to ${email}: ${pendingEmails.length} emails`);
    } catch (error) {
      console.error(`Error processing Outlook notification for ${email}:`, error);
    }
  }

  res.status(202).send();
});

interface RegisterDeviceBody {
  email: string;
  deviceToken: string;
  authCode?: string;
  provider: Provider;
  apnsSandbox?: string;
  // IMAP-specific
  password?: string;
  host?: string;
  port?: string;
}

functions.http('registerDevice', async (req: functions.Request, res: functions.Response) => {
  if (!validateRequest(req, res)) return;

  const { email, deviceToken, provider, apnsSandbox: sandboxStr } = req.body as RegisterDeviceBody;
  const apnsSandbox = sandboxStr === 'true';

  if (!email || !deviceToken || !provider) {
    res.status(400).send('Missing required fields');
    return;
  }

  try {
    if (provider === 'gmail') {
      const { authCode } = req.body as RegisterDeviceBody;
      if (!authCode) { res.status(400).send('Missing authCode'); return; }

      const refreshToken = await exchangeAuthCode(authCode);
      const watchResult = await setupWatch(refreshToken);

      await setUser(email, 'gmail', {
        deviceToken,
        apnsSandbox,
        refreshToken,
        historyId: watchResult.historyId,
        watchExpiry: watchResult.expiration,
        pendingEmails: []
      });

      res.json({
        success: true,
        provider: 'gmail',
        watchExpiry: watchResult.expiration.toISOString()
      });
    } else if (provider === 'outlook') {
      const { authCode } = req.body as RegisterDeviceBody;
      if (!authCode) { res.status(400).send('Missing authCode'); return; }

      const { accessToken, refreshToken } = await exchangeMsAuthCode(authCode);
      const subscription = await createMailSubscription(accessToken);

      await setUser(email, 'outlook', {
        deviceToken,
        apnsSandbox,
        msRefreshToken: refreshToken,
        subscriptionId: subscription.subscriptionId,
        subscriptionExpiry: subscription.expiration,
        pendingEmails: []
      });

      res.json({
        success: true,
        provider: 'outlook',
        subscriptionExpiry: subscription.expiration.toISOString()
      });
    } else if (provider === 'imap') {
      const { password, host, port } = req.body as RegisterDeviceBody;
      if (!password || !host) { res.status(400).send('Missing IMAP credentials'); return; }

      const encryptedPassword = await encrypt(password);

      await setUser(email, 'imap', {
        deviceToken,
        apnsSandbox,
        imapPasswordEncrypted: encryptedPassword,
        imapHost: host,
        imapPort: parseInt(port || '993', 10),
        lastPollUid: 0,
        pendingEmails: []
      });

      res.json({ success: true, provider: 'imap' });
    } else {
      res.status(400).send('Invalid provider');
    }
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).send('Registration failed');
  }
});

interface AppOpenedBody {
  email: string;
  provider: Provider;
}

functions.http('appOpened', async (req: functions.Request, res: functions.Response) => {
  if (!validateRequest(req, res)) return;

  const { email, provider } = req.body as AppOpenedBody;

  if (!email || !provider) {
    res.status(400).send('Missing email or provider');
    return;
  }

  const user = await getUser(email, provider);
  if (!user) {
    res.status(404).send('User not found');
    return;
  }

  await clearPendingEmails(email, provider);

  try {
    if (provider === 'gmail' && user.watchExpiry && user.refreshToken) {
      const hoursUntilExpiry = (user.watchExpiry.getTime() - Date.now()) / (1000 * 60 * 60);

      if (hoursUntilExpiry < 24) {
        const watchResult = await setupWatch(user.refreshToken);
        await setUser(email, 'gmail', {
          historyId: watchResult.historyId,
          watchExpiry: watchResult.expiration
        });

        res.json({
          success: true,
          renewed: true,
          expiry: watchResult.expiration.toISOString()
        });
        return;
      }

      res.json({
        success: true,
        renewed: false,
        expiry: user.watchExpiry.toISOString()
      });
    } else if (provider === 'outlook' && user.subscriptionExpiry && user.msRefreshToken && user.subscriptionId) {
      const hoursUntilExpiry = (user.subscriptionExpiry.getTime() - Date.now()) / (1000 * 60 * 60);

      if (hoursUntilExpiry < 24) {
        const { accessToken, refreshToken: newRefreshToken } = await refreshMsToken(user.msRefreshToken);

        if (newRefreshToken !== user.msRefreshToken) {
          await setUser(email, 'outlook', { msRefreshToken: newRefreshToken });
        }

        const subscription = await renewSubscription(accessToken, user.subscriptionId);
        await setUser(email, 'outlook', {
          subscriptionExpiry: subscription.expiration
        });

        res.json({
          success: true,
          renewed: true,
          expiry: subscription.expiration.toISOString()
        });
        return;
      }

      res.json({
        success: true,
        renewed: false,
        expiry: user.subscriptionExpiry.toISOString()
      });
    } else {
      res.json({ success: true });
    }
  } catch (error) {
    console.error('App opened error:', error);
    res.json({ success: true, error: 'Renewal failed' });
  }
});

functions.http('pollIMAPAccounts', async (req: functions.Request, res: functions.Response) => {
  if (!validateRequest(req, res)) return;

  const imapUsers = await getIMAPUsers();
  let polled = 0;
  let notified = 0;

  for (const user of imapUsers) {
    if (!user.imapPasswordEncrypted || !user.imapHost) continue;

    try {
      const password = await decrypt(user.imapPasswordEncrypted);
      const { emails, latestUid } = await pollNewMessages(
        { host: user.imapHost, port: user.imapPort || 993, email: user.email, password },
        user.lastPollUid || 0
      );

      polled++;

      if (latestUid > (user.lastPollUid || 0)) {
        await setUser(user.email, 'imap', { lastPollUid: latestUid });
      }

      if (emails.length === 0) continue;

      for (const emailData of emails) {
        await addPendingEmail(user.email, 'imap', emailData);
      }

      const pendingEmails = await getPendingEmails(user.email, 'imap');
      const { title, body } = formatNotification(pendingEmails);
      await sendNotification(user.deviceToken, title, body, pendingEmails.length, user.apnsSandbox);
      notified++;

      console.log(`IMAP poll for ${user.email}: ${emails.length} new, ${pendingEmails.length} pending`);
    } catch (error) {
      console.error(`IMAP poll error for ${user.email}:`, error);
    }
  }

  res.json({ success: true, polled, notified });
});
