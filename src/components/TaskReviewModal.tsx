import { useState } from 'react';
import { X, Upload, CheckCircle, XCircle } from 'lucide-react';
import { TaskItemsList } from './TaskItemsList';
import { supabase } from '../lib/supabase';
import { useTranslation } from 'react-i18next';

interface TaskReviewModalProps {
  task: any;
  onClose: () => void;
  onComplete: () => void;
}

export function TaskReviewModal({ task, onClose, onComplete }: TaskReviewModalProps) {
  const { t } = useTranslation();
  const [rejectedItems, setRejectedItems] = useState<string[]>([]);
  const [adminPhotos, setAdminPhotos] = useState<File[]>([]);
  const [adminNotes, setAdminNotes] = useState('');
  const [bonusPoints, setBonusPoints] = useState(0);
  const [loading, setLoading] = useState(false);

  const hasItems = task.items && Array.isArray(task.items) && task.items.length > 0;
  const helperName = task.secondary_assigned_to
    ? task.profiles_tasks_secondary_assigned_toToprofiles?.full_name
    : null;

  const toggleItemRejection = (itemId: string) => {
    setRejectedItems(prev =>
      prev.includes(itemId)
        ? prev.filter(id => id !== itemId)
        : [...prev, itemId]
    );
  };

  const uploadPhotos = async () => {
    const urls: string[] = [];
    for (const file of adminPhotos) {
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;

      const { error } = await supabase.storage
        .from('admin-reviews')
        .upload(fileName, file);

      if (!error) {
        const { data } = supabase.storage.from('admin-reviews').getPublicUrl(fileName);
        urls.push(data.publicUrl);
      }
    }
    return urls;
  };

  const handleApprove = async () => {
    setLoading(true);
    try {
      const photoUrls = await uploadPhotos();

      const { error } = await supabase.rpc('approve_task_with_items', {
        p_task_id: task.id,
        p_admin_id: (await supabase.auth.getUser()).data.user?.id,
        p_approved: true,
        p_rejection_reason: null,
        p_rejected_items: [],
        p_admin_photos: photoUrls,
        p_admin_notes: adminNotes,
        p_bonus_points: bonusPoints
      }) as any;

      if (error) throw error;
      onComplete();
    } catch (error) {
      console.error('Error approving task:', error);
      alert(t('tasks.errorApprovingTask'));
    } finally {
      setLoading(false);
    }
  };

  const handleReject = async () => {
    if (rejectedItems.length === 0 && !adminNotes) {
      alert(t('tasks.provideReasonOrSelect'));
      return;
    }

    setLoading(true);
    try {
      const photoUrls = await uploadPhotos();

      const { error } = await supabase.rpc('approve_task_with_items', {
        p_task_id: task.id,
        p_admin_id: (await supabase.auth.getUser()).data.user?.id,
        p_approved: false,
        p_rejection_reason: adminNotes || t('tasks.pleaseRedoTask'),
        p_rejected_items: rejectedItems,
        p_admin_photos: photoUrls,
        p_admin_notes: adminNotes,
        p_bonus_points: 0
      }) as any;

      if (error) throw error;
      onComplete();
    } catch (error) {
      console.error('Error rejecting task:', error);
      alert(t('tasks.errorRejectingTask'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-xl p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-xl font-bold text-gray-900">Task Review</h3>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Task Info */}
        <div className="mb-6 p-4 bg-gray-50 rounded-lg">
          <h4 className="font-semibold text-gray-900 mb-2">{task.title}</h4>
          {task.description && <p className="text-sm text-gray-600 mb-2">{task.description}</p>}
          <div className="flex items-center space-x-4 text-sm text-gray-600">
            <span>👤 {task.profiles?.full_name}</span>
            {helperName && <span>🤝 mit {helperName}</span>}
            <span>⭐ {task.points_value} Punkte{helperName && ' pro Person'}</span>
          </div>
        </div>

        {/* Staff Photos */}
        {task.photo_urls && task.photo_urls.length > 0 && (
          <div className="mb-6">
            <h5 className="font-medium text-gray-900 mb-2">Fotos vom Staff:</h5>
            <div className="grid grid-cols-3 gap-2">
              {task.photo_urls.map((url: string, idx: number) => (
                <img
                  key={idx}
                  src={url}
                  alt={`Staff foto ${idx + 1}`}
                  className="w-full h-32 object-cover rounded-lg border"
                />
              ))}
            </div>
          </div>
        )}

        {/* Items Review */}
        {hasItems && (
          <div className="mb-6">
            <h5 className="font-medium text-gray-900 mb-3">Aufgaben Review:</h5>
            <div className="space-y-2">
              {task.items.map((item: any, index: number) => (
                <div
                  key={item.id || index}
                  className={`p-3 rounded-lg border-2 ${
                    rejectedItems.includes(item.id)
                      ? 'bg-red-50 border-red-300'
                      : 'bg-green-50 border-green-300'
                  }`}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-2">
                        <CheckCircle className="w-4 h-4 text-green-600" />
                        <p className="text-sm text-gray-900">{item.text}</p>
                      </div>
                      {item.completed_by && (
                        <p className="text-xs text-gray-500 mt-1 ml-6">
                          Von: {item.completed_by}
                        </p>
                      )}
                    </div>
                    <div className="flex space-x-2">
                      <button
                        onClick={() => {
                          if (rejectedItems.includes(item.id)) {
                            setRejectedItems(prev => prev.filter(id => id !== item.id));
                          }
                        }}
                        className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
                          !rejectedItems.includes(item.id)
                            ? 'bg-green-600 text-white'
                            : 'bg-gray-200 text-gray-700 hover:bg-green-100'
                        }`}
                      >
                        ✓ OK
                      </button>
                      <button
                        onClick={() => toggleItemRejection(item.id)}
                        className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${
                          rejectedItems.includes(item.id)
                            ? 'bg-red-600 text-white'
                            : 'bg-gray-200 text-gray-700 hover:bg-red-100'
                        }`}
                      >
                        ✗ Ablehnen
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Bonus Points */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Bonus-Punkte (optional)
          </label>
          <input
            type="number"
            value={bonusPoints}
            onChange={(e) => setBonusPoints(parseInt(e.target.value) || 0)}
            min="0"
            className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
          />
        </div>

        {/* Admin Photos */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Admin Fotos (optional)
          </label>
          <input
            type="file"
            accept="image/*"
            multiple
            onChange={(e) => setAdminPhotos(Array.from(e.target.files || []))}
            className="w-full text-sm"
          />
          {adminPhotos.length > 0 && (
            <p className="text-sm text-green-600 mt-2">{adminPhotos.length} Foto(s) ausgewählt</p>
          )}
        </div>

        {/* Admin Notes */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Admin Notizen
          </label>
          <textarea
            value={adminNotes}
            onChange={(e) => setAdminNotes(e.target.value)}
            rows={3}
            className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
            placeholder="Feedback, Anmerkungen..."
          />
        </div>

        {/* Actions */}
        <div className="flex space-x-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300"
          >
            Abbrechen
          </button>
          <button
            onClick={handleReject}
            disabled={loading}
            className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 disabled:bg-gray-300"
          >
            <XCircle className="w-4 h-4 inline mr-2" />
            {rejectedItems.length > 0 ? `${rejectedItems.length} Items ablehnen` : 'Ablehnen'}
          </button>
          <button
            onClick={handleApprove}
            disabled={loading}
            className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-300"
          >
            <CheckCircle className="w-4 h-4 inline mr-2" />
            Genehmigen
          </button>
        </div>
      </div>
    </div>
  );
}
