import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import type { Database } from '../lib/database.types';

type Schedule = Database['public']['Tables']['schedules']['Row'];
type ScheduleInsert = Database['public']['Tables']['schedules']['Insert'];
type ScheduleUpdate = Database['public']['Tables']['schedules']['Update'];

export function useSchedules() {
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchSchedules = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('schedules')
        .select('*')
        .order('start_time', { ascending: true });

      if (error) throw error;
      setSchedules(data || []);
    } catch (error) {
      console.error('Error fetching schedules:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchSchedules();
  }, [fetchSchedules]);

  useRealtimeSubscription<Schedule>(
    'schedules',
    (payload) => {
      setSchedules((current) => [...current, payload.new as Schedule].sort((a, b) =>
        new Date(a.start_time).getTime() - new Date(b.start_time).getTime()
      ));
    },
    (payload) => {
      setSchedules((current) =>
        current.map((schedule) => (schedule.id === payload.new.id ? (payload.new as Schedule) : schedule))
      );
    },
    (payload) => {
      setSchedules((current) => current.filter((schedule) => schedule.id !== payload.old.id));
    }
  );

  const createSchedule = async (schedule: ScheduleInsert) => {
    const { error } = await supabase.from('schedules').insert(schedule);
    if (error) throw error;
  };

  const updateSchedule = async (id: string, updates: ScheduleUpdate) => {
    const { error } = await supabase.from('schedules').update(updates).eq('id', id);
    if (error) throw error;
  };

  const deleteSchedule = async (id: string) => {
    const { error } = await supabase.from('schedules').delete().eq('id', id);
    if (error) throw error;
  };

  return {
    schedules,
    loading,
    createSchedule,
    updateSchedule,
    deleteSchedule,
    refetch: fetchSchedules,
  };
}
