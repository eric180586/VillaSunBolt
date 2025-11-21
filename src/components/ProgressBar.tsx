import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { useHumorModules } from '../hooks/useHumorModules';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import { Clock, MessageCircle, Sparkles, Smartphone, Home } from 'lucide-react';

const iconMap = {
  Clock,
  MessageCircle,
  Sparkles,
  Smartphone,
  Home,
};

const colorMap = {
  pink: { bg: 'bg-pink-50', text: 'text-pink-600' },
  blue: { bg: 'bg-blue-50', text: 'text-blue-600' },
  purple: { bg: 'bg-purple-50', text: 'text-purple-600' },
  green: { bg: 'bg-green-50', text: 'text-green-600' },
  orange: { bg: 'bg-orange-50', text: 'text-orange-600' },
};

interface WeeklySchedule {
  id: string;
  staff_id: string;
  week_start_date: string;
  shifts: Array<{
    day: string;
    date: string;
    shift: 'morning' | 'late' | 'off';
  }>;
  is_published: boolean;
}

const formatMinutesToTime = (totalMinutes: number): string => {
  const hours = Math.floor(totalMinutes / 60);
  const minutes = Math.round(totalMinutes % 60);
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
};

export function ProgressBar() {
  const { t: _t } = useTranslation();
  const { profile } = useAuth();
  const { tasks } = useTasks();
  const { activeModules } = useHumorModules();
  const [displayTime, setDisplayTime] = useState('--:--');
  const [totalMinutes, setTotalMinutes] = useState(0);
  const [homeTime, setHomeTime] = useState('');

  useEffect(() => {
    const calculateTime = async () => {
      if (!profile?.id) return;

      const todayStr = getTodayDateString();

      // Get scheduled staff from weekly_schedules
      const { data: weeklySchedules, error: scheduleError } = await supabase
        .from('weekly_schedules')
        .select('staff_id, shifts');

      if (scheduleError) {
        console.error('Error fetching schedules:', scheduleError);
        setDisplayTime('--:--');
        setTotalMinutes(0);
        setHomeTime('');
        return;
      }

      // Count scheduled staff for today and determine user's shift
      let scheduledCountEarly = 0;
      let scheduledCountLate = 0;
      let userIsScheduled = false;
      let userShiftType: 'morning' | 'late' | null = null;

      weeklySchedules?.forEach((schedule: any) => {
        const shiftsArray = schedule.shifts as Array<{ date: string; shift: string }>;
        const todayShift = shiftsArray.find((s: any) => s.date === todayStr);

        if (todayShift && (todayShift.shift === 'morning' || todayShift.shift === 'late')) {
          if (todayShift.shift === 'morning') {
            scheduledCountEarly++;
          } else {
            scheduledCountLate++;
          }

          if (schedule.staff_id === profile.id) {
            userIsScheduled = true;
            userShiftType = todayShift.shift as 'morning' | 'late';
          }
        }
      }) as any;

      if (!userIsScheduled) {
        setDisplayTime('--:--');
        setTotalMinutes(0);
        setHomeTime('');
        return;
      }

      const scheduledCount = userShiftType === 'morning' ? scheduledCountEarly : scheduledCountLate;

      const todayTasks = tasks.filter((t) => {
        if (!t.due_date) return false;
        if (t.status === 'completed' || t.status === 'archived') return false;
        // Compare just the date part (YYYY-MM-DD)
        const taskDueDate = new Date(t.due_date).toISOString().split('T')[0];
        return taskDueDate === todayStr;
      }) as any;

      // Calculate minutes for current user based on their shift
      let minutesForCurrentUser = 0;

      todayTasks.forEach((task: any) => {
        const duration = task.duration_minutes || 30;

        // Skip tasks that are for the opposite shift
        const taskTitle = (task.title || '').toLowerCase();
        const isLateShiftTask = taskTitle.includes('late') || taskTitle.includes('spät');
        const isEarlyShiftTask = taskTitle.includes('morning') || taskTitle.includes('früh');

        if (userShiftType === 'morning' && isLateShiftTask && !task.assigned_to && !task.helper_id) {
          return; // Skip late shift tasks for early shift staff
        }
        if (userShiftType === 'late' && isEarlyShiftTask && !task.assigned_to && !task.helper_id) {
          return; // Skip early shift tasks for late shift staff
        }

        if (task.assigned_to === profile.id) {
          minutesForCurrentUser += duration;
        } else if (task.helper_id === profile.id) {
          minutesForCurrentUser += duration / 2;
        } else if (!task.assigned_to && !task.helper_id) {
          minutesForCurrentUser += scheduledCount > 0 ? duration / scheduledCount : duration;
        }
      }) as any;

      const totalWithBuffer = minutesForCurrentUser + 120;

      setTotalMinutes(totalWithBuffer);
      const timeStr = formatMinutesToTime(totalWithBuffer);
      setDisplayTime(timeStr);

      // Find user's shift for today directly from the schedule data we already have
      const currentUserSchedule = weeklySchedules?.find((s: any) => s.staff_id === profile.id);
      if (!currentUserSchedule) {
        setHomeTime('');
        return;
      }

      const todayShift = (currentUserSchedule as WeeklySchedule).shifts.find(
        (shift) => shift.date === todayStr
      );

      // Only show "go home at" for early shift
      if (todayShift && todayShift.shift === 'morning') {
        const shiftStartTime = { hours: 10, minutes: 0 };

        const baseTime = new Date();
        baseTime.setHours(shiftStartTime.hours, shiftStartTime.minutes, 0, 0);
        baseTime.setMinutes(baseTime.getMinutes() + totalWithBuffer);

        const homeHours = baseTime.getHours().toString().padStart(2, '0');
        const homeMinutes = baseTime.getMinutes().toString().padStart(2, '0');
        setHomeTime(`${homeHours}:${homeMinutes}`);
      } else {
        setHomeTime('');
      }
    };

    calculateTime();
  }, [profile, tasks]);

  return (
    <div className="bg-gradient-to-br from-white to-gray-50 rounded-xl p-6 shadow-lg border border-gray-200">
      <div className="space-y-6">
        <div className="text-center">
          <div className="flex items-center justify-center space-x-2 mb-2">
            <Clock className="w-6 h-6 text-blue-500" />
            <h3 className="text-sm font-medium text-gray-600">Estimated time for the daily ToDos</h3>
          </div>
          <div className="text-6xl font-bold text-blue-600 mb-1">
            {displayTime}
          </div>
          <p className="text-2xl font-semibold text-gray-700">Hours</p>
        </div>

        {homeTime && (
          <div className="bg-green-50 p-4 rounded-lg text-center">
            <div className="flex items-center justify-center space-x-2 mb-1">
              <Home className="w-5 h-5 text-green-600" />
              <p className="text-sm font-medium text-gray-700">So could already go home at</p>
            </div>
            <p className="text-3xl font-bold text-green-600">{homeTime}</p>
          </div>
        )}

        {activeModules.length > 0 && (
          <div className="border-t border-gray-200 pt-4 space-y-3">
            {activeModules.map((module) => {
              const Icon = iconMap[module.icon_name as keyof typeof iconMap] || Clock;
              const colors = colorMap[module.color_class as keyof typeof colorMap] || colorMap.pink;
              const moduleMinutes = (totalMinutes * module.percentage) / 100;
              const moduleTime = formatMinutesToTime(moduleMinutes);

              return (
                <div key={module.id} className={`flex items-center justify-between ${colors.bg} p-3 rounded-lg`}>
                  <div className="flex items-center space-x-2">
                    <Icon className={`w-5 h-5 ${colors.text}`} />
                    <span className="text-sm font-medium text-gray-700">{module.label}</span>
                  </div>
                  <span className={`text-lg font-bold ${colors.text}`}>{moduleTime}</span>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
