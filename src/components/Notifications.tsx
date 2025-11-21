import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useNotifications } from '../hooks/useNotifications';
import { useNotes } from '../hooks/useNotes';
import { Bell, CheckCheck, ChevronDown, ChevronUp, Eye, ArrowLeft } from 'lucide-react';

export function Notifications({ onBack }: { onBack?: () => void } = {}) {
  const { notifications, markAsRead, markAllAsRead } = useNotifications();
  const { notes } = useNotes();
  const [expandedNotes, setExpandedNotes] = useState<Set<string>>(new Set());

  const toggleNote = (noteId: string) => {
    setExpandedNotes((prev) => {
      const newSet = new Set(prev);
      if (newSet.has(noteId)) {
        newSet.delete(noteId);
      } else {
        newSet.add(noteId);
      }
      return newSet;
    });
  };

  const todayNotes = notes.filter((note) => {
    const noteDate = new Date(note.created_at);
    const today = new Date();
    return noteDate.toDateString() === today.toDateString();
  });

  const getTypeColor = (type: string) => {
    switch (type) {
      case 'success':
        return 'bg-green-100 border-green-300 text-green-800';
      case 'warning':
        return 'bg-yellow-100 border-yellow-300 text-yellow-800';
      case 'error':
        return 'bg-red-100 border-red-300 text-red-800';
      case 'task':
        return 'bg-blue-100 border-blue-300 text-blue-800';
      case 'schedule':
        return 'bg-purple-100 border-purple-300 text-purple-800';
      default:
        return 'bg-gray-100 border-gray-300 text-gray-800';
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
          <h2 className="text-3xl font-bold text-gray-900">Notifications & Notes</h2>
        </div>
        {notifications.some((n) => !n.is_read) && (
          <button
            onClick={markAllAsRead}
            className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            <CheckCheck className="w-5 h-5" />
            <span>Mark all as read</span>
          </button>
        )}
      </div>

      {todayNotes.length > 0 && (
        <div className="space-y-3">
          <h3 className="text-xl font-semibold text-gray-900">Today's Notes</h3>
          {todayNotes.map((note) => (
            <div
              key={note.id}
              className="bg-white rounded-xl border-2 border-gray-200 overflow-hidden shadow-sm"
            >
              <button
                onClick={() => toggleNote(note.id)}
                className="w-full flex items-center justify-between p-4 hover:bg-gray-50 transition-colors"
              >
                <div className="flex items-center space-x-3">
                  <Eye className="w-5 h-5 text-gray-600" />
                  <div className="text-left">
                    <h4 className="font-semibold text-gray-900">{note.title}</h4>
                    <p className="text-sm text-gray-500">
                      {new Date(note.created_at).toLocaleTimeString([], {
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </p>
                  </div>
                </div>
                {expandedNotes.has(note.id) ? (
                  <ChevronUp className="w-5 h-5 text-gray-600" />
                ) : (
                  <ChevronDown className="w-5 h-5 text-gray-600" />
                )}
              </button>
              {expandedNotes.has(note.id) && (
                <div className="px-4 pb-4 border-t border-gray-200 pt-3 bg-gray-50">
                  <p className="text-gray-700 whitespace-pre-wrap">{note.content}</p>
                  <div className="flex items-center justify-between mt-3">
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium ${
                        note.category === 'important'
                          ? 'bg-red-100 text-red-700'
                          : note.category === 'announcement'
                          ? 'bg-blue-100 text-blue-700'
                          : note.category === 'reminder'
                          ? 'bg-yellow-100 text-yellow-700'
                          : 'bg-gray-100 text-gray-700'
                      }`}
                    >
                      {note.category}
                    </span>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {notifications.length === 0 ? (
        <div className="bg-white rounded-xl p-12 text-center shadow-sm border border-gray-200">
          <Bell className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 className="text-xl font-semibold text-gray-900 mb-2">No notifications</h3>
          <p className="text-gray-600">You're all caught up!</p>
        </div>
      ) : (
        <div className="space-y-3">
          {notifications.map((notification) => (
            <div
              key={notification.id}
              className={`rounded-xl p-5 border-2 transition-all ${
                notification.is_read
                  ? 'bg-white border-gray-200'
                  : 'bg-blue-50 border-blue-300 shadow-sm'
              }`}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-2">
                    <span
                      className={`px-2 py-1 rounded-full text-xs font-medium ${getTypeColor(
                        notification.type
                      )}`}
                    >
                      {notification.type}
                    </span>
                    {!notification.is_read && (
                      <span className="w-2 h-2 bg-blue-600 rounded-full" />
                    )}
                  </div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-1">
                    {notification.title}
                  </h3>
                  <p className="text-gray-700 mb-2">{notification.message}</p>
                  <p className="text-xs text-gray-500">
                    {new Date(notification.created_at).toLocaleString()}
                  </p>
                </div>
                {!notification.is_read && (
                  <button
                    onClick={() => markAsRead(notification.id)}
                    className="ml-4 px-3 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    Mark as read
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
