import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useProfiles } from '../hooks/useProfiles';
import { supabase } from '../lib/supabase';
import { Award, Plus, Minus, Upload, X, Save, Trash2, RefreshCw, ArrowLeft } from 'lucide-react';

interface PointTemplate {
  id: string;
  name: string;
  points: number;
  reason: string;
  category: string;
}

export function PointsManager({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const { profiles, addPoints } = useProfiles();
  const [templates, setTemplates] = useState<PointTemplate[]>([]);
  const [selectedStaffIds, setSelectedStaffIds] = useState<string[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState('');
  const [customPoints, setCustomPoints] = useState(0);
  const [customReason, setCustomReason] = useState('');
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [showNewTemplate, setShowNewTemplate] = useState(false);
  const [newTemplate, setNewTemplate] = useState({
    name: '',
    points: 0,
    reason: '',
    category: 'general',
  });

  const staffProfiles = profiles.filter((p) => p.role !== 'admin');

  useEffect(() => {
    fetchTemplates();
  }, []);

  const fetchTemplates = async () => {
    const { data, error } = await supabase
      .from('point_templates')
      .select('*')
      .order('category, name');

    if (error) {
      console.error('Error fetching templates:', error);
      return;
    }

    setTemplates(data || []);
  };

  const handleTemplateSelect = (templateId: string) => {
    setSelectedTemplateId(templateId);
    const template = templates.find((t) => t.id === templateId);
    if (template) {
      setCustomPoints(template.points);
      setCustomReason(template.reason);
    }
  };

  const handleStaffToggle = (staffId: string) => {
    setSelectedStaffIds((prev) =>
      prev.includes(staffId)
        ? prev.filter((id) => id !== staffId)
        : [...prev, staffId]
    );
  };

  const handlePhotoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setPhotoFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setPhotoPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const uploadPhoto = async (): Promise<string | null> => {
    if (!photoFile) return null;

    const fileExt = photoFile.name.split('.').pop();
    const fileName = `${Math.random()}.${fileExt}`;
    const filePath = `point-photos/${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from('point-evidence')
      .upload(filePath, photoFile);

    if (uploadError) {
      console.error('Error uploading photo:', uploadError);
      return null;
    }

    const { data } = supabase.storage
      .from('point-evidence')
      .getPublicUrl(filePath);

    return data.publicUrl;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (selectedStaffIds.length === 0) {
      alert('Please select at least one staff member');
      return;
    }

    setUploading(true);

    try {
      let photoUrl: string | null = null;
      if (photoFile) {
        photoUrl = await uploadPhoto();
      }

      for (const staffId of selectedStaffIds) {
        await addPoints(staffId, customPoints, customReason, profile?.id || '', photoUrl);
      }

      setSelectedStaffIds([]);
      setSelectedTemplateId('');
      setCustomPoints(0);
      setCustomReason('');
      setPhotoFile(null);
      setPhotoPreview(null);
      alert('Points awarded successfully!');
    } catch (error) {
      console.error('Error awarding points:', error);
      alert('Error awarding points');
    } finally {
      setUploading(false);
    }
  };

  const handleSaveTemplate = async (e: React.FormEvent) => {
    e.preventDefault();

    const { error } = await supabase.from('point_templates').insert({
      name: newTemplate.name,
      points: newTemplate.points,
      reason: newTemplate.reason,
      category: newTemplate.category,
      created_by: profile?.id,
    });

    if (error) {
      console.error('Error saving template:', error);
      return;
    }

    setShowNewTemplate(false);
    setNewTemplate({ name: '', points: 0, reason: '', category: 'general' });
    fetchTemplates();
  };

  const handleDeleteTemplate = async (templateId: string) => {
    if (!confirm('Delete this template?')) return;

    const { error } = await supabase
      .from('point_templates')
      .delete()
      .eq('id', templateId);

    if (error) {
      console.error('Error deleting template:', error);
      return;
    }

    fetchTemplates();
  };

  const handleResetAllPoints = async () => {
    if (!confirm('WARNING: This will reset ALL points for ALL users. This action cannot be undone. Continue?')) {
      return;
    }

    try {
      const { error } = await supabase.rpc('reset_all_points');

      if (error) {
        console.error('Error resetting points:', error);
        throw error;
      }

      alert('All points have been reset!');
      window.location.reload();
    } catch (error) {
      console.error('Error resetting points:', error);
      alert('Error resetting points: ' + (error as any).message);
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
          <h2 className="text-3xl font-bold text-gray-900">Points Manager</h2>
        </div>
        <div className="flex space-x-2">
          <button
            onClick={() => setShowNewTemplate(true)}
            className="flex items-center space-x-2 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors"
          >
            <Plus className="w-5 h-5" />
            <span>New Template</span>
          </button>
          <button
            onClick={handleResetAllPoints}
            className="flex items-center space-x-2 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
          >
            <RefreshCw className="w-5 h-5" />
            <span>Reset All Points</span>
          </button>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="bg-white rounded-xl p-6 shadow-lg border border-gray-200 space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Select Template (Optional)
          </label>
          <select
            value={selectedTemplateId}
            onChange={(e) => handleTemplateSelect(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg"
          >
            <option value="">Custom Points</option>
            {templates.map((template) => (
              <option key={template.id} value={template.id}>
                {template.name} ({template.points > 0 ? '+' : ''}{template.points} pts) - {template.category}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Select Staff Members (Multiple)
          </label>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 max-h-64 overflow-y-auto border border-gray-200 rounded-lg p-3">
            {staffProfiles.map((staff) => (
              <label
                key={staff.id}
                className={`flex items-center space-x-3 p-3 rounded-lg cursor-pointer transition-all ${
                  selectedStaffIds.includes(staff.id)
                    ? 'bg-blue-100 border-2 border-blue-500'
                    : 'bg-gray-50 border-2 border-gray-200 hover:border-blue-300'
                }`}
              >
                <input
                  type="checkbox"
                  checked={selectedStaffIds.includes(staff.id)}
                  onChange={() => handleStaffToggle(staff.id)}
                  className="w-5 h-5"
                />
                <div>
                  <p className="font-medium text-gray-900">{staff.full_name}</p>
                  <p className="text-xs text-gray-600">{staff.total_points} pts</p>
                </div>
              </label>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Points Amount
          </label>
          <div className="flex space-x-2">
            <button
              type="button"
              onClick={() => setCustomPoints(customPoints - 5)}
              className="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200"
            >
              <Minus className="w-5 h-5" />
            </button>
            <input
              type="number"
              value={customPoints}
              onChange={(e) => setCustomPoints(parseInt(e.target.value) || 0)}
              className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-center text-xl font-bold"
              required
            />
            <button
              type="button"
              onClick={() => setCustomPoints(customPoints + 5)}
              className="px-4 py-2 bg-green-100 text-green-700 rounded-lg hover:bg-green-200"
            >
              <Plus className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Reason
          </label>
          <textarea
            value={customReason}
            onChange={(e) => setCustomReason(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg"
            rows={3}
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Photo Evidence (Optional)
          </label>
          <div className="flex items-center space-x-4">
            <label className="flex items-center space-x-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 cursor-pointer">
              <Upload className="w-5 h-5" />
              <span>Upload Photo</span>
              <input
                type="file"
                accept="image/*"
                onChange={handlePhotoSelect}
                className="hidden"
              />
            </label>
            {photoPreview && (
              <div className="relative">
                <img
                  src={photoPreview}
                  alt="Preview"
                  className="w-20 h-20 object-cover rounded-lg"
                />
                <button
                  type="button"
                  onClick={() => {
                    setPhotoFile(null);
                    setPhotoPreview(null);
                  }}
                  className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 hover:bg-red-600"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            )}
          </div>
        </div>

        <button
          type="submit"
          disabled={uploading || selectedStaffIds.length === 0}
          className="w-full flex items-center justify-center space-x-2 bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"
        >
          <Award className="w-5 h-5" />
          <span>{uploading ? 'Awarding Points...' : `Award Points to ${selectedStaffIds.length} Staff Member(s)`}</span>
        </button>
      </form>

      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <h3 className="text-xl font-bold text-gray-900 mb-4">Saved Templates</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {templates.map((template) => (
            <div
              key={template.id}
              className="border-2 border-gray-200 rounded-lg p-4 hover:border-blue-300 transition-colors"
            >
              <div className="flex items-start justify-between mb-2">
                <h4 className="font-semibold text-gray-900">{template.name}</h4>
                <button
                  onClick={() => handleDeleteTemplate(template.id)}
                  className="text-red-500 hover:text-red-700"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
              <p className="text-sm text-gray-600 mb-2">{template.reason}</p>
              <div className="flex items-center justify-between">
                <span className="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded">
                  {template.category}
                </span>
                <span className={`text-lg font-bold ${template.points > 0 ? 'text-green-600' : 'text-red-600'}`}>
                  {template.points > 0 ? '+' : ''}{template.points}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {showNewTemplate && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowNewTemplate(false);
            setNewTemplate({ name: '', action_type: 'task_completion', base_points: 0, multiplier: 1, time_bonus_enabled: false, deadline_bonus_points: 0, penalty_enabled: false, late_penalty_multiplier: 0 });
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">New Point Template</h3>
            <form onSubmit={handleSaveTemplate} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Template Name
                </label>
                <input
                  type="text"
                  value={newTemplate.name}
                  onChange={(e) => setNewTemplate({ ...newTemplate, name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Points
                </label>
                <input
                  type="number"
                  value={newTemplate.points}
                  onChange={(e) => setNewTemplate({ ...newTemplate, points: parseInt(e.target.value) })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Reason
                </label>
                <textarea
                  value={newTemplate.reason}
                  onChange={(e) => setNewTemplate({ ...newTemplate, reason: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={3}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Category
                </label>
                <select
                  value={newTemplate.category}
                  onChange={(e) => setNewTemplate({ ...newTemplate, category: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                >
                  <option value="general">General</option>
                  <option value="bonus">Bonus</option>
                  <option value="penalty">Penalty</option>
                  <option value="achievement">Achievement</option>
                </select>
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowNewTemplate(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 flex items-center justify-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                >
                  <Save className="w-5 h-5" />
                  <span>Save</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
