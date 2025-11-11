import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useChecklists } from '../hooks/useChecklists';
import { Plus, X, Edit2, Trash2, ClipboardList, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { combineDateAndTime, formatDateForInputFromUTC, formatTimeForInputFromUTC } from '../lib/dateUtils';
import { isAdmin as checkIsAdmin } from '../lib/roleUtils';

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
  { value: 'one_time', label: 'One Time' },
  { value: 'daily', label: 'Daily' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'bi_weekly', label: 'Bi-Weekly' },
  { value: 'monthly', label: 'Monthly' },
];

export function Checklists({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();

  // FEATURE DISABLED - Checklists have been merged into Tasks
  return (
    <div className="p-6">
      <div className="text-center text-gray-600">
        <ClipboardList className="w-12 h-12 mx-auto mb-4 text-yellow-500" />
        <p className="text-lg font-semibold mb-2">Checklist Templates Feature wurde deaktiviert</p>
        <p className="text-sm">Diese Funktion wurde in das Tasks-System integriert.</p>
        <p className="text-sm mt-2">Bitte verwenden Sie Tasks mit der "Template" Option.</p>
        {onBack && (
          <button onClick={onBack} className="mt-4 px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600">
            <ArrowLeft className="w-4 h-4 inline mr-2" />
            Zurück
          </button>
        )}
      </div>
    </div>
  );

  const { checklists, refetch } = useChecklists();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [editingChecklist, setEditingChecklist] = useState<any>(null);

  const isAdmin = profile?.role === 'admin';

  if (!isAdmin) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500">Access denied. Admin only.</p>
      </div>
    );
  }

  const [formData, setFormData] = useState({
    category: 'extras' as string,
    title: '',
    description: '',
    items: [''] as string[],
    due_date: '',
    due_time: '',
    points_value: 10,
    duration_minutes: 30,
    recurrence: 'one_time',
    photo_required: false,
    photo_required_sometimes: false,
    photo_explanation_text: '',
  });

  const [explanationPhoto, setExplanationPhoto] = useState<File[]>([]);

  const uploadPhoto = async (file: File, bucket: string): Promise<string | null> => {
    try {
      console.log('Uploading photo:', file.name, 'to bucket:', bucket);
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from(bucket)
        .upload(filePath, file);

      if (uploadError) {
        console.error('Upload error:', uploadError);
        throw uploadError;
      }

      const { data } = supabase.storage.from(bucket).getPublicUrl(filePath);
      console.log('Photo uploaded successfully:', data.publicUrl);
      return data.publicUrl;
    } catch (error) {
      console.error('Error uploading photo:', error);
      alert('Fehler beim Hochladen des Fotos: ' + error);
      return null;
    }
  };

  const getDefaultDateTime = (category: string) => {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    const dateStr = `${year}-${month}-${day}`;

    switch (category) {
      case 'daily_morning':
        return { date: dateStr, time: '10:00' };
      case 'room_cleaning':
        return { date: dateStr, time: '14:00' };
      default:
        return { date: dateStr, time: '23:59' };
    }
  };

  useEffect(() => {
    if (!editingChecklist) {
      const defaults = getDefaultDateTime(formData.category);
      setFormData((prev) => ({
        ...prev,
        due_date: defaults.date,
        due_time: defaults.time,
      }));
    }
  }, [formData.category, editingChecklist]);

  const getCategoryCounts = (categoryId: string) => {
    return checklists.filter((c) => c.category === categoryId).length;
  };

  const handleCategoryChange = (category: string) => {
    setFormData((prev) => ({
      ...prev,
      category,
    }));
  };

  const handleItemChange = (index: number, value: string) => {
    const newItems = [...formData.items];
    newItems[index] = value;
    setFormData({ ...formData, items: newItems });
  };

  const addItem = () => {
    setFormData({ ...formData, items: [...formData.items, ''] });
  };

  const removeItem = (index: number) => {
    const newItems = formData.items.filter((_, i) => i !== index);
    setFormData({ ...formData, items: newItems });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      let explanationPhotoUrl: string[] | null = null;

      if (explanationPhoto && explanationPhoto.length > 0) {
        console.log('Explanation photos selected, uploading...');
        const uploadedUrls: string[] = [];
        for (const file of explanationPhoto) {
          const url = await uploadPhoto(file, 'checklist-explanations');
          if (url) uploadedUrls.push(url);
        }
        explanationPhotoUrl = uploadedUrls;
        console.log('Explanation photo URLs:', explanationPhotoUrl);
      }

      const dueDateTime = combineDateAndTime(formData.due_date, formData.due_time);
      const itemsJson = formData.items.filter(item => item.trim() !== '').map((text, index) => ({
        id: `item-${Date.now()}-${index}`,
        text,
        is_completed: false,
      }));

      if (editingChecklist) {
        const updateData: any = {
          category: formData.category,
          title: formData.title,
          description: formData.description || null,
          items: itemsJson,
          due_date: dueDateTime,
          points_value: formData.points_value,
          duration_minutes: formData.duration_minutes,
          recurrence: formData.recurrence,
          photo_required: formData.photo_required,
          photo_required_sometimes: formData.photo_required_sometimes,
          photo_explanation_text: formData.photo_explanation_text || null,
          updated_at: new Date().toISOString(),
        };

        if (explanationPhotoUrl) {
          updateData.description_photo = explanationPhotoUrl;
        }

        console.log('Updating checklist template with data:', updateData);
        const { error } = await supabase
          .from('tasks')
          .update(updateData)
          .eq('id', editingChecklist.id);

        if (error) {
          console.error('Update error:', error);
          throw error;
        }
      } else {
        const insertData: any = {
          category: formData.category,
          title: formData.title,
          description: formData.description || null,
          items: itemsJson,
          due_date: dueDateTime,
          points_value: formData.points_value,
          initial_points_value: formData.points_value,
          duration_minutes: formData.duration_minutes,
          recurrence: formData.recurrence,
          photo_proof_required: formData.photo_required,
          photo_required_sometimes: formData.photo_required_sometimes,
          photo_explanation_text: formData.photo_explanation_text || null,
          is_template: true,
          status: 'pending',
          created_by: profile?.id,
        };

        if (explanationPhotoUrl) {
          insertData.description_photo = explanationPhotoUrl;
        }

        console.log('Inserting checklist template with data:', insertData);
        const { error } = await supabase.from('tasks').insert(insertData);

        if (error) {
          console.error('Insert error:', error);
          throw error;
        }
      }

      setShowModal(false);
      setEditingChecklist(null);
      setExplanationPhoto([]);
      setFormData({
        category: 'extras',
        title: '',
        description: '',
        items: [''],
        due_date: '',
        due_time: '',
        points_value: 10,
        duration_minutes: 30,
        recurrence: 'one_time',
        photo_required: false,
        photo_required_sometimes: false,
        photo_explanation_text: '',
      });

      await refetch();
    } catch (error) {
      console.error('Error saving checklist:', error);
    }
  };

  const handleEdit = (checklist: any) => {
    setEditingChecklist(checklist);

    const dateStr = checklist.due_date ? formatDateForInputFromUTC(checklist.due_date) : formatDateForInputFromUTC(new Date());
    const timeStr = checklist.due_date ? formatTimeForInputFromUTC(checklist.due_date) : '10:00';

    setFormData({
      category: checklist.category,
      title: checklist.title,
      description: checklist.description || '',
      items: checklist.items?.map((item: any) => item.text) || [''],
      due_date: dateStr,
      due_time: timeStr,
      points_value: checklist.points_value,
      duration_minutes: checklist.duration_minutes || 30,
      recurrence: checklist.recurrence || 'one_time',
      photo_required: checklist.photo_proof_required || false,
      photo_required_sometimes: checklist.photo_required_sometimes || false,
      photo_explanation_text: checklist.photo_explanation_text || '',
    });
    setShowModal(true);
  };

  const handleDelete = async (checklistId: string) => {
    if (!confirm('Are you sure you want to delete this checklist template?')) return;

    try {
      const { error } = await supabase.from('tasks').delete().eq('id', checklistId);
      if (error) throw error;
      await refetch();
    } catch (error) {
      console.error('Error deleting checklist:', error);
    }
  };

  const filteredChecklists = selectedCategory
    ? checklists.filter((c) => c.category === selectedCategory)
    : checklists;

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
          <h2 className="text-3xl font-bold text-gray-900">Checklist Templates (Admin)</h2>
        </div>
        <button
          onClick={() => {
            setEditingChecklist(null);
            setFormData({
              category: 'extras',
              title: '',
              items: [''],
              due_date: '',
              due_time: '',
              points_value: 10,
              recurrence: 'one_time',
            });
            setShowModal(true);
          }}
          className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          <Plus className="w-5 h-5" />
          <span>New Template</span>
        </button>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
        {CATEGORIES.map((category) => {
          const count = getCategoryCounts(category.id);
          const isSelected = selectedCategory === category.id;

          return (
            <button
              key={category.id}
              onClick={() => setSelectedCategory(isSelected ? null : category.id)}
              className={`${category.color} ${
                isSelected ? 'ring-4 ring-offset-2 ring-blue-500' : ''
              } text-white p-6 rounded-xl hover:opacity-90 transition-all shadow-lg`}
            >
              <div className="flex items-center justify-between mb-2">
                <ClipboardList className="w-6 h-6" />
                <span className="text-2xl font-bold">{count}</span>
              </div>
              <p className="text-sm font-medium">{category.label}</p>
              <p className="text-xs mt-1 opacity-90">{count} templates</p>
            </button>
          );
        })}
      </div>

      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
        <h3 className="text-xl font-bold text-gray-900 mb-4">
          {selectedCategory
            ? `${CATEGORIES.find((c) => c.id === selectedCategory)?.label} Templates`
            : 'All Templates'}
        </h3>

        {filteredChecklists.length === 0 ? (
          <p className="text-gray-500 text-center py-8">
            No templates found. Create your first template!
          </p>
        ) : (
          <div className="space-y-3">
            {filteredChecklists.map((checklist) => (
              <div
                key={checklist.id}
                className="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
              >
                <div className="flex-1">
                  <h4 className="font-medium text-gray-900">{checklist.title}</h4>
                  <p className="text-sm text-gray-600 mt-1">
                    {checklist.items?.length || 0} items · {checklist.points_value} points · {checklist.recurrence}
                  </p>
                </div>
                <div className="flex items-center space-x-2">
                  <button
                    onClick={() => handleEdit(checklist)}
                    className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                  >
                    <Edit2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(checklist.id)}
                    className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {showModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50 overflow-y-auto"
          onClick={() => {
            setShowModal(false);
            setEditingChecklist(null);
            setExplanationPhoto([]);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-2xl my-8"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900">
                {editingChecklist ? 'Edit Template' : 'New Template'}
              </h3>
              <button
                onClick={() => {
                  setShowModal(false);
                  setEditingChecklist(null);
                }}
                className="p-2 hover:bg-gray-100 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
                <select
                  value={formData.category}
                  onChange={(e) => handleCategoryChange(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                >
                  {CATEGORIES.map((cat) => (
                    <option key={cat.id} value={cat.id}>
                      {cat.label}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Beschreibung (optional)</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  rows={2}
                  placeholder="Kurze Beschreibung der Checkliste..."
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Checklist Items</label>
                <div className="space-y-2">
                  {formData.items.map((item, index) => (
                    <div key={index} className="flex items-center space-x-2">
                      <input
                        type="text"
                        value={item}
                        onChange={(e) => handleItemChange(index, e.target.value)}
                        placeholder={`Item ${index + 1}`}
                        className="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                      />
                      {formData.items.length > 1 && (
                        <button
                          type="button"
                          onClick={() => removeItem(index)}
                          className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                        >
                          <X className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  ))}
                  <button
                    type="button"
                    onClick={addItem}
                    className="flex items-center space-x-2 text-blue-600 hover:bg-blue-50 px-3 py-2 rounded-lg transition-colors"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Add Item</span>
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Due Date</label>
                  <input
                    type="date"
                    value={formData.due_date}
                    onChange={(e) => setFormData({ ...formData, due_date: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Due Time</label>
                  <input
                    type="time"
                    value={formData.due_time}
                    onChange={(e) => setFormData({ ...formData, due_time: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Points Value</label>
                  <input
                    type="number"
                    value={formData.points_value}
                    onChange={(e) => setFormData({ ...formData, points_value: parseInt(e.target.value) })}
                    min="1"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Duration (min)</label>
                  <input
                    type="number"
                    value={formData.duration_minutes}
                    onChange={(e) => setFormData({ ...formData, duration_minutes: parseInt(e.target.value) })}
                    min="5"
                    step="5"
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Recurrence</label>
                  <select
                    value={formData.recurrence}
                    onChange={(e) => setFormData({ ...formData, recurrence: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                  >
                    {RECURRENCE_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="border border-gray-300 rounded-lg p-4 space-y-4">
                <h4 className="font-semibold text-gray-900">Foto-Optionen</h4>

                <div className="space-y-3">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      1. Erklärungs-Foto hochladen (optional)
                    </label>
                    <p className="text-xs text-gray-600 mb-2">
                      Upload eines Fotos zur Erklärung/Veranschaulichung der Checkliste
                    </p>
                    <input
                      type="file"
                      accept="image/*"
                      multiple
                      onChange={(e) => setExplanationPhoto(Array.from(e.target.files || []))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                    />
                    {explanationPhoto && explanationPhoto.length > 0 && (
                      <p className="text-xs text-green-600 mt-1">
                        ✓ {explanationPhoto.length} Foto(s) ausgewählt
                      </p>
                    )}
                  </div>

                  <div className="bg-red-50 border border-red-200 rounded-lg p-3">
                    <div className="flex items-center space-x-2 mb-2">
                      <input
                        type="checkbox"
                        id="checklist_photo_required"
                        checked={formData.photo_required}
                        onChange={(e) => setFormData({ ...formData, photo_required: e.target.checked })}
                        className="w-4 h-4 text-red-600 rounded"
                      />
                      <label htmlFor="checklist_photo_required" className="text-sm font-bold text-red-900">
                        2. Foto VERPFLICHTEND bei Fertigmeldung
                      </label>
                    </div>
                    <p className="text-xs text-red-700 ml-6">
                      Staff muss zwingend ein Foto hochladen. Keine Vorabinfo an Staff!
                    </p>
                  </div>

                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                    <div className="flex items-center space-x-2 mb-2">
                      <input
                        type="checkbox"
                        id="checklist_photo_sometimes"
                        checked={formData.photo_required_sometimes}
                        onChange={(e) => setFormData({ ...formData, photo_required_sometimes: e.target.checked })}
                        className="w-4 h-4 text-blue-600 rounded"
                      />
                      <label htmlFor="checklist_photo_sometimes" className="text-sm font-bold text-blue-900">
                        3. Foto MANCHMAL erforderlich (30% Chance - Würfel)
                      </label>
                    </div>
                    <p className="text-xs text-blue-700 ml-6">
                      Bei Fertigmeldung wird gewürfelt ob Foto nötig ist. Keine Vorabinfo an Staff!
                    </p>
                  </div>

                  {(formData.photo_required || formData.photo_required_sometimes) && (
                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 ml-6">
                      <label className="block text-sm font-medium text-yellow-900 mb-2">
                        Foto-Anweisung für Staff (optional)
                      </label>
                      <p className="text-xs text-yellow-700 mb-2">
                        Beschreibe, WO/WAS fotografiert werden soll. Diese Anweisung wird Staff angezeigt wenn Foto erforderlich ist.
                      </p>
                      <textarea
                        value={formData.photo_explanation_text}
                        onChange={(e) => setFormData({ ...formData, photo_explanation_text: e.target.value })}
                        placeholder="z.B. 'Foto vom gereinigten Zimmer von der Tür aus' oder 'Nahaufnahme der gereinigten Badewanne'"
                        rows={3}
                        className="w-full px-3 py-2 border border-yellow-300 rounded-lg text-sm focus:ring-2 focus:ring-yellow-400 focus:border-yellow-400"
                      />
                      {formData.photo_explanation_text && (
                        <p className="text-xs text-green-600 mt-1">
                          ✓ Anweisung: {formData.photo_explanation_text.slice(0, 50)}{formData.photo_explanation_text.length > 50 ? '...' : ''}
                        </p>
                      )}
                    </div>
                  )}

                  <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
                    <p className="text-sm font-medium text-gray-900 mb-1">
                      4. Staff kann optional Foto hochladen
                    </p>
                    <p className="text-xs text-gray-600">
                      Staff kann immer freiwillig ein Foto hochladen (automatisch möglich)
                    </p>
                  </div>
                </div>
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false);
                    setEditingChecklist(null);
                    setExplanationPhoto(null);
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  {editingChecklist ? 'Update' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
