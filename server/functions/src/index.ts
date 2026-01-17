import * as functions from '@google-cloud/functions-framework';
import { getUser, setUser, addPendingEmail, clearPendingEmails } from './firestore';
import { setupWatch, getEmailMetadata, getNewMessages } from './gmail';
import { sendNotification } from './apns';
import { formatNotification } from './notifications';

const API_KEY = process.env.SWEEP_API_KEY;

function validateApiKey(req: functions.Request): boolean {
  return req.headers['x-sweep-key'] === API_KEY;
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
  const { emailAddress, historyId } = pushData;

  const user = await getUser(emailAddress);
  if (!user) {
    console.log(`Unknown user: ${emailAddress}`);
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
    const metadata = await getEmailMetadata(user.refreshToken, messageId);
    await addPendingEmail(emailAddress, metadata);
  }

  if (latestHistoryId) {
    await setUser(emailAddress, { historyId: latestHistoryId });
  }

  const pendingEmails = await (await import('./firestore')).getPendingEmails(emailAddress);
  const { title, body } = formatNotification(pendingEmails);

  await sendNotification(user.deviceToken, title, body);
  console.log(`Sent notification to ${emailAddress}: ${pendingEmails.length} emails`);
});

interface RegisterDeviceBody {
  email: string;
  deviceToken: string;
  refreshToken: string;
}

functions.http('registerDevice', async (req: functions.Request, res: functions.Response) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  if (!validateApiKey(req)) {
    res.status(401).send('Unauthorized');
    return;
  }

  const { email, deviceToken, refreshToken } = req.body as RegisterDeviceBody;

  if (!email || !deviceToken || !refreshToken) {
    res.status(400).send('Missing required fields');
    return;
  }

  const watchResult = await setupWatch(refreshToken);

  await setUser(email, {
    deviceToken,
    refreshToken,
    historyId: watchResult.historyId,
    watchExpiry: watchResult.expiration,
    pendingEmails: []
  });

  res.json({
    success: true,
    watchExpiry: watchResult.expiration.toISOString()
  });
});

interface AppOpenedBody {
  email: string;
}

functions.http('appOpened', async (req: functions.Request, res: functions.Response) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  if (!validateApiKey(req)) {
    res.status(401).send('Unauthorized');
    return;
  }

  const { email } = req.body as AppOpenedBody;

  if (!email) {
    res.status(400).send('Missing email');
    return;
  }

  const user = await getUser(email);
  if (!user) {
    res.status(404).send('User not found');
    return;
  }

  await clearPendingEmails(email);

  const hoursUntilExpiry = (user.watchExpiry.getTime() - Date.now()) / (1000 * 60 * 60);

  if (hoursUntilExpiry < 24) {
    const watchResult = await setupWatch(user.refreshToken);
    await setUser(email, {
      historyId: watchResult.historyId,
      watchExpiry: watchResult.expiration
    });

    res.json({
      success: true,
      watchRenewed: true,
      watchExpiry: watchResult.expiration.toISOString()
    });
    return;
  }

  res.json({
    success: true,
    watchRenewed: false,
    watchExpiry: user.watchExpiry.toISOString()
  });
});
