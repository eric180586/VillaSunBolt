import { useAuth } from '../contexts/AuthContext';
import { useMonthlyProgress, useTeamMonthlyProgress } from '../hooks/useDailyPointGoals';
import { Trophy, Target, Users } from 'lucide-react';
import { useTranslation } from 'react-i18next';

export function MonthlyGoalProgress() {
  const { profile } = useAuth();
  const { monthlyProgress, loading: loadingPersonal } = useMonthlyProgress(profile?.id);
  const { teamProgress, loading: loadingTeam } = useTeamMonthlyProgress();
  const { t } = useTranslation();

  if (loadingPersonal || loadingTeam) {
    return (
      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <div className="animate-pulse space-y-4">
          <div className="h-6 bg-gray-200 rounded w-1/3"></div>
          <div className="h-4 bg-gray-200 rounded w-2/3"></div>
        </div>
      </div>
    );
  }

  const personalPercentage = monthlyProgress?.percentage || 0;
  const personalAchieved = monthlyProgress?.total_achieved || 0;
  const personalTotal = monthlyProgress?.total_achievable || 0;
  const personalColor = monthlyProgress?.color_status || 'red';
  const personal90Achieved = monthlyProgress?.achieved_90_percent || false;

  const teamPercentage = teamProgress?.percentage || 0;
  const teamAchieved = teamProgress?.total_achieved || 0;
  const teamTotal = teamProgress?.total_achievable || 0;
  const teamColor = teamProgress?.color_status || 'red';
  const teamEventUnlocked = teamProgress?.team_event_unlocked || false;

  const getColorClasses = (color: string) => {
    switch (color) {
      case 'dark_green':
        return {
          bg: 'bg-green-200',
          text: 'text-green-900',
          border: 'border-green-600',
          progress: 'bg-green-800',
        };
      case 'green':
        return {
          bg: 'bg-green-100',
          text: 'text-green-700',
          border: 'border-green-500',
          progress: 'bg-green-500',
        };
      case 'orange':
        return {
          bg: 'bg-orange-100',
          text: 'text-orange-700',
          border: 'border-orange-500',
          progress: 'bg-orange-500',
        };
      case 'yellow':
        return {
          bg: 'bg-yellow-100',
          text: 'text-yellow-700',
          border: 'border-yellow-500',
          progress: 'bg-yellow-500',
        };
      case 'red':
        return {
          bg: 'bg-red-100',
          text: 'text-red-700',
          border: 'border-red-500',
          progress: 'bg-red-500',
        };
      default:
        return {
          bg: 'bg-gray-100',
          text: 'text-gray-700',
          border: 'border-gray-500',
          progress: 'bg-gray-500',
        };
    }
  };

  const personalColors = getColorClasses(personalColor);
  const teamColors = getColorClasses(teamColor);

  return (
    <div className="space-y-6">
      <div className={`rounded-xl p-6 shadow-lg border-2 ${personalColors.border} ${personalColors.bg}`}>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <Target className={`w-8 h-8 ${personalColors.text}`} />
            <div>
              <h3 className="text-xl font-bold text-gray-900">Dein Monatsziel</h3>
              <p className="text-sm text-gray-600">90% = Bonus freischalten</p>
            </div>
          </div>
          {personal90Achieved && (
            <div className="flex items-center space-x-2 bg-white px-4 py-2 rounded-full shadow-md">
              <Trophy className="w-6 h-6 text-yellow-500" />
              <span className="font-bold text-green-600">Bonus freigeschaltet!</span>
            </div>
          )}
        </div>

        <div className="mb-4">
          <div className="flex items-center justify-between mb-2">
            <span className={`text-3xl font-bold ${personalColors.text}`}>
              {personalAchieved} / {personalTotal}
            </span>
            <span className={`text-3xl font-bold ${personalColors.text}`}>
              {personalPercentage.toFixed(1)}%
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-6 overflow-hidden">
            <div
              className={`h-6 ${personalColors.progress} transition-all duration-500 flex items-center justify-end px-2`}
              style={{ width: `${Math.min(personalPercentage, 100)}%` }}
            >
              {personalPercentage >= 20 && (
                <span className="text-xs font-bold text-white">
                  {personalPercentage.toFixed(0)}%
                </span>
              )}
            </div>
          </div>
        </div>

        {personal90Achieved ? (
          <div className="bg-white rounded-lg p-4 border-2 border-yellow-400">
            <p className="text-lg font-bold text-green-700 flex items-center space-x-2">
              <Trophy className="w-5 h-5" />
              <span>Fantastisch! Du hast dein Monatsziel erreicht! 🎉</span>
            </p>
            <p className="text-sm text-gray-700 mt-1">
              Du erhältst deinen Bonus am Monatsende. Weiter so!
            </p>
          </div>
        ) : (
          <div className="bg-white rounded-lg p-4">
            <p className="text-sm text-gray-700">
              <strong>Noch {(90 - personalPercentage).toFixed(1)}%</strong> bis zum Bonus!
              {personalPercentage >= 70 && personalPercentage < 90 && (
                <span className="text-yellow-600 font-semibold"> Du bist fast da! 💪</span>
              )}
              {personalPercentage < 70 && (
                <span className="text-red-600 font-semibold"> Gib nicht auf! 🚀</span>
              )}
            </p>
          </div>
        )}
      </div>

      <div className={`rounded-xl p-6 shadow-lg border-2 ${teamColors.border} ${teamColors.bg}`}>
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <Users className={`w-8 h-8 ${teamColors.text}`} />
            <div>
              <h3 className="text-xl font-bold text-gray-900">Team Monatsziel</h3>
              <p className="text-sm text-gray-600">90% = Team-Event</p>
            </div>
          </div>
          {teamEventUnlocked && (
            <div className="flex items-center space-x-2 bg-white px-4 py-2 rounded-full shadow-md">
              <Trophy className="w-6 h-6 text-yellow-500" />
              <span className="font-bold text-green-600">Team-Event freigeschaltet!</span>
            </div>
          )}
        </div>

        <div className="mb-4">
          <div className="flex items-center justify-between mb-2">
            <span className={`text-3xl font-bold ${teamColors.text}`}>
              {teamAchieved} / {teamTotal}
            </span>
            <span className={`text-3xl font-bold ${teamColors.text}`}>
              {teamPercentage.toFixed(1)}%
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-6 overflow-hidden">
            <div
              className={`h-6 ${teamColors.progress} transition-all duration-500 flex items-center justify-end px-2`}
              style={{ width: `${Math.min(teamPercentage, 100)}%` }}
            >
              {teamPercentage >= 20 && (
                <span className="text-xs font-bold text-white">
                  {teamPercentage.toFixed(0)}%
                </span>
              )}
            </div>
          </div>
        </div>

        {teamEventUnlocked ? (
          <div className="bg-white rounded-lg p-4 border-2 border-yellow-400">
            <p className="text-lg font-bold text-green-700 flex items-center space-x-2">
              <Trophy className="w-5 h-5" />
              <span>Unglaublich! Das Team hat es geschafft! 🎊</span>
            </p>
            <p className="text-sm text-gray-700 mt-1">
              Team-Event wird am Monatsende bekannt gegeben!
            </p>
          </div>
        ) : (
          <div className="bg-white rounded-lg p-4">
            <div className="flex items-center space-x-2 mb-2">
              <TrendingUp className="w-5 h-5 text-blue-600" />
              <p className="text-sm font-semibold text-gray-700">
                Gemeinsam zum Ziel!
              </p>
            </div>
            <p className="text-sm text-gray-700">
              <strong>Noch {(90 - teamPercentage).toFixed(1)}%</strong> bis zum Team-Event!
              {teamPercentage >= 70 && teamPercentage < 90 && (
                <span className="text-yellow-600 font-semibold"> Wir sind fast da! 💪</span>
              )}
              {teamPercentage < 70 && (
                <span className="text-red-600 font-semibold"> Zusammen schaffen wir das! 🚀</span>
              )}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
