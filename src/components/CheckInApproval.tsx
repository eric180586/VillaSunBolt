import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { CheckCircle, XCircle, Clock, User, AlertCircle, ArrowLeft, Home } from 'lucide-react';
import { toLocaleTimeStringCambodia, toLocaleStringCambodia } from '../lib/dateUtils';
import { useTranslation } from 'react-i18next';

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
  const { t } = useTranslation();
  const { profile } = useAuth();
  const [pendingCheckIns, setPendingCheckIns] = useState<CheckInWithProfile[]>([]);
  const [pendingDepartures, setPendingDepartures] = useState<DepartureRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [rejectReason, setRejectReason] = useState<{ [key: string]: string }>({});
  const [showRejectModal, setShowRejectModal] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'checkin' | 'departure'>('checkin');
  const [showApproveModal, setShowApproveModal] = useState<string | null>(null);
  const [customPoints, setCustomPoints] = useState<{ [key: string]: number }>({});

  useEffect(() => {
    if (profile?.role === 'admin') {
      fetchPendingCheckIns();
      fetchPendingDepartures();

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
      alert(t('admin.errorApproving'));
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
      alert(t('admin.errorRejecting'));
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
      alert(t('admin.errorApproving'));
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
      alert(t('admin.errorRejecting'));
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
            {t('admin.checkInAndDeparture')}
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
          {t('dashboard.departure')} ({pendingDepartures.length})
        </button>
      </div>

      {activeTab === 'checkin' && (pendingCheckIns.length === 0 ? (
        <div className="bg-white rounded-xl p-12 shadow-lg border border-gray-200 text-center">
          <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-900 mb-2">{t('admin.allDone')}</h3>
          <p className="text-gray-600">{t('admin.noCheckInsOpen')}</p>
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
              {t('admin.rejectTitle', { type: activeTab === 'checkin' ? 'Check-In' : 'Departure' })}
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
          <h3 className="text-xl font-bold text-gray-900 mb-2">{t('admin.allDone')}</h3>
          <p className="text-gray-600">{t('admin.noDeparturesOpen')}</p>
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
    </div>
  );
}
