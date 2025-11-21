import { useState, useEffect } from 'react';

import { useAuth } from '../contexts/AuthContext';
import { Shield, Camera, CheckCircle, AlertCircle, Clock, QrCode, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import { QRScanner } from './QRScanner';

interface PatrolLocation {
  id: string;
  name: string;
  qr_code: string;
  description: string;
  order_index: number;
  photo_explanation?: string;
}

interface PatrolRound {
  id: string;
  date: string;
  time_slot: string;
  assigned_to: string;
  completed_at: string | null;
  profiles?: {
    full_name: string;
  };
}

interface PatrolScan {
  id: string;
  patrol_round_id: string;
  location_id: string;
  scanned_at: string;
  photo_url: string | null;
  photo_requested: boolean;
}

const TIME_SLOTS = ['11:00', '12:15', '13:30', '14:45', '16:00', '17:15', '18:30', '19:45', '21:00'];

// TEST MODE: Set to true to enable test mode (no time restrictions, creates rounds for current user)
const TEST_MODE = true;

export function PatrolRounds({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const [locations, setLocations] = useState<PatrolLocation[]>([]);
  const [todayRounds, setTodayRounds] = useState<PatrolRound[]>([]);
  const [scans, setScans] = useState<PatrolScan[]>([]);
  const [currentRound, setCurrentRound] = useState<PatrolRound | null>(null);
  const [showScanner, setShowScanner] = useState(false);
  const [showPhotoRequest, setShowPhotoRequest] = useState(false);
  const [pendingLocation, setPendingLocation] = useState<PatrolLocation | null>(null);
  const [photo, setPhoto] = useState<File | null>(null);
  const [testMode] = useState(TEST_MODE);

  useEffect(() => {
    loadLocations();
    loadTodayData();
    checkAndCreateRounds();

    const channel = supabase
      .channel(`patrol_updates_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'patrol_rounds',
        },
        () => {
          loadTodayData();
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'patrol_scans',
        },
        () => {
          loadTodayData();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const loadLocations = async () => {
    const { data, error } = await supabase
      .from('patrol_locations')
      .select('*')
      .order('order_index');

    if (error) {
      console.error('Error loading locations:', error);
      return;
    }

    setLocations(data || []);
  };

  const loadTodayData = async () => {
    const today = getTodayDateString();

    // EVERYONE can see ALL rounds
    const { data: roundsData, error: roundsError } = await supabase
      .from('patrol_rounds')
      .select(`
        *,
        profiles:assigned_to (full_name)
      `)
      .eq('date', today)
      .order('time_slot');

    if (roundsError) {
      console.error('Error loading rounds:', roundsError);
      return;
    }

    setTodayRounds(roundsData || []);

    const roundIds = (roundsData || []).map((r: any) => r.id);
    if (roundIds.length > 0) {
      const { data: scansData, error: scansError } = await supabase
        .from('patrol_scans')
        .select('*')
        .in('patrol_round_id', roundIds);

      if (scansError) {
        console.error('Error loading scans:', scansError);
        return;
      }

      setScans(scansData || []);
    }

    const activeRound = findActiveRound(roundsData || []);
    setCurrentRound(activeRound);
  };

  const checkAndCreateRounds = async () => {
    const today = getTodayDateString();
    const { data: { user } } = await supabase.auth.getUser();

    if (!user) return;

    if (testMode) {
      // TEST MODE: Create all time slots for current user
      console.log('TEST MODE: Creating patrol rounds for current user');

      for (const timeSlot of TIME_SLOTS) {
        const { data: existing } = await supabase
          .from('patrol_rounds')
          .select('id')
          .eq('date', today)
          .eq('time_slot', timeSlot)
          .eq('assigned_to', user.id)
          .maybeSingle() as any;

        if (!existing) {
          const scheduledTime = `${today}T${timeSlot}:00+07:00`;
          await supabase.from('patrol_rounds').insert({
            date: today,
            time_slot: timeSlot,
            assigned_to: user.id,
            scheduled_time: scheduledTime,
          }) as any;
        }
      }

      loadTodayData();
      return;
    }

    // NORMAL MODE: Use schedule
    const { data: schedule } = await supabase
      .from('patrol_schedules')
      .select('*')
      .eq('date', today);

    if (!schedule || schedule.length === 0) return;

    const currentHour = new Date().getHours();
    const currentShift = currentHour < 15 ? 'morning' : 'late';
    const assignedSchedule = schedule.find((s: any) => s.shift === currentShift);

    if (!assignedSchedule) return;

    const relevantTimeSlots = currentShift === 'morning'
      ? TIME_SLOTS.filter((slot) => parseInt(slot.split(':')[0]) < 15)
      : TIME_SLOTS.filter((slot) => parseInt(slot.split(':')[0]) >= 15);

    for (const timeSlot of relevantTimeSlots) {
      const { data: existing } = await supabase
        .from('patrol_rounds')
        .select('id')
        .eq('date', today)
        .eq('time_slot', timeSlot)
        .eq('assigned_to', assignedSchedule.assigned_to)
        .maybeSingle() as any;

      if (!existing) {
        const scheduledTime = `${today}T${timeSlot}:00+07:00`;
        await supabase.from('patrol_rounds').insert({
          date: today,
          time_slot: timeSlot,
          assigned_to: assignedSchedule.assigned_to,
          scheduled_time: scheduledTime,
        }) as any;
      }
    }

    loadTodayData();
  };

  const findActiveRound = (rounds: PatrolRound[]): PatrolRound | null => {
    if (testMode) {
      // TEST MODE: First incomplete round is always active
      return rounds.find(r => !r.completed_at) || null;
    }

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();

    // Find the FIRST incomplete round that is past its start time
    for (const round of rounds) {
      if (round.completed_at) continue;

      const [hours, minutes] = round.time_slot.split(':').map(Number);
      const slotTime = hours * 60 + minutes;

      // Round is active if current time >= start time (no deadline)
      if (currentTime >= slotTime) {
        return round;
      }
    }

    return null;
  };

  const canStartRound = (round: PatrolRound): boolean => {
    if (testMode) {
      // TEST MODE: Any incomplete round can be started
      return !round.completed_at;
    }

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();
    const [hours, minutes] = round.time_slot.split(':').map(Number);
    const slotTime = hours * 60 + minutes;

    // Can start if: current time >= start time AND not completed
    return currentTime >= slotTime && !round.completed_at;
  };

  const handleQRScan = async (qrCode: string) => {
    if (!currentRound) {
      alert('No active patrol round at this time. Please wait for the next time slot.');
      setShowScanner(false);
      return;
    }

    const location = locations.find((l) => l.qr_code === qrCode);
    if (!location) {
      alert('Invalid QR code. Please try again.');
      return;
    }

    const alreadyScanned = scans.some(
      (s: any) => s.patrol_round_id === currentRound.id && s.location_id === location.id
    );

    if (alreadyScanned) {
      alert('This location has already been scanned for this round');
      return;
    }

    const photoRequested = Math.random() < 0.3;

    if (photoRequested) {
      setPendingLocation(location);
      setShowPhotoRequest(true);
      setShowScanner(false);
    } else {
      setShowScanner(false);
      await completeScan(location.id, currentRound.id, null, false);
    }
  };

  const completeScan = async (
    locationId: string,
    roundId: string,
    photoUrl: string | null,
    photoRequested: boolean
  ) => {
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        alert('Not authenticated');
        return;
      }

      const { error: scanError } = await supabase.from('patrol_scans').insert({
        patrol_round_id: roundId,
        location_id: locationId,
        user_id: user.id,
        photo_url: photoUrl,
        photo_requested: photoRequested,
      }) as any;

      if (scanError) {
        console.error('Scan insert error:', scanError);
        if (scanError.code === '23505') {
          alert('This location has already been scanned for this patrol round.');
        } else {
          alert('Error recording scan: ' + (scanError.message || 'Unknown error'));
        }
        setShowScanner(false);
        setShowPhotoRequest(false);
        loadTodayData();
        return;
      }

      // Award +1 point immediately for this scan
      const locationName = locations.find(l => l.id === locationId)?.name || 'Unknown';
      await supabase.from('points_history').insert({
        user_id: user.id,
        points_change: 1,
        reason: `Patrol scan completed: ${locationName}`,
        category: 'patrol',
        created_by: user.id,
      }) as any;

      // Update daily_point_goals
      const today = getTodayDateString();
      const { data: existing } = await supabase
        .from('daily_point_goals')
        .select('*')
        .eq('user_id', user.id)
        .eq('date', today)
        .maybeSingle() as any;

      if (existing) {
        await supabase
          .from('daily_point_goals')
          .update({
            points_earned: existing.points_earned + 1,
            updated_at: new Date().toISOString()
          })
          .eq('user_id', user.id)
          .eq('date', today);
      } else {
        await supabase
          .from('daily_point_goals')
          .insert({
            user_id: user.id,
            date: today,
            points_earned: 1
          }) as any;
      }

      // Check if round is complete (all UNIQUE locations scanned)
      const { data: roundScans } = await supabase
        .from('patrol_scans')
        .select('location_id')
        .eq('patrol_round_id', roundId);

      const uniqueLocations = new Set(roundScans?.map((s: any) => s.location_id) || []);

      // Calculate if within time window (simplified - always true for now)
      const withinWindow = true;

      await loadTodayData();

      if (uniqueLocations.size === locations.length) {
        // Mark round as complete
        const pointsForRound = withinWindow ? locations.length : 0;
        await supabase
          .from('patrol_rounds')
          .update({
            completed_at: new Date().toISOString(),
            points_calculated: true,
            points_awarded: pointsForRound
          })
          .eq('id', roundId);

        if (withinWindow) {
          alert(`Patrol round completed! +${locations.length} points awarded`);
        } else {
          alert('Patrol round completed (time expired, no points awarded)');
        }

        // Close scanner after round completion
        setShowScanner(false);
      } else {
        // Individual scan feedback - reopen scanner for next scan
        alert(`Location scanned! +1 point. ${uniqueLocations.size}/${locations.length} complete.`);
        setShowScanner(true);
      }

      setShowPhotoRequest(false);
      setPendingLocation(null);
      setPhoto(null);
    } catch (error) {
      console.error('Error completing scan:', error);
      alert('Error recording scan');
    }
  };

  const uploadPhoto = async (file: File): Promise<string> => {
    const fileExt = file.name.split('.').pop();
    const fileName = `${Math.random()}.${fileExt}`;
    const filePath = `patrol/${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from('task-photos')
      .upload(filePath, file);

    if (uploadError) {
      console.error('Upload error:', uploadError);
      return '';
    }

    const { data } = supabase.storage.from('task-photos').getPublicUrl(filePath);
    return data.publicUrl;
  };

  const handlePhotoSubmit = async () => {
    if (!photo || !pendingLocation || !currentRound) return;

    const photoUrl = await uploadPhoto(photo);
    await completeScan(pendingLocation.id, currentRound.id, photoUrl, true);
  };

  const handleScannerResult = (result: string) => {
    setShowScanner(false);
    handleQRScan(result.trim().toUpperCase());
  };

  const getLocationStatus = (locationId: string): 'completed' | 'pending' => {
    if (!currentRound) return 'pending';
    return scans.some((s: any) => s.patrol_round_id === currentRound.id && s.location_id === locationId)
      ? 'completed'
      : 'pending';
  };

  const getRoundStatus = (round: PatrolRound): 'active' | 'completed' | 'upcoming' | 'missed' => {
    // Check if all UNIQUE locations scanned (use actual scan data)
    const roundScans = scans.filter(s => s.patrol_round_id === round.id);
    const uniqueLocations = new Set(roundScans.map(s => s.location_id));

    if (uniqueLocations.size === locations.length) {
      return 'completed';
    }

    const now = new Date();
    const currentTime = now.getHours() * 60 + now.getMinutes();
    const [hours, minutes] = round.time_slot.split(':').map(Number);
    const slotTime = hours * 60 + minutes;
    const diff = currentTime - slotTime;

    if (Math.abs(diff) <= 15) return 'active';
    if (diff > 15) return 'missed';
    return 'upcoming';
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
          <div>
            <div className="flex items-center space-x-3">
              <h2 className="text-3xl font-bold text-gray-900">Patrol Rounds</h2>
              {testMode && (
                <span className="bg-yellow-400 text-yellow-900 px-3 py-1 rounded-full text-sm font-bold">
                  TEST MODE
                </span>
              )}
            </div>
            <p className="text-gray-600 mt-1">
              {profile?.role === 'admin'
                ? 'Übersicht aller Patrouillengänge'
                : testMode
                  ? 'Test Mode: All rounds available, no time restrictions'
                  : 'Scanne QR Codes an den Kontrollpunkten'}
            </p>
          </div>
        </div>
        <Shield className="w-8 h-8 text-orange-600" />
      </div>

      {currentRound && profile?.role !== 'admin' && (
        <div className="bg-gradient-to-r from-orange-500 to-orange-600 rounded-xl p-6 text-white shadow-lg">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center space-x-3">
              <Clock className="w-6 h-6" />
              <div>
                <div className="text-sm opacity-90">Current Round</div>
                <div className="text-2xl font-bold">{currentRound.time_slot}</div>
              </div>
            </div>
            <button
              onClick={() => setShowScanner(true)}
              className="bg-white text-blue-600 px-6 py-3 rounded-lg font-semibold hover:bg-blue-50 transition-colors flex items-center space-x-2"
            >
              <QrCode className="w-5 h-5" />
              <span>Scan QR Code</span>
            </button>
          </div>
          <div className="grid grid-cols-3 gap-3">
            {locations.map((location) => {
              const status = getLocationStatus(location.id);
              return (
                <div
                  key={location.id}
                  className={`p-3 rounded-lg ${
                    status === 'completed'
                      ? 'bg-green-400 bg-opacity-30'
                      : 'bg-white bg-opacity-20'
                  }`}
                >
                  <div className="flex items-center space-x-2">
                    {status === 'completed' ? (
                      <CheckCircle className="w-5 h-5" />
                    ) : (
                      <AlertCircle className="w-5 h-5" />
                    )}
                    <span className="text-sm font-medium">{location.name}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-900 mb-4">Today's Rounds</h3>
        <div className="space-y-3">
          {todayRounds.map((round) => {
            const status = getRoundStatus(round);
            const roundScans = scans.filter((s: any) => s.patrol_round_id === round.id);
            const uniqueScans = new Set(roundScans.map(s => s.location_id));
            const progress = `${uniqueScans.size}/${locations.length}`;

            return (
              <div
                key={round.id}
                className={`p-4 rounded-lg border-2 ${
                  status === 'completed'
                    ? 'bg-green-50 border-green-400'
                    : status === 'active'
                    ? 'bg-orange-50 border-orange-400'
                    : status === 'missed'
                    ? 'bg-red-50 border-red-400'
                    : 'bg-beige-50 border-beige-300'
                }`}
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <Clock className="w-5 h-5 text-gray-600" />
                    <div>
                      <div className="font-semibold text-gray-900">{round.time_slot}</div>
                      {round.profiles && (
                        <div className="text-xs text-gray-500">Assigned: {round.profiles.full_name}</div>
                      )}
                      <div className="text-sm text-gray-600 capitalize">{status}</div>
                    </div>
                  </div>
                  <div className="flex items-center space-x-3">
                    <div className="text-right mr-3">
                      <div className="text-2xl font-bold text-gray-900">{progress}</div>
                      <div className="text-xs text-gray-600">locations</div>
                    </div>
                    {profile?.role !== 'admin' && canStartRound(round) && (
                      <button
                        onClick={() => {
                          setCurrentRound(round);
                          setShowScanner(true);
                        }}
                        className="bg-orange-600 text-white px-4 py-2 rounded-lg hover:bg-orange-700 transition-colors font-semibold"
                      >
                        Start
                      </button>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
          {todayRounds.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              {profile?.role === 'admin'
                ? 'Heute keine Patrouillengänge geplant'
                : 'Keine Patrouillengänge für heute zugewiesen'}
            </div>
          )}
        </div>
      </div>

      {showScanner && (
        <QRScanner
          onScan={handleScannerResult}
          onClose={() => setShowScanner(false)}
        />
      )}

      {showPhotoRequest && pendingLocation && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => setShowPhotoRequest(false)}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">📸 Foto erforderlich!</h3>
            <div className="mb-4">
              <p className="text-gray-700 mb-2">
                Patrouillenpunkt: <strong>{pendingLocation.name}</strong>
              </p>
              <p className="text-sm text-gray-600 mb-3">{pendingLocation.description}</p>
              {pendingLocation.photo_explanation && (
                <div className="bg-yellow-50 border border-yellow-300 rounded-lg p-3">
                  <p className="text-sm text-yellow-900 font-medium">
                    {pendingLocation.photo_explanation}
                  </p>
                </div>
              )}
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Upload Photo *
                </label>
                <input
                  type="file"
                  accept="image/*"
                  capture="environment"
                  onChange={(e) => setPhoto(e.target.files?.[0] || null)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div className="flex space-x-3">
                <button
                  onClick={() => {
                    setShowPhotoRequest(false);
                    setPendingLocation(null);
                    setPhoto(null);
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handlePhotoSubmit}
                  disabled={!photo}
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <Camera className="w-4 h-4" />
                  <span>Submit</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
