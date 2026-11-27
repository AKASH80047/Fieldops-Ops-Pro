import { applicationDefault, cert, getApps, initializeApp, type App, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';

const appName = 'fieldops-push';
let messaging: Messaging | null | undefined;
let configurationWarningLogged = false;

type FirebaseEnvironment = NodeJS.ProcessEnv;

function warnConfiguration(error?: unknown) {
  if (configurationWarningLogged) return;
  configurationWarningLogged = true;
  const detail = error instanceof Error ? `: ${error.message}` : '';
  console.warn(`[push] Firebase messaging is disabled${detail}`);
}

function serviceAccountFromEnvironment(env: FirebaseEnvironment): ServiceAccount | null {
  if (env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const parsed = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON) as ServiceAccount;
    if (!parsed.projectId || !parsed.clientEmail || !parsed.privateKey) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is missing required fields');
    }
    return parsed;
  }

  const projectId = env.FIREBASE_PROJECT_ID;
  const clientEmail = env.FIREBASE_CLIENT_EMAIL;
  const privateKey = env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  if (!projectId && !clientEmail && !privateKey) return null;
  if (!projectId || !clientEmail || !privateKey) {
    throw new Error('FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY must be set together');
  }
  return { projectId, clientEmail, privateKey };
}

function configuredApp(env: FirebaseEnvironment): App | null {
  if (env.FIREBASE_PUSH_ENABLED === 'false') return null;

  const existing = getApps().find((candidate) => candidate.name === appName);
  if (existing) return existing;

  const serviceAccount = serviceAccountFromEnvironment(env);
  if (serviceAccount) {
    return initializeApp(
      {
        credential: cert(serviceAccount),
        projectId: serviceAccount.projectId,
      },
      appName,
    );
  }

  if (env.FIREBASE_USE_APPLICATION_DEFAULT_CREDENTIALS === 'true') {
    return initializeApp(
      {
        credential: applicationDefault(),
        projectId: env.FIREBASE_PROJECT_ID,
      },
      appName,
    );
  }

  return null;
}

/**
 * Returns a configured Firebase Messaging client, or null when push delivery is
 * intentionally unavailable. Configuration errors are logged once and are
 * never allowed to interrupt an API request or a database transaction.
 */
export function firebaseMessaging(env: FirebaseEnvironment = process.env): Messaging | null {
  if (messaging !== undefined) return messaging;
  try {
    const app = configuredApp(env);
    messaging = app ? getMessaging(app) : null;
    if (!messaging) warnConfiguration();
  } catch (error) {
    messaging = null;
    warnConfiguration(error);
  }
  return messaging;
}

