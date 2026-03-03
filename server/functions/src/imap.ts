import { ImapFlow } from 'imapflow';
import { EmailData } from './firestore';

interface IMAPConfig {
  host: string;
  port: number;
  email: string;
  password: string;
}

export async function pollNewMessages(config: IMAPConfig, lastUid: number): Promise<{ emails: EmailData[], latestUid: number }> {
  const client = new ImapFlow({
    host: config.host,
    port: config.port,
    secure: config.port === 993,
    auth: {
      user: config.email,
      pass: config.password,
    },
    logger: false,
  });

  try {
    console.log(`[IMAP] Connecting to ${config.host}:${config.port} for ${config.email}`);
    await client.connect();
    const lock = await client.getMailboxLock('INBOX');

    try {
      const emails: EmailData[] = [];
      let latestUid = lastUid;

      // Fetch messages with UID greater than last known
      const searchCriteria = lastUid > 0
        ? { uid: `${lastUid + 1}:*` }
        : { unseen: true };

      for await (const message of client.fetch(searchCriteria, { envelope: true, uid: true })) {
        if (message.uid <= lastUid) continue;

        const envelope = message.envelope;
        if (!envelope) continue;

        const sender = envelope.from?.[0];
        const senderName = sender?.name || sender?.address || 'Unknown';

        emails.push({
          sender: senderName,
          subject: envelope.subject || '(No Subject)',
          timestamp: envelope.date || new Date(),
        });

        if (message.uid > latestUid) {
          latestUid = message.uid;
        }
      }

      console.log(`[IMAP] ${config.email}: found ${emails.length} new messages (lastUid: ${lastUid} → ${latestUid})`);
      return { emails, latestUid };
    } finally {
      lock.release();
    }
  } finally {
    await client.logout();
  }
}
