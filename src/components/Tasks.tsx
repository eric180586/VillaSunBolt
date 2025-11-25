import { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { useProfiles } from '../hooks/useProfiles';
import { Plus, CheckCircle, Clock, Users, X, RefreshCw, ArrowLeft, Edit2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { formatDateTimeForDisplay, formatDateForInput, getTodayDateString } from '../lib/dateUtils';
import { getTodayTasks } from '../lib/taskFilters';
import { TaskWithItemsModal } from './TaskWithItemsModal';
import { HelperSelectionModal } from './HelperSelectionModal';
import { TaskCreateModal } from './TaskCreateModal';
import { useTranslation } from 'react-i18next';

const CATEGORIES = [
  { id: 'daily_morning', label: 'Daily Morning', color: 'bg-orange-500' },
  { id: 'room_cleaning', label: 'Room Cleaning', color: 'bg-blue-500' },
  { id: 'small_cleaning', label: 'Small Cleaning', color: 'bg-cyan-500' },
  { id: 'extras', label: 'Extras', color: 'bg-purple-500' },
  { id: 'housekeeping', label: 'Housekeeping', color: 'bg-green-500' },
  { id: 'reception', label: 'Reception', color: 'bg-pink-500' },
  { id: 'shopping', label: 'Shopping', color: 'bg-yellow-500' },
  { id: 'repair', label: 'Repair/Need new', color: 'bg-red-500' },
  { id: 'admin', label: 'Admin', color: 'bg-gray-700' },
];

// Unused: const NAMES = ['Venus', 'Earth', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto'];


interface TasksProps {
  onNavigate?: (view: string) => void;
  filterStatus?: 'pending_review' | 'today' | null;
  onBack?: () => void;
}

export function Tasks({ onNavigate, filterStatus, onBack }: TasksProps = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { tasks, updateTask, deleteTask, refetch } = useTasks();
  const { profiles } = useProfiles();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [showItemsModal, setShowItemsModal] = useState(false);
  const [showHelperModal, setShowHelperModal] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [showReopenItemsModal, setShowReopenItemsModal] = useState(false);
  const [selectedTask, setSelectedTask] = useState<any>(null);
  const [adminNotes, setAdminNotes] = useState('');
  const [adminPhoto, setAdminPhoto] = useState<File[]>([]);
  const [itemsToReopen, setItemsToReopen] = useState<number[]>([]);
  const [_showDiceModal, _setShowDiceModal] = useState(false);
  const [_pendingTaskCompletion, _setPendingTaskCompletion] = useState<any>(null);
  const [editingTask, setEditingTask] = useState<any>(null);

  const isAdmin = profile?.role === 'admin';
  const isRepairCategory = selectedCategory === 'repair';

  const [formData, setFormData] = useState({
    category: 'extras' as string,
    title: '',
    description: '',
    due_date: '',
    due_time: '',
    duration_minutes: 30,
    points_value: 10,
    assigned_to: '',
    secondary_assigned_to: '',
    description_photo: [] as File[],
    photo_proof_required: false,
    photo_required_sometimes: false,
    photo_explanation_text: '',
  }) as any;

  const getDefaultDateTime = (category: string) => {
    const dateStr = getTodayDateString();

    switch (category) {
      case 'daily_morning':
        return { date: dateStr, time: '10:00' };
      case 'room_cleaning':
        return { date: dateStr, time: '14:00' };
      default:
        return { date: dateStr, time: '23:59' };
    }
  };

  useEffect(() => {
    if (showModal) {
      const defaults = getDefaultDateTime(formData.category);
      setFormData((prev: typeof formData) => ({
        ...prev,
        due_date: defaults.date,
        due_time: defaults.time,
        duration_minutes:
          formData.category === 'small_cleaning' ? 15 : formData.category === 'room_cleaning' ? 60 : 60,
        points_value: getDefaultPointsForCategory(formData.category),
      }));
    }
  }, [formData.category, showModal]);

  useEffect(() => {
    const filterToday = sessionStorage.getItem('tasks_filter_today');
    if (filterToday === 'true') {
      sessionStorage.removeItem('tasks_filter_today');
      const todayTasks = getTodayTasks(tasks).filter(t => t.status !== 'completed' && t.status !== 'archived');
      if (todayTasks.length > 0) {
        setSelectedCategory('all_today');
      }
    }
  }, [tasks]);


  const getCategoryCounts = (categoryId: string) => {
    const categoryTasks = tasks.filter(
      (t) => t.category === categoryId && (t.is_template !== true || t.recurrence === 'daily') && t.status !== 'archived'
    );
    const todayTasks = getTodayTasks(categoryTasks);
    const openTasks = todayTasks.filter((t: any) => t.status !== 'completed');

    return {
      totalTasks: todayTasks.length,
      openTasks: openTasks.length,
    };
  };

  const getDefaultPointsForCategory = (category: string): number => {
    switch (category) {
      case 'room_cleaning':
        return 5;
      case 'small_cleaning':
        return 3;
      default:
        return 2;
    }
  };
  const uploadPhoto = useCallback(async (file: File, folder: string): Promise<string> => {
    const fileExt = file.name.split('.').pop();
    const fileName = `${Math.random()}.${fileExt}`;
    const filePath = `${folder}/${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from('task-photos')
      .upload(filePath, file);

    if (uploadError) {
      console.error('Upload error:', uploadError);
      return '';
    }

    const { data } = supabase.storage.from('task-photos').getPublicUrl(filePath);
    return data.publicUrl;
  }, []);

  const handleAcceptTask = async (taskId: string) => {
    try {
      console.log('Accepting task:', taskId, 'for user:', profile?.id);
      const result = await updateTask(taskId, {
        assigned_to: profile?.id,
        status: 'in_progress',
      }) as any;
      console.log('Task accepted successfully:', result);
    } catch (error) {
      console.error('Error accepting task:', error);
      alert(`Failed to accept task: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const handleAddHelper = async (taskId: string) => {
    if (!profile?.id) return;
    try {
      await updateTask(taskId, {
        secondary_assigned_to: profile.id,
        status: 'in_progress',
      }) as any;
      await refetch();
    } catch (error) {
      console.error('Error adding helper:', error);
      alert(t('tasks.errorAddHelper'));
    }
  };

  // Old handleCompleteTask removed - now handled by HelperSelectionModal

  const handleApproveTask = useCallback(async (quality: 'very_good' | 'ready' | 'not_ready') => {
    const task = selectedTask;
    if (!task) return;

    try {
      let adminPhotoUrls: string[] | null = null;
      if (adminPhoto && adminPhoto.length > 0) {
        const uploadedUrls: string[] = [];
        for (const file of adminPhoto) {
          const url = await uploadPhoto(file, 'admin-reviews');
          if (url) uploadedUrls.push(url);
        }
        adminPhotoUrls = uploadedUrls;
      }

      await updateTask(task.id, {
        admin_notes: adminNotes,
        admin_photos: adminPhotoUrls,
      }) as any;

      const { data, error } = await supabase.rpc('approve_task_with_quality', {
        p_task_id: task.id,
        p_admin_id: profile?.id,
        p_review_quality: quality,
      }) as any;

      if (error) {
        console.error('Error approving task:', error);
        throw error;
      }

      const qualityLabels = {
        very_good: 'Very Good (+2 bonus)',
        ready: 'Ready',
        not_ready: 'Not Ready (-1 penalty)',
      };

      if (data) {
        alert(`Task approved as ${qualityLabels[quality]}!\n\nBase Points: ${data.base_points}\nQuality Bonus: ${data.quality_bonus > 0 ? '+' : ''}${data.quality_bonus}\nDeadline Bonus: +${data.deadline_bonus}\n\nTotal: ${data.total_points} points`);
      }

      setShowReviewModal(false);
      setSelectedTask(null);
      setAdminNotes('');
      setAdminPhoto([]);
      await refetch();
    } catch (error) {
      console.error('Error approving task:', error);
      alert(t('tasks.errorApproveTask'));
    }
  }, [adminNotes, adminPhoto, profile?.id, refetch, selectedTask, t, updateTask, uploadPhoto]);

  const handleReopenEntireTask = useCallback(async () => {
    const task = selectedTask;
    if (!task) return;

    try {
      let adminPhotoUrls: string[] | null = null;
      if (adminPhoto && adminPhoto.length > 0) {
        const uploadedUrls: string[] = [];
        for (const file of adminPhoto) {
          const url = await uploadPhoto(file, 'admin-reviews');
          if (url) uploadedUrls.push(url);
        }
        adminPhotoUrls = uploadedUrls;
      }

      const { error } = await supabase.rpc('reopen_task_with_penalty', {
        p_task_id: task.id,
        p_admin_id: profile?.id,
        p_admin_notes: adminNotes,
      }) as any;

      if (error) throw error;

      if (adminPhotoUrls && adminPhotoUrls.length > 0) {
        await updateTask(task.id, {
          admin_photos: adminPhotoUrls,
        }) as any;
      }

      setShowReviewModal(false);
      setShowReopenItemsModal(false);
      setSelectedTask(null);
      setAdminNotes('');
      setAdminPhoto([]);
      await refetch();
    } catch (error) {
      console.error('Error reopening task:', error);
      alert(t('tasks.errorReopenTask'));
    }
  }, [adminNotes, adminPhoto, profile?.id, refetch, selectedTask, t, updateTask, uploadPhoto]);

  const handleNotReady = useCallback(() => {
    const task = selectedTask;
    if (!task) return;

    if (task.items && task.items.length > 0) {
      setShowReviewModal(false);
      setShowReopenItemsModal(true);
      setItemsToReopen([]);
    } else {
      handleReopenEntireTask();
    }
  }, [handleReopenEntireTask, selectedTask]);

  const handleReopenSelectedItems = async () => {
    const task = selectedTask;
    if (!task || !task.items) return;

    if (itemsToReopen.length === 0) {
      alert(t('tasks.selectItemsToReopen'));
      return;
    }

    try {
      const updatedItems = task.items.map((item: any, index: number) => {
        if (itemsToReopen.includes(index)) {
          return {
            ...item,
            is_completed: false,
            completed_by: null,
            completed_by_id: null,
            completed_at: null,
          };
        }
        return item;
      }) as any;

      let adminPhotoUrls: string[] | null = null;
      if (adminPhoto && adminPhoto.length > 0) {
        const uploadedUrls: string[] = [];
        for (const file of adminPhoto) {
          const url = await uploadPhoto(file, 'admin-reviews');
          if (url) uploadedUrls.push(url);
        }
        adminPhotoUrls = uploadedUrls;
      }

      await updateTask(task.id, {
        items: updatedItems,
        status: 'in_progress',
        admin_notes: adminNotes,
        admin_photos: adminPhotoUrls,
      }) as any;

      setShowReopenItemsModal(false);
      setShowReviewModal(false);
      setSelectedTask(null);
      setAdminNotes('');
      setAdminPhoto([]);
      setItemsToReopen([]);
      await refetch();
      alert(t('tasks.itemsReopenedSuccess'));
    } catch (error) {
      console.error('Error reopening items:', error);
      alert(t('tasks.errorReopeningItems'));
    }
  };

  // Old checklist approval functions removed - now using task review system

  if (!selectedCategory && !filterStatus) {
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
            <h2 className="text-3xl font-bold text-gray-900">Tasks</h2>
          </div>
          {isAdmin && (
            <button
              onClick={() => setShowModal(true)}
              className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
            >
              <Plus className="w-5 h-5" />
              <span>New Task</span>
            </button>
          )}
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {CATEGORIES.filter((cat) => {
            if (!isAdmin && cat.id === 'admin') return false;
            return true;
          }).map((category) => {
            const counts = getCategoryCounts(category.id);
            return (
              <button
                key={category.id}
                onClick={() => {
                  if (category.id === 'shopping' && onNavigate) {
                    onNavigate('shopping');
                  } else {
                    setSelectedCategory(category.id);
                  }
                }}
                className="bg-white rounded-xl p-6 shadow-sm border-2 border-gray-200 hover:border-blue-500 transition-all text-left"
              >
                <div className="flex items-center space-x-3 mb-4">
                  <div className={`w-12 h-12 ${category.color} rounded-lg flex items-center justify-center`}>
                    <CheckCircle className="w-6 h-6 text-white" />
                  </div>
                  <h3 className="text-lg font-bold text-gray-900">{category.label}</h3>
                </div>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Open / Total</span>
                    <span className="text-lg font-bold text-gray-900">
                      {counts.openTasks}/{counts.totalTasks}
                    </span>
                  </div>
                </div>
              </button>
            );
          })}
        </div>

        {showModal && (
          <TaskCreateModal
            profiles={profiles}
            onComplete={() => {
              setShowModal(false);
              setEditingTask(null);
              refetch();
            }}
            onClose={() => {
              setShowModal(false);
              setEditingTask(null);
            }}
            editingTask={editingTask}
          />
        )}
      </div>
    );
  }

  let categoryTasks = selectedCategory === 'all_today'
    ? getTodayTasks(tasks)
    : selectedCategory
    ? tasks.filter((t: any) => {
        if (t.status === 'archived') return false;
        if (t.is_template && t.recurrence !== 'daily') return false;
        if (t.status === 'completed') {
          const today = getTodayDateString();
          const taskDate = t.due_date ? new Date(t.due_date).toISOString().split('T')[0] : '';
          return taskDate === today && t.category === selectedCategory;
        }
        return t.category === selectedCategory;
      })
    : tasks.filter((t: any) => {
        if (t.status === 'archived') return false;
        if (t.is_template && t.recurrence !== 'daily') return false;
        if (t.status === 'completed') {
          const today = getTodayDateString();
          const taskDate = t.due_date ? new Date(t.due_date).toISOString().split('T')[0] : '';
          return taskDate === today;
        }
        return true;
      }) as any;

  if (filterStatus === 'pending_review') {
    categoryTasks = categoryTasks.filter((t: any) => t.status === 'pending_review');
  } else if (filterStatus === 'today') {
    categoryTasks = getTodayTasks(categoryTasks);
  }


  const selectedCategoryData = CATEGORIES.find((c) => c.id === selectedCategory);
  const displayTitle = filterStatus === 'pending_review'
    ? 'Aufgaben zur Prüfung'
    : filterStatus === 'today'
    ? "Today's Tasks"
    : selectedCategory === 'all_today'
    ? "Today's Tasks"
    : (selectedCategoryData?.label || 'All Tasks');

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <button
            onClick={() => {
              setSelectedCategory(null);
              if (filterStatus) {
                onBack?.();
              }
            }}
            className="p-2 hover:bg-beige-100 rounded-lg transition-colors"
          >
            <ArrowLeft className="w-6 h-6 text-gray-700" />
          </button>
          <h2 className="text-3xl font-bold text-gray-900">{displayTitle}</h2>
          {filterStatus && (
            <span className="bg-yellow-100 text-yellow-800 px-3 py-1 rounded-full text-sm font-medium">
              Zur Prüfung: {categoryTasks.length}
            </span>
          )}
        </div>
        {(isAdmin || isRepairCategory) && (
          <button
            onClick={() => {
              setFormData((prev: typeof formData) => ({ ...prev, category: selectedCategory }));
              setShowModal(true);
            }}
            className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            <Plus className="w-5 h-5" />
            <span>New Task</span>
          </button>
        )}
      </div>

      <div className="space-y-4">
        {categoryTasks.length === 0 && (
          <div className="text-center py-16 bg-white rounded-xl border border-beige-200">
            <CheckCircle className="w-16 h-16 text-beige-300 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-700 mb-2">{t('tasks.noCurrentTodos')}</h3>
            <p className="text-gray-500 text-sm">Alle Aufgaben sind erledigt oder es wurden noch keine erstellt.</p>
          </div>
        )}

        {categoryTasks.map((task: any) => {
          const assignedUser = profiles.find((p) => p.id === task.assigned_to);
          const secondaryUser = profiles.find((p) => p.id === task.secondary_assigned_to);
          const taskIsRepair = task.category === 'repair';
          const canAccept = !task.assigned_to && task.status === 'pending' && !taskIsRepair;
          const isMyTask = task.assigned_to === profile?.id || task.secondary_assigned_to === profile?.id;
          const canHelp = task.assigned_to && task.assigned_to !== profile?.id && !task.secondary_assigned_to && (task.status === 'in_progress' || task.status === 'in_progress');

          const getStatusBorderColor = (status: string) => {
            switch (status) {
              case 'pending': return 'border-l-gray-400';
              case 'in_progress': return 'border-l-blue-500';
              case 'pending_review': return 'border-l-yellow-500';
              case 'completed': return 'border-l-green-500';
              default: return 'border-l-gray-300';
            }
          };

          return (
            <div key={task.id} className={`bg-white rounded-xl p-6 shadow-sm border-l-4 ${getStatusBorderColor(task.status)} border-t border-b border-r border-gray-200`}>
              <div className="flex items-start justify-between mb-4">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-2">
                    <h3 className="text-xl font-bold text-gray-900">{task.title}</h3>
                    {task.status === 'pending' && (
                      <span className="bg-gray-100 text-gray-700 px-2 py-1 rounded text-xs font-medium">
                        Pending
                      </span>
                    )}
                    {task.status === 'in_progress' && (
                      <span className="bg-blue-100 text-blue-700 px-2 py-1 rounded text-xs font-medium">
                        In Progress
                      </span>
                    )}
                    {task.status === 'pending_review' && (
                      <span className="bg-yellow-100 text-yellow-700 px-2 py-1 rounded text-xs font-medium">
                        Pending Review
                      </span>
                    )}
                    {task.status === 'completed' && (
                      <span className="bg-green-100 text-green-700 px-2 py-1 rounded text-xs font-medium">
                        Completed
                      </span>
                    )}
                    {task.reopened_count > 0 && (
                      <span className="bg-orange-100 text-orange-700 px-2 py-1 rounded text-xs">
                        Reopened {task.reopened_count}x
                      </span>
                    )}
                  </div>
                  {task.description && <p className="text-gray-600 mb-3 whitespace-pre-wrap">{task.description}</p>}

                  <div className="flex flex-wrap gap-2 mb-3">
                    {assignedUser && (
                      <div className="flex items-center space-x-2 bg-blue-50 px-3 py-1 rounded-full">
                        <Users className="w-4 h-4 text-blue-600" />
                        <span className="text-sm text-blue-900">{assignedUser.full_name}</span>
                      </div>
                    )}
                    {secondaryUser && (
                      <div className="flex items-center space-x-2 bg-purple-50 px-3 py-1 rounded-full">
                        <Users className="w-4 h-4 text-purple-600" />
                        <span className="text-sm text-purple-900">{secondaryUser.full_name}</span>
                      </div>
                    )}
                    <div className="flex items-center space-x-2 bg-gray-100 px-3 py-1 rounded-full">
                      <Clock className="w-4 h-4 text-gray-600" />
                      <span className="text-sm font-medium text-gray-900">{task.duration_minutes} min</span>
                    </div>
                    <div className="flex items-center space-x-2 bg-yellow-50 px-3 py-1 rounded-full">
                      <span className="text-sm font-bold text-yellow-700">+{task.points_value} pts</span>
                    </div>
                    {task.due_date && (
                      <div className="flex items-center space-x-2 bg-blue-50 px-3 py-1 rounded-full">
                        <span className="text-sm font-medium text-blue-700">
                          Due: {formatDateTimeForDisplay(task.due_date)}
                        </span>
                      </div>
                    )}
                  </div>

                  {task.description_photo && Array.isArray(task.description_photo) && task.description_photo.length > 0 && (
                    <div className="mb-3">
                      <p className="text-sm font-medium text-gray-700 mb-2">Erklärungs-Fotos:</p>
                      <div className="grid grid-cols-2 gap-2">
                        {task.description_photo.map((url: string, index: number) => (
                          <img
                            key={index}
                            src={url}
                            alt={`Erklärung ${index + 1}`}
                            className="rounded-lg w-full h-auto max-h-48 object-cover border border-gray-300 cursor-pointer hover:opacity-90 transition-opacity"
                            onClick={() => window.open(url, '_blank')}
                          />
                        ))}
                      </div>
                    </div>
                  )}

                  {task.status === 'pending_review' && task.completion_notes && (
                    <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 mb-3">
                      <p className="text-sm font-medium text-blue-900 mb-1">Completion Notes:</p>
                      <p className="text-sm text-blue-800 whitespace-pre-wrap">{task.completion_notes}</p>
                    </div>
                  )}

                  {task.photo_proof && (
                    <div className="mb-3">
                      <p className="text-sm font-medium text-gray-700 mb-1">Completion Photo:</p>
                      <img src={task.photo_proof} alt="Completion proof" className="rounded-lg max-w-xs" />
                    </div>
                  )}

                  {/* Display task items (sub-tasks) if present */}
                  {task.items && Array.isArray(task.items) && task.items.length > 0 && (
                    <div className="bg-gray-50 border-2 border-gray-300 rounded-lg p-4 mb-3">
                      <p className="text-sm font-bold text-gray-900 mb-3 flex items-center">
                        <CheckCircle className="w-5 h-5 mr-2 text-blue-600" />
                        Sub-Tasks: {task.items.filter((item: any) => item.is_completed || item.completed).length}/{task.items.length} erledigt
                      </p>
                      <ul className="space-y-2">
                        {task.items.map((item: any, index: number) => {
                          const isCompleted = item.is_completed || item.completed;
                          return (
                            <li key={index} className="flex items-start space-x-3">
                              <div className={`w-6 h-6 rounded-md flex items-center justify-center flex-shrink-0 mt-0.5 ${
                                isCompleted ? 'bg-green-500' : 'bg-gray-300'
                              }`}>
                                {isCompleted && <CheckCircle className="w-4 h-4 text-white" />}
                              </div>
                              <div className="flex-1">
                                <span className={`text-sm font-medium ${isCompleted ? 'text-gray-500 line-through' : 'text-gray-900'}`}>
                                  {item.text}
                                </span>
                                {isCompleted && item.completed_by && (
                                  <p className="text-xs text-green-600 mt-1">
                                    ✓ {item.completed_by}
                                  </p>
                                )}
                              </div>
                            </li>
                          );
                        })}
                      </ul>
                    </div>
                  )}

                  {task.admin_notes && (
                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 mb-3">
                      <p className="text-sm font-medium text-yellow-900 mb-1">Admin Notes:</p>
                      <p className="text-sm text-yellow-800 whitespace-pre-wrap">{task.admin_notes}</p>
                    </div>
                  )}

                  {task.admin_photo && Array.isArray(task.admin_photo) && task.admin_photo.length > 0 && (
                    <div className="mb-3">
                      <p className="text-sm font-medium text-gray-700 mb-2">Admin Review Fotos:</p>
                      <div className="grid grid-cols-2 gap-2">
                        {task.admin_photo.map((url: string, index: number) => (
                          <img
                            key={index}
                            src={url}
                            alt={`Admin review ${index + 1}`}
                            className="rounded-lg w-full h-auto max-h-48 object-cover border border-gray-300 cursor-pointer hover:opacity-90 transition-opacity"
                            onClick={() => window.open(url, '_blank')}
                          />
                        ))}
                      </div>
                    </div>
                  )}
                </div>

                <div className="flex flex-col items-end space-y-2 ml-4">
                  {canAccept && (
                    <button
                      onClick={() => handleAcceptTask(task.id)}
                      className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 whitespace-nowrap"
                    >
                      Me Do
                    </button>
                  )}
                  {canHelp && (
                    <button
                      onClick={() => handleAddHelper(task.id)}
                      className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 whitespace-nowrap"
                    >
                      Me Help
                    </button>
                  )}
                  {isMyTask && (task.status === 'in_progress' || task.status === 'pending') && (
                    <button
                      onClick={async () => {
                        setSelectedTask(task);

                        // Check if task already has a helper (someone joined via "Me Help")
                        const hasHelper = task.secondary_assigned_to || task.helper_id;

                        // Check if task has items (was a checklist)
                        if (task.items && task.items.length > 0) {
                          // Open items modal for checking off items
                          setShowItemsModal(true);
                        } else if (hasHelper) {
                          // Task has helper, submit directly without asking for helper
                          try {
                            await updateTask(task.id, {
                              status: 'pending_review',
                              completed_at: new Date().toISOString()
                            });
                            alert('Task zur Review eingereicht!');
                          } catch (error) {
                            console.error('Error completing task:', error);
                            alert('Fehler beim Abschließen');
                          }
                        } else {
                          // No helper yet, ask if they want to add one
                          setShowHelperModal(true);
                        }
                      }}
                      className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 whitespace-nowrap"
                    >
                      {task.reopened_count > 0 ? 'Me Clean Again' : 'Me Do Already'}
                    </button>
                  )}
                  {isAdmin && task.status === 'pending_review' && (
                    <button
                      onClick={() => {
                        setSelectedTask(task);
                        setShowReviewModal(true);
                      }}
                      className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                    >
                      Review
                    </button>
                  )}
                  {isAdmin && (task.status === 'pending' || task.status === 'in_progress') && !task.assigned_to && (
                    <button
                      onClick={() => {
                        setEditingTask(task);
                        setFormData({
                          category: task.category,
                          title: task.title,
                          description: task.description || '',
                          due_date: task.due_date ? formatDateForInput(task.due_date) : getTodayDateString(),
                          due_time: task.due_date ? new Date(task.due_date).toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit' }) : '23:59',
                          duration_minutes: task.duration_minutes,
                          points_value: task.points_value,
                          assigned_to: task.assigned_to || '',
                          secondary_assigned_to: task.secondary_assigned_to || '',
                          description_photo: [],
                          photo_proof_required: task.photo_proof_required || false,
                          photo_required_sometimes: task.photo_required_sometimes || false,
                          photo_explanation_text: task.photo_explanation_text || '',
                        }) as any;
                        setShowModal(true);
                      }}
                      className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg"
                    >
                      <Edit2 className="w-5 h-5" />
                    </button>
                  )}
                  {isAdmin && (
                    <button
                      onClick={() => deleteTask(task.id)}
                      className="p-2 text-red-600 hover:bg-red-50 rounded-lg"
                    >
                      <X className="w-5 h-5" />
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}

        {/* Checklist instances now merged into tasks */}
        {false && [].map((instance: any) => {
          const checklist = instance.checklists;
          if (!checklist) return null;

          const completedCount = instance.items?.filter((item: any) => item.completed).length || 0;
          const totalCount = instance.items?.length || 0;
          const isCompleted = instance.status === 'completed';
          const needsReview = isCompleted && !instance.admin_reviewed;
          const isApproved = instance.admin_approved === true;
          const isRejected = instance.admin_approved === false;

          return (
            <div
              key={instance.id}
              className={`bg-gradient-to-br rounded-xl p-6 shadow-sm border-2 transition-all ${
                isRejected
                  ? 'from-red-50 to-white border-red-300 cursor-pointer hover:shadow-md hover:border-red-400'
                  : isApproved
                  ? 'from-green-50 to-white border-green-300'
                  : needsReview
                  ? 'from-yellow-50 to-white border-yellow-300'
                  : 'from-purple-50 to-white border-purple-200 cursor-pointer hover:shadow-md hover:border-purple-300'
              }`}
              onClick={() => {
                // Checklist feature temporarily disabled
              }}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 mb-2 flex-wrap">
                    <CheckCircle className="w-5 h-5 text-purple-600" />
                    <h3 className="text-lg font-bold text-gray-900">{checklist.title}</h3>
                    {isRejected ? (
                      <span className="bg-red-100 text-red-700 px-2 py-1 rounded text-xs font-medium">
                        Abgelehnt
                      </span>
                    ) : isApproved ? (
                      <span className="bg-green-100 text-green-700 px-2 py-1 rounded text-xs font-medium">
                        Genehmigt ✓
                      </span>
                    ) : needsReview ? (
                      <span className="bg-yellow-100 text-yellow-700 px-2 py-1 rounded text-xs font-medium">
                        Wartet auf Überprüfung
                      </span>
                    ) : isCompleted ? (
                      <span className="bg-green-100 text-green-700 px-2 py-1 rounded text-xs font-medium">
                        Abgeschlossen
                      </span>
                    ) : (
                      <span className="bg-purple-100 text-purple-700 px-2 py-1 rounded text-xs font-medium">
                        Checkliste
                      </span>
                    )}
                  </div>

                  {instance.admin_rejection_reason && (
                    <div className="bg-red-100 border border-red-300 rounded-lg p-3 mb-3">
                      <p className="text-sm text-red-800 mb-2">
                        <strong>Ablehnungsgrund:</strong> {instance.admin_rejection_reason}
                      </p>
                      {instance.admin_photo && (
                        <img
                          src={instance.admin_photo}
                          alt="Admin Erklärung"
                          className="rounded-lg max-w-full h-auto max-h-32 object-cover border border-red-400 mt-2"
                        />
                      )}
                    </div>
                  )}

                  {instance.admin_approved && instance.admin_photo && (
                    <div className="bg-green-100 border border-green-300 rounded-lg p-3 mb-3">
                      <p className="text-sm text-green-800 mb-2">
                        <strong>Admin Hinweis:</strong>
                      </p>
                      <img
                        src={instance.admin_photo}
                        alt="Admin Erklärung"
                        className="rounded-lg max-w-full h-auto max-h-32 object-cover border border-green-400"
                      />
                    </div>
                  )}

                  {checklist.description && (
                    <p className="text-sm text-gray-600 mb-3">{checklist.description}</p>
                  )}

                  <div className="flex items-center space-x-4 text-sm">
                    <div className="flex items-center space-x-2">
                      <span className="text-gray-600">Fortschritt:</span>
                      <span className="font-bold text-purple-600">
                        {completedCount}/{totalCount}
                      </span>
                    </div>
                    {checklist.checklists?.duration_minutes && (
                      <div className="flex items-center space-x-2">
                        <Clock className="w-4 h-4 text-gray-500" />
                        <span className="text-sm text-gray-900">{checklist.checklists.duration_minutes} min</span>
                      </div>
                    )}
                    {checklist.due_date && (
                      <div className="flex items-center space-x-2">
                        <span className="text-gray-600">Deadline:</span>
                        <span className="font-medium text-gray-900">
                          {formatDateTimeForDisplay(checklist.due_date)}
                        </span>
                      </div>
                    )}
                    {checklist.points_value > 0 && (
                      <div className="flex items-center space-x-2 bg-yellow-50 px-3 py-1 rounded-full">
                        <span className="text-sm font-bold text-yellow-700">+{checklist.points_value} pts</span>
                      </div>
                    )}
                  </div>

                  <div className="mt-3 w-full bg-gray-200 rounded-full h-2">
                    <div
                      className={`h-2 rounded-full transition-all ${
                        isRejected ? 'bg-red-500' : isCompleted ? 'bg-green-500' : 'bg-purple-500'
                      }`}
                      style={{
                        width: `${totalCount > 0 ? (completedCount / totalCount) * 100 : 0}%`,
                      }}
                    />
                  </div>
                </div>

                {isAdmin && needsReview && (
                  <div className="flex space-x-2 ml-4" onClick={(e) => e.stopPropagation()}>
                    <button
                      onClick={() => {
                        // Checklist approval temporarily disabled
                      }}
                      className="p-2 text-green-600 hover:bg-green-50 rounded-lg border border-green-300"
                      title="Genehmigen"
                    >
                      <CheckCircle className="w-5 h-5" />
                    </button>
                    <button
                      onClick={() => {
                        // Checklist review temporarily disabled
                      }}
                      className="p-2 text-red-600 hover:bg-red-50 rounded-lg border border-red-300"
                      title="Ablehnen"
                    >
                      <X className="w-5 h-5" />
                    </button>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {showModal && (
        <TaskCreateModal
          profiles={profiles}
          onComplete={() => {
            setShowModal(false);
            refetch();
          }}
          onClose={() => setShowModal(false)}
        />
      )}

      {showItemsModal && selectedTask && (
        <TaskWithItemsModal
          task={selectedTask}
          onClose={() => {
            setShowItemsModal(false);
            setSelectedTask(null);
          }}
          onComplete={async () => {
            await refetch();
          }}
          onOpenHelperPopup={() => {
            // Items modal closed, now open helper modal
            setShowItemsModal(false);
            setShowHelperModal(true);
          }}
        />
      )}

      {showHelperModal && selectedTask && (
        <HelperSelectionModal
          isOpen={showHelperModal}
          task={selectedTask}
          onClose={() => {
            setShowHelperModal(false);
            setSelectedTask(null);
          }}
          onComplete={async () => {
            await refetch();
          }}
          staffMembers={profiles.filter(p => p.role === 'staff' && p.id !== profile?.id)}
        />
      )}

      {showReviewModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowReviewModal(false);
            setSelectedTask(null);
            setAdminNotes('');
            setAdminPhoto([]);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">Review Task</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Admin Notes (optional)</label>
                <textarea
                  value={adminNotes}
                  onChange={(e) => setAdminNotes(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={4}
                  placeholder="Add notes for staff..."
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Admin Photos (optional, mehrere möglich)</label>
                <input
                  type="file"
                  accept="image/*"
                  multiple
                  onChange={(e) => setAdminPhoto(Array.from(e.target.files || []))}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
                {adminPhoto.length > 0 && (
                  <p className="text-sm text-green-600 mt-1">
                    ✓ {adminPhoto.length} Foto(s: any) ausgewählt
                  </p>
                )}
              </div>
              <div className="flex flex-col space-y-3 pt-4">
                <div className="text-sm text-gray-700 font-medium mb-1">Quality Assessment:</div>
                <button
                  onClick={() => handleApproveTask('very_good')}
                  className="w-full px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 flex items-center justify-between group transition-all"
                >
                  <div className="flex items-center space-x-2">
                    <CheckCircle className="w-5 h-5" />
                    <span className="font-semibold">Very Good</span>
                  </div>
                  <span className="bg-green-700 px-3 py-1 rounded text-sm font-bold">+2 Points</span>
                </button>
                <button
                  onClick={() => handleApproveTask('ready')}
                  className="w-full px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center justify-between group transition-all"
                >
                  <div className="flex items-center space-x-2">
                    <CheckCircle className="w-5 h-5" />
                    <span className="font-semibold">Ready</span>
                  </div>
                  <span className="bg-blue-700 px-3 py-1 rounded text-sm font-bold">+0 Points</span>
                </button>
                <button
                  onClick={handleNotReady}
                  className="w-full px-4 py-3 bg-orange-600 text-white rounded-lg hover:bg-orange-700 flex items-center justify-between group transition-all"
                >
                  <div className="flex items-center space-x-2">
                    <RefreshCw className="w-5 h-5" />
                    <span className="font-semibold">Not Ready - Reopen</span>
                  </div>
                  <span className="bg-orange-700 px-3 py-1 rounded text-sm">Select Items</span>
                </button>
                <button
                  onClick={() => {
                    setShowReviewModal(false);
                    setSelectedTask(null);
                    setAdminNotes('');
                    setAdminPhoto([]);
                  }}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showReopenItemsModal && selectedTask && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowReopenItemsModal(false);
            setShowReviewModal(true);
            setItemsToReopen([]);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">
              Items zum Wiedereröffnen auswählen
            </h3>
            <p className="text-sm text-gray-600 mb-6">
              Wählen Sie die Items aus, die wiedereröffnet werden sollen. Der Mitarbeiter muss diese erneut bearbeiten.
            </p>

            <div className="space-y-2 mb-6">
              {selectedTask.items?.map((item: any, index: number) => (
                <div
                  key={index}
                  className={`flex items-start space-x-3 p-4 rounded-lg border-2 transition-all cursor-pointer ${
                    itemsToReopen.includes(index)
                      ? 'bg-orange-50 border-orange-400'
                      : item.is_completed
                      ? 'bg-green-50 border-green-200'
                      : 'bg-gray-50 border-gray-200'
                  }`}
                  onClick={() => {
                    if (itemsToReopen.includes(index)) {
                      setItemsToReopen(itemsToReopen.filter(i => i !== index));
                    } else {
                      setItemsToReopen([...itemsToReopen, index]);
                    }
                  }}
                >
                  <input
                    type="checkbox"
                    checked={itemsToReopen.includes(index)}
                    onChange={() => {}}
                    className="mt-1 h-5 w-5 text-orange-600 rounded focus:ring-orange-500 cursor-pointer"
                  />
                  <div className="flex-1">
                    <p className={`text-sm font-medium ${item.is_completed ? 'text-gray-700' : 'text-gray-500'}`}>
                      {item.text}
                    </p>
                    {item.is_completed && item.completed_by && (
                      <p className="text-xs text-green-600 mt-1">
                        <CheckCircle className="w-3 h-3 inline mr-1" />
                        Erledigt von: {item.completed_by}
                      </p>
                    )}
                    {itemsToReopen.includes(index) && (
                      <p className="text-xs text-orange-600 mt-1 font-medium">
                        → Wird wiedereröffnet
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>

            <div className="flex space-x-3">
              <button
                onClick={() => {
                  setShowReopenItemsModal(false);
                  setShowReviewModal(true);
                  setItemsToReopen([]);
                }}
                className="flex-1 px-4 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 transition-colors font-medium"
              >
                Save
              </button>
              <button
                onClick={handleReopenEntireTask}
                className="flex-1 px-4 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium"
              >
                Gesamte Aufgabe wiedereröffnen
              </button>
              <button
                onClick={handleReopenSelectedItems}
                className="flex-1 px-4 py-3 bg-orange-600 text-white rounded-lg hover:bg-orange-700 transition-colors font-medium"
                disabled={itemsToReopen.length === 0}
              >
                {itemsToReopen.length} Item(s: any) wiedereröffnen
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Checklist modal removed - now using TaskWithItemsModal */}

      {/* Dice modal removed - photo requirement handled in HelperSelectionModal */}

      {/* Old checklist approve/review modals removed */}
    </div>
  );
}
