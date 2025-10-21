import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useDepartureRequests } from '../hooks/useDepartureRequests';
import { useProfiles } from '../hooks/useProfiles';
import { Home, Check, X, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';

export function DepartureRequestAdmin({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const { requests, refetch } = useDepartureRequests();
  const { profiles } = useProfiles();

  const pendingRequests = requests.filter((r) => r.status === 'pending');

  const handleApprove = async (requestId: string, userId: string) => {
    try {
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
          title: 'Feierabend genehmigt',
          message: 'Deine Feierabend-Anfrage wurde genehmigt. Schönen Feierabend!',
          type: 'success',
        });

      if (notifError) {
        console.error('Notification error:', notifError);
      }

      await refetch();
    } catch (error) {
      console.error('Error approving request:', error);
      alert('Fehler beim Genehmigen der Anfrage');
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
          title: 'Feierabend abgelehnt',
          message: 'Deine Feierabend-Anfrage wurde abgelehnt. Bitte arbeite weiter.',
          type: 'error',
        });

      if (notifError) {
        console.error('Notification error:', notifError);
      }

      await refetch();
    } catch (error) {
      console.error('Error rejecting request:', error);
      alert('Fehler beim Ablehnen der Anfrage');
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
          <h2 className="text-3xl font-bold text-gray-900">Feierabend Anfragen</h2>
        </div>
      </div>

      {pendingRequests.length === 0 ? (
        <div className="bg-white rounded-xl p-12 text-center shadow-sm border border-gray-200">
          <Home className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-900 mb-2">Keine offenen Anfragen</h3>
          <p className="text-gray-600">Alle Feierabend-Anfragen wurden bearbeitet</p>
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
                        Schicht: <span className="font-medium">{request.shift_type === 'früh' ? 'Frühschicht' : 'Spätschicht'}</span>
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        Angefragt: {new Date(request.created_at).toLocaleString('de-DE')}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center space-x-3">
                    <button
                      onClick={() => handleApprove(request.id, request.user_id)}
                      className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                    >
                      <Check className="w-5 h-5" />
                      <span>Genehmigen</span>
                    </button>
                    <button
                      onClick={() => handleReject(request.id, request.user_id)}
                      className="flex items-center space-x-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                    >
                      <X className="w-5 h-5" />
                      <span>Ablehnen</span>
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
