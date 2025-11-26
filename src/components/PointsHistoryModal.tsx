import { useState, useEffect } from 'react';
import { X, TrendingUp, Calendar, Award, Target } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';

interface PointsHistoryModalProps {
  userId: string;
  userName: string;
  month?: string; // Format: "2025-11"
  onClose: () => void;
}

interface DailyPoints {
  goal_date: string;
  achieved_points: number;
  theoretically_achievable_points: number;
  percentage: number;
}

export function PointsHistoryModal({ userId, userName, month, onClose }: PointsHistoryModalProps) {
  const { t } = useTranslation();
  const [history, setHistory] = useState<DailyPoints[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadHistory();
  }, [userId, month]);

  const loadHistory = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('daily_point_goals')
        .select('goal_date, achieved_points, theoretically_achievable_points, percentage')
        .eq('user_id', userId)
        .order('goal_date', { ascending: false });

      if (month) {
        // Filter by month
        const startDate = `${month}-01`;
        const endDate = new Date(parseInt(month.split('-')[0]), parseInt(month.split('-')[1]), 0)
          .toISOString()
          .split('T')[0];
        query = query.gte('goal_date', startDate).lte('goal_date', endDate);
      } else {
        // Last 90 days
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - 90);
        query = query.gte('goal_date', startDate.toISOString().split('T')[0]);
      }

      const { data, error } = await query;

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
        daysWorked: 0,
      };
    }

    const totalAchieved = history.reduce((sum, day) => sum + day.achieved_points, 0);
    const totalAchievable = history.reduce((sum, day) => sum + day.theoretically_achievable_points, 0);
    const avgPercentage = history.reduce((sum, day) => sum + day.percentage, 0) / history.length;
    const daysWorked = history.length;

    return { totalAchieved, totalAchievable, avgPercentage, daysWorked };
  };

  const stats = calculateStats();

  const getPercentageColor = (percentage: number) => {
    if (percentage >= 100) return 'text-yellow-600 bg-yellow-50';
    if (percentage >= 80) return 'text-green-600 bg-green-50';
    if (percentage >= 50) return 'text-orange-600 bg-orange-50';
    return 'text-red-600 bg-red-50';
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl w-full max-w-4xl max-h-[90vh] flex flex-col shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <div>
            <h2 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
              <TrendingUp className="w-6 h-6 text-blue-600" />
              {t('pointsHistory.title', 'Punkteverlauf')}
            </h2>
            <p className="text-gray-600 mt-1">{userName}</p>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-6 h-6 text-gray-500" />
          </button>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 p-6 border-b border-gray-200">
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

          <div className="bg-gradient-to-br from-gray-50 to-gray-100 rounded-lg p-4 border border-gray-200">
            <div className="flex items-center gap-2 mb-1">
              <Calendar className="w-5 h-5 text-gray-600" />
              <span className="text-sm font-medium text-gray-800">
                {t('pointsHistory.daysWorked', 'Arbeitstage')}
              </span>
            </div>
            <div className="text-2xl font-bold text-gray-900">{stats.daysWorked}</div>
          </div>
        </div>

        {/* History List */}
        <div className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="space-y-3">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="animate-pulse">
                  <div className="h-16 bg-gray-200 rounded-lg"></div>
                </div>
              ))}
            </div>
          ) : history.length === 0 ? (
            <div className="text-center py-12 text-gray-500">
              <Calendar className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <p className="text-lg font-medium">{t('pointsHistory.noData', 'Keine Daten für diesen Zeitraum')}</p>
            </div>
          ) : (
            <div className="space-y-2">
              {history.map((day) => {
                const date = new Date(day.goal_date);
                const dayName = date.toLocaleDateString(undefined, {
                  weekday: 'short',
                  month: 'short',
                  day: 'numeric',
                  year: 'numeric',
                });

                return (
                  <div
                    key={day.goal_date}
                    className="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-3 mb-2">
                          <span className="text-sm font-semibold text-gray-700 w-48">{dayName}</span>
                          <div className="flex-1 flex items-center gap-3">
                            <div className="flex-1">
                              <div className="flex items-center justify-between text-sm mb-1">
                                <span className="font-medium text-gray-600">
                                  {t('pointsHistory.achieved', 'Erreicht')}
                                </span>
                                <span className="font-bold text-green-600">
                                  {day.achieved_points}
                                </span>
                              </div>
                              <div className="flex items-center justify-between text-sm">
                                <span className="font-medium text-gray-600">
                                  {t('pointsHistory.achievable', 'Erreichbar')}
                                </span>
                                <span className="font-bold text-blue-600">
                                  {day.theoretically_achievable_points}
                                </span>
                              </div>
                            </div>
                          </div>
                        </div>

                        {/* Progress Bar */}
                        <div className="relative h-3 bg-gray-200 rounded-full overflow-hidden">
                          <div
                            className="absolute inset-y-0 left-0 bg-gradient-to-r from-green-500 to-emerald-600 transition-all duration-300"
                            style={{
                              width: `${Math.min(
                                (day.achieved_points / day.theoretically_achievable_points) * 100,
                                100
                              )}%`,
                            }}
                          />
                        </div>
                      </div>

                      <div className="ml-4">
                        <div
                          className={`px-4 py-2 rounded-lg font-bold text-lg ${getPercentageColor(
                            day.percentage
                          )}`}
                        >
                          {day.percentage.toFixed(0)}%
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-3 p-6 border-t border-gray-200">
          <button
            onClick={onClose}
            className="px-6 py-2 bg-gray-200 text-gray-900 rounded-lg hover:bg-gray-300 font-medium transition-colors"
          >
            {t('common.close', 'Schließen')}
          </button>
        </div>
      </div>
    </div>
  );
}
