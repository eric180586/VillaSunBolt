import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { CheckCircle, XCircle, Clock, Image as ImageIcon, AlertCircle, ArrowLeft } from 'lucide-react';

interface ChecklistInstance {
  id: string;
  instance_date: string;
  status: string;
  items: any[];
  assigned_to: string;
  completed_at: string;
  photo_proof: string | null;
  admin_reviewed: boolean;
  admin_approved: boolean | null;
  admin_rejection_reason: string | null;
  admin_photos: string | null;
  checklists: {
    title: string;
    category: string;
    points_value: number;
  };
  profiles: {
    full_name: string;
  };
}

export function ChecklistReview({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const [pendingChecklists, setPendingChecklists] = useState<ChecklistInstance[]>([]);
  const [loading, setLoading] = useState(false);
  const [rejectionReason, setRejectionReason] = useState<{ [key: string]: string }>({});
  const [showRejectModal, setShowRejectModal] = useState<string | null>(null);
  const [expandedChecklist, setExpandedChecklist] = useState<string | null>(null);

  // FEATURE DISABLED - Checklists merged into Tasks
  return (
    <div className="p-6">
      <div className="text-center text-gray-600">
        <AlertCircle className="w-12 h-12 mx-auto mb-4 text-yellow-500" />
        <p>Checklist Review Feature ist vorübergehend deaktiviert.</p>
        <p className="text-sm mt-2">Diese Funktion wurde in das Tasks-System integriert.</p>
        {onBack && (
          <button onClick={onBack} className="mt-4 px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600">
            <ArrowLeft className="w-4 h-4 inline mr-2" />
            Zurück
          </button>
        )}
      </div>
    </div>
  );

  // ALL CODE BELOW IS DISABLED - DO NOT EXECUTE
  /*
  useEffect(() => {
    if (profile?.role === 'admin' || profile?.role === 'super_admin') {
      fetchPendingChecklists();

      const channel = supabase
        .channel(`checklist_instances_review_${Date.now()}`)
        .on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table: 'checklist_instances',
          },
          () => {
            fetchPendingChecklists();
          }
        )
        .subscribe();

      return () => {
        supabase.removeChannel(channel);
      };
    }
  }, [profile]);

  const fetchPendingChecklists = async () => {
    const { data, error } = await supabase
      .from('checklist_instances')
      .select(`
        *,
        checklists (title, category, points_value),
        profiles:assigned_to (full_name)
      `)
      .eq('status', 'completed')
      .eq('admin_reviewed', false)
      .order('completed_at', { ascending: false });

    if (error) {
      console.error('Error fetching checklists:', error);
      return;
    }

    setPendingChecklists(data || []);
  };

  const handleApprove = async (checklistId: string) => {
    if (!profile?.id) return;

    setLoading(true);

    try {
      const { data, error } = await supabase.rpc('approve_checklist_instance', {
        p_instance_id: checklistId,
        p_admin_id: profile.id,
      });

      if (error) throw error;

      if (data && !data.success) {
        alert(data.error || 'Fehler beim Genehmigen');
      }

      fetchPendingChecklists();
    } catch (error) {
      console.error('Error approving checklist:', error);
      alert('Fehler beim Genehmigen');
    } finally {
      setLoading(false);
    }
  };

  const handleReject = async (checklistId: string) => {
    if (!profile?.id) return;

    const reason = rejectionReason[checklistId]?.trim();
    if (!reason) {
      alert('Bitte Ablehnungsgrund angeben');
      return;
    }

    setLoading(true);

    try {
      const { data, error } = await supabase.rpc('reject_checklist_instance', {
        p_instance_id: checklistId,
        p_admin_id: profile.id,
        p_rejection_reason: reason,
      });

      if (error) throw error;

      if (data && !data.success) {
        alert(data.error || 'Fehler beim Ablehnen');
      }

      setShowRejectModal(null);
      setRejectionReason({});
      fetchPendingChecklists();
    } catch (error) {
      console.error('Error rejecting checklist:', error);
      alert('Fehler beim Ablehnen');
    } finally {
      setLoading(false);
    }
  };

  const getCategoryColor = (category: string) => {
    const colors: { [key: string]: string } = {
      daily_morning: 'bg-orange-100 text-orange-700',
      room_cleaning: 'bg-blue-100 text-blue-700',
      small_cleaning: 'bg-cyan-100 text-cyan-700',
      extras: 'bg-purple-100 text-purple-700',
      housekeeping: 'bg-green-100 text-green-700',
      reception: 'bg-pink-100 text-pink-700',
      shopping: 'bg-yellow-100 text-yellow-700',
      repair: 'bg-red-100 text-red-700',
      admin: 'bg-gray-100 text-gray-700',
    };
    return colors[category] || 'bg-gray-100 text-gray-700';
  };

  if (profile?.role !== 'admin') {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500">Nur für Admins</p>
      </div>
    );
  }

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
          <h2 className="text-3xl font-bold text-gray-900">Checklist Review</h2>
        </div>
        <div className="flex items-center space-x-2 bg-blue-50 px-4 py-2 rounded-lg">
          <Clock className="w-5 h-5 text-blue-600" />
          <span className="text-blue-900 font-semibold">
            {pendingChecklists.length} warten auf Review
          </span>
        </div>
      </div>

      {pendingChecklists.length === 0 ? (
        <div className="bg-white rounded-xl p-12 text-center shadow-sm border border-gray-200">
          <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
          <p className="text-gray-600 text-lg">Keine Checklists warten auf Review</p>
        </div>
      ) : (
        <div className="space-y-4">
          {pendingChecklists.map((checklist) => (
            <div
              key={checklist.id}
              className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden"
            >
              <div className="p-6">
                <div className="flex items-start justify-between mb-4">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3 mb-2">
                      <span
                        className={`px-3 py-1 rounded-full text-sm font-medium ${getCategoryColor(
                          checklist.checklists.category
                        )}`}
                      >
                        {checklist.checklists.category}
                      </span>
                      <h3 className="text-xl font-bold text-gray-900">
                        {checklist.checklists.title}
                      </h3>
                    </div>
                    <div className="flex items-center space-x-4 text-sm text-gray-600">
                      <span>
                        Abgeschlossen von: <strong>{checklist.profiles?.full_name}</strong>
                      </span>
                      <span>
                        {new Date(checklist.completed_at).toLocaleString('de-DE', {
                          day: '2-digit',
                          month: '2-digit',
                          year: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </span>
                      <span className="text-green-600 font-semibold">
                        {checklist.checklists.points_value} Punkte
                      </span>
                    </div>
                  </div>
                </div>

                <button
                  onClick={() =>
                    setExpandedChecklist(
                      expandedChecklist === checklist.id ? null : checklist.id
                    )
                  }
                  className="text-blue-600 hover:text-blue-700 font-medium mb-3"
                >
                  {expandedChecklist === checklist.id ? 'Details ausblenden' : 'Details anzeigen'}
                </button>

                {expandedChecklist === checklist.id && (
                  <div className="space-y-3 mb-4 bg-gray-50 rounded-lg p-4">
                    <h4 className="font-semibold text-gray-900 mb-2">Checklist Items:</h4>
                    {checklist.items.map((item: any, idx: number) => (
                      <div key={idx} className="flex items-center justify-between space-x-2">
                        <div className="flex items-center space-x-2 flex-1">
                          {item.completed ? (
                            <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0" />
                          ) : (
                            <AlertCircle className="w-5 h-5 text-gray-400 flex-shrink-0" />
                          )}
                          <span
                            className={
                              item.completed ? 'text-gray-700' : 'text-gray-400 line-through'
                            }
                          >
                            {item.text}
                          </span>
                        </div>
                        {item.completed && item.completed_by && (
                          <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded whitespace-nowrap">
                            ✓ {item.completed_by}
                          </span>
                        )}
                      </div>
                    ))}

                    {checklist.photo_proof && (
                      <div className="mt-4">
                        <h4 className="font-semibold text-gray-900 mb-2 flex items-center space-x-2">
                          <ImageIcon className="w-5 h-5" />
                          <span>Foto-Beweis:</span>
                        </h4>
                        <img
                          src={checklist.photo_proof}
                          alt="Beweis-Foto"
                          className="rounded-lg max-w-md cursor-pointer border-2 border-gray-300"
                          onClick={() => window.open(checklist.photo_proof!, '_blank')}
                        />
                      </div>
                    )}
                  </div>
                )}

                <div className="flex items-center space-x-3">
                  <button
                    onClick={() => handleApprove(checklist.id)}
                    disabled={loading}
                    className="flex items-center space-x-2 bg-green-600 text-white px-6 py-3 rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                  >
                    <CheckCircle className="w-5 h-5" />
                    <span>Genehmigen</span>
                  </button>

                  <button
                    onClick={() => setShowRejectModal(checklist.id)}
                    disabled={loading}
                    className="flex items-center space-x-2 bg-red-600 text-white px-6 py-3 rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50"
                  >
                    <XCircle className="w-5 h-5" />
                    <span>Ablehnen</span>
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {showRejectModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowRejectModal(null);
            setRejectionReason({});
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">Checklist ablehnen</h3>
            <p className="text-gray-600 mb-4">
              Bitte gib einen Grund für die Ablehnung an:
            </p>
            <textarea
              value={rejectionReason[showRejectModal] || ''}
              onChange={(e) =>
                setRejectionReason({ ...rejectionReason, [showRejectModal]: e.target.value })
              }
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent mb-4"
              rows={4}
              placeholder="Z.B. Foto unscharf, Item nicht richtig erledigt..."
              autoFocus
            />
            <div className="flex items-center space-x-3">
              <button
                onClick={() => handleReject(showRejectModal)}
                disabled={loading || !rejectionReason[showRejectModal]?.trim()}
                className="flex-1 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors disabled:opacity-50"
              >
                Ablehnen
              </button>
              <button
                onClick={() => {
                  setShowRejectModal(null);
                  setRejectionReason({});
                }}
                disabled={loading}
                className="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-300 transition-colors disabled:opacity-50"
              >
                Abbrechen
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
  */
}
