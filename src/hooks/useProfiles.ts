import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import type { Database } from '../lib/database.types';

type Profile = Database['public']['Tables']['profiles']['Row'];

export function useProfiles() {
  const [profiles, setProfiles] = useState<Profile[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchProfiles = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .order('total_points', { ascending: false });

      if (error) throw error;
      setProfiles(data || []);
    } catch (error) {
      console.error('Error fetching profiles:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchProfiles();
  }, [fetchProfiles]);

  useRealtimeSubscription<Profile>(
    'profiles',
    () => {
      fetchProfiles();
    },
    () => {
      fetchProfiles();
    },
    () => {
      fetchProfiles();
    }
  );

  const addPoints = async (
    userId: string,
    points: number,
    reason: string,
    createdBy: string,
    photoUrl: string | null = null
  ) => {
    const { error } = await supabase.from('points_history').insert({
      user_id: userId,
      points_change: points,
      reason,
      category: points > 0 ? 'bonus' : 'deduction',
      created_by: createdBy,
      photo_url: photoUrl,
    });

    if (error) throw error;
  };

  const getPointsHistory = async (userId: string): Promise<any[]> => {
    const { data, error } = await supabase
      .from('points_history')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;

    const historyWithContext = await Promise.all((data || []).map(async (entry: any) => {
      const entryDate = new Date(entry.created_at).toISOString().split('T')[0];

      const { data: dailyGoal } = await supabase
        .from('daily_point_goals')
        .select('achieved_points, theoretically_achievable_points')
        .eq('user_id', userId)
        .eq('goal_date', entryDate)
        .maybeSingle() as any;

      return {
        ...entry,
        daily_achieved: dailyGoal?.achieved_points || 0,
        daily_achievable: dailyGoal?.theoretically_achievable_points || 0
      };
    }));

    return historyWithContext;
  };

  return {
    profiles,
    loading,
    addPoints,
    getPointsHistory,
    refetch: fetchProfiles,
  };
}
