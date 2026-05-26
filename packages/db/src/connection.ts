import mongoose from 'mongoose';

let isConnected = false;

export async function connectDB(): Promise<void> {
  if (isConnected) return;

  const uri = process.env.MONGODB_URI;
  if (!uri) throw new Error('MONGODB_URI is not defined in environment');

  await mongoose.connect(uri, {
    dbName: 'aimesig',
  });

  isConnected = true;
  console.log('[DB] Connected to MongoDB Atlas');

  mongoose.connection.on('disconnected', () => {
    isConnected = false;
    console.warn('[DB] Disconnected from MongoDB');
  });
}
