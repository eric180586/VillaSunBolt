import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { TrendingUp, TrendingDown, Target, Award } from 'lucide-react';
import { useTranslation } from 'react-i18next';

interface DailyPoints {
  goal_date: string;
  achieved_points: number;
  theoretically_achievable_points: number;
  percentage: number;
}

export function PointsHistoryChart() {
  const { profile } = useAuth();
  const { t } = useTranslation();
  const [history, setHistory] = useState<DailyPoints[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState<'7' | '30' | '90'>('30');

  useEffect(() => {
    if (profile?.id) {
      loadHistory();
    }
  }, [profile?.id, timeRange]);

  const loadHistory = async () => {
    if (!profile?.id) return;

    setLoading(true);
    try {
      const daysAgo = parseInt(timeRange);
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - daysAgo);

      const { data, error } = await supabase
        .from('daily_point_goals')
        .select('goal_date, achieved_points, theoretically_achievable_points, percentage')
        .eq('user_id', profile.id)
        .gte('goal_date', startDate.toISOString().split('T')[0])
        .order('goal_date', { ascending: true });

      if (error) throw error;
      setHistory(data || []);
    } catch (error) {
      console.error('Error loading history:', error);
    } finally {
      setLoading(false);
    }
  };

  const calculateStats = () => {
    if (history.length === 0) {
      return {
        totalAchieved: 0,
        totalAchievable: 0,
        avgPercentage: 0,
        trend: 0,
      };
    }

    const totalAchieved = history.reduce((sum, day) => sum + day.achieved_points, 0);
    const totalAchievable = history.reduce((sum, day) => sum + day.theoretically_achievable_points, 0);
    const avgPercentage = history.reduce((sum, day) => sum + day.percentage, 0) / history.length;

    // Calculate trend (compare last 3 days vs previous 3 days)
    const recentDays = history.slice(-3);
    const previousDays = history.slice(-6, -3);

    const recentAvg = recentDays.length > 0
      ? recentDays.reduce((sum, day) => sum + day.percentage, 0) / recentDays.length
      : 0;
    const previousAvg = previousDays.length > 0
      ? previousDays.reduce((sum, day) => sum + day.percentage, 0) / previousDays.length
      : 0;

    const trend = recentAvg - previousAvg;

    return { totalAchieved, totalAchievable, avgPercentage, trend };
  };

  const stats = calculateStats();
  const maxPoints = Math.max(...history.map(d => d.theoretically_achievable_points), 1);

  if (loading) {
    return (
      <div className="bg-white rounded-xl shadow-lg p-6">
        <div className="animate-pulse">
          <div className="h-6 bg-gray-200 rounded w-1/3 mb-4"></div>
          <div className="h-64 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl shadow-lg p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
          <TrendingUp className="w-6 h-6 text-blue-600" />
          {t('pointsHistory.title', 'Punkteverlauf')}
        </h3>

        <div className="flex gap-2">
          <button
            onClick={() => setTimeRange('7')}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              timeRange === '7'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            7 {t('pointsHistory.days', 'Tage')}
          </button>
          <button
            onClick={() => setTimeRange('30')}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              timeRange === '30'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            30 {t('pointsHistory.days', 'Tage')}
          </button>
          <button
            onClick={() => setTimeRange('90')}
            className={`px-4 py-2 rounded-lg font-medium transition-colors ${
              timeRange === '90'
                ? 'bg-blue-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            90 {t('pointsHistory.days', 'Tage')}
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-gradient-to-br from-green-50 to-green-100 rounded-lg p-4 border border-green-200">
          <div className="flex items-center gap-2 mb-1">
            <Award className="w-5 h-5 text-green-600" />
            <span className="text-sm font-medium text-green-800">
              {t('pointsHistory.totalAchieved', 'Erreicht')}
            </span>
          </div>
          <div className="text-2xl font-bold text-green-900">{stats.totalAchieved}</div>
        </div>

        <div className="bg-gradient-to-br from-blue-50 to-blue-100 rounded-lg p-4 border border-blue-200">
          <div className="flex items-center gap-2 mb-1">
            <Target className="w-5 h-5 text-blue-600" />
            <span className="text-sm font-medium text-blue-800">
              {t('pointsHistory.totalAchievable', 'Erreichbar')}
            </span>
          </div>
          <div className="text-2xl font-bold text-blue-900">{stats.totalAchievable}</div>
        </div>

        <div className="bg-gradient-to-br from-purple-50 to-purple-100 rounded-lg p-4 border border-purple-200">
          <div className="flex items-center gap-2 mb-1">
            <TrendingUp className="w-5 h-5 text-purple-600" />
            <span className="text-sm font-medium text-purple-800">
              {t('pointsHistory.avgPercentage', 'Durchschnitt')}
            </span>
          </div>
          <div className="text-2xl font-bold text-purple-900">{stats.avgPercentage.toFixed(1)}%</div>
        </div>

        <div className={`rounded-lg p-4 border ${
          stats.trend >= 0
            ? 'bg-gradient-to-br from-emerald-50 to-emerald-100 border-emerald-200'
            : 'bg-gradient-to-br from-red-50 to-red-100 border-red-200'
        }`}>
          <div className="flex items-center gap-2 mb-1">
            {stats.trend >= 0 ? (
              <TrendingUp className="w-5 h-5 text-emerald-600" />
            ) : (
              <TrendingDown className="w-5 h-5 text-red-600" />
            )}
            <span className={`text-sm font-medium ${
              stats.trend >= 0 ? 'text-emerald-800' : 'text-red-800'
            }`}>
              {t('pointsHistory.trend', 'Trend')}
            </span>
          </div>
          <div className={`text-2xl font-bold ${
            stats.trend >= 0 ? 'text-emerald-900' : 'text-red-900'
          }`}>
            {stats.trend >= 0 ? '+' : ''}{stats.trend.toFixed(1)}%
          </div>
        </div>
      </div>

      {/* Chart */}
      {history.length === 0 ? (
        <div className="text-center py-12 text-gray-500">
          {t('pointsHistory.noData', 'Keine Daten für diesen Zeitraum')}
        </div>
      ) : (
        <div className="space-y-2">
          {history.map((day) => {
            const date = new Date(day.goal_date);
            const dayName = date.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' });
            const achievedPercent = (day.achieved_points / maxPoints) * 100;
            const achievablePercent = (day.theoretically_achievable_points / maxPoints) * 100;

            return (
              <div key={day.goal_date} className="group">
                <div className="flex items-center gap-3 mb-1">
                  <span className="text-sm font-medium text-gray-600 w-32">{dayName}</span>
                  <div className="flex-1 flex items-center gap-2">
                    {/* Achievable Bar (background) */}
                    <div className="flex-1 relative h-12 bg-gray-100 rounded-lg overflow-hidden">
                      <div
                        className="absolute inset-y-0 left-0 bg-blue-200 transition-all duration-300"
                        style={{ width: `${achievablePercent}%` }}
                      />
                      <div
                        className="absolute inset-y-0 left-0 bg-gradient-to-r from-green-500 to-emerald-600 transition-all duration-300 group-hover:from-green-600 group-hover:to-emerald-700"
                        style={{ width: `${achievedPercent}%` }}
                      />
                      <div className="absolute inset-0 flex items-center justify-between px-3">
                        <span className="text-sm font-bold text-white drop-shadow-md">
                          {day.achieved_points}
                        </span>
                        <span className="text-sm font-semibold text-gray-700">
                          / {day.theoretically_achievable_points}
                        </span>
                      </div>
                    </div>
                    <span className={`text-sm font-bold w-16 text-right ${
                      day.percentage >= 100 ? 'text-yellow-600' :
                      day.percentage >= 80 ? 'text-green-600' :
                      day.percentage >= 50 ? 'text-orange-600' :
                      'text-red-600'
                    }`}>
                      {day.percentage.toFixed(0)}%
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
