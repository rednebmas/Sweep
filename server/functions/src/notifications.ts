import { EmailData } from './firestore';

export interface NotificationContent {
  title: string;
  body: string;
}

export function formatNotification(pendingEmails: EmailData[]): NotificationContent {
  if (pendingEmails.length === 0) {
    return { title: 'Sweep', body: 'No new emails' };
  }

  const sorted = [...pendingEmails].sort(
    (a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
  );

  if (sorted.length <= 3) {
    const lines = sorted.map(e => `• ${e.sender}: ${e.subject}`);
    return {
      title: 'Sweep',
      body: lines.join('\n')
    };
  }

  const senderCounts = new Map<string, number>();
  for (const email of sorted) {
    senderCounts.set(email.sender, (senderCounts.get(email.sender) || 0) + 1);
  }

  const senderOrder: string[] = [];
  for (const email of sorted) {
    if (!senderOrder.includes(email.sender)) {
      senderOrder.push(email.sender);
    }
  }

  const senderParts = senderOrder.map(sender => {
    const count = senderCounts.get(sender)!;
    return count > 1 ? `${sender} (${count})` : sender;
  });

  return {
    title: 'Sweep',
    body: `${sorted.length} new emails • ${senderParts.join(' • ')}`
  };
}
