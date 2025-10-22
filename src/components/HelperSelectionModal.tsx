import { X, Users, Upload } from 'lucide-react';
import { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

interface HelperSelectionModalProps {
  isOpen: boolean;
  task: any;
  onClose: () => void;
  onComplete: () => void;
  staffMembers: any[];
}

export function HelperSelectionModal({
  isOpen,
  task,
  onClose,
  onComplete,
  staffMembers,
}: HelperSelectionModalProps) {
  const { profile } = useAuth();
  const [selectedHelper, setSelectedHelper] = useState<string | null>(null);
  const [photos, setPhotos] = useState<File[]>([]);
  const [notes, setNotes] = useState('');
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files) {
      setPhotos(Array.from(e.target.files));
    }
  };

  const uploadPhotos = async () => {
    const urls: string[] = [];
    for (const file of photos) {
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;

      const { error } = await supabase.storage
        .from('task-photos')
        .upload(fileName, file);

      if (!error) {
        const { data } = supabase.storage.from('task-photos').getPublicUrl(fileName);
        urls.push(data.publicUrl);
      }
    }
    return urls;
  };

  const handleSubmit = async (helperChoice: 'none' | 'helper') => {
    if (helperChoice === 'helper' && !selectedHelper) {
      alert('Bitte wähle einen Helfer aus');
      return;
    }

    setLoading(true);
    try {
      const photoUrls = await uploadPhotos();

      const updateData: any = {
        status: 'pending_review',
        completed_at: new Date().toISOString(),
        photo_urls: photoUrls,
        completion_notes: notes,
      };

      // If helper was selected, split points 50/50
      if (helperChoice === 'helper' && selectedHelper) {
        updateData.secondary_assigned_to = selectedHelper;
        const halfPoints = Math.floor((task.points_value || task.initial_points_value || 10) / 2);
        updateData.points_value = halfPoints;
      }

      const { error } = await supabase
        .from('tasks')
        .update(updateData)
        .eq('id', task.id);

      if (error) throw error;

      // Create notification for admin
      const adminQuery = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'admin')
        .single();

      if (adminQuery.data) {
        const helperName = helperChoice === 'helper' && selectedHelper
          ? staffMembers.find(s => s.id === selectedHelper)?.full_name
          : null;

        await supabase.from('notifications').insert({
          user_id: adminQuery.data.id,
          type: 'task_completed',
          title: 'Task zur Review',
          message: helperName
            ? `${profile?.full_name} und ${helperName} haben "${task.title}" abgeschlossen`
            : `${profile?.full_name} hat "${task.title}" abgeschlossen`,
          reference_id: task.id,
          priority: 'high'
        });
      }

      onComplete();
      onClose();
    } catch (error) {
      console.error('Error completing task:', error);
      alert('Fehler beim Abschließen: ' + (error as any).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[60] p-4">
      <div className="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Users className="w-6 h-6 text-blue-600" />
            <h3 className="text-xl font-semibold text-gray-900">
              War ein zweiter Mitarbeiter beteiligt?
            </h3>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            disabled={loading}
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-6 space-y-4">
          {/* Photo Upload (Optional) */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Foto (optional)
            </label>
            <div className="flex items-center space-x-2">
              <input
                type="file"
                accept="image/*"
                multiple
                onChange={handlePhotoChange}
                className="flex-1 text-sm"
                disabled={loading}
              />
              <Upload className="w-5 h-5 text-gray-400" />
            </div>
            {photos.length > 0 && (
              <p className="text-sm text-green-600 mt-2">
                {photos.length} Foto(s) ausgewählt
              </p>
            )}
          </div>

          {/* Notes (Optional) */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Notizen (optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={3}
              className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500"
              placeholder="Zusätzliche Anmerkungen..."
              disabled={loading}
            />
          </div>

          <div className="border-t border-gray-200 pt-4">
            <p className="text-gray-600 mb-4">
              Hat dir jemand bei dieser Aufgabe geholfen? Die Punkte werden 50/50 aufgeteilt.
            </p>

            <button
              onClick={() => handleSubmit('none')}
              disabled={loading}
              className="w-full px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium mb-3 disabled:bg-gray-400"
            >
              {loading ? 'Wird abgeschlossen...' : '○ Nein, ich habe alleine gearbeitet'}
            </button>

            <div className="border-t border-gray-200 pt-4">
              <p className="text-sm font-medium text-gray-700 mb-3">
                ● Ja, mit Hilfe von:
              </p>

              <select
                value={selectedHelper || ''}
                onChange={(e) => setSelectedHelper(e.target.value || null)}
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 mb-3"
                disabled={loading}
              >
                <option value="">Helfer auswählen...</option>
                {staffMembers.map((staff) => (
                  <option key={staff.id} value={staff.id}>
                    {staff.full_name}
                  </option>
                ))}
              </select>

              {selectedHelper && (
                <p className="text-sm text-blue-600 mb-3 p-2 bg-blue-50 rounded">
                  ℹ️ Die Punkte werden 50/50 aufgeteilt
                </p>
              )}

              <button
                onClick={() => handleSubmit('helper')}
                disabled={!selectedHelper || loading}
                className="w-full px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium disabled:bg-gray-400 disabled:cursor-not-allowed"
              >
                {loading ? 'Wird abgeschlossen...' : 'Mit Helfer abschließen'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
