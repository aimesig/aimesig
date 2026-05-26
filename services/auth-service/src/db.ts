// src/db.ts
// Uses @neondatabase/serverless HTTP transport directly.
// No Prisma adapter, no WebSocket, no port 5432. Pure HTTPS fetch.

import { neon, neonConfig } from '@neondatabase/serverless';

neonConfig.fetchConnectionCache = true;

export const sql = neon(process.env.DATABASE_URL!);

export async function connectDB(): Promise<void> {
  await sql`SELECT 1`;
  console.log('[db] Connected to Neon (HTTP transport)');
}

export async function disconnectDB(): Promise<void> {
  // HTTP transport is stateless — nothing to close
}