const AZURE_CLIENT_ID = process.env.AZURE_CLIENT_ID!;
const AZURE_CLIENT_SECRET = process.env.AZURE_CLIENT_SECRET!;
const AZURE_REDIRECT_URI = process.env.AZURE_REDIRECT_URI || 'msauth.com.sam.sweep://auth';
const OUTLOOK_WEBHOOK_URL = process.env.OUTLOOK_WEBHOOK_URL!;
const OUTLOOK_CLIENT_STATE = process.env.OUTLOOK_CLIENT_STATE!;

const GRAPH_BASE_URL = 'https://graph.microsoft.com/v1.0';
const TOKEN_URL = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';

interface TokenResponse {
  access_token: string;
  refresh_token?: string;
}

interface SubscriptionResponse {
  id: string;
  expirationDateTime: string;
}

interface MessageResponse {
  from?: { emailAddress?: { name?: string; address?: string } };
  subject?: string;
  receivedDateTime: string;
}

export interface TokenResult {
  accessToken: string;
  refreshToken: string;
}

export async function exchangeMsAuthCode(authCode: string): Promise<TokenResult> {
  const params = new URLSearchParams({
    client_id: AZURE_CLIENT_ID,
    client_secret: AZURE_CLIENT_SECRET,
    code: authCode,
    redirect_uri: AZURE_REDIRECT_URI,
    grant_type: 'authorization_code',
    scope: 'Mail.Read Mail.ReadWrite User.Read offline_access'
  });

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString()
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Token exchange failed: ${error}`);
  }

  const data = await response.json() as TokenResponse;
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token || ''
  };
}

export async function refreshMsToken(refreshToken: string): Promise<TokenResult> {
  const params = new URLSearchParams({
    client_id: AZURE_CLIENT_ID,
    client_secret: AZURE_CLIENT_SECRET,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
    scope: 'Mail.Read Mail.ReadWrite User.Read offline_access'
  });

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString()
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Token refresh failed: ${error}`);
  }

  const data = await response.json() as TokenResponse;
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token || refreshToken
  };
}

export interface SubscriptionResult {
  subscriptionId: string;
  expiration: Date;
}

export async function createMailSubscription(accessToken: string): Promise<SubscriptionResult> {
  const expiration = new Date();
  expiration.setMinutes(expiration.getMinutes() + 4200);

  const response = await fetch(`${GRAPH_BASE_URL}/subscriptions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      changeType: 'created',
      notificationUrl: OUTLOOK_WEBHOOK_URL,
      resource: "me/mailFolders('inbox')/messages",
      expirationDateTime: expiration.toISOString(),
      clientState: OUTLOOK_CLIENT_STATE
    })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Subscription creation failed: ${error}`);
  }

  const data = await response.json() as SubscriptionResponse;
  return {
    subscriptionId: data.id,
    expiration: new Date(data.expirationDateTime)
  };
}

export async function renewSubscription(accessToken: string, subscriptionId: string): Promise<SubscriptionResult> {
  const expiration = new Date();
  expiration.setMinutes(expiration.getMinutes() + 4200);

  const response = await fetch(`${GRAPH_BASE_URL}/subscriptions/${subscriptionId}`, {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      expirationDateTime: expiration.toISOString()
    })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Subscription renewal failed: ${error}`);
  }

  const data = await response.json() as SubscriptionResponse;
  return {
    subscriptionId: data.id,
    expiration: new Date(data.expirationDateTime)
  };
}

export interface EmailMetadata {
  sender: string;
  subject: string;
  timestamp: Date;
}

export async function getMessageMetadata(accessToken: string, messageId: string): Promise<EmailMetadata> {
  const response = await fetch(
    `${GRAPH_BASE_URL}/me/messages/${messageId}?$select=from,subject,receivedDateTime`,
    { headers: { 'Authorization': `Bearer ${accessToken}` } }
  );

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Message fetch failed: ${error}`);
  }

  const data = await response.json() as MessageResponse;
  return {
    sender: data.from?.emailAddress?.name || data.from?.emailAddress?.address || 'Unknown',
    subject: data.subject || '(No subject)',
    timestamp: new Date(data.receivedDateTime)
  };
}
