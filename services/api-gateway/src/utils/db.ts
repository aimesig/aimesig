import { neon } from '@neondatabase/serverless';
import { config } from '../config';
import { logger } from './logger';

export const sql = neon(config.databaseUrl);

export async function checkDbConnection(): Promise<void> {
  try {
    await sql`SELECT 1`;
    logger.info('Neon database connected');
  } catch (err) {
    logger.error('Neon database connection failed', { error: (err as Error).message });
    throw err;
  }
}