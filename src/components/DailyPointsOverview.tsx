import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import { useProfiles } from '../hooks/useProfiles';
import { getTodayDateString } from '../lib/dateUtils';
import { Award, TrendingUp, Users, ArrowLeft } from 'lucide-react';

interface DailyGoal {
  id: string;
  user_id: string;
  goal_date: string;
  theoretically_achievable_points: number;
  achieved_points: number;
  team_achievable_points?: number;
  team_points_earned?: number;
  percentage: number;
  color_status: 'red' | 'yellow' | 'orange' | 'green' | 'dark_green' | 'gray';
}

export function DailyPointsOverview({ onBack }: { onBack?: () => void } = {}) {
  const { t } = useTranslation();
  const { profiles } = useProfiles();
  const [dailyGoals, setDailyGoals] = useState<DailyGoal[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDailyGoals();

    const channel = supabase
      .channel(`daily_goals_admin_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'daily_point_goals',
        },
        () => {
          fetchDailyGoals();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchDailyGoals = async () => {
    try {
      setLoading(true);
      const today = getTodayDateString();

      const { data, error } = await supabase
        .from('daily_point_goals')
        .select('*')
        .eq('goal_date', today)
        .order('percentage', { ascending: false });

      if (error) throw error;

      setDailyGoals(data || []);
    } catch (error) {
      console.error('Error fetching daily goals:', error);
    } finally {
      setLoading(false);
    }
  };

  const refreshAllGoals = async () => {
    try {
      await supabase.rpc('initialize_daily_goals_for_today');
      await fetchDailyGoals();
    } catch (error) {
      console.error('Error refreshing goals:', error);
    }
  };

  const getTextColorClasses = (color: 'red' | 'yellow' | 'orange' | 'green' | 'dark_green' | 'gray') => {
    switch (color) {
      case 'dark_green':
        return 'text-green-800';
      case 'green':
        return 'text-green-600';
      case 'orange':
        return 'text-orange-600';
      case 'yellow':
        return 'text-yellow-600';
      case 'red':
        return 'text-red-600';
      case 'gray':
        return 'text-gray-500';
    }
  };

  if (loading) {
    return (
      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-200 rounded w-1/3"></div>
          <div className="h-4 bg-gray-200 rounded w-2/3"></div>
        </div>
      </div>
    );
  }

  const firstGoal = dailyGoals[0];
  const totalAchievable = firstGoal?.team_achievable_points || 0;
  const totalAchieved = firstGoal?.team_points_earned || 0;
  const teamPercentage = totalAchievable > 0 ? (totalAchieved / totalAchievable) * 100 : 0;

  const getTeamColor = (): 'red' | 'yellow' | 'orange' | 'green' | 'dark_green' | 'gray' => {
    if (totalAchievable === 0) return 'gray';
    if (teamPercentage >= 95) return 'dark_green';
    if (teamPercentage >= 90) return 'green';
    if (teamPercentage >= 83) return 'orange';
    if (teamPercentage >= 74) return 'yellow';
    return 'red';
  };

  const teamColor = getTeamColor();

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <Award className="w-8 h-8 text-blue-600" />
            <h2 className="text-2xl font-bold text-gray-900">Heutige Punkteübersicht</h2>
          </div>
          <button
            onClick={refreshAllGoals}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Aktualisieren
          </button>
        </div>

        <div className="rounded-lg p-4 border-2 border-gray-200 bg-white mb-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Users className="w-6 h-6 text-blue-600" />
              <div>
                <p className="font-bold text-lg text-gray-900">Team Gesamt</p>
                <p className={`text-sm font-semibold ${getTextColorClasses(teamColor)}`}>
                  {totalAchieved} / {totalAchievable} Punkte
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className={`text-3xl font-bold ${getTextColorClasses(teamColor)}`}>{teamPercentage.toFixed(1)}%</p>
              <p className="text-xs uppercase font-semibold text-gray-600">
                {totalAchievable === 0
                  ? 'Kein Zeitplan'
                  : teamPercentage >= 90
                  ? 'Ausgezeichnet'
                  : teamPercentage >= 70
                  ? 'Gut'
                  : teamPercentage >= 50
                  ? 'Weiter so'
                  : 'Mehr Einsatz'}
              </p>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          {dailyGoals.map((goal) => {
            const profile = profiles.find((p) => p.id === goal.user_id);
            if (!profile) return null;

            return (
              <div
                key={goal.id}
                className="flex items-center justify-between p-4 rounded-lg border-2 border-gray-200 bg-white"
              >
                <div className="flex items-center space-x-4">
                  <div className="w-12 h-12 rounded-full bg-gray-100 flex items-center justify-center font-bold text-lg text-gray-700">
                    {profile.full_name.charAt(0)}
                  </div>
                  <div>
                    <p className="font-bold text-gray-900">{profile.full_name}</p>
                    <p className={`text-sm font-semibold ${getTextColorClasses(goal.color_status)}`}>
                      {goal.achieved_points} / {goal.theoretically_achievable_points} Punkte
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className={`text-2xl font-bold ${getTextColorClasses(goal.color_status)}`}>{goal.percentage.toFixed(1)}%</p>
                  <div className="flex items-center space-x-1 mt-1">
                    <TrendingUp className={`w-4 h-4 ${getTextColorClasses(goal.color_status)}`} />
                    <span className={`text-xs font-semibold ${getTextColorClasses(goal.color_status)}`}>
                      {goal.theoretically_achievable_points === 0
                        ? 'Frei'
                        : goal.percentage >= 90
                        ? 'Bonus!'
                        : goal.percentage >= 70
                        ? 'Fast da!'
                        : goal.percentage >= 50
                        ? 'Noch Luft'
                        : 'Aufholen!'}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}

          {dailyGoals.length === 0 && (
            <div className="text-center py-8 text-gray-500">
              <p>Noch keine Punkteziele für heute</p>
              <button
                onClick={refreshAllGoals}
                className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Jetzt initialisieren
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
