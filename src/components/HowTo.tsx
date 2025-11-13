import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { Upload, FileText, Video, Image, Plus, X, Edit2, Trash2, ChevronUp, ChevronDown, Download, Eye, ArrowLeft, BookOpen, Trophy, Settings, Sparkles } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import TutorialViewer from './TutorialViewer';
import QuizGame from './QuizGame';
import TutorialSlideManager from './TutorialSlideManager';
import { FortuneWheel } from './FortuneWheel';

interface HowToDocument {
  id: string;
  title: string;
  description: string;
  file_url: string;
  file_type: 'pdf' | 'video' | 'image';
  file_name: string;
  file_size: number;
  category: string;
  sort_order: number;
  created_at: string;
  created_by: string;
}

const CATEGORIES = [
  { id: 'general', label: 'Allgemein' },
  { id: 'cleaning', label: 'Reinigung' },
  { id: 'reception', label: 'Rezeption' },
  { id: 'maintenance', label: 'Wartung' },
  { id: 'safety', label: 'Sicherheit' },
];

export function HowTo({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const [documents, setDocuments] = useState<HowToDocument[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingDocument, setEditingDocument] = useState<HowToDocument | null>(null);
  const [viewingDocument, setViewingDocument] = useState<HowToDocument | null>(null);
  const [loading, setLoading] = useState(false);
  const [showTutorial, setShowTutorial] = useState(false);
  const [showQuiz, setShowQuiz] = useState(false);
  const [showSlideManager, setShowSlideManager] = useState(false);
  const [showFortuneWheel, setShowFortuneWheel] = useState(false);

  const isAdmin = profile?.role === 'admin';

  const [formData, setFormData] = useState({
    title: '',
    description: '',
    category: 'general',
    file: null as File | null,
  });

  useEffect(() => {
    fetchDocuments();
  }, []);

  const fetchDocuments = async () => {
    try {
      const { data, error } = await supabase
        .from('how_to_documents')
        .select('*')
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: false });

      if (error) throw error;
      setDocuments(data || []);
    } catch (error) {
      console.error('Error fetching documents:', error);
    }
  };

  const getFileType = (file: File): 'pdf' | 'video' | 'image' => {
    if (file.type.includes('pdf')) return 'pdf';
    if (file.type.includes('video')) return 'video';
    if (file.type.includes('image')) return 'image';
    return 'pdf';
  };

  const uploadFile = async (file: File): Promise<string> => {
    const fileExt = file.name.split('.').pop();
    const fileName = `${Math.random().toString(36).substring(2)}_${Date.now()}.${fileExt}`;
    const filePath = `${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from('how-to-files')
      .upload(filePath, file);

    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage
      .from('how-to-files')
      .getPublicUrl(filePath);

    return urlData.publicUrl;
  };

  const handleUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.file || !profile?.id) return;

    setLoading(true);
    try {
      const fileUrl = await uploadFile(formData.file);
      const fileType = getFileType(formData.file);

      const { error } = await supabase.from('how_to_documents').insert({
        title: formData.title,
        description: formData.description,
        category: formData.category,
        file_url: fileUrl,
        file_type: fileType,
        file_name: formData.file.name,
        file_size: formData.file.size,
        created_by: profile.id,
      });

      if (error) throw error;

      setShowUploadModal(false);
      setFormData({ title: '', description: '', category: 'general', file: null });
      await fetchDocuments();
    } catch (error) {
      console.error('Error uploading document:', error);
      alert(t('howTo.errorUploading'));
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingDocument) return;

    setLoading(true);
    try {
      const { error } = await supabase
        .from('how_to_documents')
        .update({
          title: formData.title,
          description: formData.description,
          category: formData.category,
          updated_at: new Date().toISOString(),
        })
        .eq('id', editingDocument.id);

      if (error) throw error;

      setShowEditModal(false);
      setEditingDocument(null);
      setFormData({ title: '', description: '', category: 'general', file: null });
      await fetchDocuments();
    } catch (error) {
      console.error('Error updating document:', error);
      alert(t('howTo.errorUpdating'));
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (doc: HowToDocument) => {
    if (!confirm(`"${doc.title}" wirklich löschen?`)) return;

    setLoading(true);
    try {
      const filePath = doc.file_url.split('/').pop();
      if (filePath) {
        await supabase.storage.from('how-to-files').remove([filePath]);
      }

      const { error } = await supabase
        .from('how_to_documents')
        .delete()
        .eq('id', doc.id);

      if (error) throw error;
      await fetchDocuments();
    } catch (error) {
      console.error('Error deleting document:', error);
      alert(t('howTo.errorDeleting'));
    } finally {
      setLoading(false);
    }
  };

  const handleSortMove = async (doc: HowToDocument, direction: 'up' | 'down') => {
    const filteredDocs = documents.filter(d =>
      selectedCategory === 'all' ? true : d.category === selectedCategory
    );
    const currentIndex = filteredDocs.findIndex(d => d.id === doc.id);

    if (
      (direction === 'up' && currentIndex === 0) ||
      (direction === 'down' && currentIndex === filteredDocs.length - 1)
    ) {
      return;
    }

    const swapIndex = direction === 'up' ? currentIndex - 1 : currentIndex + 1;
    const swapDoc = filteredDocs[swapIndex];

    try {
      await supabase.from('how_to_documents').update({ sort_order: swapDoc.sort_order }).eq('id', doc.id);
      await supabase.from('how_to_documents').update({ sort_order: doc.sort_order }).eq('id', swapDoc.id);
      await fetchDocuments();
    } catch (error) {
      console.error('Error updating sort order:', error);
    }
  };

  const downloadFile = async (doc: HowToDocument) => {
    try {
      const response = await fetch(doc.file_url);
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = doc.file_name;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (error) {
      console.error('Error downloading file:', error);
      alert(t('howTo.errorDownloading'));
    }
  };

  const getFileIcon = (type: string) => {
    switch (type) {
      case 'pdf':
        return <FileText className="w-8 h-8 text-red-600" />;
      case 'video':
        return <Video className="w-8 h-8 text-blue-600" />;
      case 'image':
        return <Image className="w-8 h-8 text-green-600" />;
      default:
        return <FileText className="w-8 h-8 text-gray-600" />;
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  const filteredDocuments = selectedCategory === 'all'
    ? documents
    : documents.filter(doc => doc.category === selectedCategory);

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
          <h2 className="text-3xl font-bold text-gray-900">How-To Anleitungen</h2>
        </div>
        {isAdmin && (
          <button
            onClick={() => setShowUploadModal(true)}
            className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            <Plus className="w-5 h-5" />
            <span>Dokument hochladen</span>
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="relative">
          <button
            onClick={() => setShowTutorial(true)}
            className="w-full bg-gradient-to-br from-amber-500 to-yellow-600 text-white rounded-xl p-6 hover:shadow-lg transition-all group"
          >
            <div className="flex items-center justify-between mb-4">
              <BookOpen className="w-12 h-12 group-hover:scale-110 transition-transform" />
              <div className="bg-white bg-opacity-20 px-3 py-1 rounded-full text-sm font-semibold">
                Interactive
              </div>
            </div>
            <h3 className="text-2xl font-bold mb-2">Sunny's Cleaning Guide</h3>
            <p className="text-amber-100">
              Learn the proper cleaning procedures with Sunny! Interactive comic tutorial with quiz game.
            </p>
          </button>
          {isAdmin && (
            <button
              onClick={() => setShowSlideManager(true)}
              className="absolute top-3 right-3 p-3 bg-gray-900 hover:bg-gray-800 rounded-lg transition-colors shadow-lg z-10"
              title="Tutorial Slides verwalten"
            >
              <Settings className="w-6 h-6 text-white" />
            </button>
          )}
        </div>

        <button
          onClick={() => setShowQuiz(true)}
          className="bg-gradient-to-br from-green-500 to-emerald-600 text-white rounded-xl p-6 hover:shadow-lg transition-all group"
        >
          <div className="flex items-center justify-between mb-4">
            <Trophy className="w-12 h-12 group-hover:scale-110 transition-transform" />
            <div className="bg-white bg-opacity-20 px-3 py-1 rounded-full text-sm font-semibold">
              2-4 Players
            </div>
          </div>
          <h3 className="text-2xl font-bold mb-2">Quiz Game Challenge</h3>
          <p className="text-green-100">
            Test your knowledge! Compete with colleagues in a fun quiz game and earn bonus points.
          </p>
        </button>

        <button
          onClick={() => setShowFortuneWheel(true)}
          className="bg-gradient-to-br from-purple-500 to-pink-600 text-white rounded-xl p-6 hover:shadow-lg transition-all group"
        >
          <div className="flex items-center justify-between mb-4">
            <Sparkles className="w-12 h-12 group-hover:scale-110 transition-transform" />
            <div className="bg-white bg-opacity-20 px-3 py-1 rounded-full text-sm font-semibold">
              Fun
            </div>
          </div>
          <h3 className="text-2xl font-bold mb-2">Fortune Wheel</h3>
          <p className="text-purple-100">
            Test your luck! Spin the wheel and win bonus points or fun challenges.
          </p>
        </button>
      </div>

      <div className="flex space-x-2 overflow-x-auto pb-2">
        <button
          onClick={() => setSelectedCategory('all')}
          className={`px-4 py-2 rounded-lg font-medium whitespace-nowrap ${
            selectedCategory === 'all'
              ? 'bg-blue-600 text-white'
              : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
          }`}
        >
          Alle
        </button>
        {CATEGORIES.map(cat => (
          <button
            key={cat.id}
            onClick={() => setSelectedCategory(cat.id)}
            className={`px-4 py-2 rounded-lg font-medium whitespace-nowrap ${
              selectedCategory === cat.id
                ? 'bg-blue-600 text-white'
                : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
            }`}
          >
            {cat.label}
          </button>
        ))}
      </div>

      {filteredDocuments.length === 0 ? (
        <div className="text-center py-12 bg-gray-50 rounded-xl">
          <Upload className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600">Noch keine Dokumente vorhanden</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredDocuments.map((doc, index) => (
            <div
              key={doc.id}
              className="bg-white rounded-xl p-6 shadow-sm border border-gray-200 hover:shadow-md transition-all"
            >
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center space-x-3">
                  {getFileIcon(doc.file_type)}
                  <div>
                    <h3 className="font-bold text-gray-900">{doc.title}</h3>
                    <p className="text-xs text-gray-500">
                      {CATEGORIES.find(c => c.id === doc.category)?.label || doc.category}
                    </p>
                  </div>
                </div>
                {isAdmin && (
                  <div className="flex space-x-1">
                    <button
                      onClick={() => handleSortMove(doc, 'up')}
                      disabled={index === 0}
                      className="p-1 text-gray-400 hover:text-gray-600 disabled:opacity-30"
                      title="Nach oben"
                    >
                      <ChevronUp className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleSortMove(doc, 'down')}
                      disabled={index === filteredDocuments.length - 1}
                      className="p-1 text-gray-400 hover:text-gray-600 disabled:opacity-30"
                      title="Nach unten"
                    >
                      <ChevronDown className="w-4 h-4" />
                    </button>
                  </div>
                )}
              </div>

              {doc.description && (
                <p className="text-sm text-gray-600 mb-4 line-clamp-2">{doc.description}</p>
              )}

              <div className="flex items-center justify-between text-xs text-gray-500 mb-4">
                <span>{doc.file_name}</span>
                <span>{formatFileSize(doc.file_size)}</span>
              </div>

              <div className="flex space-x-2">
                <button
                  onClick={() => setViewingDocument(doc)}
                  className="flex-1 flex items-center justify-center space-x-1 bg-blue-50 text-blue-600 px-3 py-2 rounded-lg hover:bg-blue-100 transition-colors"
                >
                  <Eye className="w-4 h-4" />
                  <span>Ansehen</span>
                </button>
                <button
                  onClick={() => downloadFile(doc)}
                  className="flex-1 flex items-center justify-center space-x-1 bg-gray-100 text-gray-700 px-3 py-2 rounded-lg hover:bg-gray-200 transition-colors"
                >
                  <Download className="w-4 h-4" />
                  <span>Download</span>
                </button>
              </div>

              {isAdmin && (
                <div className="flex space-x-2 mt-2">
                  <button
                    onClick={() => {
                      setEditingDocument(doc);
                      setFormData({
                        title: doc.title,
                        description: doc.description,
                        category: doc.category,
                        file: null,
                      });
                      setShowEditModal(true);
                    }}
                    className="flex-1 flex items-center justify-center space-x-1 text-blue-600 px-3 py-2 rounded-lg hover:bg-blue-50 transition-colors"
                  >
                    <Edit2 className="w-4 h-4" />
                    <span>Bearbeiten</span>
                  </button>
                  <button
                    onClick={() => handleDelete(doc)}
                    className="flex-1 flex items-center justify-center space-x-1 text-red-600 px-3 py-2 rounded-lg hover:bg-red-50 transition-colors"
                  >
                    <Trash2 className="w-4 h-4" />
                    <span>Löschen</span>
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {showUploadModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowUploadModal(false);
            setFormData({ title: '', description: '', category: 'general', file: null });
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900">Dokument hochladen</h3>
              <button onClick={() => setShowUploadModal(false)}>
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            <form onSubmit={handleUpload} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Titel</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Beschreibung</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={3}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Kategorie</label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                >
                  {CATEGORIES.map(cat => (
                    <option key={cat.id} value={cat.id}>{cat.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Datei (PDF, Video, Bild)
                </label>
                <input
                  type="file"
                  accept=".pdf,video/*,image/*"
                  onChange={(e) => setFormData({ ...formData, file: e.target.files?.[0] || null })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
                {formData.file && (
                  <p className="text-sm text-gray-500 mt-1">
                    {formData.file.name} ({formatFileSize(formData.file.size)})
                  </p>
                )}
              </div>
              <div className="flex space-x-3">
                <button
                  type="button"
                  onClick={() => setShowUploadModal(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Abbrechen
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                >
                  {loading ? 'Lädt...' : 'Hochladen'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {showEditModal && editingDocument && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowEditModal(false);
            setEditingDocument(null);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900">Dokument bearbeiten</h3>
              <button onClick={() => setShowEditModal(false)}>
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            <form onSubmit={handleEdit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Titel</label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Beschreibung</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={3}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Kategorie</label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                >
                  {CATEGORIES.map(cat => (
                    <option key={cat.id} value={cat.id}>{cat.label}</option>
                  ))}
                </select>
              </div>
              <div className="flex space-x-3">
                <button
                  type="button"
                  onClick={() => setShowEditModal(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Abbrechen
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                >
                  {loading ? 'Speichert...' : 'Speichern'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {viewingDocument && (
        <div
          className="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center p-4 z-50"
          onClick={() => setViewingDocument(null)}
        >
          <div
            className="relative w-full h-full max-w-6xl max-h-[90vh] bg-white rounded-xl overflow-hidden"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="absolute top-4 right-4 z-10 flex space-x-2">
              <button
                onClick={() => downloadFile(viewingDocument)}
                className="p-2 bg-white rounded-lg shadow-lg hover:bg-gray-100"
                title="Download"
              >
                <Download className="w-5 h-5 text-gray-700" />
              </button>
              <button
                onClick={() => setViewingDocument(null)}
                className="p-2 bg-white rounded-lg shadow-lg hover:bg-gray-100"
              >
                <X className="w-5 h-5 text-gray-700" />
              </button>
            </div>
            <div className="w-full h-full overflow-auto">
              {viewingDocument.file_type === 'pdf' && (
                <iframe
                  src={viewingDocument.file_url}
                  className="w-full h-full"
                  title={viewingDocument.title}
                />
              )}
              {viewingDocument.file_type === 'video' && (
                <video
                  src={viewingDocument.file_url}
                  controls
                  className="w-full h-full object-contain"
                />
              )}
              {viewingDocument.file_type === 'image' && (
                <img
                  src={viewingDocument.file_url}
                  alt={viewingDocument.title}
                  className="w-full h-full object-contain"
                />
              )}
            </div>
          </div>
        </div>
      )}

      {showTutorial && (
        <TutorialViewer
          onComplete={() => {
            setShowTutorial(false);
            setShowQuiz(true);
          }}
          onClose={() => setShowTutorial(false)}
        />
      )}

      {showQuiz && (
        <QuizGame onClose={() => setShowQuiz(false)} />
      )}

      {showSlideManager && (
        <TutorialSlideManager onClose={() => setShowSlideManager(false)} />
      )}

      {showFortuneWheel && (
        <FortuneWheel
          onClose={() => setShowFortuneWheel(false)}
          onSpinComplete={(segment) => {
            console.log('Wheel result:', segment);
          }}
        />
      )}
    </div>
  );
}
