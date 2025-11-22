import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import { CheckCircle, XCircle, Clock, Award, AlertCircle, Trophy, ArrowLeft } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { FortuneWheel } from './FortuneWheel';
import type { CheckInResult, CheckIn, ScheduleShift, FortuneWheelSegment } from '../types/common';

export function CheckIn({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const { t } = useTranslation();
  const [checkInResult, setCheckInResult] = useState<CheckInResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [todayCheckIns, setTodayCheckIns] = useState<CheckIn[]>([]);
  const [hasScheduleToday, setHasScheduleToday] = useState<boolean | null>(null);
  const [scheduledShift, setScheduledShift] = useState<string | null>(null);
  const [showFortuneWheel, setShowFortuneWheel] = useState(false);
  const [currentCheckInId, setCurrentCheckInId] = useState<string | null>(null);
  const [alreadySpunToday, setAlreadySpunToday] = useState(false);
  const [isCheckingWheel, setIsCheckingWheel] = useState(false);
  const [showLateReasonDialog, setShowLateReasonDialog] = useState(false);
  const [lateReason, setLateReason] = useState('');
  const [pendingShiftType, setPendingShiftType] = useState<'früh' | 'spät' | null>(null);

  useEffect(() => {
    if (profile?.id) {
      fetchTodayCheckIns();
      checkScheduleForToday();
      checkIfAlreadySpunToday();

      // Only check for missed wheel after a delay to avoid race conditions with manual check-in
      const wheelCheckTimer = setTimeout(() => {
        checkForMissedFortuneWheel();
      }, 1000);

      const channel = supabase
        .channel(`check_ins_changes_${Date.now()}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'check_ins',
            filter: `user_id=eq.${profile.id}`,
          },
          () => {
            fetchTodayCheckIns();
            // Don't trigger checkForMissedFortuneWheel here to avoid closing an open wheel
          }
        )
        .subscribe();

      return () => {
        clearTimeout(wheelCheckTimer);
        supabase.removeChannel(channel);
      };
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile]);

  const checkIfAlreadySpunToday = async () => {
    if (!profile?.id) return false;

    const today = getTodayDateString();

    const { data, error } = await supabase
      .from('fortune_wheel_spins')
      .select('id')
      .eq('user_id', profile.id)
      .eq('spin_date', today)
      .maybeSingle() as any;

    const hasSpun = !error && !!data;
    setAlreadySpunToday(hasSpun);
    return hasSpun;
  };

  const checkForMissedFortuneWheel = async () => {
    if (!profile?.id || isCheckingWheel) {
      console.log('checkForMissedFortuneWheel: No profile ID or already checking');
      return;
    }

    setIsCheckingWheel(true);
    try {
      const today = getTodayDateString();
      console.log('checkForMissedFortuneWheel: Today date string:', today);

      const hasSpun = await checkIfAlreadySpunToday();
      console.log('checkForMissedFortuneWheel: Already spun?', hasSpun);

      if (hasSpun) {
        console.log('checkForMissedFortuneWheel: Already spun today, skipping');
        return;
      }

      // Check for check-in today (any status, not just approved)
      const { data: checkInData, error: checkInError } = await supabase
        .from('check_ins')
        .select('id, status, check_in_date')
        .eq('user_id', profile.id)
        .eq('check_in_date', today)
        .maybeSingle() as { data: { id: string; status: string; check_in_date: string } | null; error: any };

      console.log('checkForMissedFortuneWheel: Check-in data:', checkInData, 'Error:', checkInError);

      if (checkInData) {
        console.log('Found check-in without fortune wheel spin!', checkInData.id);
        console.log('Check-in status:', checkInData.status);

        if (!showFortuneWheel) {
          console.log('Opening Fortune Wheel NOW!');
          setCurrentCheckInId(checkInData.id);
          setShowFortuneWheel(true);
        } else {
          console.log('Fortune Wheel already showing, not opening again');
        }
      } else {
        console.log('checkForMissedFortuneWheel: No check-in found for today');
      }
    } finally {
      setIsCheckingWheel(false);
    }
  };

  const checkScheduleForToday = async () => {
    if (!profile?.id) return;

    try {
      const today = getTodayDateString();
      console.log('Checking schedule for date:', today);

      const { data, error } = await supabase
        .from('weekly_schedules')
        .select('shifts')
        .eq('staff_id', profile.id)
        .eq('is_published', true) as { data: Array<{ shifts: any }> | null; error: any };

      console.log('Schedule query result:', { data, error }) as any;

      if (error) {
        console.error('Schedule query error:', error);
        setHasScheduleToday(true);
        setScheduledShift('morning');
        return;
      }

      if (!data || data.length === 0) {
        console.log('No schedules found for user - allowing check-in anyway');
        setHasScheduleToday(true);
        setScheduledShift('morning');
        return;
      }

      let todayShift = null;
      for (const schedule of data) {
        console.log('Checking schedule:', schedule);
        const shift = (schedule.shifts as ScheduleShift[])?.find(
          (s: any) => {
            console.log('Comparing shift date:', s.date, 'with today:', today);
            return s.date === today;
          }
        );
        if (shift) {
          console.log('Found shift for today:', shift);
          todayShift = shift;
          break;
        }
      }

      if (!todayShift || todayShift.shift === 'off') {
        console.log('No valid shift for today (off day or not found) - allowing check-in anyway');
        setHasScheduleToday(true);
        setScheduledShift('morning');
      } else {
        console.log('User has shift today:', todayShift.shift);
        setHasScheduleToday(true);
        setScheduledShift(todayShift.shift);
      }
    } catch (error) {
      console.error('Error checking schedule:', error);
      setHasScheduleToday(true);
      setScheduledShift('morning');
    }
  };

  const fetchTodayCheckIns = async () => {
    if (!profile?.id) return;

    const today = getTodayDateString();

    const { data, error } = await supabase
      .from('check_ins')
      .select('*')
      .eq('user_id', profile.id)
      .eq('check_in_date', today)
      .order('check_in_time', { ascending: false}) as any;

    if (error) {
      console.error('Error fetching check-ins:', error);
      return;
    }

    setTodayCheckIns(data || []);
  };

  const handleCheckIn = async () => {
    console.log('[CHECK-IN] handleCheckIn called');
    console.log('[CHECK-IN] Profile:', profile);
    console.log('[CHECK-IN] Scheduled shift:', scheduledShift);

    if (!profile?.id) {
      console.error('[CHECK-IN] BLOCKED: No profile ID!', profile);
      alert('Error: Profile not loaded. Please refresh the page.');
      return;
    }

    if (!scheduledShift) {
      alert('No shift scheduled for today');
      return;
    }

    const shiftType = scheduledShift === 'morning' ? 'früh' : 'spät';

    const now = new Date();
    const cambodiaTime = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Phnom_Penh',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).format(now);

    const [hours, minutes] = cambodiaTime.split(':').map(Number);
    const currentTime = hours * 60 + minutes;
    const shiftStartTime = shiftType === 'früh' ? 9 * 60 : 15 * 60;
    const isLate = currentTime > shiftStartTime;

    if (isLate) {
      setPendingShiftType(shiftType);
      setShowLateReasonDialog(true);
      return;
    }

    await performCheckIn(shiftType, null);
  };

  const performCheckIn = async (shiftType: 'früh' | 'spät', reason: string | null) => {
    if (!profile?.id) return;

    setLoading(true);
    setCheckInResult(null);

    try {
      // Map German shift types to English for database
      const mappedShiftType = shiftType === 'früh' ? 'early' : 'late';

      console.log('[CHECK-IN] Starting check-in with params:', {
        user_id: profile.id,
        shift_type: mappedShiftType,
        late_reason: reason
      }) as any;

      const { data, error } = await supabase.rpc('process_check_in', {
        p_user_id: profile.id,
        p_shift_type: mappedShiftType,
        p_late_reason: reason,
      }) as any;

      console.log('[CHECK-IN] RPC Response:', { data, error }) as any;

      if (error) {
        console.error('[CHECK-IN] RPC ERROR:', error);

        if (error.message?.includes('JWT') || error.message?.includes('token') || error.message?.includes('session')) {
          alert('Your session has expired. Please log out and log in again.');
        } else {
          alert(`Check-in failed: ${error.message || JSON.stringify(error)}`);
        }
        throw error;
      }

      if (!data) {
        console.error('[CHECK-IN] No data returned from RPC');
        alert('Check-in failed: No response from server');
        return;
      }

      console.log('[CHECK-IN] Full response data:', JSON.stringify(data, null, 2));

      setCheckInResult(data);
      await fetchTodayCheckIns();

      if (data?.success && data?.check_in_id) {
        console.log('Check-in successful, checking fortune wheel status...');

        if (data?.show_fortune_wheel) {
          console.log('Opening Fortune Wheel for check-in:', data.check_in_id);
          setCurrentCheckInId(data.check_in_id);
          setShowFortuneWheel(true);
        } else {
          console.log('Backend says no fortune wheel for this check-in');
        }
      } else {
        console.log('Check-in response missing required data:', data);
      }

      setTimeout(() => {
        setCheckInResult(null);
      }, 5000);
    } catch (error) {
      console.error('Error checking in:', error);
      alert('Error checking in. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleLateReasonSubmit = () => {
    if (pendingShiftType && lateReason.trim()) {
      setShowLateReasonDialog(false);
      performCheckIn(pendingShiftType, lateReason.trim());
      setLateReason('');
      setPendingShiftType(null);
    }
  };

  const handleLateReasonCancel = () => {
    setShowLateReasonDialog(false);
    setLateReason('');
    setPendingShiftType(null);
  };

  const handleFortuneWheelComplete = async (segment: FortuneWheelSegment) => {
    if (!profile?.id || !currentCheckInId) {
      console.error('handleFortuneWheelComplete: Missing profile or check-in ID');
      return;
    }

    try {
      const today = getTodayDateString();

      console.log('Fortune Wheel Complete:', {
        user_id: profile.id,
        check_in_id: currentCheckInId,
        segment: segment,
        actualPoints: segment.actualPoints
      }) as any;

      const hasSpun = await checkIfAlreadySpunToday();
      if (hasSpun) {
        console.log('User already spun today, not saving again');
        return;
      }

      const { error } = await supabase
        .from('fortune_wheel_spins')
        .insert([{
          user_id: profile.id,
          check_in_id: currentCheckInId,
          spin_date: today,
          points_won: segment.actualPoints || 0,
          reward_type: segment.rewardType,
          reward_value: segment.rewardValue,
          reward_label: segment.label,
        }] as any);

      if (error) {
        console.error('Error inserting spin:', error);
        throw error;
      }

      console.log('Spin saved successfully');

      if (segment.rewardType === 'bonus_points' && segment.actualPoints !== 0) {
        console.log('Adding bonus points:', segment.actualPoints);
        const { data: pointsData, error: pointsError } = await supabase.rpc('add_bonus_points', {
          p_user_id: profile.id,
          p_points: segment.actualPoints,
          p_reason: `${t('fortuneWheel.title')}: ${segment.label}`,
        }) as any;

        if (pointsError) {
          console.error('Error adding bonus points:', pointsError);
        } else {
          console.log('Bonus points added successfully:', pointsData);
        }
      } else {
        console.log('No bonus points to add (actualPoints is 0)');
      }

      setAlreadySpunToday(true);
      await checkIfAlreadySpunToday();
    } catch (error) {
      console.error('Error saving fortune wheel spin:', error);
    }
  };

  const handleCloseFortuneWheel = () => {
    console.log('Closing fortune wheel');
    setShowFortuneWheel(false);
    setCurrentCheckInId(null);
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'approved':
        return <span className="text-xs bg-green-100 text-green-800 px-2 py-1 rounded-full font-medium">{t('checkin.statusApproved')}</span>;
      case 'rejected':
        return <span className="text-xs bg-red-100 text-red-800 px-2 py-1 rounded-full font-medium">{t('checkin.statusRejected')}</span>;
      default:
        return <span className="text-xs bg-yellow-100 text-yellow-800 px-2 py-1 rounded-full font-medium">{t('checkin.statusPending')}</span>;
    }
  };

  const getStatusIcon = (checkIn: any) => {
    if (checkIn.status === 'approved') {
      return <CheckCircle className="w-6 h-6 text-green-500" />;
    } else if (checkIn.status === 'rejected') {
      return <XCircle className="w-6 h-6 text-red-500" />;
    } else if (checkIn.is_late) {
      return <Clock className="w-6 h-6 text-orange-500" />;
    } else {
      return <AlertCircle className="w-6 h-6 text-yellow-500" />;
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          {onBack && (
            <button
              onClick={onBack}
              className="p-2 hover:bg-beige-100 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-gray-700" />
            </button>
          )}
          <h2 className="text-3xl font-bold text-gray-900">{t('checkin.title')}</h2>
        </div>
      </div>

      {checkInResult && (
        <div className={`p-6 rounded-xl shadow-lg ${
          checkInResult.is_late ? 'bg-orange-50 border-2 border-orange-500' : 'bg-green-50 border-2 border-green-500'
        }`}>
          <div className="flex items-center space-x-4">
            {checkInResult.is_late ? (
              <Clock className="w-12 h-12 text-orange-600" />
            ) : (
              <CheckCircle className="w-12 h-12 text-green-600" />
            )}
            <div className="flex-1">
              <h3 className="text-xl font-bold text-gray-900 mb-1">
                {t('checkin.submitted')}
              </h3>
              {checkInResult.is_late && (
                <p className="text-orange-700 mb-2">
                  {t('checkin.minutesLate', { minutes: checkInResult.minutes_late })}
                </p>
              )}
              <p className="text-sm text-gray-700 mb-2">
                {t('checkin.waitingForApproval')}
              </p>
              <div className="flex items-center space-x-2">
                <Award className="w-5 h-5 text-blue-600" />
                <span className="font-semibold text-gray-900">
                  {t('checkin.possiblePoints', { points: (checkInResult.points_awarded && checkInResult.points_awarded > 0 ? '+' : '') + (checkInResult.points_awarded || 0) })}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <h3 className="text-xl font-bold text-gray-900 mb-4">{t('checkin.checkInNow')}</h3>

        {hasScheduleToday === false && profile?.role !== 'admin' ? (
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-6 text-center">
            <AlertCircle className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <h4 className="font-semibold text-gray-900 mb-2 text-lg">
              {t('checkin.noScheduleToday', 'Kein Dienstplan für heute')}
            </h4>
            <p className="text-gray-600">
              {t('checkin.noScheduleMessage', 'Du bist heute nicht eingeplant. Check-In ist nur an Arbeitstagen möglich.')}
            </p>
            <p className="text-sm text-gray-500 mt-3">
              {t('checkin.readOnlyMode', 'Du kannst weiterhin Notes schreiben und Freiwünsche abgeben.')}
            </p>
          </div>
        ) : hasScheduleToday === null && profile?.role !== 'admin' ? (
          <div className="animate-pulse space-y-4">
            <div className="h-20 bg-gray-200 rounded"></div>
            <div className="grid grid-cols-2 gap-4">
              <div className="h-32 bg-gray-200 rounded"></div>
              <div className="h-32 bg-gray-200 rounded"></div>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h4 className="font-semibold text-blue-900 mb-2">{t('checkin.howItWorks')}</h4>
              <ul className="space-y-1 text-sm text-blue-800">
                <li>✓ {t('checkin.instruction1')}</li>
                <li>✓ {t('checkin.instruction2')}</li>
                <li>✓ {t('checkin.instruction3')}</li>
                <li>✓ {t('checkin.instruction4')}</li>
                <li>✓ {t('checkin.instruction5')}</li>
                <li>✓ {t('checkin.instruction6')}</li>
              </ul>
            </div>

            <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
              <p className="text-sm text-green-800">
                <strong>{t('checkin.scheduledFor', 'Eingeplant für:')}</strong> {scheduledShift === 'morning' ? t('checkin.earlyShift', 'Frühschicht') : t('checkin.lateShift', 'Spätschicht')}
              </p>
            </div>

            {todayCheckIns.length > 0 ? (
              <div className="bg-green-50 border-2 border-green-400 rounded-xl p-6">
                <div className="flex items-center space-x-4">
                  <CheckCircle className="w-12 h-12 text-green-600" />
                  <div>
                    <h4 className="font-bold text-gray-900 text-lg">{t('checkin.alreadyCheckedIn', 'Bereits eingecheckt!')}</h4>
                    <p className="text-gray-700">{t('checkin.alreadyCheckedInMessage', 'Du hast dich heute bereits eingestempelt.')}</p>
                  </div>
                </div>
              </div>
            ) : (
              <button
                onClick={handleCheckIn}
                disabled={loading}
                className="w-full flex flex-col items-center justify-center p-12 bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl hover:shadow-2xl transform hover:scale-105 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg text-white"
              >
                <CheckCircle className="w-16 h-16 mb-4" />
                <span className="font-bold text-2xl mb-2">{t('checkin.checkInNow')}</span>
                <span className="text-lg opacity-90">
                  {t('checkin.systemRecognizesShift', 'Das System erkennt deine Schicht automatisch')}
                </span>
              </button>
            )}
          </div>
        )}
      </div>

      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <h3 className="text-xl font-bold text-gray-900 mb-4">{t('checkin.todayCheckIns')}</h3>

        {todayCheckIns.length === 0 ? (
          <p className="text-gray-600 text-center py-8">{t('checkin.noCheckIns')}</p>
        ) : (
          <div className="space-y-3">
            {todayCheckIns.map((checkIn) => (
              <div
                key={checkIn.id}
                className="flex items-center justify-between p-4 bg-gray-50 rounded-lg"
              >
                <div className="flex items-center space-x-4">
                  {getStatusIcon(checkIn)}
                  <div>
                    <div className="flex items-center space-x-2">
                      <p className="font-semibold text-gray-900 capitalize">
                        {checkIn.shift_type}schicht
                      </p>
                      {getStatusBadge(checkIn.status)}
                    </div>
                    <p className="text-sm text-gray-600">
                      {new Date(checkIn.check_in_time).toLocaleTimeString('de-DE', {
                        timeZone: 'Asia/Phnom_Penh',
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </p>
                    {checkIn.is_late && (
                      <p className="text-xs text-orange-600">
                        {checkIn.minutes_late} Min. zu spät
                      </p>
                    )}
                  </div>
                </div>
                <div className="text-right">
                  {checkIn.status === 'approved' && (
                    <>
                      <span className={`text-lg font-bold ${
                        (checkIn.points_awarded || 0) > 0 ? 'text-green-600' : 'text-red-600'
                      }`}>
                        {(checkIn.points_awarded || 0) > 0 ? '+' : ''}{checkIn.points_awarded || 0}
                      </span>
                      <p className="text-xs text-gray-600">{t('common.points')}</p>
                    </>
                  )}
                  {checkIn.status === 'pending' && (
                    <>
                      <span className="text-lg font-bold text-gray-400">
                        {(checkIn.points_awarded || 0) > 0 ? '+' : ''}{checkIn.points_awarded || 0}
                      </span>
                      <p className="text-xs text-gray-600">{t('checkin.possible')}</p>
                    </>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showFortuneWheel && (
        <div className="fixed inset-0 z-[9999]">
          <FortuneWheel
            onClose={handleCloseFortuneWheel}
            onSpinComplete={handleFortuneWheelComplete}
          />
        </div>
      )}

      {alreadySpunToday && (
        <div className="bg-gradient-to-br from-yellow-50 to-orange-50 border-2 border-yellow-400 rounded-xl p-6 shadow-lg">
          <div className="flex items-center space-x-4">
            <div className="flex-shrink-0">
              <Trophy className="w-16 h-16 text-yellow-600" />
            </div>
            <div className="flex-1">
              <h3 className="text-2xl font-bold text-gray-900 mb-2">
                {t('fortuneWheel.alreadySpun')}
              </h3>
              <p className="text-lg text-gray-700">
                {t('fortuneWheel.tryAgainTomorrow')}
              </p>
            </div>
          </div>
        </div>
      )}

      {showLateReasonDialog && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-2xl">
            <h3 className="text-2xl font-bold text-gray-900 mb-4">
              {t('checkin.lateExplanationTitle', 'Begründung für Verspätung')}
            </h3>
            <p className="text-gray-600 mb-4">
              {t('checkin.lateExplanationMessage', 'Bitte gib einen Grund für deine Verspätung an. Dies wird dem Admin angezeigt.')}
            </p>
            <textarea
              value={lateReason}
              onChange={(e) => setLateReason(e.target.value)}
              placeholder={t('checkin.lateReasonPlaceholder', 'z.B. Verkehrsstau, Familiärer Notfall, etc.')}
              className="w-full p-3 border border-gray-300 rounded-lg mb-4 min-h-[100px] focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              autoFocus
            />
            <div className="flex space-x-3">
              <button
                onClick={handleLateReasonCancel}
                className="flex-1 py-3 bg-gray-200 text-gray-900 rounded-lg hover:bg-gray-300 font-medium transition-colors"
              >
                {t('common.cancel', 'Abbrechen')}
              </button>
              <button
                onClick={handleLateReasonSubmit}
                disabled={!lateReason.trim()}
                className="flex-1 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {t('checkin.submit', 'Einchecken')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
