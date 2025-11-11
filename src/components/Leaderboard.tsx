import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useProfiles } from '../hooks/useProfiles';
import { supabase } from '../lib/supabase';
import { Award, TrendingUp, Trophy, Medal, Plus, Minus, ArrowLeft, Users, ArrowUp, ArrowDown, Minus as MinusIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';

interface DailyGoal {
  user_id: string;
  goal_date: string;
  theoretically_achievable_points: number;
  achieved_points: number;
  team_achievable_points: number;
  team_points_earned: number;
  percentage: number;
  color_status: string;
}

interface MonthlyStats {
  totalAchievable: number;
  totalAchieved: number;
  percentage: number;
  daysCount: number;
}

export function Leaderboard({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const { t } = useTranslation();
  const { profiles, addPoints, getPointsHistory } = useProfiles();

  const staffProfiles = profiles.filter((p) => p.role !== 'admin');
  const [showModal, setShowModal] = useState(false);
  const [selectedUserId, setSelectedUserId] = useState('');
  const [pointsForm, setPointsForm] = useState({
    points: 0,
    reason: '',
  });
  const [historyUserId, setHistoryUserId] = useState<string | null>(null);
  const [history, setHistory] = useState<any[]>([]);
  const [dailyGoals, setDailyGoals] = useState<DailyGoal[]>([]);
  const [monthlyStats, setMonthlyStats] = useState<Record<string, MonthlyStats>>({});
  const [loading, setLoading] = useState(true);

  const isManager = profile?.role === 'admin' || profile?.role === 'super_admin' || profile?.role === 'manager';

  useEffect(() => {
    fetchGoalsData();
  }, []);

  const fetchGoalsData = async () => {
    try {
      setLoading(true);

      // Fetch today's data
      const today = new Date().toISOString().split('T')[0];
      const { data: todayData, error: todayError } = await supabase
        .from('daily_point_goals')
        .select('*')
        .eq('goal_date', today);

      if (todayError) throw todayError;
      setDailyGoals(todayData || []);

      // Fetch monthly data for all staff
      const firstDayOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
        .toISOString().split('T')[0];

      const { data: monthlyData, error: monthlyError } = await supabase
        .from('daily_point_goals')
        .select('user_id, theoretically_achievable_points, achieved_points')
        .gte('goal_date', firstDayOfMonth);

      if (monthlyError) throw monthlyError;

      // Aggregate monthly stats per user
      const statsMap: Record<string, MonthlyStats> = {};
      monthlyData?.forEach((day) => {
        if (!statsMap[day.user_id]) {
          statsMap[day.user_id] = {
            totalAchievable: 0,
            totalAchieved: 0,
            percentage: 0,
            daysCount: 0,
          };
        }
        statsMap[day.user_id].totalAchievable += day.theoretically_achievable_points;
        statsMap[day.user_id].totalAchieved += day.achieved_points;
        statsMap[day.user_id].daysCount += 1;
      });

      // Calculate percentages
      Object.keys(statsMap).forEach((userId) => {
        const stats = statsMap[userId];
        stats.percentage = stats.totalAchievable > 0
          ? (stats.totalAchieved / stats.totalAchievable) * 100
          : 0;
      });

      setMonthlyStats(statsMap);
    } catch (error) {
      console.error('Error fetching goals data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await addPoints(
        selectedUserId,
        pointsForm.points,
        pointsForm.reason,
        profile?.id || ''
      );
      setShowModal(false);
      setPointsForm({ points: 0, reason: '' });
      setSelectedUserId('');
    } catch (error) {
      console.error('Error adding points:', error);
    }
  };

  const handleViewHistory = async (userId: string) => {
    try {
      const data = await getPointsHistory(userId);
      setHistory(data);
      setHistoryUserId(userId);
    } catch (error) {
      console.error('Error fetching history:', error);
    }
  };

  const getRankIcon = (index: number) => {
    if (index === 0) return <Trophy className="w-6 h-6 text-yellow-500" />;
    if (index === 1) return <Medal className="w-6 h-6 text-gray-400" />;
    if (index === 2) return <Medal className="w-6 h-6 text-amber-600" />;
    return <span className="text-lg font-bold text-gray-400">{index + 1}</span>;
  };

  const getColorClasses = (percentage: number) => {
    if (percentage >= 95) return 'bg-green-200 text-green-900 border-green-500';
    if (percentage >= 90) return 'bg-green-100 text-green-700 border-green-300';
    if (percentage >= 83) return 'bg-orange-100 text-orange-700 border-orange-300';
    if (percentage >= 74) return 'bg-yellow-100 text-yellow-700 border-yellow-300';
    return 'bg-red-100 text-red-700 border-red-300';
  };

  const calculateRequiredPerformance = (monthlyStats: MonthlyStats) => {
    const targetPercentage = 95;
    const currentDay = new Date().getDate();
    const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
    const remainingDays = daysInMonth - currentDay;

    if (remainingDays <= 0) {
      return { requiredPercentage: 0, status: 'completed' };
    }

    if (monthlyStats.percentage >= targetPercentage) {
      return { requiredPercentage: 0, status: 'exceeded' };
    }

    // Estimate remaining achievable based on average
    const avgAchievablePerDay = monthlyStats.totalAchievable / monthlyStats.daysCount;
    const estimatedRemainingAchievable = avgAchievablePerDay * remainingDays;

    // Calculate total needed for 95%
    const totalAchievableMonth = monthlyStats.totalAchievable + estimatedRemainingAchievable;
    const targetTotalAchieved = (targetPercentage / 100) * totalAchievableMonth;
    const pointsStillNeeded = targetTotalAchieved - monthlyStats.totalAchieved;

    // Required performance for remaining days
    const requiredPercentage = (pointsStillNeeded / estimatedRemainingAchievable) * 100;

    let status: 'easy' | 'moderate' | 'hard' | 'critical';
    if (requiredPercentage < 80) status = 'easy';
    else if (requiredPercentage < 95) status = 'moderate';
    else if (requiredPercentage < 105) status = 'hard';
    else status = 'critical';

    return {
      requiredPercentage: Math.round(requiredPercentage * 10) / 10,
      status,
      remainingDays
    };
  };

  const getTrendIcon = (monthlyPercent: number, dailyPercent: number) => {
    if (dailyPercent === 0) return <MinusIcon className="w-4 h-4" />;
    const diff = dailyPercent - monthlyPercent;
    if (diff > 5) return <ArrowUp className="w-4 h-4 text-green-600" />;
    if (diff < -5) return <ArrowDown className="w-4 h-4 text-red-600" />;
    return <MinusIcon className="w-4 h-4 text-gray-400" />;
  };

  const getRequiredPerformanceDisplay = (data: ReturnType<typeof calculateRequiredPerformance>, currentPerf: number) => {
    switch (data.status) {
      case 'exceeded':
        return (
          <div className="bg-green-100 border border-green-300 rounded-lg p-3 mt-3">
            <p className="text-green-900 font-semibold text-sm">
              🎉 Monatsziel bereits erreicht!
            </p>
            <p className="text-green-700 text-xs mt-1">
              Weiter so - jeder Punkt zählt fürs Team!
            </p>
          </div>
        );

      case 'easy':
        return (
          <div className="bg-green-50 border border-green-200 rounded-lg p-3 mt-3">
            <p className="text-green-900 font-semibold text-sm">
              🎯 Benötigt: Ø {data.requiredPercentage}% pro Tag für {data.remainingDays} Tage
            </p>
            <p className="text-green-700 text-xs mt-1">
              ✅ Du liegst bei {currentPerf.toFixed(1)}% - Ziel sicher erreichbar!
            </p>
          </div>
        );

      case 'moderate':
        return (
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mt-3">
            <p className="text-yellow-900 font-semibold text-sm">
              🎯 Benötigt: Ø {data.requiredPercentage}% pro Tag für {data.remainingDays} Tage
            </p>
            <p className="text-yellow-700 text-xs mt-1">
              ⚠️ Du liegst bei {currentPerf.toFixed(1)}% - konstant bleiben!
            </p>
          </div>
        );

      case 'hard':
        return (
          <div className="bg-orange-50 border border-orange-200 rounded-lg p-3 mt-3">
            <p className="text-orange-900 font-semibold text-sm">
              🎯 Benötigt: Ø {data.requiredPercentage}% pro Tag für {data.remainingDays} Tage
            </p>
            <p className="text-orange-700 text-xs mt-1">
              ⚠️ Du liegst bei {currentPerf.toFixed(1)}% - mehr Einsatz nötig!
            </p>
          </div>
        );

      case 'critical':
        return (
          <div className="bg-red-50 border border-red-200 rounded-lg p-3 mt-3">
            <p className="text-red-900 font-semibold text-sm">
              🎯 Benötigt: Ø {data.requiredPercentage}% pro Tag für {data.remainingDays} Tage
            </p>
            <p className="text-red-700 text-xs mt-1">
              ❌ Du liegst bei {currentPerf.toFixed(1)}% - Ziel kaum noch erreichbar!
            </p>
          </div>
        );

      default:
        return null;
    }
  };

  // Sort by monthly percentage
  const sortedStaff = [...staffProfiles].sort((a, b) => {
    const aMonthly = monthlyStats[a.id];
    const bMonthly = monthlyStats[b.id];
    const aPercent = aMonthly?.percentage || 0;
    const bPercent = bMonthly?.percentage || 0;
    return bPercent - aPercent;
  });

  const myMonthlyStats = profile ? monthlyStats[profile.id] : null;
  const myRank = sortedStaff.findIndex((p) => p.id === profile?.id) + 1;
  const myDailyGoal = dailyGoals.find((g) => g.user_id === profile?.id);
  const teamDailyGoal = dailyGoals[0];

  if (loading) {
    return (
      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-200 rounded w-1/3"></div>
          <div className="h-24 bg-gray-200 rounded"></div>
          <div className="h-24 bg-gray-200 rounded"></div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          {onBack && (
            <button
              onClick={onBack}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-gray-700" />
            </button>
          )}
          <h2 className="text-3xl font-bold text-gray-900">🏆 {t('leaderboard.title')}</h2>
        </div>
        {isManager && (
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            <Award className="w-5 h-5" />
            <span>{t('leaderboard.managePoints')}</span>
          </button>
        )}
      </div>

      {/* My Monthly Performance - MAIN FOCUS */}
      {myMonthlyStats && (
        <div className={`rounded-xl p-6 border-2 shadow-lg ${getColorClasses(myMonthlyStats.percentage)}`}>
          <div className="flex items-center space-x-3 mb-4">
            <Award className="w-8 h-8" />
            <h3 className="text-xl font-bold">📊 DEINE MONATLICHE PERFORMANCE</h3>
          </div>

          <div className="flex items-center justify-between mb-4">
            <div>
              <p className="text-sm font-medium mb-1">Platz #{myRank} von {sortedStaff.length}</p>
              <p className="text-3xl font-bold">
                {myMonthlyStats.totalAchieved} / {myMonthlyStats.totalAchievable} Punkte
              </p>
            </div>
            <div className="text-right">
              <p className="text-5xl font-bold">{myMonthlyStats.percentage.toFixed(1)}%</p>
            </div>
          </div>

          {/* Progress Bar */}
          <div className="w-full bg-white bg-opacity-50 rounded-full h-6 mb-2">
            <div
              className="bg-current h-6 rounded-full transition-all duration-500 flex items-center justify-end pr-2"
              style={{ width: `${Math.min(myMonthlyStats.percentage, 100)}%` }}
            >
              <span className="text-xs font-bold text-white drop-shadow">
                {myMonthlyStats.percentage.toFixed(1)}%
              </span>
            </div>
          </div>

          {/* Required Performance */}
          {getRequiredPerformanceDisplay(
            calculateRequiredPerformance(myMonthlyStats),
            myMonthlyStats.percentage
          )}
        </div>
      )}

      {/* Team Monthly Performance - 90% Goal */}
      {Object.keys(monthlyStats).length > 0 && (
        <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl p-6 shadow-lg border-2 border-blue-200">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center space-x-3">
              <Users className="w-8 h-8 text-blue-600" />
              <div>
                <p className="font-bold text-xl text-gray-900">Team-Event Ziel: 90% für diesen Monat</p>
                <p className="text-sm text-gray-600">
                  Gemeinsam schaffen wir das!
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className={`text-4xl font-bold ${
                Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0) /
                Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0) * 100 >= 90
                  ? 'text-green-600'
                  : 'text-gray-900'
              }`}>
                {(
                  (Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0) /
                  Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0)) * 100
                ).toFixed(1)}%
              </p>
            </div>
          </div>
          <div className="w-full bg-white bg-opacity-60 rounded-full h-6 mb-3">
            <div
              className={`h-6 rounded-full transition-all duration-500 flex items-center justify-center ${
                Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0) /
                Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0) * 100 >= 90
                  ? 'bg-green-500'
                  : 'bg-blue-500'
              }`}
              style={{
                width: `${Math.min(
                  (Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0) /
                  Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0)) * 100,
                  100
                )}%`
              }}
            >
              <span className="text-xs font-bold text-white drop-shadow">
                {(
                  (Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0) /
                  Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0)) * 100
                ).toFixed(1)}%
              </span>
            </div>
          </div>
          <div className="flex items-center justify-between text-sm">
            <span className="font-semibold text-gray-700">
              {Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0)} /{' '}
              {Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0)} Punkte
            </span>
            {Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0) /
            Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0) * 100 >= 90 ? (
              <span className="font-bold text-green-600">Team-Event erreicht!</span>
            ) : (
              <span className="text-gray-600">
                Noch{' '}
                {(
                  Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchievable, 0) * 0.9 -
                  Object.values(monthlyStats).reduce((sum, s) => sum + s.totalAchieved, 0)
                ).toFixed(0)}{' '}
                Punkte bis zum Ziel
              </span>
            )}
          </div>
        </div>
      )}

      {/* Team Performance Today */}
      {teamDailyGoal && (
        <div className="bg-white rounded-xl p-5 shadow-md border-2 border-gray-200">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <Users className="w-6 h-6 text-blue-600" />
              <div>
                <p className="font-bold text-lg text-gray-900">Team Performance Heute</p>
                <p className="text-sm text-gray-600">
                  {teamDailyGoal.team_points_earned} / {teamDailyGoal.team_achievable_points} Punkte
                </p>
              </div>
            </div>
            <div className="text-right">
              <p className="text-3xl font-bold text-gray-900">
                {teamDailyGoal.team_achievable_points > 0
                  ? ((teamDailyGoal.team_points_earned / teamDailyGoal.team_achievable_points) * 100).toFixed(1)
                  : 0}%
              </p>
            </div>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-4 mt-3">
            <div
              className={`h-4 rounded-full transition-all duration-500 ${
                teamDailyGoal.team_achievable_points > 0
                  ? getColorClasses((teamDailyGoal.team_points_earned / teamDailyGoal.team_achievable_points) * 100).split(' ')[0]
                  : 'bg-gray-300'
              }`}
              style={{
                width: `${Math.min(
                  teamDailyGoal.team_achievable_points > 0
                    ? (teamDailyGoal.team_points_earned / teamDailyGoal.team_achievable_points) * 100
                    : 0,
                  100
                )}%`
              }}
            />
          </div>
        </div>
      )}

      {/* Staff Ranking */}
      <div>
        <h3 className="text-xl font-bold text-gray-900 mb-4">📋 STAFF RANKING (Monatlich)</h3>
        <div className="space-y-3">
          {sortedStaff.map((user, index) => {
            const userMonthly = monthlyStats[user.id];
            const userDaily = dailyGoals.find((g) => g.user_id === user.id);
            const isCurrentUser = user.id === profile?.id;

            if (!userMonthly) return null;

            return (
              <div
                key={user.id}
                className={`rounded-xl p-5 border-2 shadow-sm transition-all ${
                  isCurrentUser
                    ? `${getColorClasses(userMonthly.percentage)} border-blue-500 border-4`
                    : getColorClasses(userMonthly.percentage)
                }`}
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center space-x-3">
                    <div className="flex items-center justify-center w-10 h-10">
                      {getRankIcon(index)}
                    </div>
                    <div>
                      <h3 className="font-bold text-lg">{user.full_name}</h3>
                      {isCurrentUser && <span className="text-xs font-semibold">← DU</span>}
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-2xl font-bold">
                      {userMonthly.totalAchieved} / {userMonthly.totalAchievable}
                    </p>
                    <p className="text-3xl font-bold">{userMonthly.percentage.toFixed(1)}%</p>
                  </div>
                </div>

                {/* Progress Bar */}
                <div className="w-full bg-white bg-opacity-50 rounded-full h-3 mb-2">
                  <div
                    className="bg-current h-3 rounded-full transition-all duration-500"
                    style={{ width: `${Math.min(userMonthly.percentage, 100)}%` }}
                  />
                </div>

                {/* Today's Performance */}
                {userDaily && (
                  <div className="flex items-center justify-between text-sm">
                    <div className="flex items-center space-x-2">
                      <span className="font-medium">Heute:</span>
                      <span>
                        {userDaily.achieved_points}/{userDaily.theoretically_achievable_points}
                        ({userDaily.percentage.toFixed(1)}%)
                      </span>
                      {getTrendIcon(userMonthly.percentage, userDaily.percentage)}
                    </div>
                    <button
                      onClick={() => handleViewHistory(user.id)}
                      className="px-3 py-1 text-xs bg-white bg-opacity-50 rounded-lg hover:bg-opacity-100 transition-colors font-medium"
                    >
                      {t('common.history')}
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>

      {showModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowModal(false);
            setSelectedUserId('');
            setPointsForm({ points: 0, reason: '' });
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">{t('leaderboard.managePoints')}</h3>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t('leaderboard.staffMember')}
                </label>
                <select
                  value={selectedUserId}
                  onChange={(e) => setSelectedUserId(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                >
                  <option value="">{t('leaderboard.selectStaff')}</option>
                  {staffProfiles.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.full_name} ({p.total_points} pts)
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t('leaderboard.pointsNote')}
                </label>
                <div className="flex space-x-2">
                  <button
                    type="button"
                    onClick={() => setPointsForm({ ...pointsForm, points: pointsForm.points - 10 })}
                    className="px-3 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200"
                  >
                    <Minus className="w-4 h-4" />
                  </button>
                  <input
                    type="number"
                    value={pointsForm.points}
                    onChange={(e) =>
                      setPointsForm({ ...pointsForm, points: parseInt(e.target.value) || 0 })
                    }
                    className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-center"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setPointsForm({ ...pointsForm, points: pointsForm.points + 10 })}
                    className="px-3 py-2 bg-green-100 text-green-700 rounded-lg hover:bg-green-200"
                  >
                    <Plus className="w-4 h-4" />
                  </button>
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t('leaderboard.reason')}
                </label>
                <textarea
                  value={pointsForm.reason}
                  onChange={(e) => setPointsForm({ ...pointsForm, reason: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={3}
                  required
                />
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  {t('common.cancel')}
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  {t('common.apply')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {historyUserId && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => setHistoryUserId(null)}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[80vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900">{t('leaderboard.pointsHistory')}</h3>
              <button
                onClick={() => setHistoryUserId(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <Plus className="w-6 h-6 rotate-45" />
              </button>
            </div>
            <div className="space-y-3">
              {history.map((entry) => (
                <div
                  key={entry.id}
                  className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
                >
                  <div className="flex-1">
                    <p className="font-medium text-gray-900">{entry.reason}</p>
                    <p className="text-sm text-gray-600">
                      {new Date(entry.created_at).toLocaleString()}
                    </p>
                  </div>
                  <span
                    className={`text-xl font-bold ${
                      entry.points_change > 0 ? 'text-green-600' : 'text-red-600'
                    }`}
                  >
                    {entry.points_change > 0 ? '+' : ''}
                    {entry.points_change}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
