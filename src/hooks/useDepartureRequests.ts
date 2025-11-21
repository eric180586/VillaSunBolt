import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import type { Database } from '../lib/database.types';

type DepartureRequest = Database['public']['Tables']['departure_requests']['Row'];
type DepartureRequestInsert = Database['public']['Tables']['departure_requests']['Insert'];
type DepartureRequestUpdate = Database['public']['Tables']['departure_requests']['Update'];

export function useDepartureRequests() {
  const [requests, setRequests] = useState<DepartureRequest[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchRequests = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('departure_requests')
        .select('*')
        .order('request_time', { ascending: false });

      if (error) throw error;
      setRequests(data || []);
    } catch (error) {
      console.error('Error fetching departure requests:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  useRealtimeSubscription<DepartureRequest>(
    'departure_requests',
    (payload) => {
      setRequests((current) => [payload.new as DepartureRequest, ...current]);
    },
    (payload) => {
      setRequests((current) =>
        current.map((req) => (req.id === payload.new.id ? (payload.new as DepartureRequest) : req))
      );
    },
    (payload) => {
      setRequests((current) => current.filter((req) => req.id !== payload.old.id));
    }
  );

  const createRequest = async (request: DepartureRequestInsert) => {
    console.log('[useDepartureRequests] Creating request:', request);
    const { data, error } = await supabase.from('departure_requests').insert(request).select() as any;
    if (error) {
      console.error('[useDepartureRequests] Error creating request:', error);
      console.error('[useDepartureRequests] Error details:', JSON.stringify(error, null, 2));
      throw error;
    }
    console.log('[useDepartureRequests] Request created successfully:', data);
  };

  const updateRequest = async (id: string, updates: DepartureRequestUpdate) => {
    const { error } = await supabase.from('departure_requests').update(updates).eq('id', id);
    if (error) throw error;
  };

  const deleteRequest = async (id: string) => {
    const { error } = await supabase.from('departure_requests').delete().eq('id', id);
    if (error) throw error;
  };

  return {
    requests,
    loading,
    createRequest,
    updateRequest,
    deleteRequest,
    refetch: fetchRequests,
  };
}
