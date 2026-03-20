import { encrypt } from "octagonal-wheels/encryption/encryption";
import { randomBytes } from "node:crypto";

function randomUriPassphrase() {
  // 192-bit random passphrase for setup URI payload encryption.
  return randomBytes(24).toString("base64url");
}

function randomLivesyncPassphrase() {
  return randomBytes(18).toString("base64url");
}

function required(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

async function main() {
  const couchdbUri = required("SETUP_URI_HOSTNAME");
  const database = required("SETUP_URI_DATABASE");
  const username = required("username");
  const password = required("password");

  const livesyncPassphrase = process.env.SETUP_URI_LIVESYNC_PASSPHRASE || randomLivesyncPassphrase();
  const uriPassphrase = process.env.SETUP_URI_URI_PASSPHRASE || randomUriPassphrase();

  const config = {
    couchDB_URI: couchdbUri,
    couchDB_USER: username,
    couchDB_PASSWORD: password,
    couchDB_DBNAME: database,
    syncOnStart: true,
    gcDelay: 0,
    periodicReplication: true,
    syncOnFileOpen: true,
    encrypt: true,
    passphrase: livesyncPassphrase,
    usePathObfuscation: true,
    batchSave: true,
    batch_size: 50,
    batches_limit: 50,
    useHistory: true,
    disableRequestURI: true,
    customChunkSize: 50,
    syncAfterMerge: false,
    concurrencyOfReadChunksOnline: 100,
    minimumIntervalOfReadChunksOnline: 100,
    handleFilenameCaseSensitive: false,
    doNotUseFixedRevisionForChunks: false,
    settingVersion: 10,
    notifyThresholdOfRemoteStorageSize: 800,
  };

  const encrypted = await encrypt(JSON.stringify(config), uriPassphrase, false);
  const setupUri = `obsidian://setuplivesync?settings=${encodeURIComponent(encrypted)}`;

  console.log("-- Generated Obsidian LiveSync Setup URI -->");
  console.log(`SETUP_URI_HOSTNAME=${couchdbUri}`);
  console.log(`SETUP_URI_DATABASE=${database}`);
  console.log(`SETUP_URI_PASSPHRASE=${uriPassphrase}`);
  console.log(`LIVESYNC_PASSPHRASE=${livesyncPassphrase}`);
  console.log(setupUri);
  console.log("<-- Generated Obsidian LiveSync Setup URI");
}

main().catch((error) => {
  console.error(`ERROR: Failed to generate setup URI: ${error.message}`);
  process.exit(1);
});
