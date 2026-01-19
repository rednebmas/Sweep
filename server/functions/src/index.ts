import * as functions from '@google-cloud/functions-framework';
import { getUser, setUser, addPendingEmail, clearPendingEmails, getPendingEmails, getUserBySubscriptionId, Provider } from './firestore';
import { setupWatch, getEmailMetadata as getGmailMetadata, getNewMessages, exchangeAuthCode } from './gmail';
import { exchangeMsAuthCode, createMailSubscription, renewSubscription, refreshMsToken, getMessageMetadata as getOutlookMetadata } from './outlook';
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

  for (const messageId of messageIds) {
    const metadata = await getGmailMetadata(user.refreshToken, messageId);
    await addPendingEmail(emailAddress, 'gmail', metadata);
  }

  if (latestHistoryId) {
    await setUser(emailAddress, 'gmail', { historyId: latestHistoryId });
  }

  const pendingEmails = await getPendingEmails(emailAddress, 'gmail');
  const { title, body } = formatNotification(pendingEmails);

  await sendNotification(user.deviceToken, title, body);
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

      await sendNotification(user.deviceToken, title, body);
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
  authCode: string;
  provider: Provider;
}

functions.http('registerDevice', async (req: functions.Request, res: functions.Response) => {
  if (!validateRequest(req, res)) return;

  const { email, deviceToken, authCode, provider } = req.body as RegisterDeviceBody;

  if (!email || !deviceToken || !authCode || !provider) {
    res.status(400).send('Missing required fields');
    return;
  }

  try {
    if (provider === 'gmail') {
      const refreshToken = await exchangeAuthCode(authCode);
      const watchResult = await setupWatch(refreshToken);

      await setUser(email, 'gmail', {
        deviceToken,
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
      const { accessToken, refreshToken } = await exchangeMsAuthCode(authCode);
      const subscription = await createMailSubscription(accessToken);

      await setUser(email, 'outlook', {
        deviceToken,
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
