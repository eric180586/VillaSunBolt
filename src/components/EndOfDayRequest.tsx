import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useSchedules } from '../hooks/useSchedules';
import { useDepartureRequests } from '../hooks/useDepartureRequests';
import { Home, CheckCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { getTodayDateString, isSameDay } from '../lib/dateUtils';

export function EndOfDayRequest() {
  const { profile } = useAuth();
  const { schedules } = useSchedules();
  const { requests, createRequest } = useDepartureRequests();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  const [currentShift, setCurrentShift] = useState<string | null>(null);

  useEffect(() => {
    const detectShift = async () => {
      if (!profile) return;

      const today = getTodayDateString();
      console.log('[EndOfDayRequest] Detecting shift for date:', today);

      const { data: checkIn, error } = await supabase
        .from('check_ins')
        .select('shift_type')
        .eq('user_id', profile.id)
        .in('status', ['approved', 'pending'])
        .gte('check_in_time', `${today}T00:00:00`)
        .lte('check_in_time', `${today}T23:59:59`)
        .order('check_in_time', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (error) {
        console.error('[EndOfDayRequest] Error fetching check-in:', error);
        console.error('[EndOfDayRequest] Error details:', JSON.stringify(error, null, 2));
      }

      if (checkIn) {
        console.log('[EndOfDayRequest] Check-in found, shift_type:', checkIn.shift_type);
        setCurrentShift(checkIn.shift_type);
      } else {
        console.log('[EndOfDayRequest] No check-in found for today');
      }
    };

    detectShift();
  }, [profile]);

  const handleRequest = async () => {
    if (!profile) return;

    console.log('[EndOfDayRequest] Handle request clicked, currentShift:', currentShift);

    if (!currentShift) {
      alert('No shift found for today. Please check in first.');
      return;
    }

    const today = new Date();
    // Map database shift_type (morning/late) to German (früh/spät)
    const shiftType = currentShift === 'morning' ? 'früh' : 'spät';
    console.log('[EndOfDayRequest] Creating request for shift type:', shiftType);

    const hasPendingRequest = requests.some(
      (r) =>
        r.user_id === profile.id &&
        new Date(r.shift_date).toDateString() === today.toDateString() &&
        r.status === 'pending'
    );

    if (hasPendingRequest) {
      console.log('[EndOfDayRequest] Already has pending request for today');
      alert('You already have a pending departure request for today');
      return;
    }

    setIsSubmitting(true);
    try {
      console.log('[EndOfDayRequest] Calling createRequest...');
      await createRequest({
        user_id: profile.id,
        shift_date: today.toISOString().split('T')[0],
        shift_type: shiftType as 'früh' | 'spät',
      });
      console.log('[EndOfDayRequest] Request created successfully');
      setShowSuccess(true);
      setTimeout(() => setShowSuccess(false), 3000);
    } catch (error) {
      console.error('[EndOfDayRequest] Error creating departure request:', error);
      console.error('[EndOfDayRequest] Error details:', JSON.stringify(error, null, 2));
      alert('Error creating request');
    } finally {
      setIsSubmitting(false);
    }
  };

  if (showSuccess) {
    return (
      <div className="bg-green-500 text-white rounded-lg p-6 text-center shadow-lg animate-pulse">
        <CheckCircle className="w-12 h-12 mx-auto mb-3" />
        <h3 className="text-xl font-bold mb-2">Request sent!</h3>
        <p className="text-green-100 text-sm">Admin has been notified</p>
      </div>
    );
  }

  return (
    <div className="bg-gradient-to-r from-orange-500 to-amber-500 rounded-xl p-6 text-center shadow-xl animate-pulse-slow border-2 border-orange-300">
      <Home className="w-12 h-12 text-white mx-auto mb-3 animate-bounce" />
      <h3 className="text-2xl font-bold text-white mb-3 drop-shadow-md">
        Me work a lot, me go home now
      </h3>
      <button
        onClick={handleRequest}
        disabled={isSubmitting}
        className="bg-white text-orange-600 px-8 py-3 rounded-xl text-lg font-bold hover:bg-orange-50 hover:scale-110 transform transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed shadow-2xl hover:shadow-orange-300/50 active:scale-95 animate-pulse"
      >
        {isSubmitting ? 'Sending...' : 'Ok?'}
      </button>
      <p className="text-orange-50 text-sm mt-3 font-medium">
        Request will be sent to admin for approval
      </p>
    </div>
  );
}
