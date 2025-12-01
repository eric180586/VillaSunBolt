// hooks/useRealtimeSubscription.ts
import { useEffect, useState } from 'react';
import { supabase, RealtimeWatchdog, ChannelStatus } from '../lib/supabase';

export function useRealtimeSubscription(
  channelName: string,
  table: string,
  onEvent: (payload: any) => void
) {
  const [status, setStatus] = useState<ChannelStatus>("connected");
  const [error, setError] = useState<any>(null);

  useEffect(() => {
    const channel = supabase.channel(channelName).on(
      'postgres_changes',
      { event: '*', schema: 'public', table },
      onEvent
    );
    const watchdog = new RealtimeWatchdog();
    watchdog.subscribe(channelName, channel, (st, err) => {
      setStatus(st);
      setError(err || null);
    });
    channel.subscribe();

    return () => {
      channel.unsubscribe();
    };
  }, [channelName, table, onEvent]);

  return { status, error };
}
