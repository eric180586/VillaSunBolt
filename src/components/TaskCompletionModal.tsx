import { useState } from 'react';
import { X, Upload, Users } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { TaskItemsList } from './TaskItemsList';
import { PhotoRequirementDice } from './PhotoRequirementDice';
import { supabase } from '../lib/supabase';

interface TaskCompletionModalProps {
  task: any;
  items: any[];
  onClose: () => void;
  onComplete: () => void;
  profiles: any[];
}

export function TaskCompletionModal({ task, items, onClose, onComplete, profiles }: TaskCompletionModalProps) {
  const { profile } = useAuth();
  const [hasHelper, setHasHelper] = useState(false);
  const [selectedHelper, setSelectedHelper] = useState<string>('');
  const [photos, setPhotos] = useState<File[]>([]);
  const [notes, setNotes] = useState('');
  const [showDice, setShowDice] = useState(false);
  const [photoRequired, setPhotoRequired] = useState(task.photo_proof_required);
  const [loading, setLoading] = useState(false);
  const [taskItems, setTaskItems] = useState(items || []);

  const hasItems = taskItems && taskItems.length > 0;
  const allItemsCompleted = !hasItems || taskItems.every(item => item.is_completed);

  const handleToggleItem = (index: number) => {
    const newItems = [...taskItems];
    newItems[index].is_completed = !newItems[index].is_completed;
    setTaskItems(newItems);
  };

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

  const handleSubmit = async () => {
    if (!allItemsCompleted) {
      alert('Bitte alle Aufgaben abhaken bevor du abschließt!');
      return;
    }

    if (photoRequired && photos.length === 0) {
      alert('Foto erforderlich!');
      return;
    }

    if (hasHelper && !selectedHelper) {
      alert('Bitte Helfer auswählen!');
      return;
    }

    setLoading(true);
    try {
      const photoUrls = await uploadPhotos();

      // Update task with completed items
      const updateData: any = {
        status: 'pending_review',
        completed_at: new Date().toISOString(),
        photo_urls: photoUrls,
        completion_notes: notes,
      };

      if (hasItems) {
        updateData.items = taskItems;
      }

      if (hasHelper && selectedHelper) {
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
      const adminResult = await supabase.from('profiles').select('id').eq('role', 'admin').maybeSingle();
      if (adminResult.data) {
        await supabase.from('notifications').insert({
        user_id: adminResult.data.id,
        type: 'task_completed',
        title: 'Task zur Review',
        message: `${profile?.full_name} hat "${task.title}" abgeschlossen`,
        reference_id: task.id,
        priority: 'high'
      });
      }

      if (error) throw error;

      onComplete();
      onClose();
    } catch (error) {
      console.error('Error completing task:', error);
      alert('Fehler beim Abschließen: ' + (error as any).message);
    } finally {
      setLoading(false);
    }
  };

  // Check if photo dice should be shown
  const checkPhotoRequirement = () => {
    if (task.photo_proof_required) {
      setPhotoRequired(true);
    } else if (task.photo_required_sometimes && !photoRequired && !showDice) {
      setShowDice(true);
    }
  };

  const staffProfiles = profiles.filter(p => p.role === 'staff' && p.id !== profile?.id);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-xl font-bold text-gray-900">Task abschließen</h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="mb-4">
          <h4 className="font-semibold text-gray-900 mb-2">{task.title}</h4>
          {task.description && (
            <p className="text-sm text-gray-600">{task.description}</p>
          )}
        </div>

        {hasItems && (
          <div className="mb-6">
            <TaskItemsList
              items={taskItems}
              onToggleItem={handleToggleItem}
              readOnly={false}
              showCompletedBy={false}
            />
          </div>
        )}

        {/* Helper Selection */}
        <div className="mb-6 p-4 bg-blue-50 rounded-lg">
          <div className="flex items-center space-x-2 mb-3">
            <Users className="w-5 h-5 text-blue-600" />
            <p className="font-medium text-gray-900">War ein zweiter Mitarbeiter beteiligt?</p>
          </div>

          <div className="space-y-3">
            <label className="flex items-center space-x-3 cursor-pointer">
              <input
                type="radio"
                checked={!hasHelper}
                onChange={() => {
                  setHasHelper(false);
                  setSelectedHelper('');
                }}
                className="w-4 h-4 text-purple-600"
              />
              <span className="text-gray-700">Nein, nur ich</span>
            </label>

            <label className="flex items-center space-x-3 cursor-pointer">
              <input
                type="radio"
                checked={hasHelper}
                onChange={() => setHasHelper(true)}
                className="w-4 h-4 text-purple-600"
              />
              <span className="text-gray-700">Ja, mit Hilfe</span>
            </label>

            {hasHelper && (
              <select
                value={selectedHelper}
                onChange={(e) => setSelectedHelper(e.target.value)}
                className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
              >
                <option value="">Helfer auswählen...</option>
                {staffProfiles.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.full_name}
                  </option>
                ))}
              </select>
            )}

            {hasHelper && selectedHelper && (
              <p className="text-sm text-blue-600">
                ℹ️ Die Punkte werden 50/50 aufgeteilt
              </p>
            )}
          </div>
        </div>

        {/* Photo Upload */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            {photoRequired ? 'Foto erforderlich *' : 'Foto (optional)'}
          </label>
          <div className="flex items-center space-x-2">
            <input
              type="file"
              accept="image/*"
              multiple
              onChange={handlePhotoChange}
              className="flex-1 text-sm"
            />
            <Upload className="w-5 h-5 text-gray-400" />
          </div>
          {photos.length > 0 && (
            <p className="text-sm text-green-600 mt-2">
              {photos.length} Foto(s) ausgewählt
            </p>
          )}
        </div>

        {/* Notes */}
        <div className="mb-6">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Notizen (optional)
          </label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={3}
            className="w-full p-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
            placeholder="Zusätzliche Anmerkungen..."
          />
        </div>

        {/* Submit Button */}
        <div className="flex space-x-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors"
          >
            Abbrechen
          </button>
          <button
            onClick={handleSubmit}
            disabled={!allItemsCompleted || loading || (hasHelper && !selectedHelper)}
            className="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors disabled:bg-gray-300 disabled:cursor-not-allowed"
          >
            {loading ? 'Wird abgeschlossen...' : 'Abschließen'}
          </button>
        </div>

        {!allItemsCompleted && (
          <p className="text-sm text-red-600 mt-3 text-center">
            ⚠️ Bitte alle Aufgaben abhaken bevor du abschließt
          </p>
        )}
      </div>

      {showDice && (
        <PhotoRequirementDice
          onResult={(required) => {
            setPhotoRequired(required);
            setShowDice(false);
          }}
        />
      )}
    </div>
  );
}
