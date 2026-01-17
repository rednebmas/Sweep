import { google } from 'googleapis';

const PROJECT_ID = process.env.SWEEP_PROJECT_ID || 'sweep-push';
const TOPIC_NAME = `projects/${PROJECT_ID}/topics/gmail-notifications`;

function createOAuthClient(refreshToken: string) {
  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET
  );
  oauth2Client.setCredentials({ refresh_token: refreshToken });
  return oauth2Client;
}

export interface WatchResult {
  historyId: string;
  expiration: Date;
}

export async function setupWatch(refreshToken: string): Promise<WatchResult> {
  const auth = createOAuthClient(refreshToken);
  const gmail = google.gmail({ version: 'v1', auth });

  const response = await gmail.users.watch({
    userId: 'me',
    requestBody: {
      topicName: TOPIC_NAME,
      labelIds: ['INBOX']
    }
  });

  return {
    historyId: response.data.historyId!,
    expiration: new Date(parseInt(response.data.expiration!))
  };
}

export interface EmailMetadata {
  sender: string;
  subject: string;
  timestamp: Date;
}

export async function getEmailMetadata(refreshToken: string, messageId: string): Promise<EmailMetadata> {
  const auth = createOAuthClient(refreshToken);
  const gmail = google.gmail({ version: 'v1', auth });

  const response = await gmail.users.messages.get({
    userId: 'me',
    id: messageId,
    format: 'metadata',
    metadataHeaders: ['From', 'Subject']
  });

  const headers = response.data.payload?.headers || [];
  const fromHeader = headers.find(h => h.name === 'From')?.value || '';
  const subject = headers.find(h => h.name === 'Subject')?.value || '(No subject)';

  const senderMatch = fromHeader.match(/^([^<]+)/);
  const sender = senderMatch ? senderMatch[1].trim().replace(/"/g, '') : fromHeader;

  return {
    sender,
    subject,
    timestamp: new Date(parseInt(response.data.internalDate!))
  };
}

export interface HistoryResult {
  messageIds: string[];
  latestHistoryId: string | null;
  needsFullSync?: boolean;
}

export async function getNewMessages(refreshToken: string, startHistoryId: string): Promise<HistoryResult> {
  const auth = createOAuthClient(refreshToken);
  const gmail = google.gmail({ version: 'v1', auth });

  try {
    const response = await gmail.users.history.list({
      userId: 'me',
      startHistoryId,
      historyTypes: ['messageAdded'],
      labelId: 'INBOX'
    });

    const history = response.data.history || [];
    const messageIds = new Set<string>();

    for (const item of history) {
      for (const msg of (item.messagesAdded || [])) {
        if (msg.message?.labelIds?.includes('INBOX')) {
          messageIds.add(msg.message.id!);
        }
      }
    }

    return {
      messageIds: Array.from(messageIds),
      latestHistoryId: response.data.historyId || null
    };
  } catch (error: unknown) {
    if ((error as { code?: number }).code === 404) {
      return { messageIds: [], latestHistoryId: null, needsFullSync: true };
    }
    throw error;
  }
}
