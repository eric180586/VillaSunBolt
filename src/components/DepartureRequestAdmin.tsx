import { useAuth } from '../contexts/AuthContext';
import { useDepartureRequests } from '../hooks/useDepartureRequests';
import { useProfiles } from '../hooks/useProfiles';
import { Home, Check, X, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useTranslation } from 'react-i18next';

export function DepartureRequestAdmin({ onBack }: { onBack?: () => void } = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { requests, refetch } = useDepartureRequests();
  const { profiles } = useProfiles();

  const pendingRequests = requests.filter((r) => r.status === 'pending');

  const handleApprove = async (requestId: string, userId: string) => {
    try {
      // First verify user has checked in today
      const request = requests.find(r => r.id === requestId);
      if (!request) {
        alert(t('common.error'));
        return;
      }

      const { data: checkIn, error: checkInError } = await supabase
        .from('check_ins')
        .select('id, check_out_time')
        .eq('user_id', userId)
        .eq('check_in_date', request.shift_date)
        .in('status', ['approved', 'pending'])
        .maybeSingle() as any;

      if (checkInError) throw checkInError;

      if (!checkIn) {
        alert(t('departure.errorNoCheckIn'));
        return;
      }

      if (checkIn.check_out_time) {
        alert(t('common.error'));
        return;
      }

      // Now update check-out time
      const { error: checkOutError } = await supabase
        .from('check_ins')
        .update({
          check_out_time: new Date().toISOString(),
        })
        .eq('id', checkIn.id);

      if (checkOutError) throw checkOutError;

      const { error: updateError } = await supabase
        .from('departure_requests')
        .update({
          status: 'approved',
          admin_id: profile?.id,
          processed_at: new Date().toISOString(),
        })
        .eq('id', requestId);

      if (updateError) throw updateError;

      const { error: notifError } = await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          title: t('departure.departureApprovedTitle'),
          message: t('departure.departureApprovedMessage'),
          type: 'success',
        }) as any;

      if (notifError) {
        console.error('Notification error:', notifError);
      }

      await refetch();
    } catch (error) {
      console.error('Error approving request:', error);
      alert(t('admin.errorApproving'));
    }
  };

  const handleReject = async (requestId: string, userId: string) => {
    try {
      const { error: updateError } = await supabase
        .from('departure_requests')
        .update({
          status: 'rejected',
          admin_id: profile?.id,
          processed_at: new Date().toISOString(),
        })
        .eq('id', requestId);

      if (updateError) throw updateError;

      const { error: notifError } = await supabase
        .from('notifications')
        .insert({
          user_id: userId,
          title: t('departure.departureRejectedTitle'),
          message: t('departure.departureRejectedMessage'),
          type: 'error',
        }) as any;

      if (notifError) {
        console.error('Notification error:', notifError);
      }

      await refetch();
    } catch (error) {
      console.error('Error rejecting request:', error);
      alert(t('admin.errorRejecting'));
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
          <h2 className="text-3xl font-bold text-gray-900">{t('departure.departureRequests')}</h2>
        </div>
      </div>

      {pendingRequests.length === 0 ? (
        <div className="bg-white rounded-xl p-12 text-center shadow-sm border border-gray-200">
          <Home className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-900 mb-2">{t('admin.noPendingItems')}</h3>
          <p className="text-gray-600">{t('departure.allProcessed')}</p>
        </div>
      ) : (
        <div className="space-y-4">
          {pendingRequests.map((request) => {
            const user = profiles.find((p) => p.id === request.user_id);
            return (
              <div key={request.id} className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-4">
                    <div className="w-12 h-12 bg-gradient-to-br from-orange-500 to-pink-600 rounded-full flex items-center justify-center text-white font-bold text-lg">
                      {user?.full_name.charAt(0)}
                    </div>
                    <div>
                      <h3 className="text-lg font-bold text-gray-900">{user?.full_name}</h3>
                      <p className="text-sm text-gray-600">
                        {t('schedules.shift')}: <span className="font-medium">{request.shift_type === 'früh' ? t('schedules.morning') : t('schedules.late')}</span>
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        {t('departure.requestTime')}: {new Date(request.created_at).toLocaleString('de-DE')}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-3">
                    <button
                      onClick={() => handleApprove(request.id, request.user_id)}
                      className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                    >
                      <Check className="w-5 h-5" />
                      <span>{t('departure.approve')}</span>
                    </button>
                    <button
                      onClick={() => handleReject(request.id, request.user_id)}
                      className="flex items-center space-x-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                    >
                      <X className="w-5 h-5" />
                      <span>{t('departure.reject')}</span>
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
