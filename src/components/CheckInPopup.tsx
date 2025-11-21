import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import { CheckCircle, Clock, X, AlertCircle } from 'lucide-react';
import { useTranslation } from 'react-i18next';

interface CheckInPopupProps {
  onClose: () => void;
}

export function CheckInPopup({ onClose }: CheckInPopupProps) {
  const { profile } = useAuth();
  const { t } = useTranslation();
  const [loading, setLoading] = useState(false);
  const [checkInResult, setCheckInResult] = useState<any>(null);
  const [hasScheduleToday, setHasScheduleToday] = useState<boolean | null>(null);
  const [scheduledShift, setScheduledShift] = useState<string | null>(null);

  useEffect(() => {
    checkScheduleForToday();
  }, [profile]);

  const checkScheduleForToday = async () => {
    if (!profile?.id) return;

    try {
      const today = getTodayDateString();

      const { data, error } = await supabase
        .from('weekly_schedules')
        .select('shifts')
        .eq('staff_id', profile.id)
        .eq('is_published', true);

      if (error) throw error;

      if (!data || data.length === 0) {
        setHasScheduleToday(false);
        return;
      }

      let todayShift = null;
      for (const schedule of data) {
        const shift = (schedule.shifts as any[])?.find(
          (s: any) => s.date === today
        );
        if (shift) {
          todayShift = shift;
          break;
        }
      }

      if (!todayShift || todayShift.shift === 'off') {
        setHasScheduleToday(false);
        setScheduledShift(null);
      } else {
        setHasScheduleToday(true);
        setScheduledShift(todayShift.shift);
      }
    } catch (error) {
      console.error('Error checking schedule:', error);
      setHasScheduleToday(false);
    }
  };

  const handleCheckIn = async () => {
    if (!profile?.id) return;

    if (!scheduledShift) {
      alert('No shift scheduled for today');
      return;
    }

    setLoading(true);

    try {
      const mappedShiftType = scheduledShift === 'morning' ? 'early' : 'late';

      console.log('[CHECK-IN POPUP] Calling process_check_in with:', {
        p_user_id: profile.id,
        p_shift_type: mappedShiftType
      });

      const { data, error } = await supabase.rpc('process_check_in', {
        p_user_id: profile.id,
        p_shift_type: mappedShiftType,
        p_late_reason: null,
      });

      console.log('[CHECK-IN POPUP] Response:', { data, error });

      if (error) throw error;

      setCheckInResult(data);

      setTimeout(() => {
        onClose();
      }, 3000);
    } catch (error) {
      console.error('Error checking in:', error);
      alert(t('checkin.errorCheckingIn', 'Error checking in. Please try again.'));
      setLoading(false);
    }
  };

  const handleSkip = () => {
    onClose();
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl p-8 w-full max-w-2xl shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-3xl font-bold text-gray-900">{t('checkin.welcomeBack', 'Willkommen zurück!')}</h2>
          <button
            onClick={handleSkip}
            className="text-gray-400 hover:text-gray-600"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {checkInResult ? (
          <div className={`p-6 rounded-xl ${
            checkInResult.is_late ? 'bg-orange-50 border-2 border-orange-500' : 'bg-green-50 border-2 border-green-500'
          }`}>
            <div className="flex items-center space-x-4">
              {checkInResult.is_late ? (
                <Clock className="w-16 h-16 text-orange-600" />
              ) : (
                <CheckCircle className="w-16 h-16 text-green-600" />
              )}
              <div className="flex-1">
                <h3 className="text-2xl font-bold text-gray-900 mb-2">
                  {t('checkin.checkInSuccessful', 'Check-In erfolgreich!')}
                </h3>
                {checkInResult.is_late ? (
                  <p className="text-orange-700 mb-2">
                    {t('checkin.minutesLate', 'Du bist {{minutes}} Minuten zu spät', { minutes: checkInResult.minutes_late })}
                  </p>
                ) : (
                  <p className="text-green-700 mb-2">
                    {t('checkin.onTime', 'Pünktlich eingecheckt!')}
                  </p>
                )}
                <p className="text-gray-700">
                  {t('checkin.waitingForApproval', 'Dein Check-In wartet auf Admin-Bestätigung.')}
                </p>
                <p className="text-sm text-gray-600 mt-2">
                  {t('checkin.possiblePoints', 'Mögliche Punkte: {{points}}', { points: (checkInResult.points_awarded > 0 ? '+' : '') + checkInResult.points_awarded })}
                </p>
              </div>
            </div>
          </div>
        ) : hasScheduleToday === false ? (
          <div className="text-center">
            <AlertCircle className="w-20 h-20 text-gray-400 mx-auto mb-4" />
            <h3 className="text-xl font-bold text-gray-900 mb-2">
              {t('checkin.noScheduleToday', 'Kein Dienstplan für heute')}
            </h3>
            <p className="text-gray-600 mb-6">
              {t('checkin.noScheduleMessage', 'Du bist heute nicht eingeplant. Check-In ist nur an Arbeitstagen möglich.')}
            </p>
            <p className="text-sm text-gray-500 mb-6">
              {t('checkin.readOnlyMode', 'Du kannst weiterhin Notes schreiben und Freiwünsche abgeben.')}
            </p>
            <button
              onClick={handleSkip}
              className="w-full py-3 bg-gray-200 text-gray-900 rounded-lg hover:bg-gray-300 font-medium"
            >
              {t('common.close', 'Schließen')}
            </button>
          </div>
        ) : (
          <>
            <p className="text-gray-600 mb-6 text-lg">
              {t('checkin.pleaseCheckIn', 'Bitte checke dich für deine Schicht ein')}
            </p>

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <h4 className="font-semibold text-blue-900 mb-2">{t('checkin.important', 'Wichtig:')}</h4>
              <ul className="space-y-1 text-sm text-blue-800">
                <li>✓ {t('checkin.adminNotified', 'Admin erhält Benachrichtigung')}</li>
                <li>✓ {t('checkin.pointsAfterApproval', 'Nach Bestätigung erhältst du deine Punkte')}</li>
                <li>✓ {t('checkin.onTimePoints', 'Pünktlich: +5 Punkte')}</li>
                <li>✓ {t('checkin.latePointsDeduction', 'Pro 5 Min. zu spät: -1 Punkt')}</li>
              </ul>
            </div>

            <button
              onClick={handleCheckIn}
              disabled={loading}
              className="w-full flex flex-col items-center justify-center p-12 bg-gradient-to-br from-blue-500 to-blue-600 text-white rounded-xl hover:shadow-2xl hover:from-blue-600 hover:to-blue-700 transform hover:scale-105 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg mb-6"
            >
              <CheckCircle className="w-20 h-20 mb-4" />
              <span className="font-bold text-2xl">{t('checkin.checkInNow', 'Jetzt Einchecken')}</span>
              <span className="text-sm text-blue-100 mt-2">{t('checkin.autoDetect', 'Das System erkennt deine Schicht automatisch')}</span>
            </button>

            <button
              onClick={handleSkip}
              className="w-full py-3 text-gray-600 hover:text-gray-900 font-medium"
            >
              {t('checkin.checkInLater', 'Später einchecken')}
            </button>
          </>
        )}
      </div>
    </div>
  );
}
