import * as http2 from 'http2';
import * as crypto from 'crypto';

const APNS_HOST = 'api.push.apple.com';
const TEAM_ID = process.env.APNS_TEAM_ID!;
const KEY_ID = process.env.APNS_KEY_ID!;
const BUNDLE_ID = 'com.sambender.Sweep';
const COLLAPSE_ID = 'sweep-inbox';

let cachedToken: string | null = null;
let tokenExpiry = 0;

function generateJWT(): string {
  const now = Math.floor(Date.now() / 1000);

  if (cachedToken && now < tokenExpiry - 60) {
    return cachedToken;
  }

  const apnsKey = process.env.APNS_KEY;
  if (!apnsKey) throw new Error('APNS_KEY not configured');

  const header = Buffer.from(JSON.stringify({
    alg: 'ES256',
    kid: KEY_ID
  })).toString('base64url');

  const payload = Buffer.from(JSON.stringify({
    iss: TEAM_ID,
    iat: now
  })).toString('base64url');

  const signInput = `${header}.${payload}`;
  const sign = crypto.createSign('SHA256');
  sign.update(signInput);
  const signature = sign.sign(apnsKey, 'base64url');

  cachedToken = `${signInput}.${signature}`;
  tokenExpiry = now + 3600;

  return cachedToken;
}

export interface APNsResult {
  success: boolean;
  error?: string;
}

export function sendNotification(deviceToken: string, title: string, body: string): Promise<APNsResult> {
  return new Promise((resolve, reject) => {
    const jwt = generateJWT();
    const path = `/3/device/${deviceToken}`;

    const payload = JSON.stringify({
      aps: {
        alert: { title, body },
        sound: 'default',
        'mutable-content': 1
      }
    });

    const client = http2.connect(`https://${APNS_HOST}`);

    client.on('error', reject);

    const req = client.request({
      ':method': 'POST',
      ':path': path,
      'authorization': `bearer ${jwt}`,
      'apns-topic': BUNDLE_ID,
      'apns-collapse-id': COLLAPSE_ID,
      'apns-push-type': 'alert',
      'content-type': 'application/json'
    });

    let responseData = '';

    req.on('response', (headers) => {
      const status = headers[':status'];
      if (status === 200) {
        client.close();
        resolve({ success: true });
      }
    });

    req.on('data', (chunk) => {
      responseData += chunk;
    });

    req.on('end', () => {
      client.close();
      if (responseData) {
        try {
          const error = JSON.parse(responseData);
          reject(new Error(error.reason || 'APNs error'));
        } catch {
          reject(new Error(responseData));
        }
      }
    });

    req.write(payload);
    req.end();
  });
}
