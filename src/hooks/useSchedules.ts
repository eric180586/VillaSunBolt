import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import type { Database } from '../lib/database.types';

type Schedule = Database['public']['Tables']['weekly_schedules']['Row'];
type ScheduleInsert = Database['public']['Tables']['weekly_schedules']['Insert'];
type ScheduleUpdate = Database['public']['Tables']['weekly_schedules']['Update'];

export function useSchedules() {
  const [schedules, setSchedules] = useState<Schedule[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchSchedules = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('weekly_schedules')
        .select('*')
        .order('week_start_date', { ascending: true });

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
    'weekly_schedules',
    (payload) => {
      setSchedules((current) => [...current, payload.new as Schedule].sort((a, b) =>
        new Date(a.week_start_date).getTime() - new Date(b.week_start_date).getTime()
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
    const { error } = await supabase.from('weekly_schedules').insert(schedule);
    if (error) throw error;
  };

  const updateSchedule = async (id: string, updates: ScheduleUpdate) => {
    const { error } = await supabase.from('weekly_schedules').update(updates).eq('id', id);
    if (error) throw error;
  };

  const deleteSchedule = async (id: string) => {
    const { error } = await supabase.from('weekly_schedules').delete().eq('id', id);
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
