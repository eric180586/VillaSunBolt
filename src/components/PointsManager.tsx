import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
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

interface MonthlyPoints {
  [userId: string]: number;
}

export function PointsManager({ onBack }: { onBack?: () => void } = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { profiles, addPoints } = useProfiles();
  const [templates, setTemplates] = useState<PointTemplate[]>([]);
  const [selectedStaffIds, setSelectedStaffIds] = useState<string[]>([]);
  const [selectedTemplateId, setSelectedTemplateId] = useState('');
  const [customPoints, setCustomPoints] = useState(0);
  const [customReason, setCustomReason] = useState('');
  const [photoFiles, setPhotoFiles] = useState<File[]>([]);
  const [photoPreviews, setPhotoPreviews] = useState<string[]>([]);
  const [uploading, setUploading] = useState(false);
  const [showNewTemplate, setShowNewTemplate] = useState(false);
  const [newTemplate, setNewTemplate] = useState({
    name: '',
    points: 0,
    reason: '',
    category: 'general',
  }) as any;
  const [monthlyPoints, setMonthlyPoints] = useState<MonthlyPoints>({}) as any;

  const staffProfiles = profiles.filter((p) => p.role !== 'admin');

  useEffect(() => {
    fetchTemplates();
    fetchMonthlyPoints();

    // Realtime subscription for templates
    const templatesChannel = supabase
      .channel(`point_templates_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'point_templates',
        },
        () => {
          fetchTemplates();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(templatesChannel);
    };
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

  const fetchMonthlyPoints = async () => {
    const firstDayOfMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1)
      .toISOString().split('T')[0];

    const { data, error } = await supabase
      .from('daily_point_goals')
      .select('user_id, achieved_points')
      .gte('goal_date', firstDayOfMonth);

    if (error) {
      console.error('Error fetching monthly points:', error);
      return;
    }

    const pointsMap: MonthlyPoints = {};
    data?.forEach((day: any) => {
      if (!pointsMap[day.user_id]) {
        pointsMap[day.user_id] = 0;
      }
      pointsMap[day.user_id] += day.achieved_points;
    }) as any;

    setMonthlyPoints(pointsMap);
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
        ? prev.filter((id: string) => id !== staffId)
        : [...prev, staffId]
    );
  };

  const handlePhotoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    if (files.length === 0) return;

    setPhotoFiles((prev) => [...prev, ...files]);

    files.forEach((file) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        setPhotoPreviews((prev) => [...prev, reader.result as string]);
      };
      reader.readAsDataURL(file);
    }) as any;
  };

  const uploadPhotos = async (): Promise<string[]> => {
    if (photoFiles.length === 0) return [];

    const uploadedUrls: string[] = [];

    for (const file of photoFiles) {
      const fileExt = file.name.split('.').pop();
      const fileName = `${Math.random()}.${fileExt}`;
      const filePath = `point-photos/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('point-evidence')
        .upload(filePath, file);

      if (uploadError) {
        console.error('Error uploading photo:', uploadError);
        continue;
      }

      const { data } = supabase.storage
        .from('point-evidence')
        .getPublicUrl(filePath);

      uploadedUrls.push(data.publicUrl);
    }

    return uploadedUrls;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (selectedStaffIds.length === 0) {
      alert(t('pointsManager.selectStaffWarning'));
      return;
    }

    setUploading(true);

    try {
      const photoUrls = await uploadPhotos();
      const photoUrlString = photoUrls.length > 0 ? photoUrls[0] : null;

      for (const staffId of selectedStaffIds) {
        await addPoints(staffId, customPoints, customReason, profile?.id || '', photoUrlString);
      }

      setSelectedStaffIds([]);
      setSelectedTemplateId('');
      setCustomPoints(0);
      setCustomReason('');
      setPhotoFiles([]);
      setPhotoPreviews([]);
      alert(t('pointsManager.pointsAwardedSuccess'));
    } catch (error) {
      console.error('Error awarding points:', error);
      alert(t('pointsManager.pointsAwardedError'));
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
    }) as any;

    if (error) {
      console.error('Error saving template:', error);
      return;
    }

    setShowNewTemplate(false);
    setNewTemplate({ name: '', points: 0, reason: '', category: 'general' }) as any;
    fetchTemplates();
  };

  const handleDeleteTemplate = async (templateId: string) => {
    if (!confirm(t('pointsManager.confirmDeleteTemplate'))) return;

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
    if (!confirm(t('pointsManager.confirmResetAllPoints'))) {
      return;
    }

    try {
      const { error } = await supabase.rpc('reset_all_points');

      if (error) {
        console.error('Error resetting points:', error);
        throw error;
      }

      alert(t('pointsManager.resetAllPointsSuccess'));
      window.location.reload();
    } catch (error) {
      console.error('Error resetting points:', error);
      alert(t('pointsManager.resetAllPointsError', { message: (error as any).message }));
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
          <h2 className="text-3xl font-bold text-gray-900">{t('pointsManager.title')}</h2>
        </div>
        <div className="flex space-x-2">
          <button
            onClick={() => setShowNewTemplate(true)}
            className="flex items-center space-x-2 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors"
          >
            <Plus className="w-5 h-5" />
            <span>{t('pointsManager.newTemplate')}</span>
          </button>
          <button
            onClick={handleResetAllPoints}
            className="flex items-center space-x-2 bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
          >
            <RefreshCw className="w-5 h-5" />
            <span>{t('pointsManager.resetAllPoints')}</span>
          </button>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="bg-white rounded-xl p-6 shadow-lg border border-gray-200 space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            {t('pointsManager.selectTemplate')}
          </label>
          <select
            value={selectedTemplateId}
            onChange={(e) => handleTemplateSelect(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg"
          >
            <option value="">{t('pointsManager.customPointsOption')}</option>
            {templates.map((template) => (
              <option key={template.id} value={template.id}>
                {template.name} ({template.points > 0 ? '+' : ''}{template.points} pts) - {template.category}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            {t('pointsManager.selectStaff')}
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
                  <p className="text-xs text-gray-600">{t('pointsManager.monthlyPoints', { points: monthlyPoints[staff.id] || 0 })}</p>
                </div>
              </label>
            ))}
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            {t('pointsManager.pointsAmount')}
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
            {t('pointsManager.reason')}
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
            {t('pointsManager.photoEvidence')}
          </label>
          <div className="space-y-3">
            <label className="flex items-center space-x-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 cursor-pointer w-fit">
              <Upload className="w-5 h-5" />
              <span>{t('pointsManager.uploadPhotos')}</span>
              <input
                type="file"
                accept="image/*"
                multiple
                onChange={handlePhotoSelect}
                className="hidden"
              />
            </label>
            {photoPreviews.length > 0 && (
              <div className="flex flex-wrap gap-3">
                {photoPreviews.map((preview, index) => (
                  <div key={index} className="relative">
                    <img
                      src={preview}
                      alt={t('pointsManager.photoPreviewAlt', { index: index + 1 })}
                      className="w-20 h-20 object-cover rounded-lg"
                    />
                    <button
                      type="button"
                      onClick={() => {
                        setPhotoFiles((prev) => prev.filter((_, i) => i !== index));
                        setPhotoPreviews((prev) => prev.filter((_, i) => i !== index));
                      }}
                      className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 hover:bg-red-600"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                ))}
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
          <span>
            {uploading
              ? t('pointsManager.awarding')
              : t('pointsManager.awardPoints', { count: selectedStaffIds.length })}
          </span>
        </button>
      </form>

      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <h3 className="text-xl font-bold text-gray-900 mb-4">{t('pointsManager.savedTemplates')}</h3>
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
            setNewTemplate({ name: '', action_type: 'task_completion', base_points: 0, multiplier: 1, time_bonus_enabled: false, deadline_bonus_points: 0, penalty_enabled: false, late_penalty_multiplier: 0 }) as any;
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">{t('pointsManager.newTemplateTitle')}</h3>
            <form onSubmit={handleSaveTemplate} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  {t('pointsManager.templateName')}
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
                  {t('pointsManager.pointsLabel')}
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
                  {t('pointsManager.reason')}
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
                  {t('pointsManager.category')}
                </label>
                <select
                  value={newTemplate.category}
                  onChange={(e) => setNewTemplate({ ...newTemplate, category: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                >
                  <option value="general">{t('pointsManager.categoryGeneral')}</option>
                  <option value="bonus">{t('pointsManager.categoryBonus')}</option>
                  <option value="penalty">{t('pointsManager.categoryPenalty')}</option>
                  <option value="achievement">{t('pointsManager.categoryAchievement')}</option>
                </select>
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowNewTemplate(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  {t('common.cancel')}
                </button>
                <button
                  type="submit"
                  className="flex-1 flex items-center justify-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                >
                  <Save className="w-5 h-5" />
                  <span>{t('common.save')}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
