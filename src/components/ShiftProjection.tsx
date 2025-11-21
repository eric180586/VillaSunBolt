import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import { Clock } from 'lucide-react';

export function ShiftProjection() {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { tasks } = useTasks();
  const [projectedEndTime, setProjectedEndTime] = useState<string>('');
  const [message, setMessage] = useState<string>('');

  useEffect(() => {
    const calculateProjection = async () => {
      const todayDateString = getTodayDateString();

      // Hole alle GEPLANTEN Mitarbeiter aus weekly_schedules für heute
      const { data: weeklySchedules, error: scheduleError } = await supabase
        .from('weekly_schedules')
        .select('staff_id, shifts');

      if (scheduleError) {
        console.error('Error fetching schedules:', scheduleError);
        return;
      }

      // Zähle Mitarbeiter die heute eingeplant sind (early oder late)
      let scheduledCountEarly = 0;
      let scheduledCountLate = 0;
      let userIsScheduled = false;
      let userShiftType: 'morning' | 'late' | null = null;

      weeklySchedules?.forEach((schedule) => {
        const shiftsArray = schedule.shifts as Array<{ date: string; shift: string }>;
        const todayShift = shiftsArray.find((s) => s.date === todayDateString);

        if (todayShift && (todayShift.shift === 'morning' || todayShift.shift === 'late')) {
          if (todayShift.shift === 'morning') {
            scheduledCountEarly++;
          } else {
            scheduledCountLate++;
          }

          if (schedule.staff_id === profile?.id) {
            userIsScheduled = true;
            userShiftType = todayShift.shift as 'morning' | 'late';
          }
        }
      }) as any;

      if (!userIsScheduled) {
        setMessage('You are not scheduled today');
        return;
      }

      // Use the count for the user's shift type
      const scheduledCount = userShiftType === 'morning' ? scheduledCountEarly : scheduledCountLate;

      // Hole alle offenen Tasks von heute (due today, not just created today)
      const todayTasks = tasks.filter((t) => {
        if (t.status === 'completed' || t.status === 'cancelled' || t.status === 'archived') return false;
        if (!t.due_date) return false;

        // Compare due_date (YYYY-MM-DD)
        const taskDueDate = new Date(t.due_date).toISOString().split('T')[0];
        return taskDueDate === todayDateString;
      }) as any;

      // Berechne estimated time für aktuellen User
      let minutesForCurrentUser = 0;

      todayTasks.forEach((task) => {
        const duration = task.duration_minutes || 0;

        // Skip tasks that are for the opposite shift
        const taskTitle = (task.title || '').toLowerCase();
        const isLateShiftTask = taskTitle.includes('late') || taskTitle.includes('spät');
        const isEarlyShiftTask = taskTitle.includes('morning') || taskTitle.includes('früh');

        if (userShiftType === 'morning' && isLateShiftTask && !task.assigned_to && !task.helper_id) {
          // Skip late shift tasks for early shift staff (unless assigned)
          return;
        }
        if (userShiftType === 'late' && isEarlyShiftTask && !task.assigned_to && !task.helper_id) {
          // Skip early shift tasks for late shift staff (unless assigned)
          return;
        }

        if (task.assigned_to === profile?.id) {
          // Task ist mir zugewiesen
          minutesForCurrentUser += duration;
        } else if (task.helper_id === profile?.id) {
          // Ich bin Helper (geteilte Arbeit)
          minutesForCurrentUser += duration / 2;
        } else if (!task.assigned_to && !task.helper_id) {
          // Unassigned task - wird durch alle GEPLANTEN Mitarbeiter geteilt
          minutesForCurrentUser += scheduledCount > 0 ? duration / scheduledCount : duration;
        }
        // Else: Task ist jemand anderem zugewiesen, zählt nicht für mich
      }) as any;

      // Add 2 hours base time for regular work
      const BASE_WORK_MINUTES = 120;
      const minutesPerPerson = minutesForCurrentUser + BASE_WORK_MINUTES;

      // Formatiere die Zeit
      const totalHours = Math.floor(minutesPerPerson / 60);
      const remainingMinutes = Math.round(minutesPerPerson % 60);
      const taskCount = todayTasks.length;

      if (taskCount === 0) {
        setMessage(`Estimated time for the daily ToDos: 2h (base work time)`);
        setProjectedEndTime('');
      } else {
        // Zeige die geschätzte Zeit pro Person
        if (totalHours === 0 && remainingMinutes > 0) {
          setMessage(`Estimated time for the daily ToDos: ${remainingMinutes} minutes`);
        } else if (totalHours > 0 && remainingMinutes === 0) {
          setMessage(`Estimated time for the daily ToDos: ${totalHours}h`);
        } else if (totalHours > 0 && remainingMinutes > 0) {
          setMessage(`Estimated time for the daily ToDos: ${totalHours}h ${remainingMinutes}m`);
        } else {
          setMessage('Estimated time for the daily ToDos: 2h (base work time)');
        }
        setProjectedEndTime('');
      }
    };

    if (profile?.id) {
      calculateProjection();
    }
  }, [profile, tasks]);

  if (!message) return null;

  return (
    <div className="bg-gradient-to-r from-blue-500 to-blue-600 rounded-xl p-6 text-white shadow-lg">
      <div className="flex items-start space-x-3">
        <Clock className="w-6 h-6 flex-shrink-0 mt-1" />
        <div className="flex-1">
          <h3 className="text-xl font-bold mb-2">{message}</h3>
          {projectedEndTime && (
            <p className="text-blue-100 text-sm">
              Based on remaining tasks and scheduled staff
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
