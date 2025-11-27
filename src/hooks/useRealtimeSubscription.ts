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
    console.log(`📡 [Realtime] Setting up subscription for table: ${table}`);

    const channel = supabase
      .channel(`${table}_${Date.now()}_${Math.random()}`)
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table },
        (payload: any) => {
          console.log(`📡 [Realtime] INSERT event on ${table}:`, payload);
          onInsert?.(payload as RealtimePostgresChangesPayload<T>);
        }
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table },
        (payload: any) => {
          console.log(`📡 [Realtime] UPDATE event on ${table}:`, payload);
          onUpdate?.(payload as RealtimePostgresChangesPayload<T>);
        }
      )
      .on(
        'postgres_changes',
        { event: 'DELETE', schema: 'public', table },
        (payload: any) => {
          console.log(`📡 [Realtime] DELETE event on ${table}:`, payload);
          onDelete?.(payload as RealtimePostgresChangesPayload<T>);
        }
      )
      .subscribe((status) => {
        console.log(`📡 [Realtime] Subscription status for ${table}:`, status);
      });

    return () => {
      console.log(`📡 [Realtime] Cleaning up subscription for ${table}`);
      supabase.removeChannel(channel);
    };
  }, [table, onInsert, onUpdate, onDelete]);
}
