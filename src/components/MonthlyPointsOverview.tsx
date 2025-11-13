import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import { useProfiles } from '../hooks/useProfiles';
import { Calendar, TrendingUp, Users, Target } from 'lucide-react';

interface MonthlyGoal {
  id: string;
  user_id: string;
  month: string;
  total_achievable_points: number;
  total_achieved_points: number;
  percentage: number;
  color_status: 'red' | 'yellow' | 'orange' | 'green' | 'dark_green' | 'gray';
}

export function MonthlyPointsOverview() {
  const { t } = useTranslation();
  const { profiles } = useProfiles();
  const [monthlyGoals, setMonthlyGoals] = useState<MonthlyGoal[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedMonth, setSelectedMonth] = useState(() => {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  });

  useEffect(() => {
    fetchMonthlyGoals();

    const channel = supabase
      .channel(`monthly_goals_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'monthly_point_goals',
        },
        () => {
          fetchMonthlyGoals();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [selectedMonth]);

  const fetchMonthlyGoals = async () => {
    try {
      setLoading(true);

      const { data, error } = await supabase
        .from('monthly_point_goals')
        .select('*')
        .eq('month', selectedMonth)
        .order('percentage', { ascending: false });

      if (error) throw error;

      setMonthlyGoals(data || []);
    } catch (error) {
      console.error('Error fetching monthly goals:', error);
    } finally {
      setLoading(false);
    }
  };

  const refreshMonthlyGoals = async () => {
    try {
      await supabase.rpc('update_all_monthly_point_goals', { p_month: selectedMonth });
      await fetchMonthlyGoals();
    } catch (error) {
      console.error('Error refreshing monthly goals:', error);
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

  const totalAchievable = monthlyGoals.reduce((sum, g) => sum + g.total_achievable_points, 0);
  const totalAchieved = monthlyGoals.reduce((sum, g) => sum + g.total_achieved_points, 0);
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
  const monthName = new Date(selectedMonth + '-01').toLocaleDateString('de-DE', { month: 'long', year: 'numeric' });

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-3">
            <Calendar className="w-8 h-8 text-blue-600" />
            <div>
              <h2 className="text-2xl font-bold text-gray-900">Monatliche Punkteübersicht</h2>
              <p className="text-sm text-gray-600 capitalize">{monthName}</p>
            </div>
          </div>
          <div className="flex items-center space-x-3">
            <input
              type="month"
              value={selectedMonth}
              onChange={(e) => setSelectedMonth(e.target.value)}
              className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <button
              onClick={refreshMonthlyGoals}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Aktualisieren
            </button>
          </div>
        </div>

        <div className="rounded-lg p-6 border-2 border-gray-200 bg-white mb-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Users className="w-8 h-8 text-blue-600" />
              <div>
                <p className="font-bold text-xl text-gray-900">Team Gesamt - {monthName}</p>
                <p className={`text-base font-semibold ${getTextColorClasses(teamColor)}`}>
                  {totalAchieved} / {totalAchievable} Punkte
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className={`text-4xl font-bold ${getTextColorClasses(teamColor)}`}>{teamPercentage.toFixed(1)}%</p>
              <div className="flex items-center space-x-2 mt-2">
                <Target className="w-5 h-5 text-gray-600" />
                <p className="text-sm font-semibold text-gray-600">
                  Ziel: 90% für Team-Event
                </p>
              </div>
              {teamPercentage >= 90 && (
                <p className="text-sm font-bold text-green-600 mt-1">
                  Team-Event erreicht!
                </p>
              )}
            </div>
          </div>
        </div>

        <div className="space-y-3">
          {monthlyGoals.map((goal) => {
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
                      {goal.total_achieved_points} / {goal.total_achievable_points} Punkte
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className={`text-2xl font-bold ${getTextColorClasses(goal.color_status)}`}>{goal.percentage.toFixed(1)}%</p>
                  <div className="flex items-center space-x-1 mt-1">
                    <TrendingUp className={`w-4 h-4 ${getTextColorClasses(goal.color_status)}`} />
                    <span className={`text-xs font-semibold ${getTextColorClasses(goal.color_status)}`}>
                      {goal.total_achievable_points === 0
                        ? 'Kein Zeitplan'
                        : goal.percentage >= 90
                        ? 'Ausgezeichnet'
                        : goal.percentage >= 70
                        ? 'Gut'
                        : goal.percentage >= 50
                        ? 'Weiter so'
                        : 'Aufholen'}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}

          {monthlyGoals.length === 0 && (
            <div className="text-center py-8 text-gray-500">
              <p>Noch keine monatlichen Ziele für {monthName}</p>
              <button
                onClick={refreshMonthlyGoals}
                className="mt-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Jetzt berechnen
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
