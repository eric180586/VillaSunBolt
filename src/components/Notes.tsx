import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNotes } from '../hooks/useNotes';
import { Plus, AlertCircle, X, Edit, ArrowLeft, StickyNote } from 'lucide-react';
import { isAdmin as checkIsAdmin } from '../lib/roleUtils';

export function Notes({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const { notes, createNote, updateNote, deleteNote } = useNotes();
  const [showModal, setShowModal] = useState(false);
  const [editingNote, setEditingNote] = useState<string | null>(null);
  const [formData, setFormData] = useState({
    title: '',
    content: '',
    category: 'general',
    is_important: false,
  });

  const getReceptionTemplate = () => {
    return `Rooms Check in:\n\n\nRooms Check out:\n\n\nImportant infos:\n\n\nLaundry:\n\n`;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingNote) {
        await updateNote(editingNote, formData);
        setEditingNote(null);
      } else {
        await createNote({
          ...formData,
          created_by: profile?.id || '',
        });
      }
      setShowModal(false);
      setFormData({
        title: '',
        content: '',
        category: 'general',
        is_important: false,
      });
    } catch (error) {
      console.error('Error saving note:', error);
    }
  };

  const handleEdit = (noteId: string) => {
    const note = notes.find((n) => n.id === noteId);
    if (note) {
      setFormData({
        title: note.title,
        content: note.content,
        category: note.category,
        is_important: note.is_important,
      });
      setEditingNote(noteId);
      setShowModal(true);
    }
  };

  const getCategoryColor = (category: string) => {
    switch (category) {
      case 'important':
        return 'bg-red-100 text-red-700 border-red-200';
      case 'announcement':
        return 'bg-blue-100 text-blue-700 border-blue-200';
      case 'reminder':
        return 'bg-yellow-100 text-yellow-700 border-yellow-200';
      case 'reception':
        return 'bg-green-100 text-green-700 border-green-200';
      default:
        return 'bg-gray-100 text-gray-700 border-gray-200';
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
          <h2 className="text-3xl font-bold text-gray-900">Notes & Info</h2>
        </div>
        <button
          onClick={() => {
            setEditingNote(null);
            setFormData({
              title: '',
              content: '',
              category: 'general',
              is_important: false,
            });
            setShowModal(true);
          }}
          className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          <Plus className="w-5 h-5" />
          <span>New Note</span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {notes.length === 0 && (
          <div className="col-span-full text-center py-16 bg-white rounded-xl border border-beige-200">
            <StickyNote className="w-16 h-16 text-beige-300 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-700 mb-2">Keine aktuellen Infos</h3>
            <p className="text-gray-500 text-sm">Es wurden noch keine Notizen erstellt.</p>
          </div>
        )}

        {notes.map((note) => (
          <div
            key={note.id}
            className={`bg-white rounded-xl p-5 shadow-sm border-2 ${
              note.is_important ? 'border-red-300 bg-red-50' : 'border-gray-200'
            }`}
          >
            <div className="flex items-start justify-between mb-3">
              <div className="flex items-center space-x-2">
                {note.is_important && (
                  <AlertCircle className="w-5 h-5 text-red-500" />
                )}
                <h3 className="text-lg font-semibold text-gray-900">{note.title}</h3>
              </div>
              <div className="flex items-center space-x-1">
                {(note.created_by === profile?.id || checkIsAdmin(profile)) && (
                  <>
                    <button
                      onClick={() => handleEdit(note.id)}
                      className="p-1 text-gray-400 hover:text-blue-600"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => deleteNote(note.id)}
                      className="p-1 text-gray-400 hover:text-red-600"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </>
                )}
              </div>
            </div>
            <p className="text-gray-700 whitespace-pre-wrap mb-3">{note.content}</p>
            <div className="flex items-center justify-between">
              <span className={`px-2 py-1 rounded-full text-xs border ${getCategoryColor(note.category)}`}>
                {note.category}
              </span>
              <span className="text-xs text-gray-500">
                {new Date(note.created_at).toLocaleDateString()}
              </span>
            </div>
          </div>
        ))}
      </div>

      {showModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowModal(false);
            setEditingNote(null);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">
              {editingNote ? 'Edit Note' : 'Create Note'}
            </h3>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Title
                </label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Content
                </label>
                <textarea
                  value={formData.content}
                  onChange={(e) => setFormData({ ...formData, content: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={5}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Category
                </label>
                <select
                  value={formData.category}
                  onChange={(e) => {
                    const newCategory = e.target.value;
                    setFormData({
                      ...formData,
                      category: newCategory,
                      content: newCategory === 'reception' && !editingNote ? getReceptionTemplate() : formData.content,
                      title: newCategory === 'reception' && !editingNote && !formData.title ? 'Rezeption Info - ' + new Date().toLocaleDateString('de-DE') : formData.title
                    });
                  }}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                >
                  <option value="general">General</option>
                  <option value="announcement">Announcement</option>
                  <option value="reminder">Reminder</option>
                  <option value="important">Important</option>
                  <option value="reception">Rezeption Info</option>
                </select>
              </div>
              <div className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  id="important"
                  checked={formData.is_important}
                  onChange={(e) =>
                    setFormData({ ...formData, is_important: e.target.checked })
                  }
                  className="w-4 h-4 text-blue-600 rounded"
                />
                <label htmlFor="important" className="text-sm font-medium text-gray-700">
                  Mark as important
                </label>
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false);
                    setEditingNote(null);
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  {editingNote ? 'Update' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
