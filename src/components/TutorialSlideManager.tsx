import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Plus, X, ChevronUp, ChevronDown, Trash2, Upload, Image as ImageIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';

interface TutorialSlide {
  id: string;
  order_index: number;
  image_url: string;
  title: string;
  description: string;
  category: string;
  tips: any[];
  created_at: string;
}

export default function TutorialSlideManager({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const [slides, setSlides] = useState<TutorialSlide[]>([]);
  const [loading, setLoading] = useState(false);
  const [showAddModal, setShowAddModal] = useState(false);
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    image: null as File | null,
  });

  const isAdmin = profile?.role === 'admin';

  useEffect(() => {
    if (isAdmin) {
      loadSlides();
    }
  }, [isAdmin]);

  const loadSlides = async () => {
    try {
      const { data, error } = await supabase
        .from('tutorial_slides')
        .select('*')
        .order('order_index');

      if (error) throw error;
      setSlides(data || []);
    } catch (error: any) {
      console.error('Error loading slides:', error);
      const errorMessage = error?.message || t('howTo.unknownError');
      alert(`${t('howTo.errorLoadingSlides')}: ${errorMessage}`);
    }
  };

  const uploadImage = async (file: File): Promise<string> => {
    const fileExt = file.name.split('.').pop();
    const fileName = `${Math.random().toString(36).substring(2)}_${Date.now()}.${fileExt}`;

    const { error: uploadError } = await supabase.storage
      .from('tutorial_slides')
      .upload(fileName, file);

    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage
      .from('tutorial_slides')
      .getPublicUrl(fileName);

    return urlData.publicUrl;
  };

  const handleAddSlide = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.image || !profile?.id) return;

    setLoading(true);
    try {
      const imageUrl = await uploadImage(formData.image);
      const maxOrder = Math.max(...slides.map(s => s.order_index), -1);

      const { error } = await supabase.from('tutorial_slides').insert({
        title: formData.title,
        description: formData.description,
        image_url: imageUrl,
        order_index: maxOrder + 1,
        category: 'cleaning',
        tips: [],
        created_by: profile.id,
      });

      if (error) throw error;

      setShowAddModal(false);
      setFormData({ title: '', description: '', image: null });
      await loadSlides();
      alert('Slide erfolgreich hinzugefügt!');
    } catch (error: any) {
      console.error('Error adding slide:', error);
      const errorMessage = error?.message || t('howTo.unknownError');
      alert(`${t('howTo.errorAddingSlide')}: ${errorMessage}`);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (slide: TutorialSlide) => {
    if (!confirm(`"${slide.title}" wirklich löschen?`)) return;

    setLoading(true);
    try {
      const fileName = slide.image_url.split('/').pop();
      if (fileName) {
        await supabase.storage.from('tutorial_slides').remove([fileName]);
      }

      const { error } = await supabase
        .from('tutorial_slides')
        .delete()
        .eq('id', slide.id);

      if (error) throw error;
      await loadSlides();
    } catch (error: any) {
      console.error('Error deleting slide:', error);
      const errorMessage = error?.message || t('howTo.unknownError');
      alert(`${t('howTo.errorDeleting')}: ${errorMessage}`);
    } finally {
      setLoading(false);
    }
  };

  const handleMove = async (slide: TutorialSlide, direction: 'up' | 'down') => {
    const currentIndex = slides.findIndex(s => s.id === slide.id);
    if (
      (direction === 'up' && currentIndex === 0) ||
      (direction === 'down' && currentIndex === slides.length - 1)
    ) {
      return;
    }

    const swapIndex = direction === 'up' ? currentIndex - 1 : currentIndex + 1;
    const swapSlide = slides[swapIndex];

    try {
      await supabase.from('tutorial_slides')
        .update({ order_index: swapSlide.order_index })
        .eq('id', slide.id);

      await supabase.from('tutorial_slides')
        .update({ order_index: slide.order_index })
        .eq('id', swapSlide.id);

      await loadSlides();
    } catch (error: any) {
      console.error('Error reordering slides:', error);
      const errorMessage = error?.message || t('howTo.unknownError');
      alert(`${t('howTo.errorMoving')}: ${errorMessage}`);
    }
  };

  if (!isAdmin) {
    return (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
        <div className="bg-white rounded-xl p-6 max-w-md">
          <p className="text-red-600 font-semibold">Nur für Admins verfügbar</p>
          <button
            onClick={onClose}
            className="mt-4 w-full bg-gray-600 text-white py-2 rounded-lg"
          >
            Schließen
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4 overflow-y-auto">
      <div className="bg-white rounded-xl p-6 w-full max-w-4xl max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold text-gray-900">Tutorial Slides verwalten</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
            <X className="w-6 h-6" />
          </button>
        </div>

        <button
          onClick={() => setShowAddModal(true)}
          className="w-full mb-6 flex items-center justify-center space-x-2 bg-amber-500 text-white py-3 rounded-lg hover:bg-amber-600 transition-colors"
        >
          <Plus className="w-5 h-5" />
          <span>Neue Slide hinzufügen</span>
        </button>

        {slides.length === 0 ? (
          <div className="text-center py-12 bg-gray-50 rounded-xl">
            <ImageIcon className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">Noch keine Tutorial-Slides vorhanden</p>
            <p className="text-sm text-gray-500 mt-2">Klicken Sie oben, um die erste Slide hinzuzufügen</p>
          </div>
        ) : (
          <div className="space-y-4">
            {slides.map((slide, index) => (
              <div
                key={slide.id}
                className="bg-gray-50 rounded-lg p-4 flex items-center space-x-4"
              >
                <img
                  src={slide.image_url}
                  alt={slide.title}
                  className="w-32 h-24 object-cover rounded-lg"
                />
                <div className="flex-1">
                  <h3 className="font-bold text-gray-900">{slide.title}</h3>
                  {slide.description && (
                    <p className="text-sm text-gray-600 mt-1">{slide.description}</p>
                  )}
                  <p className="text-xs text-gray-500 mt-1">Slide #{slide.order_index + 1}</p>
                </div>
                <div className="flex flex-col space-y-2">
                  <button
                    onClick={() => handleMove(slide, 'up')}
                    disabled={index === 0}
                    className="p-2 text-gray-600 hover:bg-gray-200 rounded disabled:opacity-30"
                    title="Nach oben"
                  >
                    <ChevronUp className="w-5 h-5" />
                  </button>
                  <button
                    onClick={() => handleMove(slide, 'down')}
                    disabled={index === slides.length - 1}
                    className="p-2 text-gray-600 hover:bg-gray-200 rounded disabled:opacity-30"
                    title="Nach unten"
                  >
                    <ChevronDown className="w-5 h-5" />
                  </button>
                </div>
                <button
                  onClick={() => handleDelete(slide)}
                  className="p-2 text-red-600 hover:bg-red-50 rounded"
                  title="Löschen"
                >
                  <Trash2 className="w-5 h-5" />
                </button>
              </div>
            ))}
          </div>
        )}

        {showAddModal && (
          <div
            className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
            onClick={() => setShowAddModal(false)}
          >
            <div
              className="bg-white rounded-xl p-6 w-full max-w-md"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-xl font-bold text-gray-900">Neue Slide hinzufügen</h3>
                <button onClick={() => setShowAddModal(false)}>
                  <X className="w-5 h-5 text-gray-500" />
                </button>
              </div>
              <form onSubmit={handleAddSlide} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Titel
                  </label>
                  <input
                    type="text"
                    value={formData.title}
                    onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    required
                    placeholder="z.B. Schritt 1: Vorbereitung"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Beschreibung
                  </label>
                  <textarea
                    value={formData.description}
                    onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    rows={3}
                    placeholder="Zusätzliche Erklärung..."
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Bild (Comic/Foto)
                  </label>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={(e) => setFormData({ ...formData, image: e.target.files?.[0] || null })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    required
                  />
                  {formData.image && (
                    <p className="text-sm text-gray-500 mt-1">{formData.image.name}</p>
                  )}
                </div>
                <div className="flex space-x-3">
                  <button
                    type="button"
                    onClick={() => setShowAddModal(false)}
                    className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    Abbrechen
                  </button>
                  <button
                    type="submit"
                    disabled={loading}
                    className="flex-1 px-4 py-2 bg-amber-500 text-white rounded-lg hover:bg-amber-600 disabled:opacity-50"
                  >
                    {loading ? 'Lädt...' : 'Hinzufügen'}
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
