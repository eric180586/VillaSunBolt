import { CheckCircle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { useTranslation } from 'react-i18next';

interface TaskItem {
  id: string;
  text: string;
  is_completed: boolean;
  completed_by?: string;
  completed_by_id?: string;
  completed_at?: string;
  admin_reviewed?: boolean;
  admin_rejected?: boolean;
}

interface TaskItemsListProps {
  items: TaskItem[];
  onToggleItem?: (index: number) => void;
  readOnly?: boolean;
  showCompletedBy?: boolean;
}

export function TaskItemsList({ items, onToggleItem, readOnly = false, showCompletedBy = false }: TaskItemsListProps) {
  const { t: _t } = useTranslation();
  const { profile: _profile } = useAuth();

  if (!items || items.length === 0) {
    return null;
  }

  const _completedCount = items.filter(item => item.is_completed).length;
  const _totalCount = items.length;

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between mb-4">
        <h4 className="font-semibold text-gray-700">{t('tasks.title')}</h4>
        <div className="text-sm text-gray-600">
          {completedCount}/{totalCount} erledigt
        </div>
      </div>

      <div className="w-full bg-gray-200 rounded-full h-2 mb-4">
        <div
          className="bg-green-500 h-2 rounded-full transition-all duration-300"
          style={{ width: `${(completedCount / totalCount) * 100}%` }}
        />
      </div>

      <div className="space-y-2">
        {items.map((item, index) => (
          <div
            key={item.id || index}
            className={`flex items-start space-x-3 p-3 rounded-lg border-2 transition-all ${
              item.admin_rejected
                ? 'bg-red-50 border-red-300'
                : item.is_completed
                ? 'bg-green-50 border-green-300'
                : 'bg-gray-50 border-gray-200 hover:border-purple-300'
            } ${!readOnly && !item.is_completed ? 'cursor-pointer' : ''}`}
            onClick={() => !readOnly && !item.is_completed && onToggleItem?.(index)}
          >
            <input
              type="checkbox"
              checked={item.is_completed}
              onChange={() => !readOnly && onToggleItem?.(index)}
              className="mt-1 h-5 w-5 text-purple-600 rounded focus:ring-purple-500"
              disabled={readOnly}
            />
            <div className="flex-1">
              <p className={`text-sm ${item.is_completed ? 'text-gray-600' : 'text-gray-900'}`}>
                {item.text}
              </p>
              {showCompletedBy && item.is_completed && item.completed_by && (
                <p className="text-xs text-gray-500 mt-1">
                  <CheckCircle className="w-3 h-3 inline mr-1" />
                  {item.completed_by}
                </p>
              )}
              {item.admin_rejected && (
                <p className="text-xs text-red-600 mt-1 font-medium">
                  ⚠️ Abgelehnt - Bitte erneut erledigen
                </p>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
