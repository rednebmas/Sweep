import { KeyManagementServiceClient } from '@google-cloud/kms';

const client = new KeyManagementServiceClient();

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || '';
const LOCATION = 'global';
const KEYRING = 'sweep';
const KEY = 'imap-credentials';

const keyName = client.cryptoKeyPath(PROJECT_ID, LOCATION, KEYRING, KEY);

export async function encrypt(plaintext: string): Promise<string> {
  const [result] = await client.encrypt({
    name: keyName,
    plaintext: Buffer.from(plaintext),
  });
  return Buffer.from(result.ciphertext as Uint8Array).toString('base64');
}

export async function decrypt(ciphertext: string): Promise<string> {
  const [result] = await client.decrypt({
    name: keyName,
    ciphertext: Buffer.from(ciphertext, 'base64'),
  });
  return Buffer.from(result.plaintext as Uint8Array).toString('utf8');
}
