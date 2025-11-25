import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useProfiles } from '../hooks/useProfiles';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import { CheckCircle, XCircle, Clock, AlertCircle, Users, ArrowLeft, LogOut, History, Check, X as XIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';

interface CheckInStatus {
  user_id: string;
  full_name: string;
  shift_type: string | null;
  has_schedule: boolean;
  checked_in: boolean;
  is_late: boolean;
  minutes_late: number;
  status: string;
  check_in_time: string | null;
  check_in_id: string | null;
  check_out_time: string | null;
  work_hours: number | null;
  has_departure_request: boolean;
  departure_status: string | null;
  departure_request_id: string | null;
}

interface CheckInOverviewProps {
  onBack?: () => void;
  onNavigate?: (view: string) => void;
}

export function CheckInOverview({ onBack, onNavigate }: CheckInOverviewProps = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { profiles } = useProfiles();
  const [checkInStatuses, setCheckInStatuses] = useState<CheckInStatus[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchCheckInStatuses = useCallback(async () => {
    try {
      setLoading(true);
      const today = getTodayDateString();
      console.log('[CheckInOverview] Fetching for date:', today);

      const staffProfiles = profiles.filter(p => p.role === 'staff');
      console.log('[CheckInOverview] Staff profiles count:', staffProfiles.length);

      if (staffProfiles.length === 0) {
        setCheckInStatuses([]);
        setLoading(false);
        return;
      }

      console.log('[CheckInOverview] Fetching weekly schedules...');
      const { data: allSchedules, error: schedError } = await supabase
        .from('weekly_schedules')
        .select('staff_id, shifts')
        .eq('is_published', true) as any;

      if (schedError) {
        console.error('[CheckInOverview] Schedule error:', schedError);
        throw schedError;
      }
      console.log('[CheckInOverview] Schedules fetched:', allSchedules?.length);

      console.log('[CheckInOverview] Fetching check-ins...');
      const { data: allCheckIns, error: checkError } = await supabase
        .from('check_ins')
        .select('*')
        .eq('check_in_date', today) as any;

      if (checkError) {
        console.error('[CheckInOverview] Check-in error:', checkError);
        throw checkError;
      }
      console.log('[CheckInOverview] Check-ins fetched:', allCheckIns?.length);

      const todayStartTs = `${today}T00:00:00+07:00`;
      const todayEndTs = `${today}T23:59:59+07:00`;

      console.log('[CheckInOverview] Fetching departure requests...');
      const { data: allDepartureRequests, error: depError } = await supabase
        .from('departure_requests')
        .select('*')
        .gte('request_time', todayStartTs)
        .lte('request_time', todayEndTs) as any;

      if (depError) {
        console.error('[CheckInOverview] Departure error:', depError);
        throw depError;
      }
      console.log('[CheckInOverview] Departure requests fetched:', allDepartureRequests?.length);

      const statuses: CheckInStatus[] = [];
      console.log('[CheckInOverview] Building statuses for staff...');

      for (const staffProfile of staffProfiles) {
        console.log('[CheckInOverview] Processing:', staffProfile.full_name);

        const staffSchedules = allSchedules?.filter((s: any) => s.staff_id === staffProfile.id) || [];

        let todayShift = null;
        for (const schedule of staffSchedules) {
          const shift = (schedule.shifts as any[])?.find((s: any) => s.date === today);
          if (shift) {
            todayShift = shift;
            break;
          }
        }

        const hasSchedule = todayShift && todayShift.shift !== 'off';
        const checkIn = allCheckIns?.find((c: any) => c.user_id === staffProfile.id);

        const userDepartureRequests = allDepartureRequests?.filter((d: any) => d.user_id === staffProfile.id) || [];
        const departureRequest = userDepartureRequests.length > 0
          ? userDepartureRequests.sort((a: any, b: any) =>
              new Date(b.created_at || 0).getTime() - new Date(a.created_at || 0).getTime()
            )[0]
          : null;

        statuses.push({
          user_id: staffProfile.id,
          full_name: staffProfile.full_name,
          shift_type: todayShift?.shift || null,
          has_schedule: hasSchedule,
          checked_in: !!checkIn,
          is_late: checkIn?.is_late || false,
          minutes_late: checkIn?.minutes_late || 0,
          status: checkIn?.status || 'missing',
          check_in_time: checkIn?.check_in_time || null,
          check_in_id: checkIn?.id || null,
          check_out_time: checkIn?.check_out_time || null,
          work_hours: checkIn?.work_hours || null,
          has_departure_request: !!departureRequest,
          departure_status: departureRequest?.status || null,
          departure_request_id: departureRequest?.id || null,
        }) as any;
      }

      console.log('[CheckInOverview] Statuses built successfully:', statuses.length);
      setCheckInStatuses(statuses);
    } catch (error) {
      console.error('Error fetching check-in statuses:', error);
      console.error('Error details:', JSON.stringify(error, null, 2));
    } finally {
      setLoading(false);
    }
  }, [profiles]);

  useEffect(() => {
    if ((profile?.role === 'admin') && profiles.length > 0) {
      fetchCheckInStatuses();

      const checkInsChannel = supabase
        .channel(`check_ins_overview_${Date.now()}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'check_ins',
          },
          () => {
            fetchCheckInStatuses();
          }
        )
        .subscribe();

      const departureChannel = supabase
        .channel(`departure_requests_overview_${Date.now()}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'departure_requests',
          },
          () => {
            fetchCheckInStatuses();
          }
        )
        .subscribe();

      return () => {
        supabase.removeChannel(checkInsChannel);
        supabase.removeChannel(departureChannel);
      };
    }
  }, [fetchCheckInStatuses, profile?.role, profiles.length]);

  if (profile?.role !== 'admin') {
    return null;
  }

  const scheduledStaff = checkInStatuses.filter((s: any) => s.has_schedule);
  const checkedInCount = scheduledStaff.filter((s: any) => s.checked_in).length;
  const missingCount = scheduledStaff.filter((s: any) => !s.checked_in).length;
  const lateCount = scheduledStaff.filter((s: any) => s.checked_in && s.is_late).length;
  const pendingCount = scheduledStaff.filter((s: any) => s.checked_in && s.status === 'pending').length;

  const getStatusIcon = (status: CheckInStatus) => {
    if (!status.has_schedule) {
      return <div className="w-3 h-3 rounded-full bg-gray-300"></div>;
    }
    if (!status.checked_in) {
      return <XCircle className="w-5 h-5 text-red-500" />;
    }
    if (status.status === 'approved') {
      return <CheckCircle className="w-5 h-5 text-green-500" />;
    }
    if (status.is_late) {
      return <Clock className="w-5 h-5 text-orange-500" />;
    }
    return <AlertCircle className="w-5 h-5 text-yellow-500" />;
  };

  const getStatusColor = (status: CheckInStatus) => {
    if (!status.has_schedule) return 'bg-gray-50 border-gray-200';
    if (!status.checked_in) return 'bg-red-50 border-red-300';
    if (status.status === 'approved' && !status.is_late) return 'bg-green-50 border-green-300';
    if (status.is_late) return 'bg-orange-50 border-orange-300';
    return 'bg-yellow-50 border-yellow-300';
  };

  const handleApproveDeparture = async (requestId: string, userId: string) => {
    try {
      const now = new Date().toISOString();

      const { error: updateError } = await supabase
        .from('departure_requests')
        .update({
          status: 'approved',
          admin_id: profile?.id,
          processed_at: now,
        } as any)
        .eq('id', requestId);

      if (updateError) {
        console.error('Error updating departure request:', updateError);
        alert(`${t('admin.errorApproving')}: ${updateError.message}`);
        return;
      }

      const today = getTodayDateString();
      const todayStart = `${today}T00:00:00+07:00`;
      const todayEnd = `${today}T23:59:59+07:00`;

      const { data: checkIn, error: checkInFetchError } = await supabase
        .from('check_ins')
        .select('*')
        .eq('user_id', userId)
        .gte('check_in_time', todayStart)
        .lte('check_in_time', todayEnd)
        .maybeSingle() as any;

      if (checkInFetchError || !checkIn) {
        console.error('Could not find check-in:', checkInFetchError);
      } else if (!checkIn.check_out_time) {
        const checkInTime = new Date(checkIn.check_in_time);
        const checkOutTime = new Date(now);
        const workHours = (checkOutTime.getTime() - checkInTime.getTime()) / (1000 * 60 * 60);

        const { error: checkInUpdateError } = await supabase
          .from('check_ins')
          .update({
            check_out_time: now,
            work_hours: Math.round(workHours * 100) / 100,
          } as any)
          .eq('id', checkIn.id);

        if (checkInUpdateError) {
          console.error('Error updating check-in with work hours:', checkInUpdateError);
        }
      }

      const { error: notifError } = await supabase
        .from('notifications')
        .insert([{
          user_id: userId,
          title: t('departure.departureApprovedTitle'),
          message: t('departure.departureApprovedMessage'),
          type: 'success',
        }] as any);

      if (notifError) {
        console.error('Notification error:', notifError);
      }

      await fetchCheckInStatuses();
    } catch (error: any) {
      console.error('Error approving departure request:', error);
      alert(`${t('admin.errorApproving')}: ${error.message || t('howTo.unknownError')}`);
    }
  };

  const handleApproveCheckIn = async (checkInId: string) => {
    if (!profile?.id) return;

    try {
      const { error } = await supabase.rpc('approve_check_in', {
        p_check_in_id: checkInId,
        p_admin_id: profile.id,
        p_custom_points: null,
      }) as any;

      if (error) throw error;

      await fetchCheckInStatuses();
    } catch (error: any) {
      console.error('Error approving check-in:', error);
      alert(`${t('admin.errorApproving')}: ${error.message || t('howTo.unknownError')}`);
    }
  };

  const handleRejectCheckIn = async (checkInId: string) => {
    if (!profile?.id) return;

    const reason = prompt('Grund für Ablehnung:');
    if (!reason) return;

    try {
      const { error } = await supabase.rpc('reject_check_in', {
        p_check_in_id: checkInId,
        p_admin_id: profile.id,
        p_reason: reason,
      }) as any;

      if (error) throw error;

      await fetchCheckInStatuses();
    } catch (error: any) {
      console.error('Error rejecting check-in:', error);
      alert(`${t('admin.errorRejecting')}: ${error.message || t('howTo.unknownError')}`);
    }
  };

  const handleRejectDeparture = async (requestId: string, userId: string) => {
    try {
      const { error: updateError } = await supabase
        .from('departure_requests')
        .update({
          status: 'rejected',
          admin_id: profile?.id,
          processed_at: new Date().toISOString(),
        } as any)
        .eq('id', requestId);

      if (updateError) {
        console.error('Error updating departure request:', updateError);
        alert(`${t('admin.errorRejecting')}: ${updateError.message}`);
        return;
      }

      const { error: notifError } = await supabase
        .from('notifications')
        .insert([{
          user_id: userId,
          title: t('departure.departureRejectedTitle'),
          message: t('departure.departureRejectedMessage'),
          type: 'error',
        }] as any);

      if (notifError) {
        console.error('Notification error:', notifError);
      }

      await fetchCheckInStatuses();
    } catch (error: any) {
      console.error('Error rejecting departure request:', error);
      alert(`${t('admin.errorRejecting')}: ${error.message || t('howTo.unknownError')}`);
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
          <h2 className="text-3xl font-bold text-gray-900">Check-In Overview</h2>
        </div>
        <div className="flex items-center space-x-3">
          <button
            onClick={() => onNavigate?.('checkin-history')}
            className="flex items-center space-x-2 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors"
          >
            <History className="w-5 h-5" />
            <span>Historie</span>
          </button>
          <button
            onClick={fetchCheckInStatuses}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Refresh
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Scheduled</p>
              <p className="text-3xl font-bold text-gray-900">{scheduledStaff.length}</p>
            </div>
            <Users className="w-10 h-10 text-blue-500" />
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 shadow-sm border border-green-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Checked In</p>
              <p className="text-3xl font-bold text-green-600">{checkedInCount}</p>
            </div>
            <CheckCircle className="w-10 h-10 text-green-500" />
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 shadow-sm border border-red-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Missing</p>
              <p className="text-3xl font-bold text-red-600">{missingCount}</p>
            </div>
            <XCircle className="w-10 h-10 text-red-500" />
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 shadow-sm border border-orange-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-600">Late / Pending</p>
              <p className="text-3xl font-bold text-orange-600">{lateCount} / {pendingCount}</p>
            </div>
            <Clock className="w-10 h-10 text-orange-500" />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
        <h3 className="text-xl font-bold text-gray-900 mb-4">Staff Status</h3>

        {loading ? (
          <div className="animate-pulse space-y-3">
            {[1, 2, 3, 4, 5].map(i => (
              <div key={i} className="h-16 bg-gray-200 rounded-lg"></div>
            ))}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-beige-50 border-b-2 border-beige-200">
                <tr>
                  <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Status</th>
                  <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Name</th>
                  <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Schicht</th>
                  <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Check-in</th>
                  <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Checkout-Anfrage</th>
                  <th className="px-4 py-3 text-left text-sm font-semibold text-gray-700">Arbeitszeit</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {checkInStatuses.map((status) => (
                  <tr key={status.user_id} className={getStatusColor(status)}>
                    <td className="px-4 py-3">
                      <div className="flex items-center">
                        {getStatusIcon(status)}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <p className="font-semibold text-gray-900">{status.full_name}</p>
                    </td>
                    <td className="px-4 py-3">
                      <p className="text-sm text-gray-600">
                        {!status.has_schedule ? (
                          <span className="text-gray-500">Off</span>
                        ) : (
                          <span className="capitalize">{status.shift_type === 'morning' ? 'Früh' : 'Spät'}</span>
                        )}
                      </p>
                    </td>
                    <td className="px-4 py-3">
                      {status.check_in_time ? (
                        <div className="flex items-center space-x-2">
                          <div>
                            <p className="text-sm font-medium text-gray-900">
                              {new Date(status.check_in_time).toLocaleTimeString('de-DE', {
                                hour: '2-digit',
                                minute: '2-digit',
                                timeZone: 'Asia/Phnom_Penh',
                              })}
                            </p>
                            {status.is_late && (
                              <p className="text-xs text-orange-600">+{status.minutes_late} min</p>
                            )}
                            {status.status === 'pending' && (
                              <p className="text-xs text-yellow-600">Pending</p>
                            )}
                            {status.status === 'approved' && (
                              <p className="text-xs text-green-600">Genehmigt</p>
                            )}
                            {status.status === 'rejected' && (
                              <p className="text-xs text-red-600">Abgelehnt</p>
                            )}
                          </div>
                          {status.status === 'pending' && status.check_in_id && (
                            <div className="flex items-center space-x-1">
                              <button
                                onClick={() => handleApproveCheckIn(status.check_in_id!)}
                                className="p-1 text-green-600 hover:bg-green-50 rounded border border-green-300"
                                title="Genehmigen"
                              >
                                <Check className="w-4 h-4" />
                              </button>
                              <button
                                onClick={() => handleRejectCheckIn(status.check_in_id!)}
                                className="p-1 text-red-600 hover:bg-red-50 rounded border border-red-300"
                                title="Ablehnen"
                              >
                                <XIcon className="w-4 h-4" />
                              </button>
                            </div>
                          )}
                        </div>
                      ) : (
                        <span className="text-sm text-red-600">-</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {status.has_departure_request ? (
                        <div className="flex items-center space-x-2">
                          <LogOut className="w-4 h-4 text-blue-600" />
                          {status.departure_status === 'pending' && status.departure_request_id ? (
                            <div className="flex items-center space-x-2">
                              <button
                                onClick={() => handleApproveDeparture(status.departure_request_id!, status.user_id)}
                                className="p-1 text-green-600 hover:bg-green-50 rounded border border-green-300"
                                title="Genehmigen"
                              >
                                <Check className="w-4 h-4" />
                              </button>
                              <button
                                onClick={() => handleRejectDeparture(status.departure_request_id!, status.user_id)}
                                className="p-1 text-red-600 hover:bg-red-50 rounded border border-red-300"
                                title="Ablehnen"
                              >
                                <XIcon className="w-4 h-4" />
                              </button>
                            </div>
                          ) : (
                            <span className={`text-sm font-medium ${
                              status.departure_status === 'approved' ? 'text-green-600' :
                              status.departure_status === 'rejected' ? 'text-red-600' :
                              'text-yellow-600'
                            }`}>
                              {status.departure_status === 'approved' ? 'Genehmigt' :
                               status.departure_status === 'rejected' ? 'Abgelehnt' :
                               'Ausstehend'}
                            </span>
                          )}
                        </div>
                      ) : (
                        <span className="text-sm text-gray-400">-</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      {status.work_hours ? (
                        <p className="text-sm font-semibold text-gray-900">
                          {status.work_hours.toFixed(2)}h
                        </p>
                      ) : status.check_in_time && !status.check_out_time ? (
                        <p className="text-sm text-blue-600 animate-pulse">
                          Läuft...
                        </p>
                      ) : (
                        <span className="text-sm text-gray-400">-</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
