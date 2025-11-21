import { useState, useEffect } from 'react';

import { useNotes } from '../hooks/useNotes';
import { X, AlertCircle } from 'lucide-react';

interface NotesPopupProps {
  onClose: () => void;
}

export function NotesPopup({ onClose }: NotesPopupProps) {
  const { notes } = useNotes();
  const [currentNoteIndex, setCurrentNoteIndex] = useState(0);

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const importantNotes = notes.filter((note: any) => {
    const noteDate = note.created_at ? new Date(note.created_at) : new Date();
    noteDate.setHours(0, 0, 0, 0);
    return (
      noteDate.getTime() === today.getTime() &&
      (note.is_important || note.category === 'important' || note.category === 'announcement')
    );
  }) as any;

  useEffect(() => {
    if (importantNotes.length === 0) {
      onClose();
    }
  }, [importantNotes.length, onClose]);

  if (importantNotes.length === 0) {
    return null;
  }

  const currentNote = importantNotes[currentNoteIndex];

  const handleNext = () => {
    if (currentNoteIndex < importantNotes.length - 1) {
      setCurrentNoteIndex(currentNoteIndex + 1);
    } else {
      onClose();
    }
  };

  const handleSkipAll = () => {
    onClose();
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center p-4 z-50"
      onClick={handleSkipAll}
    >
      <div
        className="bg-white rounded-2xl p-8 max-w-2xl w-full shadow-2xl animate-pulse"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between mb-6">
          <div className="flex items-center space-x-3">
            <AlertCircle className="w-8 h-8 text-red-500 animate-pulse" />
            <h2 className="text-2xl font-bold text-gray-900">Important Information</h2>
          </div>
          <button
            onClick={handleSkipAll}
            className="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="mb-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-xl font-bold text-gray-900">{currentNote.title}</h3>
            <span
              className={`px-3 py-1 rounded-full text-sm font-medium ${
                currentNote.category === 'important'
                  ? 'bg-red-100 text-red-700'
                  : currentNote.category === 'announcement'
                  ? 'bg-blue-100 text-blue-700'
                  : 'bg-gray-100 text-gray-700'
              }`}
            >
              {currentNote.category}
            </span>
          </div>
          <p className="text-gray-700 text-lg whitespace-pre-wrap leading-relaxed">
            {currentNote.content}
          </p>
          <p className="text-sm text-gray-500 mt-4">
            {currentNote.created_at ? new Date(currentNote.created_at).toLocaleString() : new Date().toLocaleString()}
          </p>
        </div>

        <div className="flex items-center justify-between">
          <span className="text-sm text-gray-600">
            Note {currentNoteIndex + 1} of {importantNotes.length}
          </span>
          <div className="flex space-x-3">
            {importantNotes.length > 1 && (
              <button
                onClick={handleSkipAll}
                className="px-4 py-2 text-gray-600 hover:text-gray-800 font-medium"
              >
                Skip All
              </button>
            )}
            <button
              onClick={handleNext}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-bold transition-colors shadow-lg"
            >
              {currentNoteIndex < importantNotes.length - 1 ? 'Next' : 'Got it!'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
