import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, CheckCircle2, Clock, AlertCircle } from 'lucide-react';

interface TodayTasksOverviewProps {
  onBack?: () => void;
}

export function TodayTasksOverview({ onBack }: TodayTasksOverviewProps) {
  const { profile } = useAuth();
  const { tasks } = useTasks();
  const { t } = useTranslation();

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const todayTasks = tasks.filter((task) => {
    if (!task.due_date) return false;
    const taskDate = new Date(task.due_date);
    taskDate.setHours(0, 0, 0, 0);
    return taskDate.getTime() === today.getTime();
  });

  const pendingTasks = todayTasks.filter(
    (task) => task.status === 'pending' || task.status === 'in_progress'
  );
  const completedTasks = todayTasks.filter(
    (task) => task.status === 'completed'
  );
  const reviewTasks = todayTasks.filter(
    (task) => task.status === 'review'
  );

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'completed':
        return 'bg-green-100 text-green-800 border-green-300';
      case 'review':
        return 'bg-blue-100 text-blue-800 border-blue-300';
      case 'in_progress':
        return 'bg-yellow-100 text-yellow-800 border-yellow-300';
      case 'pending':
        return 'bg-gray-100 text-gray-800 border-gray-300';
      default:
        return 'bg-gray-100 text-gray-800 border-gray-300';
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'completed':
        return <CheckCircle2 className="w-5 h-5 text-green-600" />;
      case 'review':
        return <Clock className="w-5 h-5 text-blue-600" />;
      case 'in_progress':
        return <Clock className="w-5 h-5 text-yellow-600" />;
      case 'pending':
        return <AlertCircle className="w-5 h-5 text-gray-600" />;
      default:
        return <AlertCircle className="w-5 h-5 text-gray-600" />;
    }
  };

  const formatDuration = (minutes: number) => {
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return `${hours}h ${mins}m`;
    } else if (hours > 0) {
      return `${hours}h`;
    } else {
      return `${mins}m`;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-orange-50 p-6">
      <div className="max-w-4xl mx-auto">
        <div className="flex items-center gap-4 mb-6">
          {onBack && (
            <button
              onClick={onBack}
              className="p-2 hover:bg-white/50 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-gray-700" />
            </button>
          )}
          <div>
            <h1 className="text-3xl font-bold text-gray-900">
              {t('dashboard.todaysTasks')}
            </h1>
            <p className="text-gray-600 mt-1">
              {todayTasks.length} {todayTasks.length === 1 ? 'Task' : 'Tasks'}
            </p>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-4 mb-6">
          <div className="bg-white rounded-lg shadow p-4 border-l-4 border-yellow-500">
            <div className="text-2xl font-bold text-gray-900">{pendingTasks.length}</div>
            <div className="text-sm text-gray-600">To Do</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4 border-l-4 border-blue-500">
            <div className="text-2xl font-bold text-gray-900">{reviewTasks.length}</div>
            <div className="text-sm text-gray-600">Review</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4 border-l-4 border-green-500">
            <div className="text-2xl font-bold text-gray-900">{completedTasks.length}</div>
            <div className="text-sm text-gray-600">Completed</div>
          </div>
        </div>

        {todayTasks.length === 0 ? (
          <div className="bg-white rounded-lg shadow-md p-12 text-center">
            <CheckCircle2 className="w-16 h-16 text-green-500 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-gray-900 mb-2">
              {t('dashboard.noTasksToday')}
            </h3>
            <p className="text-gray-600">
              {t('dashboard.allDone')}
            </p>
          </div>
        ) : (
          <div className="space-y-3">
            {todayTasks.map((task) => (
              <div
                key={task.id}
                className={`bg-white rounded-lg shadow-md p-5 border-l-4 ${
                  task.status === 'completed'
                    ? 'border-green-500'
                    : task.status === 'review'
                    ? 'border-blue-500'
                    : task.status === 'in_progress'
                    ? 'border-yellow-500'
                    : 'border-gray-300'
                }`}
              >
                <div className="flex items-start justify-between gap-4">
                  <div className="flex items-start gap-3 flex-1">
                    {getStatusIcon(task.status)}
                    <div className="flex-1 min-w-0">
                      <h3 className="font-semibold text-gray-900 mb-1">
                        {task.title}
                      </h3>
                      {task.description && (
                        <p className="text-sm text-gray-600 mb-2">
                          {task.description}
                        </p>
                      )}
                      <div className="flex flex-wrap items-center gap-3 text-sm text-gray-500">
                        {task.duration_minutes && (
                          <span className="flex items-center gap-1">
                            <Clock className="w-4 h-4" />
                            {formatDuration(task.duration_minutes)}
                          </span>
                        )}
                        {task.points_value && (
                          <span className="font-medium text-orange-600">
                            {task.points_value} {t('dashboard.points')}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="flex-shrink-0">
                    <span
                      className={`px-3 py-1 rounded-full text-xs font-medium border ${getStatusColor(
                        task.status
                      )}`}
                    >
                      {t(`tasks.status.${task.status}`)}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
