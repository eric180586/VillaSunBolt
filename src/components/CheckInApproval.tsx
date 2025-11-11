import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { CheckCircle, XCircle, Clock, User, AlertCircle, ArrowLeft, Home, UserPlus, LogOut } from 'lucide-react';
import { toLocaleTimeStringCambodia, toLocaleStringCambodia, combineDateAndTime, getTodayDateString } from '../lib/dateUtils';

interface CheckInWithProfile {
  id: string;
  user_id: string;
  check_in_time: string;
  shift_type: string;
  is_late: boolean;
  minutes_late: number;
  points_awarded: number;
  status: string;
  late_reason: string | null;
  profiles: {
    full_name: string;
  };
}

interface CheckInApprovalProps {
  onNavigate?: (view: string) => void;
}

interface DepartureRequest {
  id: string;
  staff_id: string;
  requested_at: string;
  status: string;
  profiles: {
    full_name: string;
  };
}

export function CheckInApproval({ onNavigate }: CheckInApprovalProps = {}) {
  const { profile } = useAuth();
  const [pendingCheckIns, setPendingCheckIns] = useState<CheckInWithProfile[]>([]);
  const [pendingDepartures, setPendingDepartures] = useState<DepartureRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState<{ [key: string]: string }>({});
  const [showRejectModal, setShowRejectModal] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'checkin' | 'departure' | 'manual' | 'checkout'>('checkin');
  const [showApproveModal, setShowApproveModal] = useState<string | null>(null);
  const [customPoints, setCustomPoints] = useState<{ [key: string]: number }>({});
  const [showManualCheckIn, setShowManualCheckIn] = useState(false);
  const [allStaff, setAllStaff] = useState<any[]>([]);
  const [manualCheckInForm, setManualCheckInForm] = useState({
    userId: '',
    date: getTodayDateString(),
    time: '09:00',
    shiftType: 'morning' as 'morning' | 'evening',
    lateReason: '',
  });
  const [manualCheckOutForm, setManualCheckOutForm] = useState({
    userId: '',
    time: new Date().toTimeString().slice(0, 5),
    reason: '',
  });
  const [activeStaff, setActiveStaff] = useState<any[]>([]);

  useEffect(() => {
    if (profile?.role === 'admin') {
      fetchPendingCheckIns();
      fetchPendingDepartures();
      fetchAllStaff();
      fetchActiveStaff();

      const checkInChannel = supabase
        .channel(`check_ins_admin_${Date.now()}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'check_ins',
          },
          () => {
            fetchPendingCheckIns();
          }
        )
        .subscribe();

      const departureChannel = supabase
        .channel(`departure_requests_admin_${Date.now()}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'departure_requests',
          },
          () => {
            fetchPendingDepartures();
          }
        )
        .subscribe();

      return () => {
        supabase.removeChannel(checkInChannel);
        supabase.removeChannel(departureChannel);
      };
    }
  }, [profile]);

  const fetchPendingCheckIns = async () => {
    const { data, error } = await supabase
      .from('check_ins')
      .select(`
        *,
        profiles:user_id (full_name)
      `)
      .eq('status', 'pending')
      .order('check_in_time', { ascending: false });

    if (error) {
      console.error('Error fetching check-ins:', error);
      return;
    }

    setPendingCheckIns(data || []);
  };

  const fetchPendingDepartures = async () => {
    const { data, error } = await supabase
      .from('departure_requests')
      .select(`
        *,
        profiles:staff_id (full_name)
      `)
      .eq('status', 'pending')
      .order('requested_at', { ascending: false });

    if (error) {
      console.error('Error fetching departure requests:', error);
      return;
    }

    setPendingDepartures(data || []);
  };

  const fetchAllStaff = async () => {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, full_name, role')
      .eq('role', 'staff')
      .order('full_name');

    if (error) {
      console.error('Error fetching staff:', error);
      return;
    }

    setAllStaff(data || []);
  };

  const fetchActiveStaff = async () => {
    const { data, error } = await supabase
      .from('check_ins')
      .select(`
        id,
        user_id,
        check_in_time,
        check_out_time,
        profiles:user_id (id, full_name)
      `)
      .eq('status', 'approved')
      .is('check_out_time', null)
      .order('check_in_time', { ascending: false });

    if (error) {
      console.error('Error fetching active staff:', error);
      return;
    }

    setActiveStaff(data || []);
  };

  const handleManualCheckIn = async () => {
    if (!profile?.id || !manualCheckInForm.userId) {
      alert('Bitte wähle einen Mitarbeiter aus');
      return;
    }

    setLoading(true);

    try {
      const checkInTimestamp = combineDateAndTime(manualCheckInForm.date, manualCheckInForm.time);

      const { error } = await supabase.rpc('process_check_in', {
        p_user_id: manualCheckInForm.userId,
        p_check_in_time: checkInTimestamp,
        p_shift_type: manualCheckInForm.shiftType,
        p_late_reason: manualCheckInForm.lateReason || null,
      });

      if (error) throw error;

      alert('Check-In erfolgreich erstellt!');
      setShowManualCheckIn(false);
      setManualCheckInForm({
        userId: '',
        date: getTodayDateString(),
        time: '09:00',
        shiftType: 'morning',
        lateReason: '',
      });
      fetchPendingCheckIns();
    } catch (error: any) {
      console.error('Error creating manual check-in:', error);
      alert('Fehler: ' + (error.message || 'Unbekannter Fehler'));
    } finally {
      setLoading(false);
    }
  };

  const handleManualCheckOut = async () => {
    if (!profile?.id || !manualCheckOutForm.userId) {
      alert('Bitte wähle einen Mitarbeiter aus');
      return;
    }

    setLoading(true);

    try {
      const checkoutTimestamp = combineDateAndTime(getTodayDateString(), manualCheckOutForm.time);

      const { data, error } = await supabase.rpc('admin_checkout_user', {
        p_admin_id: profile.id,
        p_user_id: manualCheckOutForm.userId,
        p_checkout_time: checkoutTimestamp,
        p_reason: manualCheckOutForm.reason || null,
      });

      if (error) throw error;

      alert(`Mitarbeiter erfolgreich ausgecheckt!`);
      setManualCheckOutForm({
        userId: '',
        time: new Date().toTimeString().slice(0, 5),
        reason: '',
      });
      fetchActiveStaff();
    } catch (error: any) {
      console.error('Error creating manual checkout:', error);
      if (error.message.includes('Kein aktives Check-in')) {
        alert('Fehler: Dieser Mitarbeiter ist nicht eingecheckt!');
      } else {
        alert('Fehler: ' + (error.message || 'Unbekannter Fehler'));
      }
    } finally {
      setLoading(false);
    }
  };

  const handleApproveDeparture = async (requestId: string) => {
    if (!profile?.id) return;

    setLoading(true);

    try {
      const { error } = await supabase
        .from('departure_requests')
        .update({
          status: 'approved',
          reviewed_by: profile.id,
          reviewed_at: new Date().toISOString(),
        })
        .eq('id', requestId);

      if (error) throw error;

      fetchPendingDepartures();
    } catch (error) {
      console.error('Error approving departure:', error);
      alert('Fehler beim Bestätigen');
    } finally {
      setLoading(false);
    }
  };

  const handleRejectDeparture = async (requestId: string) => {
    if (!profile?.id) return;

    setLoading(true);

    try {
      const { error } = await supabase
        .from('departure_requests')
        .update({
          status: 'rejected',
          reviewed_by: profile.id,
          reviewed_at: new Date().toISOString(),
          admin_response: rejectReason[requestId] || 'Keine Angabe',
        })
        .eq('id', requestId);

      if (error) throw error;

      setShowRejectModal(null);
      setRejectReason((prev) => {
        const newReasons = { ...prev };
        delete newReasons[requestId];
        return newReasons;
      });
      fetchPendingDepartures();
    } catch (error) {
      console.error('Error rejecting departure:', error);
      alert('Fehler beim Ablehnen');
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (checkInId: string, useCustomPoints: boolean = false) => {
    if (!profile?.id) return;

    setLoading(true);

    try {
      const params: any = {
        p_check_in_id: checkInId,
        p_admin_id: profile.id,
      };

      if (useCustomPoints && customPoints[checkInId] !== undefined) {
        params.p_custom_points = customPoints[checkInId];
      }

      const { error } = await supabase.rpc('approve_check_in', params);

      if (error) throw error;

      setShowApproveModal(null);
      setCustomPoints((prev) => {
        const newPoints = { ...prev };
        delete newPoints[checkInId];
        return newPoints;
      });
      fetchPendingCheckIns();
    } catch (error) {
      console.error('Error approving check-in:', error);
      alert('Fehler beim Bestätigen');
    } finally {
      setLoading(false);
    }
  };

  const getCheckInById = (id: string) => {
    return pendingCheckIns.find((c) => c.id === id);
  };

  const handleReject = async (checkInId: string) => {
    if (!profile?.id) return;

    setLoading(true);

    try {
      const { error } = await supabase.rpc('reject_check_in', {
        p_check_in_id: checkInId,
        p_admin_id: profile.id,
        p_reason: rejectReason[checkInId] || 'Keine Angabe',
      });

      if (error) throw error;

      setShowRejectModal(null);
      setRejectReason((prev) => {
        const newReasons = { ...prev };
        delete newReasons[checkInId];
        return newReasons;
      });
      fetchPendingCheckIns();
    } catch (error) {
      console.error('Error rejecting check-in:', error);
      alert('Fehler beim Ablehnen');
    } finally {
      setLoading(false);
    }
  };

  if (profile?.role !== 'admin') {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600">Nur für Admins verfügbar</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center space-x-4">
        {onNavigate && (
          <button
            onClick={() => onNavigate('admin-dashboard')}
            className="p-2 hover:bg-beige-100 rounded-lg transition-colors"
          >
            <ArrowLeft className="w-6 h-6 text-gray-700" />
          </button>
        )}
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Anfragen Übersicht</h2>
          <p className="text-gray-600 mt-1">
            Check-In & Feierabend Anfragen
          </p>
        </div>
      </div>

      <div className="flex space-x-2 border-b border-beige-200">
        <button
          onClick={() => setActiveTab('checkin')}
          className={`px-6 py-3 font-medium transition-colors ${
            activeTab === 'checkin'
              ? 'border-b-2 border-orange-500 text-orange-600'
              : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          Check-In ({pendingCheckIns.length})
        </button>
        <button
          onClick={() => setActiveTab('departure')}
          className={`px-6 py-3 font-medium transition-colors ${
            activeTab === 'departure'
              ? 'border-b-2 border-orange-500 text-orange-600'
              : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          Feierabend ({pendingDepartures.length})
        </button>
        <button
          onClick={() => setActiveTab('manual')}
          className={`px-6 py-3 font-medium transition-colors ${
            activeTab === 'manual'
              ? 'border-b-2 border-orange-500 text-orange-600'
              : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          <div className="flex items-center space-x-2">
            <UserPlus className="w-5 h-5" />
            <span>Einchecken</span>
          </div>
        </button>
        <button
          onClick={() => setActiveTab('checkout')}
          className={`px-6 py-3 font-medium transition-colors ${
            activeTab === 'checkout'
              ? 'border-b-2 border-orange-500 text-orange-600'
              : 'text-gray-600 hover:text-gray-900'
          }`}
        >
          <div className="flex items-center space-x-2">
            <LogOut className="w-5 h-5" />
            <span>Auschecken ({activeStaff.length})</span>
          </div>
        </button>
      </div>

      {activeTab === 'checkin' && (pendingCheckIns.length === 0 ? (
        <div className="bg-white rounded-xl p-12 shadow-lg border border-gray-200 text-center">
          <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-900 mb-2">Alles erledigt!</h3>
          <p className="text-gray-600">Keine offenen Check-In Anfragen</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4">
          {pendingCheckIns.map((checkIn) => (
            <div
              key={checkIn.id}
              className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-6 shadow-lg border-2 border-gray-200"
            >
              <div className="flex items-start justify-between">
                <div className="flex items-start space-x-4 flex-1">
                  <div className={`p-3 rounded-lg ${
                    checkIn.is_late ? 'bg-orange-100' : 'bg-green-100'
                  }`}>
                    {checkIn.is_late ? (
                      <Clock className="w-8 h-8 text-orange-600" />
                    ) : (
                      <CheckCircle className="w-8 h-8 text-green-600" />
                    )}
                  </div>

                  <div className="flex-1">
                    <div className="flex items-center space-x-2 mb-2">
                      <User className="w-5 h-5 text-gray-600" />
                      <h3 className="text-xl font-bold text-gray-900">
                        {checkIn.profiles.full_name}
                      </h3>
                    </div>

                    <div className="grid grid-cols-2 gap-4 mb-3">
                      <div>
                        <p className="text-sm text-gray-600">Schicht</p>
                        <p className="font-semibold text-gray-900 capitalize">
                          {checkIn.shift_type}schicht
                        </p>
                      </div>
                      <div>
                        <p className="text-sm text-gray-600">Check-In Zeit</p>
                        <p className="font-semibold text-gray-900">
                          {toLocaleTimeStringCambodia(checkIn.check_in_time, 'de-DE')}
                        </p>
                      </div>
                    </div>

                    {checkIn.is_late && (
                      <div className="bg-orange-50 border border-orange-200 rounded-lg p-3 mb-3">
                        <div className="flex items-center space-x-2 mb-2">
                          <AlertCircle className="w-5 h-5 text-orange-600" />
                          <span className="font-semibold text-orange-900">
                            {checkIn.minutes_late} Minuten zu spät
                          </span>
                        </div>
                        {checkIn.late_reason && (
                          <div className="mt-2 pl-7">
                            <p className="text-sm text-gray-700">
                              <span className="font-semibold text-gray-900">Begründung:</span>
                            </p>
                            <p className="text-sm text-gray-700 italic mt-1">
                              "{checkIn.late_reason}"
                            </p>
                          </div>
                        )}
                      </div>
                    )}

                    <div className="flex items-center space-x-2">
                      <div className={`px-4 py-2 rounded-lg ${
                        checkIn.points_awarded > 0 ? 'bg-green-100' : 'bg-red-100'
                      }`}>
                        <span className={`text-lg font-bold ${
                          checkIn.points_awarded > 0 ? 'text-green-700' : 'text-red-700'
                        }`}>
                          {checkIn.points_awarded > 0 ? '+' : ''}{checkIn.points_awarded} Punkte
                        </span>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="flex flex-col space-y-2 ml-4">
                  <button
                    onClick={() => setShowApproveModal(checkIn.id)}
                    disabled={loading}
                    className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                  >
                    <CheckCircle className="w-5 h-5" />
                    <span>Bestätigen</span>
                  </button>

                  <button
                    onClick={() => setShowRejectModal(checkIn.id)}
                    disabled={loading}
                    className="flex items-center space-x-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50"
                  >
                    <XCircle className="w-5 h-5" />
                    <span>Ablehnen</span>
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      ))}

      {showApproveModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => setShowApproveModal(null)}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">Check-In bestätigen</h3>

            {(() => {
              const checkIn = getCheckInById(showApproveModal);
              if (!checkIn) return null;

              const currentPoints = customPoints[showApproveModal] ?? checkIn.points_awarded;

              return (
                <>
                  <div className="bg-gray-50 rounded-lg p-4 mb-4">
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-sm text-gray-600">Mitarbeiter:</span>
                      <span className="font-semibold">{checkIn.profiles.full_name}</span>
                    </div>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-sm text-gray-600">Schicht:</span>
                      <span className="font-semibold capitalize">{checkIn.shift_type}schicht</span>
                    </div>
                    {checkIn.is_late && (
                      <div className="flex items-center justify-between">
                        <span className="text-sm text-gray-600">Verspätung:</span>
                        <span className="font-semibold text-orange-600">{checkIn.minutes_late} Min</span>
                      </div>
                    )}
                  </div>

                  <div className="mb-4">
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Punkte anpassen (optional)
                    </label>
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-3">
                      <p className="text-xs text-blue-800 mb-1">
                        Vorschlag: {checkIn.points_awarded} Punkte
                      </p>
                      <p className="text-xs text-gray-600">
                        {checkIn.is_late
                          ? `Automatisch reduziert wegen ${checkIn.minutes_late} Min Verspätung`
                          : 'Pünktliches Erscheinen'}
                      </p>
                    </div>

                    <div className="space-y-3">
                      <input
                        type="range"
                        min="-5"
                        max="5"
                        value={currentPoints}
                        onChange={(e) => setCustomPoints({
                          ...customPoints,
                          [showApproveModal]: parseInt(e.target.value)
                        })}
                        className="w-full h-2 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                        style={{
                          background: `linear-gradient(to right, #ef4444 0%, #f59e0b ${((currentPoints + 5) / 10) * 50}%, #10b981 ${((currentPoints + 5) / 10) * 100}%)`,
                        }}
                      />

                      <div className="flex items-center justify-between">
                        <button
                          onClick={() => setCustomPoints({
                            ...customPoints,
                            [showApproveModal]: Math.max(-5, currentPoints - 1)
                          })}
                          className="px-3 py-1 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 font-semibold"
                        >
                          -1
                        </button>

                        <div className={`px-6 py-2 rounded-lg font-bold text-xl ${
                          currentPoints > 0 ? 'bg-green-100 text-green-700' :
                          currentPoints < 0 ? 'bg-red-100 text-red-700' :
                          'bg-gray-100 text-gray-700'
                        }`}>
                          {currentPoints > 0 ? '+' : ''}{currentPoints}
                        </div>

                        <button
                          onClick={() => setCustomPoints({
                            ...customPoints,
                            [showApproveModal]: Math.min(5, currentPoints + 1)
                          })}
                          className="px-3 py-1 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 font-semibold"
                        >
                          +1
                        </button>
                      </div>

                      <div className="flex items-center justify-between text-xs text-gray-500">
                        <span>-5 (Strafe)</span>
                        <span>0 (Neutral)</span>
                        <span>+5 (Maximum)</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex space-x-3">
                    <button
                      onClick={() => {
                        setShowApproveModal(null);
                        setCustomPoints((prev) => {
                          const newPoints = { ...prev };
                          delete newPoints[showApproveModal];
                          return newPoints;
                        });
                      }}
                      className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
                    >
                      Abbrechen
                    </button>
                    <button
                      onClick={() => handleApprove(showApproveModal, true)}
                      disabled={loading}
                      className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 flex items-center justify-center space-x-2"
                    >
                      <CheckCircle className="w-5 h-5" />
                      <span>Bestätigen</span>
                    </button>
                  </div>
                </>
              );
            })()}
          </div>
        </div>
      )}

      {showRejectModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50" onClick={() => setShowRejectModal(null)}>
          <div className="bg-white rounded-xl p-6 w-full max-w-md" onClick={(e) => e.stopPropagation()}>
            <h3 className="text-xl font-bold text-gray-900 mb-4">
              {activeTab === 'checkin' ? 'Check-In' : 'Feierabend'} ablehnen
            </h3>
            <p className="text-gray-600 mb-4">Bitte gib einen Grund für die Ablehnung an:</p>
            <textarea
              value={rejectReason[showRejectModal] || ''}
              onChange={(e) => setRejectReason({ ...rejectReason, [showRejectModal]: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg mb-4"
              rows={3}
              placeholder="z.B. Falscher Zeitpunkt, nicht anwesend, etc."
            />
            <div className="flex space-x-3">
              <button
                onClick={() => setShowRejectModal(null)}
                className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
              >
                Abbrechen
              </button>
              <button
                onClick={() => activeTab === 'checkin' ? handleReject(showRejectModal) : handleRejectDeparture(showRejectModal)}
                disabled={loading}
                className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:opacity-50"
              >
                Ablehnen
              </button>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'departure' && (pendingDepartures.length === 0 ? (
        <div className="bg-white rounded-xl p-12 shadow-lg border border-beige-200 text-center">
          <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-900 mb-2">Alles erledigt!</h3>
          <p className="text-gray-600">Keine offenen Feierabend Anfragen</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {pendingDepartures.map((request) => (
            <div
              key={request.id}
              className="bg-gradient-to-br from-white to-beige-50 rounded-xl p-6 shadow-lg border-2 border-orange-300"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-3">
                  <Home className="w-6 h-6 text-orange-600" />
                  <div>
                    <h3 className="font-bold text-gray-900">{request.profiles.full_name}</h3>
                    <p className="text-xs text-gray-500">
                      {toLocaleStringCambodia(request.requested_at, 'de-DE')}
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex space-x-2 mt-4">
                <button
                  onClick={() => handleApproveDeparture(request.id)}
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <CheckCircle className="w-4 h-4" />
                  <span>OK</span>
                </button>
                <button
                  onClick={() => setShowRejectModal(request.id)}
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50 flex items-center justify-center space-x-2"
                >
                  <XCircle className="w-4 h-4" />
                  <span>Nein</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      ))}

      {activeTab === 'manual' && (
        <div className="bg-white rounded-xl p-8 shadow-lg border border-gray-200">
          <div className="flex items-center space-x-3 mb-6">
            <UserPlus className="w-8 h-8 text-orange-600" />
            <h3 className="text-2xl font-bold text-gray-900">Manuelles Check-In</h3>
          </div>

          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Mitarbeiter
              </label>
              <select
                value={manualCheckInForm.userId}
                onChange={(e) => setManualCheckInForm({ ...manualCheckInForm, userId: e.target.value })}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              >
                <option value="">Mitarbeiter auswählen...</option>
                {allStaff.map((staff) => (
                  <option key={staff.id} value={staff.id}>
                    {staff.full_name}
                  </option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Datum
                </label>
                <input
                  type="date"
                  value={manualCheckInForm.date}
                  onChange={(e) => setManualCheckInForm({ ...manualCheckInForm, date: e.target.value })}
                  className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Uhrzeit
                </label>
                <input
                  type="time"
                  value={manualCheckInForm.time}
                  onChange={(e) => setManualCheckInForm({ ...manualCheckInForm, time: e.target.value })}
                  className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Schicht
              </label>
              <select
                value={manualCheckInForm.shiftType}
                onChange={(e) => setManualCheckInForm({ ...manualCheckInForm, shiftType: e.target.value as 'morning' | 'evening' })}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              >
                <option value="morning">Morningschicht</option>
                <option value="evening">Eveningschicht</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Grund für Verspätung (optional)
              </label>
              <textarea
                value={manualCheckInForm.lateReason}
                onChange={(e) => setManualCheckInForm({ ...manualCheckInForm, lateReason: e.target.value })}
                placeholder="Falls zu spät, hier Grund angeben..."
                rows={3}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
              />
            </div>

            <div className="flex space-x-3 pt-4">
              <button
                onClick={handleManualCheckIn}
                disabled={loading || !manualCheckInForm.userId}
                className="flex-1 px-6 py-3 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed font-semibold flex items-center justify-center space-x-2"
              >
                <CheckCircle className="w-5 h-5" />
                <span>Check-In Erstellen</span>
              </button>
            </div>
          </div>

          <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex items-start space-x-2">
              <AlertCircle className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div className="text-sm text-blue-800">
                <p className="font-semibold mb-1">Hinweis:</p>
                <p>Das manuelle Check-In wird automatisch als "pending" erstellt und muss anschließend noch genehmigt werden.</p>
              </div>
            </div>
          </div>
        </div>
      )}

      {activeTab === 'checkout' && (
        <div className="bg-white rounded-xl p-8 shadow-lg border border-gray-200">
          <div className="flex items-center space-x-3 mb-6">
            <LogOut className="w-8 h-8 text-orange-600" />
            <h3 className="text-2xl font-bold text-gray-900">Manuelles Check-Out</h3>
          </div>

          {activeStaff.length === 0 ? (
            <div className="text-center py-8">
              <Clock className="w-16 h-16 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600">Keine Mitarbeiter aktuell eingecheckt</p>
            </div>
          ) : (
            <>
              <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <h4 className="font-semibold text-blue-900 mb-2">Aktuell eingecheckte Mitarbeiter:</h4>
                <div className="space-y-2">
                  {activeStaff.map((staff: any) => (
                    <div key={staff.id} className="flex items-center justify-between bg-white p-3 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <User className="w-5 h-5 text-gray-600" />
                        <span className="font-medium text-gray-900">{staff.profiles.full_name}</span>
                      </div>
                      <div className="text-sm text-gray-600">
                        Eingecheckt: {toLocaleTimeStringCambodia(staff.check_in_time, 'de-DE')}
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Mitarbeiter
                  </label>
                  <select
                    value={manualCheckOutForm.userId}
                    onChange={(e) => setManualCheckOutForm({ ...manualCheckOutForm, userId: e.target.value })}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  >
                    <option value="">Mitarbeiter auswählen...</option>
                    {activeStaff.map((staff: any) => (
                      <option key={staff.user_id} value={staff.user_id}>
                        {staff.profiles.full_name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Check-Out Uhrzeit
                  </label>
                  <input
                    type="time"
                    value={manualCheckOutForm.time}
                    onChange={(e) => setManualCheckOutForm({ ...manualCheckOutForm, time: e.target.value })}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Grund (optional)
                  </label>
                  <textarea
                    value={manualCheckOutForm.reason}
                    onChange={(e) => setManualCheckOutForm({ ...manualCheckOutForm, reason: e.target.value })}
                    placeholder="z.B. Früherer Feierabend genehmigt..."
                    rows={3}
                    className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  />
                </div>

                <div className="flex space-x-3 pt-4">
                  <button
                    onClick={handleManualCheckOut}
                    disabled={loading || !manualCheckOutForm.userId}
                    className="flex-1 px-6 py-3 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed font-semibold flex items-center justify-center space-x-2"
                  >
                    <LogOut className="w-5 h-5" />
                    <span>Mitarbeiter Auschecken</span>
                  </button>
                </div>
              </div>
            </>
          )}

          <div className="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <div className="flex items-start space-x-2">
              <AlertCircle className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
              <div className="text-sm text-blue-800">
                <p className="font-semibold mb-1">Hinweis:</p>
                <p>Der Mitarbeiter erhält eine Benachrichtigung, dass er ausgecheckt wurde.</p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
