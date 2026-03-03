import { KeyManagementServiceClient } from '@google-cloud/kms';

let _client: KeyManagementServiceClient | null = null;

function getClient(): KeyManagementServiceClient {
  if (!_client) _client = new KeyManagementServiceClient();
  return _client;
}

function getKeyName(): string {
  const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || '';
  return getClient().cryptoKeyPath(projectId, 'global', 'sweep', 'imap-credentials');
}

export async function encrypt(plaintext: string): Promise<string> {
  const [result] = await getClient().encrypt({
    name: getKeyName(),
    plaintext: Buffer.from(plaintext),
  });
  return Buffer.from(result.ciphertext as Uint8Array).toString('base64');
}

export async function decrypt(ciphertext: string): Promise<string> {
  const [result] = await getClient().decrypt({
    name: getKeyName(),
    ciphertext: Buffer.from(ciphertext, 'base64'),
  });
  return Buffer.from(result.plaintext as Uint8Array).toString('utf8');
}
