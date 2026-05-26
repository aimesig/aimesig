// src/models/user.model.ts
import { sql } from '../db';

export interface IUser {
  id: string; phone: string; username: string; email: string;
  firebaseUid: string; displayName: string | null; avatar: string | null;
  isVerified: boolean; role: 'USER' | 'ADMIN'; tenantId: string | null;
  createdAt: Date; updatedAt: Date;
}

function buildEmail(username: string) {
  return `${username.toLowerCase()}@aimesig.com`;
}

export const User = {
  findOne: async (where: { phone?: string; username?: string }): Promise<IUser | null> => {
    const key = where.phone ? 'phone' : 'username';
    const val = where.phone ?? where.username!;
    const rows = key === 'phone'
      ? await sql`SELECT * FROM users WHERE phone = ${val} LIMIT 1`
      : await sql`SELECT * FROM users WHERE username = ${val} LIMIT 1`;
    return rows[0] ? dbRowToUser(rows[0]) : null;
  },

  findById: async (id: string): Promise<IUser | null> => {
    const rows = await sql`SELECT * FROM users WHERE id = ${id} LIMIT 1`;
    return rows[0] ? dbRowToUser(rows[0]) : null;
  },

  create: async (data: {
    phone: string; username: string; firebaseUid: string;
    isVerified?: boolean; role?: 'user' | 'admin'; tenantId?: string | null;
  }): Promise<IUser> => {
    const clean = data.username.toLowerCase().trim();
    const rows = await sql`
      INSERT INTO users (id, phone, username, email, firebase_uid, is_verified, role, tenant_id)
      VALUES (
        gen_random_uuid()::text, ${data.phone}, ${clean}, ${buildEmail(clean)},
        ${data.firebaseUid}, ${data.isVerified ?? false},
        ${data.role === 'admin' ? 'ADMIN' : 'USER'}, ${data.tenantId ?? null}
      )
      RETURNING *`;
    return dbRowToUser(rows[0]);
  },

  save: async (user: IUser): Promise<IUser> => {
    const rows = await sql`
      UPDATE users SET
        phone        = ${user.phone},
        username     = ${user.username},
        email        = ${buildEmail(user.username)},
        firebase_uid = ${user.firebaseUid},
        is_verified  = ${user.isVerified},
        role         = ${user.role},
        tenant_id    = ${user.tenantId ?? null},
        updated_at   = now()
      WHERE id = ${user.id}
      RETURNING *`;
    return dbRowToUser(rows[0]);
  },
};

function dbRowToUser(row: any): IUser {
  return {
    id:          row.id,
    phone:       row.phone,
    username:    row.username,
    email:       row.email,
    firebaseUid: row.firebase_uid,
    displayName: row.display_name,
    avatar:      row.avatar,
    isVerified:  row.is_verified,
    role:        row.role,
    tenantId:    row.tenant_id,
    createdAt:   row.created_at,
    updatedAt:   row.updated_at,
  };
}