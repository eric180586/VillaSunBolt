import { useState } from 'react';
import { X, CheckCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { useTranslation } from 'react-i18next';

interface TaskWithItemsModalProps {
  task: any;
  onClose: () => void;
  onComplete: () => void;
  onOpenHelperPopup: () => void;
}

export function TaskWithItemsModal({ task, onClose, onComplete: _onComplete, onOpenHelperPopup }: TaskWithItemsModalProps) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const [items, setItems] = useState(task.items || []);
  const [saving, setSaving] = useState(false);

  const completedCount = items.filter((item: any) => item.is_completed).length;
  const totalCount = items.length;
  const allCompleted = completedCount === totalCount && totalCount > 0;

  const handleToggleItem = async (index: number) => {
    // Optimistic UI update
    const newItems = [...items];
    newItems[index] = {
      ...newItems[index],
      is_completed: !newItems[index].is_completed,
      completed_by: !newItems[index].is_completed ? profile?.full_name : null,
      completed_by_id: !newItems[index].is_completed ? profile?.id : null,
      completed_at: !newItems[index].is_completed ? new Date().toISOString() : null,
    };
    setItems(newItems);

    // Auto-save to database
    setSaving(true);
    try {
      const { error } = await supabase
        .from('tasks')
        .update({ items: newItems })
        .eq('id', task.id);

      if (error) throw error;

      // Check if all items are now completed
      const allNowCompleted = newItems.every((item: any) => item.is_completed);
      if (allNowCompleted) {
        // Check if task already has a helper
        const hasHelper = task.secondary_assigned_to || task.helper_id;

        if (hasHelper) {
          // Task already has helper, skip helper selection and submit directly
          alert('Alle Items abgehakt! Der Task wird jetzt zur Review eingereicht.');

          // Submit task directly without helper selection
          const { error: updateError } = await supabase
            .from('tasks')
            .update({
              status: 'pending_review',
              completed_at: new Date().toISOString()
            })
            .eq('id', task.id);

          if (updateError) {
            alert('Fehler beim Abschließen der Aufgabe');
          } else {
            onClose();
          }
        } else {
          // No helper yet, open helper selection modal
          setTimeout(() => {
            onOpenHelperPopup();
          }, 500);
        }
      }
    } catch (error) {
      console.error('Error saving item:', error);
      // Revert on error
      setItems(items);
      alert(t('tasks.errorSaving'));
    } finally {
      setSaving(false);
    }
  };

  const handleCompleteTask = () => {
    if (!allCompleted) {
      alert(t('tasks.checkAllItems'));
      return;
    }

    // Keep this modal open and open helper popup on top
    onOpenHelperPopup();
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-xl font-bold text-gray-900">{task.title}</h3>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {task.description && (
          <p className="text-sm text-gray-600 mb-4">{task.description}</p>
        )}

        {/* Progress */}
        <div className="mb-6">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-medium text-gray-700">Fortschritt</span>
            <span className="text-sm text-gray-600">
              {completedCount}/{totalCount} erledigt
            </span>
          </div>
          <div className="w-full bg-gray-200 rounded-full h-3">
            <div
              className="bg-green-500 h-3 rounded-full transition-all duration-300"
              style={{ width: `${(completedCount / totalCount) * 100}%` }}
            />
          </div>
        </div>

        {/* Items List */}
        <div className="space-y-2 mb-6">
          {items.map((item: any, index: number) => (
            <div
              key={item.id || index}
              className={`flex items-start space-x-3 p-4 rounded-lg border-2 transition-all cursor-pointer ${
                item.is_completed
                  ? 'bg-green-50 border-green-300'
                  : 'bg-white border-gray-200 hover:border-blue-300'
              }`}
              onClick={() => handleToggleItem(index)}
            >
              <input
                type="checkbox"
                checked={item.is_completed}
                onChange={() => handleToggleItem(index)}
                className="mt-1 h-6 w-6 text-green-600 rounded focus:ring-green-500 cursor-pointer"
                disabled={saving}
              />
              <div className="flex-1">
                <p className={`text-sm font-medium ${item.is_completed ? 'text-gray-600 line-through' : 'text-gray-900'}`}>
                  {item.text}
                </p>
                {item.is_completed && item.completed_by && (
                  <p className="text-xs text-green-600 mt-1">
                    <CheckCircle className="w-3 h-3 inline mr-1" />
                    {item.completed_by}
                  </p>
                )}
              </div>
            </div>
          ))}
        </div>

        {saving && (
          <p className="text-sm text-blue-600 text-center mb-4">
            💾 Wird gespeichert...
          </p>
        )}

        {/* Complete Button */}
        <div className="flex space-x-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors font-medium"
          >
            Abbrechen
          </button>
          <button
            onClick={handleCompleteTask}
            disabled={!allCompleted}
            className={`flex-1 px-4 py-3 rounded-lg font-medium transition-colors ${
              allCompleted
                ? 'bg-green-600 text-white hover:bg-green-700'
                : 'bg-gray-300 text-gray-500 cursor-not-allowed'
            }`}
          >
            {allCompleted ? '✓ Task abschließen' : `${totalCount - completedCount} Items offen`}
          </button>
        </div>

        {!allCompleted && (
          <p className="text-sm text-amber-600 mt-3 text-center">
            ⚠️ Erst wenn ALLE Items abgehakt sind, kann der Task abgeschlossen werden
          </p>
        )}
      </div>
    </div>
  );
}
