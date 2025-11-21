import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Database } from '../lib/database.types';
import { getTodayDateString } from '../lib/dateUtils';

type DailyPointGoal = Database['public']['Tables']['daily_point_goals']['Row'];

export function useDailyPointGoals(userId?: string, date?: string) {
  const [dailyGoal, setDailyGoal] = useState<DailyPointGoal | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }

    fetchDailyGoal();

    const channel = supabase
      .channel(`daily_goals_${userId}_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'daily_point_goals',
          filter: `user_id=eq.${userId}`,
        },
        () => {
          fetchDailyGoal();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, date]);

  const fetchDailyGoal = async () => {
    if (!userId) return;

    try {
      setLoading(true);
      const targetDate = date || getTodayDateString();

      const { data, error: fetchError } = await supabase
        .from('daily_point_goals')
        .select('*')
        .eq('user_id', userId)
        .eq('goal_date', targetDate)
        .maybeSingle() as any;

      if (fetchError) throw fetchError;

      setDailyGoal(data);
      setError(null);
    } catch (err) {
      setError(err as Error);
      console.error('Error fetching daily goal:', err);
    } finally {
      setLoading(false);
    }
  };

  const refreshDailyGoal = async () => {
    if (!userId) return;

    try {
      const targetDate = date || getTodayDateString();

      await supabase.rpc('update_daily_point_goals', {
        p_user_id: userId,
        p_date: targetDate,
      });

      await fetchDailyGoal();
    } catch (err) {
      console.error('Error refreshing daily goal:', err);
    }
  };

  return {
    dailyGoal,
    loading,
    error,
    refreshDailyGoal,
  };
}

export function useMonthlyProgress(userId?: string) {
  const [monthlyProgress, setMonthlyProgress] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!userId) {
      setLoading(false);
      return;
    }

    fetchMonthlyProgress();
  }, [userId]);

  const fetchMonthlyProgress = async () => {
    if (!userId) return;

    try {
      setLoading(true);
      const now = new Date();
      const { data, error } = await supabase.rpc('calculate_monthly_progress', {
        p_user_id: userId,
        p_year: now.getFullYear(),
        p_month: now.getMonth() + 1,
      });

      if (error) throw error;

      setMonthlyProgress(data);
    } catch (err) {
      console.error('Error fetching monthly progress:', err);
    } finally {
      setLoading(false);
    }
  };

  return {
    monthlyProgress,
    loading,
    refreshMonthlyProgress: fetchMonthlyProgress,
  };
}

export function useTeamMonthlyProgress() {
  const [teamProgress, setTeamProgress] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchTeamProgress();
  }, []);

  const fetchTeamProgress = async () => {
    try {
      setLoading(true);
      const now = new Date();
      const { data, error } = await supabase.rpc('calculate_team_monthly_progress', {
        p_year: now.getFullYear(),
        p_month: now.getMonth() + 1,
      });

      if (error) throw error;

      setTeamProgress(data);
    } catch (err) {
      console.error('Error fetching team progress:', err);
    } finally {
      setLoading(false);
    }
  };

  return {
    teamProgress,
    loading,
    refreshTeamProgress: fetchTeamProgress,
  };
}
