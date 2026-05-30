// src/models/user.model.ts
import { sql } from '../db';

export interface IUser {
  id: string;
  phone: string | null;
  username: string;
  email: string;
  passwordHash: string | null;
  firebaseUid: string | null;
  displayName: string | null;
  avatar: string | null;
  isVerified: boolean;
  authProvider: 'EMAIL' | 'PHONE' | 'GOOGLE';
  role: 'USER' | 'ADMIN';
  tenantId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export const User = {
  findOne: async (where: {
    phone?: string;
    username?: string;
    email?: string;
  }): Promise<IUser | null> => {
    let rows: any[];
    if (where.phone) {
      rows = await sql`SELECT * FROM users WHERE phone = ${where.phone} LIMIT 1`;
    } else if (where.email) {
      rows = await sql`SELECT * FROM users WHERE email = ${where.email} LIMIT 1`;
    } else {
      rows = await sql`SELECT * FROM users WHERE username = ${where.username!} LIMIT 1`;
    }
    return rows[0] ? dbRowToUser(rows[0]) : null;
  },

  findById: async (id: string): Promise<IUser | null> => {
    const rows = await sql`SELECT * FROM users WHERE id = ${id} LIMIT 1`;
    return rows[0] ? dbRowToUser(rows[0]) : null;
  },

  create: async (data: {
    username: string;
    email: string;
    phone?: string | null;
    passwordHash?: string | null;
    firebaseUid?: string | null;
    displayName?: string | null;
    isVerified?: boolean;
    authProvider?: 'EMAIL' | 'PHONE' | 'GOOGLE';
    role?: 'user' | 'admin';
    tenantId?: string | null;
  }): Promise<IUser> => {
    const clean = data.username.toLowerCase().trim();
    const provider = data.authProvider ?? 'EMAIL';
    const rows = await sql`
      INSERT INTO users (
        id, username, email, phone, password_hash, firebase_uid,
        display_name, is_verified, auth_provider, role, tenant_id
      )
      VALUES (
        gen_random_uuid()::text,
        ${clean},
        ${data.email.toLowerCase().trim()},
        ${data.phone ?? null},
        ${data.passwordHash ?? null},
        ${data.firebaseUid ?? null},
        ${data.displayName ?? null},
        ${data.isVerified ?? false},
        ${provider},
        ${data.role === 'admin' ? 'ADMIN' : 'USER'},
        ${data.tenantId ?? null}
      )
      RETURNING *`;
    return dbRowToUser(rows[0]);
  },

  save: async (user: Partial<IUser> & { id: string }): Promise<IUser> => {
    const rows = await sql`
      UPDATE users SET
        phone         = ${user.phone ?? null},
        username      = ${user.username ?? null},
        email         = ${user.email ?? null},
        password_hash = ${user.passwordHash ?? null},
        firebase_uid  = ${user.firebaseUid ?? null},
        display_name  = ${user.displayName ?? null},
        avatar        = ${user.avatar ?? null},
        is_verified   = ${user.isVerified ?? false},
        auth_provider = ${user.authProvider ?? 'EMAIL'},
        role          = ${user.role ?? 'USER'},
        tenant_id     = ${user.tenantId ?? null},
        updated_at    = now()
      WHERE id = ${user.id}
      RETURNING *`;
    return dbRowToUser(rows[0]);
  },
};

function dbRowToUser(row: any): IUser {
  return {
    id: row.id,
    phone: row.phone,
    username: row.username,
    email: row.email,
    passwordHash: row.password_hash,
    firebaseUid: row.firebase_uid,
    displayName: row.display_name,
    avatar: row.avatar,
    isVerified: row.is_verified,
    authProvider: row.auth_provider,
    role: row.role,
    tenantId: row.tenant_id,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
