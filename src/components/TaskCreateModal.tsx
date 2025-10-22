import { useState, useEffect } from 'react';
import { X, Plus, Trash2, Upload } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { combineDateAndTime, getTodayDateString } from '../lib/dateUtils';

const CATEGORIES = [
  { id: 'daily_morning', label: 'Daily Morning', color: 'bg-orange-500' },
  { id: 'room_cleaning', label: 'Room Cleaning', color: 'bg-blue-500' },
  { id: 'small_cleaning', label: 'Small Cleaning', color: 'bg-cyan-500' },
  { id: 'extras', label: 'Extras', color: 'bg-purple-500' },
  { id: 'housekeeping', label: 'Housekeeping', color: 'bg-green-500' },
  { id: 'reception', label: 'Reception', color: 'bg-pink-500' },
  { id: 'shopping', label: 'Shopping', color: 'bg-yellow-500' },
  { id: 'repair', label: 'Repair/Need new', color: 'bg-red-500' },
  { id: 'admin', label: 'Admin', color: 'bg-gray-700' },
];

const RECURRENCE_OPTIONS = [
  { value: 'one_time', label: 'Einmalig' },
  { value: 'daily', label: 'Täglich' },
  { value: 'weekly', label: 'Wöchentlich' },
  { value: 'bi_weekly', label: 'Alle 2 Wochen' },
  { value: 'monthly', label: 'Monatlich' },
];

interface TaskCreateModalProps {
  onClose: () => void;
  onComplete: () => void;
  profiles: any[];
  editingTask?: any;
}

export function TaskCreateModal({ onClose, onComplete, profiles, editingTask }: TaskCreateModalProps) {
  const [formData, setFormData] = useState({
    category: 'extras',
    title: '',
    description: '',
    due_date: getTodayDateString(),
    due_time: '23:59',
    duration_minutes: 30,
    points_value: 10,
    assigned_to: '',
    is_template: false,
    recurrence: 'one_time',
    has_items: false,
  });

  const [items, setItems] = useState<string[]>(['']);
  const [photoSettings, setPhotoSettings] = useState({
    photo_proof_required: false,
    photo_required_sometimes: false,
    photo_optional: false,
    photo_explanation_text: '',
  });
  const [descriptionPhotos, setDescriptionPhotos] = useState<File[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (editingTask) {
      setFormData({
        category: editingTask.category || 'extras',
        title: editingTask.title || '',
        description: editingTask.description || '',
        due_date: editingTask.due_date ? new Date(editingTask.due_date).toISOString().split('T')[0] : getTodayDateString(),
        due_time: editingTask.due_date ? new Date(editingTask.due_date).toTimeString().slice(0, 5) : '23:59',
        duration_minutes: editingTask.duration_minutes || 30,
        points_value: editingTask.points_value || 10,
        assigned_to: editingTask.assigned_to || '',
        is_template: editingTask.is_template || false,
        recurrence: editingTask.recurrence || 'one_time',
        has_items: editingTask.items && editingTask.items.length > 0,
      });

      if (editingTask.items && editingTask.items.length > 0) {
        setItems(editingTask.items.map((item: any) => item.text));
      }

      setPhotoSettings({
        photo_proof_required: editingTask.photo_proof_required || false,
        photo_required_sometimes: editingTask.photo_required_sometimes || false,
        photo_optional: editingTask.photo_optional || false,
        photo_explanation_text: editingTask.photo_explanation_text || '',
      });
    }
  }, [editingTask]);

  const addItem = () => {
    setItems([...items, '']);
  };

  const updateItem = (index: number, value: string) => {
    const newItems = [...items];
    newItems[index] = value;
    setItems(newItems);
  };

  const removeItem = (index: number) => {
    setItems(items.filter((_, i) => i !== index));
  };

  const uploadPhotos = async () => {
    const urls: string[] = [];
    for (const file of descriptionPhotos) {
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
    if (!formData.title) {
      alert('Bitte Titel eingeben!');
      return;
    }

    if (!formData.is_template && !formData.assigned_to) {
      alert('Bitte Mitarbeiter zuweisen!');
      return;
    }

    if (formData.has_items && items.filter(i => i.trim()).length === 0) {
      alert('Bitte mindestens eine Aufgabe hinzufügen!');
      return;
    }

    setLoading(true);
    try {
      const photoUrls = await uploadPhotos();
      const dueDateTime = combineDateAndTime(formData.due_date, formData.due_time);

      const itemsData = formData.has_items
        ? items.filter(i => i.trim()).map((text, idx) => ({
            id: `item-${Date.now()}-${idx}`,
            text: text.trim(),
            is_completed: false,
            completed_by: null,
            completed_by_id: null,
            completed_at: null,
            admin_reviewed: false,
            admin_rejected: false,
          }))
        : [];

      const taskData = {
        ...formData,
        due_date: dueDateTime,
        items: itemsData,
        description_photo: photoUrls,
        ...photoSettings,
        initial_points_value: formData.points_value,
        status: formData.is_template ? 'pending' : 'pending',
      };

      if (editingTask) {
        const { error } = await supabase
          .from('tasks')
          .update(taskData)
          .eq('id', editingTask.id);

        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('tasks')
          .insert([taskData]);

        if (error) throw error;
      }

      onComplete();
    } catch (error) {
      console.error('Error saving task:', error);
      alert('Fehler beim Speichern!');
    } finally {
      setLoading(false);
    }
  };

  const staffProfiles = profiles.filter(p => p.role === 'staff');

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-xl p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-xl font-bold text-gray-900">
            {editingTask ? 'Task bearbeiten' : 'Neuer Task'}
          </h3>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Template Toggle */}
        <div className="mb-6 p-4 bg-purple-50 rounded-lg">
          <label className="flex items-center space-x-3 cursor-pointer">
            <input
              type="checkbox"
              checked={formData.is_template}
              onChange={(e) => setFormData({ ...formData, is_template: e.target.checked })}
              className="w-4 h-4 text-purple-600"
            />
            <span className="font-medium text-gray-900">Als Vorlage speichern (wiederkehrend)</span>
          </label>

          {formData.is_template && (
            <div className="mt-3">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Wiederkehr
              </label>
              <select
                value={formData.recurrence}
                onChange={(e) => setFormData({ ...formData, recurrence: e.target.value })}
                className="w-full p-2 border border-gray-300 rounded-lg"
              >
                {RECURRENCE_OPTIONS.map(opt => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
          )}
        </div>

        <div className="grid grid-cols-2 gap-4 mb-4">
          {/* Category */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Kategorie *
            </label>
            <select
              value={formData.category}
              onChange={(e) => setFormData({ ...formData, category: e.target.value })}
              className="w-full p-2 border border-gray-300 rounded-lg"
            >
              {CATEGORIES.map(cat => (
                <option key={cat.id} value={cat.id}>{cat.label}</option>
              ))}
            </select>
          </div>

          {/* Assigned To */}
          {!formData.is_template && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Zugewiesen an *
              </label>
              <select
                value={formData.assigned_to}
                onChange={(e) => setFormData({ ...formData, assigned_to: e.target.value })}
                className="w-full p-2 border border-gray-300 rounded-lg"
              >
                <option value="">Auswählen...</option>
                {staffProfiles.map(p => (
                  <option key={p.id} value={p.id}>{p.full_name}</option>
                ))}
              </select>
            </div>
          )}
        </div>

        {/* Title */}
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Titel *
          </label>
          <input
            type="text"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
            className="w-full p-2 border border-gray-300 rounded-lg"
            placeholder="Z.B. Zimmer Venus reinigen"
          />
        </div>

        {/* Description */}
        <div className="mb-4">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Beschreibung
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            rows={3}
            className="w-full p-2 border border-gray-300 rounded-lg"
            placeholder="Zusätzliche Details..."
          />
        </div>

        {/* Has Items Toggle */}
        <div className="mb-6 p-4 bg-blue-50 rounded-lg">
          <label className="flex items-center space-x-3 cursor-pointer">
            <input
              type="checkbox"
              checked={formData.has_items}
              onChange={(e) => setFormData({ ...formData, has_items: e.target.checked })}
              className="w-4 h-4 text-blue-600"
            />
            <span className="font-medium text-gray-900">Hat Teilaufgaben (Items)</span>
          </label>

          {formData.has_items && (
            <div className="mt-4 space-y-2">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Aufgaben
              </label>
              {items.map((item, index) => (
                <div key={index} className="flex items-center space-x-2">
                  <input
                    type="text"
                    value={item}
                    onChange={(e) => updateItem(index, e.target.value)}
                    className="flex-1 p-2 border border-gray-300 rounded-lg text-sm"
                    placeholder={`Aufgabe ${index + 1}`}
                  />
                  <button
                    onClick={() => removeItem(index)}
                    className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              ))}
              <button
                onClick={addItem}
                className="flex items-center space-x-2 text-blue-600 hover:text-blue-700 text-sm font-medium"
              >
                <Plus className="w-4 h-4" />
                <span>Weitere Aufgabe hinzufügen</span>
              </button>
            </div>
          )}
        </div>

        <div className="grid grid-cols-3 gap-4 mb-4">
          {/* Date & Time */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Datum
            </label>
            <input
              type="date"
              value={formData.due_date}
              onChange={(e) => setFormData({ ...formData, due_date: e.target.value })}
              className="w-full p-2 border border-gray-300 rounded-lg"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Zeit
            </label>
            <input
              type="time"
              value={formData.due_time}
              onChange={(e) => setFormData({ ...formData, due_time: e.target.value })}
              className="w-full p-2 border border-gray-300 rounded-lg"
            />
          </div>

          {/* Points */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Punkte
            </label>
            <input
              type="number"
              value={formData.points_value}
              onChange={(e) => setFormData({ ...formData, points_value: parseInt(e.target.value) || 0 })}
              className="w-full p-2 border border-gray-300 rounded-lg"
            />
          </div>
        </div>

        {/* Submit */}
        <div className="flex space-x-3 mt-6">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300"
          >
            Abbrechen
          </button>
          <button
            onClick={handleSubmit}
            disabled={loading}
            className="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:bg-gray-300"
          >
            {loading ? 'Speichert...' : editingTask ? 'Aktualisieren' : 'Erstellen'}
          </button>
        </div>
      </div>
    </div>
  );
}
