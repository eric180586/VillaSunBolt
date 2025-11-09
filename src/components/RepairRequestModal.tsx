import { useState } from 'react';
import { X, Upload } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { getTodayDateString } from '../lib/dateUtils';

interface RepairRequestModalProps {
  onClose: () => void;
  onComplete: () => void;
}

export function RepairRequestModal({ onClose, onComplete }: RepairRequestModalProps) {
  const { profile } = useAuth();
  const [formData, setFormData] = useState({
    title: '',
    description: '',
  });
  const [descriptionPhotos, setDescriptionPhotos] = useState<File[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    setDescriptionPhotos(prev => [...prev, ...files]);
  };

  const removePhoto = (index: number) => {
    setDescriptionPhotos(prev => prev.filter((_, i) => i !== index));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!formData.title.trim()) {
      alert('Bitte geben Sie einen Titel ein');
      return;
    }

    setIsSubmitting(true);

    try {
      let photoUrls: string[] = [];

      // Upload photos if any
      if (descriptionPhotos.length > 0) {
        const uploadPromises = descriptionPhotos.map(async (file) => {
          const fileExt = file.name.split('.').pop();
          const fileName = `${Math.random().toString(36).substring(2)}_${Date.now()}.${fileExt}`;
          const filePath = `task_photos/${fileName}`;

          const { error: uploadError } = await supabase.storage
            .from('task_photos')
            .upload(filePath, file);

          if (uploadError) throw uploadError;

          const { data: { publicUrl } } = supabase.storage
            .from('task_photos')
            .getPublicUrl(filePath);

          return publicUrl;
        });

        photoUrls = await Promise.all(uploadPromises);
      }

      // Create repair task
      const { error } = await supabase.from('tasks').insert({
        category: 'repair',
        title: formData.title,
        description: formData.description,
        due_date: new Date(getTodayDateString() + 'T23:59:00').toISOString(),
        duration_minutes: 30,
        points_value: 10,
        assigned_to: profile?.id,
        status: 'pending',
        description_photo: photoUrls,
        photo_proof_required: false,
        is_template: false,
        recurrence: 'one_time',
      });

      if (error) throw error;

      alert('Reparatur-Anfrage erfolgreich erstellt!');
      onComplete();
    } catch (error) {
      console.error('Error creating repair request:', error);
      alert('Fehler beim Erstellen der Anfrage');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex justify-between items-center">
          <h2 className="text-xl font-bold text-gray-900">Reparatur melden</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Titel *
            </label>
            <input
              type="text"
              required
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent"
              placeholder="z.B. Wasserhahn tropft in Venus"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Beschreibung
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              rows={4}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-red-500 focus:border-transparent"
              placeholder="Detaillierte Beschreibung des Problems..."
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Fotos (optional)
            </label>
            <div className="space-y-2">
              <label className="flex items-center justify-center px-4 py-3 border-2 border-dashed border-gray-300 rounded-lg cursor-pointer hover:border-red-500 transition-colors">
                <Upload className="w-5 h-5 text-gray-400 mr-2" />
                <span className="text-sm text-gray-600">Foto hinzufügen</span>
                <input
                  type="file"
                  accept="image/*"
                  multiple
                  onChange={handlePhotoChange}
                  className="hidden"
                />
              </label>

              {descriptionPhotos.length > 0 && (
                <div className="grid grid-cols-2 gap-2">
                  {descriptionPhotos.map((file, index) => (
                    <div key={index} className="relative">
                      <img
                        src={URL.createObjectURL(file)}
                        alt={`Preview ${index + 1}`}
                        className="w-full h-24 object-cover rounded-lg"
                      />
                      <button
                        type="button"
                        onClick={() => removePhoto(index)}
                        className="absolute top-1 right-1 bg-red-500 text-white rounded-full p-1 hover:bg-red-600"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          <div className="flex space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium"
            >
              Abbrechen
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex-1 px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 font-medium disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? 'Wird erstellt...' : 'Erstellen'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
