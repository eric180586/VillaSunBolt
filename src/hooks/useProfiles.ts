import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import type { Database } from '../lib/database.types';

type Profile = Database['public']['Tables']['profiles']['Row'];
type PointsHistory = Database['public']['Tables']['points_history']['Row'];

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
    (payload) => {
      fetchProfiles();
    },
    (payload) => {
      fetchProfiles();
    },
    (payload) => {
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

  const getPointsHistory = async (userId: string): Promise<PointsHistory[]> => {
    const { data, error } = await supabase
      .from('points_history')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (error) throw error;
    return data || [];
  };

  return {
    profiles,
    loading,
    addPoints,
    getPointsHistory,
    refetch: fetchProfiles,
  };
}
