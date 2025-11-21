import { useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { RealtimePostgresChangesPayload } from '@supabase/supabase-js';

export function useRealtimeSubscription<T extends Record<string, any>>(
  table: string,
  onInsert?: (payload: RealtimePostgresChangesPayload<T>) => void,
  onUpdate?: (payload: RealtimePostgresChangesPayload<T>) => void,
  onDelete?: (payload: RealtimePostgresChangesPayload<T>) => void
) {
  useEffect(() => {
    const channel = supabase
      .channel(`${table}_${Date.now()}_${Math.random()}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table },
        (payload: any) => onInsert?.(payload as RealtimePostgresChangesPayload<T>)
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table },
        (payload: any) => onUpdate?.(payload as RealtimePostgresChangesPayload<T>)
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table },
        (payload: any) => onDelete?.(payload as RealtimePostgresChangesPayload<T>)
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [table, onInsert, onUpdate, onDelete]);
}
