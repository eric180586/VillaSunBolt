import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useProfiles } from '../hooks/useProfiles';
import { User, Mail, Award, Shield, Calendar, Globe, Bell } from 'lucide-react';
import { PushNotificationToggle } from './PushNotificationToggle';
import { useTranslation } from 'react-i18next';

export function Profile({ onBack: _onBack }: { onBack?: () => void } = {}) {
  const { profile, updateLanguage } = useAuth();
  const { getPointsHistory } = useProfiles();
  const { t } = useTranslation();
  const [history, setHistory] = useState<any[]>([]);
  const [showHistory, setShowHistory] = useState(false);

  const loadHistory = async () => {
    if (!profile) return;
    try {
      const data = await getPointsHistory(profile.id);
      // Sort by date to group entries per day
      const sorted = data.sort((a, b) =>
        (b.created_at ? new Date(b.created_at).getTime() : new Date().getTime()) - (a.created_at ? new Date(a.created_at).getTime() : new Date().getTime())
      );
      setHistory(sorted);
      setShowHistory(true);
    } catch (error) {
      console.error('Error loading history:', error);
    }
  };

  const handleLanguageChange = async (language: 'de' | 'en' | 'km') => {
    try {
      await updateLanguage(language);
    } catch (error) {
      console.error('Error updating language:', error);
      alert(t('common.error'));
    }
  };

  if (!profile) return null;

  return (
    <div className="space-y-6">
      <h2 className="text-3xl font-bold text-gray-900">{t('profile.title')}</h2>

      <div className="bg-white rounded-xl p-8 shadow-sm border border-gray-200">
        <div className="flex items-start space-x-6">
          <div className="w-24 h-24 bg-gradient-to-br from-blue-500 to-blue-600 rounded-full flex items-center justify-center text-white font-bold text-4xl">
            {profile.full_name.charAt(0)}
          </div>
          <div className="flex-1">
            <h3 className="text-2xl font-bold text-gray-900 mb-2">{profile.full_name}</h3>
            <div className="space-y-2">
              <div className="flex items-center space-x-2 text-gray-600">
                <Mail className="w-5 h-5" />
                <span>{profile.email}</span>
              </div>
              <div className="flex items-center space-x-2 text-gray-600">
                <Shield className="w-5 h-5" />
                <span className="capitalize">{profile.role}</span>
              </div>
              <div className="flex items-center space-x-2 text-gray-600">
                <Calendar className="w-5 h-5" />
                <span>{t('profile.memberSince')} {profile.created_at ? new Date(profile.created_at).toLocaleDateString() : new Date().toLocaleDateString()}</span>
              </div>
              <div className="flex items-center space-x-2 text-gray-600">
                <Globe className="w-5 h-5" />
                <select
                  value={profile.preferred_language || ''}
                  onChange={(e: any) => handleLanguageChange(e.target.value as 'de' | 'en' | 'km')}
                  className="px-3 py-1 border border-gray-300 rounded-lg bg-white text-gray-900 font-medium"
                >
                  <option value="de">{t('languages.de')}</option>
                  <option value="en">{t('languages.en')}</option>
                  <option value="km">{t('languages.km')}</option>
                </select>
              </div>

      {/* Push notifications toggle */}
      <div className="flex items-center space-x-2 text-gray-600">
        <Bell className="w-5 h-5" />
        <PushNotificationToggle />
      </div>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-gradient-to-r from-yellow-500 to-yellow-600 rounded-xl p-8 text-white shadow-lg">
        <div className="flex items-center justify-between">
          <div>
            <div className="flex items-center space-x-2 mb-2">
              <Award className="w-6 h-6" />
              <span className="text-lg font-medium">{t('profile.totalPoints')}</span>
            </div>
            <h3 className="text-5xl font-bold">{profile.total_points}</h3>
          </div>
          <button
            onClick={loadHistory}
            className="bg-white text-yellow-600 px-6 py-3 rounded-lg font-semibold hover:bg-yellow-50 transition-colors"
          >
            {t('profile.viewHistory')}
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <div className="text-center">
            <User className="w-12 h-12 text-blue-500 mx-auto mb-3" />
            <h4 className="text-lg font-semibold text-gray-900 mb-1">{t('profile.accountType')}</h4>
            <p className="text-2xl font-bold text-blue-600 capitalize">{profile.role}</p>
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <div className="text-center">
            <Award className="w-12 h-12 text-yellow-500 mx-auto mb-3" />
            <h4 className="text-lg font-semibold text-gray-900 mb-1">{t('profile.pointsRank')}</h4>
            <p className="text-2xl font-bold text-yellow-600">#1</p>
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <div className="text-center">
            <Calendar className="w-12 h-12 text-green-500 mx-auto mb-3" />
            <h4 className="text-lg font-semibold text-gray-900 mb-1">{t('profile.memberSince')}</h4>
            <p className="text-sm font-medium text-green-600">
              {profile.created_at ? new Date(profile.created_at).toLocaleDateString() : new Date().toLocaleDateString()}
            </p>
          </div>
        </div>
      </div>

      {showHistory && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => setShowHistory(false)}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[80vh] overflow-y-auto"
            onClick={(e: any) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-6">
              <h3 className="text-2xl font-bold text-gray-900">{t('profile.pointsHistory')}</h3>
              <button
                onClick={() => setShowHistory(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                ✕
              </button>
            </div>
            {history.length === 0 ? (
              <p className="text-center text-gray-600 py-8">{t('profile.noHistory')}</p>
            ) : (
              <div className="space-y-4">
                {/* Group by date */}
                {Object.entries(
                  history.reduce((acc, entry) => {
                    const dateKey = entry.created_at ? new Date(entry.created_at).toLocaleDateString() : new Date().toLocaleDateString();
                    if (!acc[dateKey]) acc[dateKey] = [];
                    acc[dateKey].push(entry);
                    return acc;
                  }, {} as Record<string, typeof history>)
                ).map(([date, entries]: [string, any]) => {
                  const dayTotal = (entries as any[]).reduce((sum: number, e: any) => sum + e.points_change, 0);
                  const dayAchievable = (entries as any[])[0]?.daily_achievable || 0;
                  const dayAchieved = (entries as any[])[0]?.daily_achieved || 0;

                  return (
                    <div key={date} className="border-2 border-gray-200 rounded-lg overflow-hidden">
                      {/* Day Header */}
                      <div className="bg-gradient-to-r from-blue-50 to-purple-50 p-3 border-b-2 border-gray-200">
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="font-bold text-gray-900">{String(date)}</p>
                            {dayAchievable > 0 && (
                              <p className="text-sm text-gray-600">
                                Daily: {dayAchieved}/{dayAchievable} pts ({((dayAchieved/dayAchievable)*100).toFixed(0)}%)
                              </p>
                            )}
                          </div>
                          <span className={`text-lg font-bold ${
                            dayTotal > 0 ? 'text-green-600' : dayTotal < 0 ? 'text-red-600' : 'text-gray-600'
                          }`}>
                            {dayTotal > 0 ? '+' : ''}{dayTotal}
                          </span>
                        </div>
                      </div>
                      {/* Day Entries */}
                      <div className="divide-y divide-gray-200">
                        {(entries as any[]).map((entry: any) => (
                          <div
                            key={entry.id}
                            className="flex items-center justify-between p-3 bg-white hover:bg-gray-50"
                          >
                            <div className="flex-1">
                              <p className="font-medium text-gray-900 text-sm">{entry.reason}</p>
                              <span className="text-xs text-gray-500 capitalize">
                                {entry.category.replace('_', ' ')}
                              </span>
                            </div>
                            <span
                              className={`text-lg font-bold ml-3 ${
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
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
