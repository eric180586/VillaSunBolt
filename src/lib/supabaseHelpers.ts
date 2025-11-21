import { supabase } from './supabase';
import type { Database } from './database.types';

type TableName = keyof Database['public']['Tables'];
type TableRow<T extends TableName> = Database['public']['Tables'][T]['Row'];
type TableInsert<T extends TableName> = Database['public']['Tables'][T]['Insert'];
type TableUpdate<T extends TableName> = Database['public']['Tables'][T]['Update'];

export type SupabaseQueryResult<T> = {
  data: T | null;
  error: Error | null;
};

export type SupabaseQueryArrayResult<T> = {
  data: T[] | null;
  error: Error | null;
};

export async function selectOne<T extends TableName>(
  table: T,
  column: string,
  value: string
): Promise<TableRow<T> | null> {
  const { data, error } = await supabase
    .from(table)
    .select('*')
    .eq(column, value)
    .maybeSingle();

  if (error) throw error;
  return data as TableRow<T> | null;
}

export async function selectMany<T extends TableName>(
  table: T,
  filters?: Record<string, any>
): Promise<TableRow<T>[]> {
  let query = supabase.from(table).select('*');

  if (filters) {
    Object.entries(filters).forEach(([key, value]) => {
      query = query.eq(key, value);
    });
  }

  const { data, error } = await query;

  if (error) throw error;
  return (data as TableRow<T>[]) || [];
}

export async function insertOne<T extends TableName>(
  table: T,
  values: TableInsert<T>
): Promise<TableRow<T>> {
  const { data, error } = await supabase
    .from(table)
    .insert(values)
    .select()
    .single();

  if (error) throw error;
  return data as TableRow<T>;
}

export async function updateOne<T extends TableName>(
  table: T,
  id: string,
  values: TableUpdate<T>
): Promise<TableRow<T>> {
  const { data, error } = await supabase
    .from(table)
    .update(values)
    .eq('id', id)
    .select()
    .single();

  if (error) throw error;
  return data as TableRow<T>;
}

export async function deleteOne<T extends TableName>(
  table: T,
  id: string
): Promise<void> {
  const { error } = await supabase
    .from(table)
    .delete()
    .eq('id', id);

  if (error) throw error;
}

export type CheckInRow = TableRow<'check_ins'>;
export type TaskRow = TableRow<'tasks'>;
export type ProfileRow = TableRow<'profiles'>;
export type NotificationRow = TableRow<'notifications'>;
export type ScheduleRow = TableRow<'weekly_schedules'>;
export type NoteRow = TableRow<'notes'>;
export type DepartureRequestRow = TableRow<'departure_requests'>;
export type ChatMessageRow = TableRow<'chat_messages'>;
export type PointsHistoryRow = TableRow<'points_history'>;
export type DailyPointGoalRow = TableRow<'daily_point_goals'>;
