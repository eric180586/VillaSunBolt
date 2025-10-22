import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { useProfiles } from '../hooks/useProfiles';
import { useChecklists } from '../hooks/useChecklists';
import { Plus, CheckCircle, Clock, Users, X, RefreshCw, ArrowLeft, Edit2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { formatDateTimeForDisplay, formatDateForInput, getTodayDateString, isSameDay, combineDateAndTime } from '../lib/dateUtils';
import { PhotoRequirementDice } from './PhotoRequirementDice';
import { TaskCompletionModal } from './TaskCompletionModal';
import { TaskReviewModal } from './TaskReviewModal';

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

const ROOM_NAMES = ['Venus', 'Earth', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Pluto'];

const MOTIVATIONAL_MESSAGES = [
  'Great job! Keep up the excellent work!',
  'Fantastic work! You are doing amazing!',
  'Outstanding! You are a star!',
  'Excellent! Your dedication shows!',
  'Wonderful! You make a difference!',
  'Superb work! Keep shining!',
  'Amazing! You are truly appreciated!',
  'Perfect! Your effort is inspiring!',
];

interface TasksProps {
  onNavigate?: (view: string) => void;
  filterStatus?: 'pending_review' | 'today' | null;
  onBack?: () => void;
}

export function Tasks({ onNavigate, filterStatus, onBack }: TasksProps = {}) {
  const { profile } = useAuth();
  const { tasks, createTask, updateTask, deleteTask } = useTasks();
  const { profiles } = useProfiles();
  const { checklists } = useChecklists();
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [showModal, setShowModal] = useState(false);
  const [showCompleteModal, setShowCompleteModal] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [selectedTask, setSelectedTask] = useState<any>(null);
  const [completionNotes, setCompletionNotes] = useState('');
  const [completionPhoto, setCompletionPhoto] = useState<File | null>(null);
  const [photoRequiredThisTime, setPhotoRequiredThisTime] = useState(false);
  const [hadHelper, setHadHelper] = useState(false);
  const [selectedHelper, setSelectedHelper] = useState<string | null>(null);
  const [adminNotes, setAdminNotes] = useState('');
  const [adminPhoto, setAdminPhoto] = useState<File[]>([]);
  const [showDiceModal, setShowDiceModal] = useState(false);
  const [pendingTaskCompletion, setPendingTaskCompletion] = useState<any>(null);
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
  });

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
      setFormData((prev) => ({
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
    loadChecklistInstances();

    const filterToday = sessionStorage.getItem('tasks_filter_today');
    if (filterToday === 'true') {
      sessionStorage.removeItem('tasks_filter_today');
      const today = getTodayDateString();
      const todayTasks = tasks.filter(t => {
        if (!t.due_date) return false;
        const taskDate = new Date(t.due_date).toISOString().split('T')[0];
        return taskDate === today && t.status !== 'completed' && t.status !== 'archived';
      });
      if (todayTasks.length > 0) {
        setSelectedCategory('all_today');
      }
    }

    const channel = supabase
      .channel(`checklist_instances_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'checklist_instances',
        },
        () => {
          loadChecklistInstances();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [tasks]);


  const getCategoryCounts = (categoryId: string) => {
    const today = new Date();
    const categoryTasks = tasks.filter(
      (t) => t.category === categoryId && t.is_template !== true
    );
    const todayTasks = categoryTasks.filter(
      (t) => t.due_date && isSameDay(t.due_date, today)
    );
    const openTasks = todayTasks.filter((t) => t.status !== 'completed' && t.status !== 'archived');

    return {
      totalTasks: todayTasks.length,
      openTasks: openTasks.length,
      totalChecklists: 0,
      openChecklists: 0,
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

  const handleCategoryChange = (category: string) => {
    setFormData((prev) => ({
      ...prev,
      category,
      title: category === 'room_cleaning' || category === 'small_cleaning' ? '' : prev.title,
      points_value: getDefaultPointsForCategory(category),
    }));
  };

  const uploadPhoto = async (file: File, folder: string): Promise<string> => {
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
  };

  const getRandomMotivationalMessage = () => {
    return MOTIVATIONAL_MESSAGES[Math.floor(Math.random() * MOTIVATIONAL_MESSAGES.length)];
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const dueDateTime = isRepairCategory ? null : combineDateAndTime(formData.due_date, formData.due_time);

      let descriptionPhotoUrl: string[] | null = null;

      if (formData.description_photo && formData.description_photo.length > 0) {
        const uploadedUrls: string[] = [];
        for (const file of formData.description_photo) {
          const fileExt = file.name.split('.').pop();
          const fileName = `description_${Math.random().toString(36).substring(2)}_${Date.now()}.${fileExt}`;
          const filePath = `${fileName}`;

          const { error: uploadError } = await supabase.storage
            .from('checklist-explanations')
            .upload(filePath, file);

          if (uploadError) throw uploadError;

          const { data: urlData } = supabase.storage
            .from('checklist-explanations')
            .getPublicUrl(filePath);

          uploadedUrls.push(urlData.publicUrl);
        }
        descriptionPhotoUrl = uploadedUrls;
      }

      if (editingTask) {
        await updateTask(editingTask.id, {
          category: formData.category,
          title: formData.title,
          description: formData.description || null,
          description_photo: descriptionPhotoUrl || editingTask.description_photo,
          due_date: dueDateTime,
          duration_minutes: formData.duration_minutes,
          points_value: isRepairCategory ? 0 : formData.points_value,
          assigned_to: isRepairCategory ? null : (formData.assigned_to || null),
          secondary_assigned_to: isRepairCategory ? null : (formData.secondary_assigned_to || null),
          photo_proof_required: formData.photo_proof_required,
          photo_required_sometimes: formData.photo_required_sometimes,
          photo_explanation_text: formData.photo_explanation_text || null,
        });
      } else {
        await createTask({
          category: formData.category,
          title: formData.title,
          description: formData.description || null,
          description_photo: descriptionPhotoUrl,
          due_date: dueDateTime,
          duration_minutes: formData.duration_minutes,
          points_value: isRepairCategory ? 0 : formData.points_value,
          assigned_to: isRepairCategory ? null : (formData.assigned_to || null),
          secondary_assigned_to: isRepairCategory ? null : (formData.secondary_assigned_to || null),
          photo_proof_required: formData.photo_proof_required,
          photo_required_sometimes: formData.photo_required_sometimes,
          photo_explanation_text: formData.photo_explanation_text || null,
          created_by: profile?.id || '',
          status: 'pending',
        });
      }

      if (!editingTask) {
        const staffUsers = profiles.filter((p) => p.role === 'staff');
        if (staffUsers.length > 0) {
          await supabase.from('notifications').insert(
            staffUsers.map((p) => ({
              user_id: p.id,
              title: 'New Task',
              message: `New task created: ${formData.title}`,
              type: 'task',
            }))
          );
        }
      }

      setShowModal(false);
      setEditingTask(null);
      setFormData({
        category: 'extras',
        title: '',
        description: '',
        due_date: '',
        due_time: '',
        duration_minutes: 30,
        points_value: 10,
        assigned_to: '',
        secondary_assigned_to: '',
        description_photo: [],
        photo_proof_required: false,
        photo_required_sometimes: false,
        photo_explanation_text: '',
      });
    } catch (error) {
      console.error('Error creating task:', error);
    }
  };

  const handleAcceptTask = async (taskId: string) => {
    try {
      console.log('Accepting task:', taskId, 'for user:', profile?.id);
      const result = await updateTask(taskId, {
        assigned_to: profile?.id,
        status: 'in_progress',
      });
      console.log('Task accepted successfully:', result);
    } catch (error) {
      console.error('Error accepting task:', error);
      alert(`Failed to accept task: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const handleCompleteTask = async () => {
    if (!selectedTask) return;

    if (hadHelper && !selectedHelper) {
      alert('Bitte wähle den Mitarbeiter aus, der geholfen hat.');
      return;
    }

    try {
      let photoProofUrl = null;
      if (completionPhoto) {
        photoProofUrl = await uploadPhoto(completionPhoto, 'proofs');
      }

      if (photoRequiredThisTime && !photoProofUrl) {
        alert('Foto ist diesmal erforderlich! Bitte lade ein Beweisfoto hoch.');
        return;
      }

      const updateData: any = {
        status: 'pending_review',
        completion_notes: completionNotes,
        photo_proof: photoProofUrl,
        completed_at: new Date().toISOString(),
      };

      if (hadHelper && selectedHelper) {
        updateData.secondary_assigned_to = selectedHelper;
      }

      await updateTask(selectedTask.id, updateData);

      const admins = profiles.filter((p) => p.role === 'admin');
      if (admins.length > 0) {
        await supabase.from('notifications').insert(
          admins.map((admin) => ({
            user_id: admin.id,
            title: 'Task Completed',
            message: `${profile?.full_name} completed: ${selectedTask.title}`,
            type: 'task',
          }))
        );
      }

      setShowCompleteModal(false);
      setSelectedTask(null);
      setCompletionNotes('');
      setCompletionPhoto(null);
      setHadHelper(false);
      setSelectedHelper(null);
    } catch (error) {
      console.error('Error completing task:', error);
    }
  };

  const handleApproveTask = async () => {
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
        admin_photo: adminPhotoUrls,
      });

      const { data, error } = await supabase.rpc('approve_task_with_points', {
        p_task_id: task.id,
        p_admin_id: profile?.id,
      });

      if (error) {
        console.error('Error approving task:', error);
        throw error;
      }

      setShowReviewModal(false);
      setSelectedTask(null);
      setAdminNotes('');
      setAdminPhoto([]);
    } catch (error) {
      console.error('Error approving task:', error);
      alert('Error approving task');
    }
  };

  const handleReopenTask = async () => {
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
        admin_photo: adminPhotoUrls,
      });

      const { data, error } = await supabase.rpc('reopen_task_with_penalty', {
        p_task_id: task.id,
        p_admin_id: profile?.id,
        p_admin_notes: adminNotes,
      });

      if (error) throw error;

      setShowReviewModal(false);
      setSelectedTask(null);
      setAdminNotes('');
      setAdminPhoto([]);
    } catch (error) {
      console.error('Error reopening task:', error);
      alert('Error reopening task');
    }
  };

  const handleApproveChecklist = async () => {
    if (!profile?.id || !selectedChecklistForReview) return;

    try {
      let adminPhotoUrl = null;
      if (checklistAdminPhoto) {
        adminPhotoUrl = await uploadPhoto(checklistAdminPhoto, 'admin-reviews');
      }

      const { data, error } = await supabase.rpc('approve_checklist_instance', {
        p_instance_id: selectedChecklistForReview.id,
        p_admin_id: profile.id,
        p_admin_photo: adminPhotoUrl,
      });

      if (error) throw error;

      const result = data as { success: boolean; error?: string };
      if (!result.success) {
        alert(result.error || 'Fehler beim Genehmigen');
        return;
      }

      setShowChecklistApproveModal(false);
      setSelectedChecklistForReview(null);
      setChecklistAdminPhoto(null);
      await loadChecklistInstances();
    } catch (error) {
      console.error('Error approving checklist:', error);
      alert('Fehler beim Genehmigen der Checklist');
    }
  };

  const handleRejectChecklist = async () => {
    if (!selectedChecklistForReview || !profile?.id) return;

    if (!checklistRejectionReason.trim()) {
      alert('Bitte gib einen Ablehnungsgrund an');
      return;
    }

    try {
      let adminPhotoUrl = null;
      if (checklistAdminPhoto) {
        adminPhotoUrl = await uploadPhoto(checklistAdminPhoto, 'admin-reviews');
      }

      const { data, error } = await supabase.rpc('reject_checklist_instance', {
        p_instance_id: selectedChecklistForReview.id,
        p_admin_id: profile.id,
        p_rejection_reason: checklistRejectionReason,
        p_admin_photo: adminPhotoUrl,
      });

      if (error) throw error;

      const result = data as { success: boolean; error?: string };
      if (!result.success) {
        alert(result.error || 'Fehler beim Ablehnen');
        return;
      }

      setShowChecklistReviewModal(false);
      setSelectedChecklistForReview(null);
      setChecklistRejectionReason('');
      setChecklistAdminPhoto(null);
      await fetchChecklistInstances();
    } catch (error) {
      console.error('Error rejecting checklist:', error);
      alert('Fehler beim Ablehnen der Checklist');
    }
  };

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
                    <span className="text-sm text-gray-600">Tasks Today</span>
                    <span className="text-lg font-bold text-gray-900">
                      {counts.openTasks}/{counts.totalTasks}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-gray-600">Checklists</span>
                    <span className="text-lg font-bold text-gray-900">
                      {counts.openChecklists}/{counts.totalChecklists}
                    </span>
                  </div>
                </div>
              </button>
            );
          })}
        </div>

        {showModal && (
          <TaskCreateModal
            formData={formData}
            setFormData={setFormData}
            profiles={profiles}
            onSubmit={handleSubmit}
            onClose={() => {
              setShowModal(false);
              setEditingTask(null);
            }}
            onCategoryChange={handleCategoryChange}
            isRepairCategory={isRepairCategory}
            isAdmin={isAdmin}
            editingTask={editingTask}
          />
        )}
      </div>
    );
  }

  let categoryTasks = selectedCategory === 'all_today'
    ? (() => {
        const today = getTodayDateString();
        return tasks.filter(t => {
          if (!t.due_date) return false;
          const taskDate = new Date(t.due_date).toISOString().split('T')[0];
          return taskDate === today && t.status !== 'archived';
        });
      })()
    : selectedCategory
    ? tasks.filter((t) => {
        if (t.status === 'archived') return false;
        if (t.status === 'completed') {
          const today = getTodayDateString();
          const taskDate = t.due_date ? new Date(t.due_date).toISOString().split('T')[0] : '';
          return taskDate === today && t.category === selectedCategory;
        }
        return t.category === selectedCategory;
      })
    : tasks.filter((t) => {
        if (t.status === 'archived') return false;
        if (t.status === 'completed') {
          const today = getTodayDateString();
          const taskDate = t.due_date ? new Date(t.due_date).toISOString().split('T')[0] : '';
          return taskDate === today;
        }
        return true;
      });

  if (filterStatus === 'pending_review') {
    categoryTasks = categoryTasks.filter((t) => t.status === 'pending_review');
  } else if (filterStatus === 'today') {
    const today = getTodayDateString();
    categoryTasks = categoryTasks.filter((t) => {
      if (!t.due_date) return false;
      const taskDate = new Date(t.due_date).toISOString().split('T')[0];
      return taskDate === today && t.status !== 'archived';
    });
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
              setFormData((prev) => ({ ...prev, category: selectedCategory }));
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
        {categoryTasks.length === 0 && categoryChecklistInstances.length === 0 && (
          <div className="text-center py-16 bg-white rounded-xl border border-beige-200">
            <CheckCircle className="w-16 h-16 text-beige-300 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-700 mb-2">Keine aktuellen ToDos</h3>
            <p className="text-gray-500 text-sm">Alle Aufgaben sind erledigt oder es wurden noch keine erstellt.</p>
          </div>
        )}

        {categoryTasks.map((task) => {
          const assignedUser = profiles.find((p) => p.id === task.assigned_to);
          const secondaryUser = profiles.find((p) => p.id === task.secondary_assigned_to);
          const taskIsRepair = task.category === 'repair';
          const canAccept = !task.assigned_to && task.status === 'pending' && !taskIsRepair;
          const isMyTask = task.assigned_to === profile?.id || task.secondary_assigned_to === profile?.id;

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
                  {isMyTask && (task.status === 'in_progress' || task.status === 'pending') && (
                    <button
                      onClick={() => {
                        if (task.photo_proof_required) {
                          setSelectedTask(task);
                          setPhotoRequiredThisTime(true);
                          setCompletionPhoto(null);
                          setCompletionNotes('');
                          setShowCompleteModal(true);
                        } else if (task.photo_required_sometimes) {
                          setPendingTaskCompletion(task);
                          setShowDiceModal(true);
                        } else {
                          setSelectedTask(task);
                          setPhotoRequiredThisTime(false);
                          setCompletionPhoto(null);
                          setCompletionNotes('');
                          setShowCompleteModal(true);
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
                        });
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

        {categoryChecklistInstances.map((instance: any) => {
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
                if (!isCompleted || isRejected) {
                  setSelectedChecklist(instance);
                  setChecklistItems(instance.items || []);
                  setChecklistPhotoRequired(false);
                  setChecklistPhoto(null);
                  setShowChecklistModal(true);
                }
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
                        setSelectedChecklistForReview(instance);
                        setShowChecklistApproveModal(true);
                      }}
                      className="p-2 text-green-600 hover:bg-green-50 rounded-lg border border-green-300"
                      title="Genehmigen"
                    >
                      <CheckCircle className="w-5 h-5" />
                    </button>
                    <button
                      onClick={() => {
                        setSelectedChecklistForReview(instance);
                        setShowChecklistReviewModal(true);
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
          formData={formData}
          setFormData={setFormData}
          profiles={profiles}
          onSubmit={handleSubmit}
          onClose={() => setShowModal(false)}
          onCategoryChange={handleCategoryChange}
          isRepairCategory={isRepairCategory}
          isAdmin={isAdmin}
        />
      )}

      {showCompleteModal && selectedTask && (
        <TaskCompletionModal
          task={selectedTask}
          items={selectedTask.items || []}
          onClose={() => {
            setShowCompleteModal(false);
            setSelectedTask(null);
          }}
          onComplete={async () => {
            await tasks;
            setShowCompleteModal(false);
            setSelectedTask(null);
          }}
          profiles={profiles}
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
                    ✓ {adminPhoto.length} Foto(s) ausgewählt
                  </p>
                )}
              </div>
              <div className="flex flex-col space-y-2 pt-4">
                <button
                  onClick={handleApproveTask}
                  className="w-full px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 flex items-center justify-center space-x-2"
                >
                  <CheckCircle className="w-5 h-5" />
                  <span>Very Good - Approve</span>
                </button>
                <button
                  onClick={handleReopenTask}
                  className="w-full px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 flex items-center justify-center space-x-2"
                >
                  <RefreshCw className="w-5 h-5" />
                  <span>Not Perfect - Reopen</span>
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

      {showChecklistModal && selectedChecklist && (
        <ChecklistCompletionModal
          checklist={selectedChecklist}
          checklistItems={checklistItems}
          setChecklistItems={setChecklistItems}
          photoRequired={checklistPhotoRequired}
          setPhotoRequired={setChecklistPhotoRequired}
          photo={checklistPhoto}
          setPhoto={setChecklistPhoto}
          onClose={() => {
            setShowChecklistModal(false);
            setSelectedChecklist(null);
            setChecklistItems([]);
            setChecklistPhotoRequired(false);
            setChecklistPhoto(null);
          }}
          onComplete={async () => {
            await loadChecklistInstances();
          }}
        />
      )}

      {showDiceModal && pendingTaskCompletion && (
        <PhotoRequirementDice
          onResult={(requiresPhoto) => {
            setShowDiceModal(false);
            setSelectedTask(pendingTaskCompletion);
            setPhotoRequiredThisTime(requiresPhoto);
            setCompletionPhoto(null);
            setCompletionNotes('');
            setShowCompleteModal(true);
            setPendingTaskCompletion(null);
          }}
          onCancel={() => {
            setShowDiceModal(false);
            setPendingTaskCompletion(null);
          }}
        />
      )}

      {showChecklistApproveModal && selectedChecklistForReview && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowChecklistApproveModal(false);
            setSelectedChecklistForReview(null);
            setChecklistAdminPhoto(null);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">Checklist Genehmigen</h3>
            <div className="space-y-4">
              <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                <p className="text-sm text-gray-700">
                  <strong>{selectedChecklistForReview.checklists?.title}</strong>
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  Von: {profiles.find(p => p.id === selectedChecklistForReview.completed_by)?.full_name}
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Admin Foto (optional)
                </label>
                <input
                  type="file"
                  accept="image/*"
                  capture="environment"
                  onChange={(e) => setChecklistAdminPhoto(e.target.files?.[0] || null)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
                {checklistAdminPhoto && (
                  <p className="text-sm text-green-600 mt-1">✓ Foto ausgewählt: {checklistAdminPhoto.name}</p>
                )}
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  onClick={() => {
                    setShowChecklistApproveModal(false);
                    setSelectedChecklistForReview(null);
                    setChecklistAdminPhoto(null);
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Abbrechen
                </button>
                <button
                  onClick={handleApproveChecklist}
                  className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                >
                  Genehmigen
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showChecklistReviewModal && selectedChecklistForReview && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowChecklistReviewModal(false);
            setSelectedChecklistForReview(null);
            setChecklistRejectionReason('');
            setChecklistAdminPhoto(null);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">Checklist Ablehnen</h3>
            <div className="space-y-4">
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <p className="text-sm text-gray-700">
                  <strong>{selectedChecklistForReview.checklists?.title}</strong>
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  Von: {profiles.find(p => p.id === selectedChecklistForReview.completed_by)?.full_name}
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Ablehnungsgrund *
                </label>
                <textarea
                  value={checklistRejectionReason}
                  onChange={(e) => setChecklistRejectionReason(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={3}
                  placeholder="Warum wird diese Checklist abgelehnt?"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Admin Foto (optional)
                </label>
                <input
                  type="file"
                  accept="image/*"
                  capture="environment"
                  onChange={(e) => setChecklistAdminPhoto(e.target.files?.[0] || null)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
                {checklistAdminPhoto && (
                  <p className="text-sm text-green-600 mt-1">✓ Foto ausgewählt: {checklistAdminPhoto.name}</p>
                )}
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  onClick={() => {
                    setShowChecklistReviewModal(false);
                    setSelectedChecklistForReview(null);
                    setChecklistRejectionReason('');
                    setChecklistAdminPhoto(null);
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Abbrechen
                </button>
                <button
                  onClick={handleRejectChecklist}
                  className="flex-1 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
                >
                  Ablehnen
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function ChecklistCompletionModal({ checklist, checklistItems, setChecklistItems, photoRequired, setPhotoRequired, photo, setPhoto, onClose, onComplete }: any) {
  const { profile } = useAuth();
  const [showDice, setShowDice] = useState(false);
  const [pendingItems, setPendingItems] = useState<any[]>([]);

  const autoSaveProgress = async (items: any[]) => {
    try {
      await supabase
        .from('checklist_instances')
        .update({
          items: items,
          updated_at: new Date().toISOString(),
        })
        .eq('id', checklist.id);
    } catch (error) {
      console.error('Error auto-saving checklist progress:', error);
    }
  };

  const handleToggleItem = (index: number) => {
    const newItems = [...checklistItems];
    const isNowCompleted = !(newItems[index].completed || newItems[index].is_completed);
    newItems[index] = {
      ...newItems[index],
      completed: isNowCompleted,
      is_completed: isNowCompleted,
      completed_by: isNowCompleted ? profile?.full_name : null,
      completed_by_id: isNowCompleted ? profile?.id : null
    };
    setChecklistItems(newItems);

    autoSaveProgress(newItems);

    const allCompleted = newItems.every((item: any) => item.completed || item.is_completed);
    if (allCompleted) {
      if (checklist.checklists?.photo_required && !photoRequired) {
        // Foto VERPFLICHTEND - direkt setzen, kein Würfel
        setPhotoRequired(true);
      } else if (checklist.checklists?.photo_required_sometimes && !photoRequired && !showDice) {
        // Foto MANCHMAL - Würfel zeigen
        setPendingItems(newItems);
        setShowDice(true);
      } else if (!checklist.checklists?.photo_required && !checklist.checklists?.photo_required_sometimes) {
        // Kein Foto erforderlich - direkt abschließen
        handleComplete(newItems, null);
      }
    }
  };

  const uploadPhoto = async (file: File): Promise<string> => {
    const fileExt = file.name.split('.').pop();
    const fileName = `${Math.random()}.${fileExt}`;
    const filePath = `checklist-proofs/${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from('task-photos')
      .upload(filePath, file);

    if (uploadError) throw uploadError;

    const { data } = supabase.storage.from('task-photos').getPublicUrl(filePath);
    return data.publicUrl;
  };

  const handleComplete = async (items: any[], photoUrl: string | null) => {
    try {
      const { error } = await supabase
        .from('checklist_instances')
        .update({
          items: items,
          status: 'completed',
          photo_proof: photoUrl,
          photo_required_for_completion: photoRequired,
          admin_reviewed: false,
          admin_approved: null,
          admin_rejection_reason: null,
          admin_photo: null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', checklist.id);

      if (error) throw error;

      await onComplete();
      onClose();
    } catch (error) {
      console.error('Error completing checklist:', error);
      alert('Fehler beim Abschließen der Checkliste');
    }
  };

  const handleSubmit = async () => {
    if (photoRequired && !photo) {
      alert('Foto ist erforderlich!');
      return;
    }

    let photoUrl = null;
    if (photo) {
      photoUrl = await uploadPhoto(photo);
    }

    await handleComplete(checklistItems, photoUrl);
  };

  const allCompleted = checklistItems.every((item: any) => item.completed || item.is_completed);
  const completedCount = checklistItems.filter((item: any) => item.completed || item.is_completed).length;

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-2xl font-bold text-gray-900 mb-2">{checklist.checklists?.title}</h3>
        <p className="text-sm text-gray-600 mb-4">
          Fortschritt: {completedCount}/{checklistItems.length} erledigt
        </p>

        {checklist.checklists?.description_photo && (
          <div className="mb-4 bg-gray-50 border border-gray-200 rounded-lg p-3">
            <p className="text-xs font-medium text-gray-900 mb-2">Erklärungs-Foto:</p>
            <img
              src={checklist.checklists.description_photo}
              alt="Erklärung"
              className="rounded-lg max-w-full h-auto max-h-64 object-cover border border-gray-300"
            />
          </div>
        )}

        <div className="space-y-3 mb-6">
          {checklistItems.map((item: any, index: number) => (
            <div
              key={index}
              className={`flex items-start space-x-3 p-4 rounded-lg border-2 transition-all cursor-pointer ${
                (item.completed || item.is_completed)
                  ? 'bg-green-50 border-green-300'
                  : 'bg-gray-50 border-gray-200 hover:border-purple-300'
              }`}
              onClick={() => handleToggleItem(index)}
            >
              <input
                type="checkbox"
                checked={item.completed || item.is_completed}
                onChange={() => {}}
                className="w-5 h-5 mt-0.5 text-purple-600 rounded"
              />
              <span className={`flex-1 ${(item.completed || item.is_completed) ? 'text-gray-500 line-through' : 'text-gray-900'}`}>
                {item.text}
              </span>
            </div>
          ))}
        </div>

        {photoRequired && (
          <div className="bg-yellow-50 border-l-4 border-yellow-400 rounded-lg p-4 mb-4">
            <div className="flex items-start">
              <span className="text-2xl mr-3">📸</span>
              <div className="flex-1">
                <h4 className="font-bold text-yellow-900 mb-2">Foto erforderlich!</h4>
                {checklist.checklists?.photo_explanation_text ? (
                  <div className="bg-white border border-yellow-200 rounded p-3 mb-3">
                    <p className="text-xs font-semibold text-yellow-900 mb-1">📋 Foto-Anweisung:</p>
                    <p className="text-sm text-yellow-800 whitespace-pre-wrap">
                      {checklist.checklists.photo_explanation_text}
                    </p>
                  </div>
                ) : (
                  <p className="text-sm text-yellow-800 mb-3">
                    Bitte mache ein Foto als Beweis für die Fertigstellung.
                  </p>
                )}
              </div>
            </div>
            <label className="block text-sm font-medium text-yellow-900 mb-2">
              Beweisfoto hochladen *
            </label>
            <input
              type="file"
              accept="image/*"
              capture="environment"
              onChange={(e) => setPhoto(e.target.files?.[0] || null)}
              className="w-full px-3 py-2 border-2 border-yellow-400 bg-yellow-50 rounded-lg"
              required
            />
            {photo && (
              <p className="text-sm text-green-600 mt-2">✓ Foto ausgewählt: {photo.name}</p>
            )}
          </div>
        )}

        <div className="flex space-x-3">
          <button
            onClick={onClose}
            className="flex-1 px-4 py-3 border border-gray-300 rounded-lg hover:bg-gray-50 font-medium"
          >
            Abbrechen
          </button>
          <button
            onClick={handleSubmit}
            disabled={!allCompleted || (photoRequired && !photo)}
            className={`flex-1 px-4 py-3 rounded-lg font-medium ${
              (allCompleted && (!photoRequired || photo))
                ? 'bg-purple-600 text-white hover:bg-purple-700'
                : 'bg-gray-300 text-gray-500 cursor-not-allowed'
            }`}
          >
            {!allCompleted ? `Noch ${checklistItems.length - completedCount} Items` :
             (photoRequired && !photo) ? 'Foto erforderlich!' : 'Abschließen'}
          </button>
        </div>

        {showDice && (
          <PhotoRequirementDice
            onResult={(requiresPhoto) => {
              setShowDice(false);
              if (requiresPhoto) {
                setPhotoRequired(true);
              } else {
                handleComplete(pendingItems, null);
              }
            }}
            onCancel={() => {
              setShowDice(false);
              setPendingItems([]);
            }}
          />
        )}
      </div>
    </div>
  );
}

function TaskCreateModal({ formData, setFormData, profiles, onSubmit, onClose, onCategoryChange, isRepairCategory, isAdmin, editingTask }: any) {
  const isRoomBased = formData.category === 'room_cleaning' || formData.category === 'small_cleaning';

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-50 flex items-start justify-center p-4 z-50 overflow-y-auto"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-xl p-6 w-full max-w-2xl my-8"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-xl font-bold text-gray-900 mb-4">
          {editingTask ? 'Edit Task' : isRepairCategory ? 'Report Repair/Need new' : 'Create New Task'}
        </h3>
        <form onSubmit={onSubmit} className="space-y-4">
          {isAdmin && !isRepairCategory && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Category</label>
              <select
                value={formData.category}
                onChange={(e) => onCategoryChange(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                required
              >
                {CATEGORIES.map((cat) => (
                  <option key={cat.id} value={cat.id}>
                    {cat.label}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              {isRoomBased ? 'Room' : 'Title'}
            </label>
            {isRoomBased ? (
              <select
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                required
              >
                <option value="">Select room</option>
                {ROOM_NAMES.map((room) => (
                  <option key={room} value={room}>
                    {room}
                  </option>
                ))}
              </select>
            ) : (
              <input
                type="text"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                required
              />
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg"
              rows={3}
            />
          </div>

          {!isRepairCategory && (
            <>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Due Date</label>
                  <input
                    type="date"
                    value={formData.due_date}
                    onChange={(e) => setFormData({ ...formData, due_date: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Due Time</label>
                  <input
                    type="time"
                    value={formData.due_time}
                    onChange={(e) => setFormData({ ...formData, due_time: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Duration (minutes)</label>
                  <input
                    type="number"
                    value={formData.duration_minutes}
                    onChange={(e) => setFormData({ ...formData, duration_minutes: parseInt(e.target.value) })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    min="1"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Points</label>
                  <input
                    type="number"
                    value={formData.points_value}
                    onChange={(e) => setFormData({ ...formData, points_value: parseInt(e.target.value) })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                    min="0"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Assign to Staff</label>
                  <select
                    value={formData.assigned_to}
                    onChange={(e) => setFormData({ ...formData, assigned_to: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  >
                    <option value="">Optional</option>
                    {profiles.filter((p: any) => p.role === 'staff').map((p: any) => (
                      <option key={p.id} value={p.id}>
                        {p.full_name}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Assign to 2nd Staff</label>
                  <select
                    value={formData.secondary_assigned_to}
                    onChange={(e) => setFormData({ ...formData, secondary_assigned_to: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  >
                    <option value="">Optional</option>
                    {profiles.filter((p: any) => p.role === 'staff' && p.id !== formData.assigned_to).map((p: any) => (
                      <option key={p.id} value={p.id}>
                        {p.full_name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="border border-gray-300 rounded-lg p-4 space-y-4">
                <h4 className="font-semibold text-gray-900">Foto-Optionen</h4>

                <div className="space-y-3">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      1. Erklärungs-Foto hochladen (optional)
                    </label>
                    <p className="text-xs text-gray-600 mb-2">
                      Upload eines Fotos zur Erklärung/Veranschaulichung der Aufgabe
                    </p>
                    <input
                      type="file"
                      accept="image/*"
                      multiple
                      onChange={(e) => {
                        const files = Array.from(e.target.files || []);
                        setFormData({ ...formData, description_photo: files });
                      }}
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                    />
                    {formData.description_photo && formData.description_photo.length > 0 && (
                      <p className="text-xs text-green-600 mt-1">
                        ✓ {formData.description_photo.length} Foto(s) ausgewählt
                      </p>
                    )}
                  </div>

                  <div className="bg-red-50 border border-red-200 rounded-lg p-3">
                    <div className="flex items-center space-x-2 mb-2">
                      <input
                        type="checkbox"
                        id="photo_required"
                        checked={formData.photo_proof_required}
                        onChange={(e) => setFormData({ ...formData, photo_proof_required: e.target.checked })}
                        className="w-4 h-4 text-red-600 rounded"
                      />
                      <label htmlFor="photo_required" className="text-sm font-bold text-red-900">
                        2. Foto VERPFLICHTEND bei Fertigmeldung
                      </label>
                    </div>
                    <p className="text-xs text-red-700 ml-6">
                      Staff muss zwingend ein Foto hochladen. Keine Vorabinfo an Staff!
                    </p>
                  </div>

                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                    <div className="flex items-center space-x-2 mb-2">
                      <input
                        type="checkbox"
                        id="photo_sometimes"
                        checked={formData.photo_required_sometimes}
                        onChange={(e) => setFormData({ ...formData, photo_required_sometimes: e.target.checked })}
                        className="w-4 h-4 text-blue-600 rounded"
                      />
                      <label htmlFor="photo_sometimes" className="text-sm font-bold text-blue-900">
                        3. Foto MANCHMAL erforderlich (30% Chance - Würfel)
                      </label>
                    </div>
                    <p className="text-xs text-blue-700 ml-6">
                      Bei Fertigmeldung wird gewürfelt ob Foto nötig ist. Keine Vorabinfo an Staff!
                    </p>
                  </div>

                  {(formData.photo_proof_required || formData.photo_required_sometimes) && (
                    <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3 ml-6">
                      <label className="block text-sm font-medium text-yellow-900 mb-2">
                        Foto-Anweisung für Staff (optional)
                      </label>
                      <p className="text-xs text-yellow-700 mb-2">
                        Beschreibe, WO/WAS fotografiert werden soll. Diese Anweisung wird Staff angezeigt wenn Foto erforderlich ist.
                      </p>
                      <textarea
                        value={formData.photo_explanation_text}
                        onChange={(e) => setFormData({ ...formData, photo_explanation_text: e.target.value })}
                        placeholder="z.B. 'Foto vom Poolbereich nach der Reinigung, von der Eingangstür aus gesehen' oder 'Nahaufnahme der gereinigten Toilette'"
                        rows={3}
                        className="w-full px-3 py-2 border border-yellow-300 rounded-lg text-sm focus:ring-2 focus:ring-yellow-400 focus:border-yellow-400"
                      />
                      {formData.photo_explanation_text && (
                        <p className="text-xs text-green-600 mt-1">
                          ✓ Anweisung: {formData.photo_explanation_text.slice(0, 50)}{formData.photo_explanation_text.length > 50 ? '...' : ''}
                        </p>
                      )}
                    </div>
                  )}

                  <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
                    <p className="text-sm font-medium text-gray-900 mb-1">
                      4. Staff kann optional Foto hochladen
                    </p>
                    <p className="text-xs text-gray-600">
                      Staff kann immer freiwillig ein Foto hochladen (automatisch möglich)
                    </p>
                  </div>
                </div>
              </div>
            </>
          )}

          <div className="flex space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancel
            </button>
            <button type="submit" className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              Create Task
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
