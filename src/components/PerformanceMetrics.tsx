import { useAuth } from '../contexts/AuthContext';
import { useTranslation } from 'react-i18next';
import { useTasks } from '../hooks/useTasks';
import { useSchedules } from '../hooks/useSchedules';
import { useProfiles } from '../hooks/useProfiles';
import { useDailyPointGoals, useMonthlyProgress } from '../hooks/useDailyPointGoals';
import { CheckSquare, Award, TrendingUp, Users } from 'lucide-react';
import { LucideIcon } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import { getTodayMyTasks } from '../lib/taskFilters';
import { useState, useEffect } from 'react';

interface MetricCardProps {
  title: string;
  value: string;
  total: string;
  percentage: number;
  icon: LucideIcon;
  colorStatus?: 'red' | 'yellow' | 'orange' | 'green' | 'dark_green' | 'gray';
  showProgressBar?: boolean;
  unit?: 'tasks' | 'points';
  estimatedTime?: number;
  onClick?: () => void;
  checklistValue?: string;
  checklistTotal?: string;
}

function MetricCard({ title, value, total, percentage, icon: Icon, colorStatus, showProgressBar = false, unit = 'points', estimatedTime, onClick, checklistValue, checklistTotal }: MetricCardProps) {
  const displayValue = total === '0' && value === '0' ? '0/0' : total === '-' ? value : `${value}/${total}`;
  const displayPercentage = total === '0' || total === '-' ? '' : `${percentage.toFixed(0)}%`;

  const unitText = unit === 'tasks' ? 'Aufgaben' : 'Punkten';
  const achievedText = unit === 'tasks' ? 'erledigte' : 'erreichte';
  const achievableText = unit === 'tasks' ? 'gesamt' : 'erreichbaren';

  const descriptiveText = total === '0' && value === '0' ? `0 ${achievedText} von 0 ${achievableText} ${unitText}` :
    total === '-' ? '' : `${value} ${achievedText} von ${total} ${achievableText} ${unitText}`;

  const hasChecklists = checklistValue !== undefined && checklistTotal !== undefined;

  // Bei 0/0 immer grau anzeigen (colorStatus = 'gray' aus DB)
  const isZeroValue = total === '0' && value === '0';

  const getTextColorClass = (status?: 'red' | 'yellow' | 'orange' | 'green' | 'dark_green' | 'gray') => {
    if (isZeroValue || status === 'gray') return 'text-gray-500';
    if (!status) return 'text-gray-900';
    switch (status) {
      case 'dark_green':
        return 'text-green-800';
      case 'green':
        return 'text-green-600';
      case 'orange':
        return 'text-orange-500';
      case 'yellow':
        return 'text-yellow-500';
      case 'red':
        return 'text-red-600';
      default:
        return 'text-gray-900';
    }
  };

  const getProgressBarColor = (status?: 'red' | 'yellow' | 'orange' | 'green' | 'dark_green' | 'gray') => {
    if (isZeroValue || status === 'gray') return 'bg-gray-400';
    if (!status) return 'bg-gray-500';
    switch (status) {
      case 'dark_green':
        return 'bg-green-800';
      case 'green':
        return 'bg-green-600';
      case 'orange':
        return 'bg-orange-500';
      case 'yellow':
        return 'bg-yellow-500';
      case 'red':
        return 'bg-red-600';
      default:
        return 'bg-gray-500';
    }
  };

  const textColorClass = getTextColorClass(colorStatus);
  const progressBarColor = getProgressBarColor(colorStatus);

  return (
    <div
      className={`bg-gradient-to-br from-white to-gray-50 rounded-xl p-6 shadow-lg border-2 border-gray-200 hover:shadow-xl hover:border-gray-300 transform hover:scale-105 transition-all ${
        onClick ? 'cursor-pointer' : ''
      }`}
      onClick={onClick}
    >
      <div className="flex items-center justify-between mb-4">
        <Icon className={`w-8 h-8 ${textColorClass}`} />
        {displayPercentage && (
          <span className={`text-2xl font-bold ${textColorClass}`}>
            {displayPercentage}
          </span>
        )}
      </div>
      <h3 className="text-sm font-medium text-gray-600 mb-2">{title}</h3>
      <div className={`text-3xl font-bold ${textColorClass} mb-1`}>
        {displayValue}
      </div>
      {descriptiveText && (
        <p className="text-xs text-gray-500 mb-3">{descriptiveText}</p>
      )}
      {hasChecklists && (
        <div className="mt-2 pt-2 border-t border-gray-200">
          <p className="text-xs text-gray-600 font-medium">Checklisten: {checklistValue}/{checklistTotal}</p>
        </div>
      )}
      {estimatedTime !== undefined && (
        <p className="text-xs text-gray-600 font-medium">
          Geschätzte Zeit: {Math.floor(estimatedTime / 60)}h {estimatedTime % 60}m
        </p>
      )}

      {showProgressBar && total !== '-' && !isZeroValue && (
        <div className="w-full bg-gray-200 rounded-full h-2 overflow-hidden">
          <div
            className={`h-2 ${progressBarColor} transition-all duration-500`}
            style={{ width: `${Math.min(percentage, 100)}%` }}
          />
        </div>
      )}
    </div>
  );
}

interface PerformanceMetricsProps {
  onNavigate?: (view: string, filter?: 'pending_review' | 'today' | null) => void;
}

export function PerformanceMetrics({ onNavigate }: PerformanceMetricsProps = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { tasks } = useTasks();
  const { schedules } = useSchedules();
  const { profiles } = useProfiles();
  const { dailyGoal } = useDailyPointGoals(profile?.id);
  const { monthlyProgress } = useMonthlyProgress(profile?.id);
  const [teamAchievable, setTeamAchievable] = useState(0);
  const [teamAchieved, setTeamAchieved] = useState(0);
  const [motivationalMessage, setMotivationalMessage] = useState('');
  const [checklistInstances, setChecklistInstances] = useState<any[]>([]);
  const [totalTasksToday, setTotalTasksToday] = useState(0);
  const [completedTasksToday, setCompletedTasksToday] = useState(0);
  const [teamEstimatedTime, setTeamEstimatedTime] = useState(0);

  useEffect(() => {
    if (dailyGoal) {
      setTeamAchievable(dailyGoal.team_achievable_points || 0);
      setTeamAchieved(dailyGoal.team_points_earned || 0);
    }
  }, [dailyGoal]);

  useEffect(() => {
    const fetchChecklistInstances = async () => {
      // Checklists are now integrated into Tasks - return empty array
      setChecklistInstances([]);
    };

    const fetchTeamTaskCounts = async () => {
      // Call without parameter to use Cambodia's current date automatically
      const { data, error } = await supabase
        .rpc('get_team_daily_task_counts');

      if (!error && data && data.length > 0) {
        setTotalTasksToday(data[0].total_tasks || 0);
        setCompletedTasksToday(data[0].completed_tasks || 0);
      } else {
        setTotalTasksToday(0);
        setCompletedTasksToday(0);
      }
    };

    fetchChecklistInstances();
    fetchTeamTaskCounts();

    // Subscribe to changes on tasks table (since we now query directly)
    const channel = supabase
      .channel(`team_task_counts_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'tasks',
        },
        () => {
          fetchTeamTaskCounts();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [profile?.id]);

  useEffect(() => {
    const fetchTeamPoints = async () => {
      if (dailyGoal) return;

      try {
        const today = getTodayDateString();

        const { data: goalsData, error: goalsError } = await supabase
          .from('daily_point_goals')
          .select('team_achievable_points, team_points_earned')
          .eq('goal_date', today)
          .limit(1)
          .maybeSingle() as any;

        if (goalsError) throw goalsError;

        setTeamAchievable(goalsData?.team_achievable_points || 0);
        setTeamAchieved(goalsData?.team_points_earned || 0);
      } catch (error) {
        console.error('Error fetching team points:', error);
      }
    };

    fetchTeamPoints();

    // Subscribe to changes
    const channel = supabase
      .channel(`team_points_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'daily_point_goals',
        },
        () => {
          fetchTeamPoints();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  useEffect(() => {
    const calculateEstimatedTime = async () => {
      try {
        const today = getTodayDateString();

        // Get scheduled staff for today from weekly_schedules
        const { data: weeklySchedules, error: scheduleError } = await supabase
          .from('weekly_schedules')
          .select('staff_id, shifts');

        if (scheduleError) throw scheduleError;

        // Count scheduled staff for today
        let scheduledCount = 0;
        weeklySchedules?.forEach((schedule) => {
          const shiftsArray = schedule.shifts as Array<{ date: string; shift: string }>;
          const todayShift = shiftsArray.find((s) => s.date === today);

          if (todayShift && (todayShift.shift === 'morning' || todayShift.shift === 'late')) {
            scheduledCount++;
          }
        }) as any;

        if (scheduledCount === 0) {
          setTeamEstimatedTime(120);
          return;
        }

        const { data: tasksData, error: tasksError } = await supabase
          .from('tasks')
          .select('duration_minutes, status')
          .eq('due_date', today)
          .neq('status', 'completed')
          .neq('status', 'archived');

        if (tasksError) throw tasksError;

        const totalTaskMinutes = (tasksData || [])
          .reduce((sum, task) => sum + (task.duration_minutes || 0), 0);

        // Checklists are now integrated into Tasks
        const totalChecklistMinutes = 0;

        const totalMinutes = totalTaskMinutes + totalChecklistMinutes;
        const estimatedMinutes = Math.ceil(totalMinutes / scheduledCount) + 120;

        setTeamEstimatedTime(estimatedMinutes);

      } catch (error: any) {
        console.error('Estimated time error:', error);
        setTeamEstimatedTime(0);
      }
    };

    calculateEstimatedTime();

    const interval = setInterval(calculateEstimatedTime, 60000);

    return () => clearInterval(interval);
  }, []);

  const staffProfiles = profiles.filter((p) => p.role !== 'admin');

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const todaySchedules = schedules.filter((s) => {
    const scheduleDate = new Date(s.start_time);
    scheduleDate.setHours(0, 0, 0, 0);
    return scheduleDate.getTime() === today.getTime();
  }) as any;

  const currentUserSchedule = todaySchedules.find((s) => s.staff_id === profile?.id);

  const myTasks = getTodayMyTasks(tasks, profile?.id);
  const completedMyTasks = myTasks.filter((t) => t.status === 'completed' || t.status === 'archived');
  const taskPercentage = myTasks.length > 0
    ? (completedMyTasks.length / myTasks.length) * 100
    : 0;

  // Checklists are now integrated into Tasks - all checklist variables set to empty/zero
  const myChecklistInstances: any[] = [];
  const completedChecklists: any[] = [];
  const openChecklistInstances: any[] = [];
  const checklistTimeMinutes = 0;

  const estimatedTimeMinutes = myTasks
    .filter((t) => t.status !== 'completed' && t.status !== 'archived')
    .reduce((sum, t) => sum + (t.duration_minutes || 0), 0) + checklistTimeMinutes;

  const dailyGoalPercentage = typeof dailyGoal?.percentage === 'string'
    ? parseFloat(dailyGoal.percentage)
    : dailyGoal?.percentage || 0;
  const dailyGoalAchieved = dailyGoal?.achieved_points || 0;
  const dailyGoalTotal = dailyGoal?.theoretically_achievable_points || 0;
  const dailyColorStatus = dailyGoal?.color_status;

  const monthlyPercentage = monthlyProgress?.percentage || 0;
  const monthlyAchieved = monthlyProgress?.total_achieved || 0;
  const monthlyTotal = monthlyProgress?.total_achievable || 0;
  const monthlyColorStatus = monthlyProgress?.color_status;

  const teamPercentage = teamAchievable > 0 ? (teamAchieved / teamAchievable) * 100 : 0;

  useEffect(() => {
    if (!monthlyProgress) return;

    const now = new Date();
    const currentDay = now.getDate();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    const progressThroughMonth = (currentDay / daysInMonth) * 100;

    const monthlyPerc = monthlyProgress.percentage || 0;

    let message = '';

    if (currentDay < 10) {
      if (monthlyPerc >= 90) {
        message = 'Fantastischer Start! Du bist super im Plan!';
      } else if (monthlyPerc >= 70) {
        message = 'Guter Start in den Monat! Bleib dran!';
      } else if (monthlyPerc >= 50) {
        message = 'Solider Start! Mit etwas mehr Einsatz schaffst du es!';
      } else {
        message = 'Noch viel Zeit! Bleib fokussiert!';
      }
    } else if (currentDay < 20) {
      if (monthlyPerc >= progressThroughMonth + 10) {
        message = 'Überragend! Du liegst über dem Soll!';
      } else if (monthlyPerc >= progressThroughMonth - 5) {
        message = 'Du bist genau im Soll! Weiter so!';
      } else if (monthlyPerc >= progressThroughMonth - 15) {
        message = 'Leicht zurück, aber das holst du noch auf!';
      } else {
        message = 'Bleib dran! Du kannst es noch schaffen!';
      }
    } else {
      if (monthlyPerc >= 90) {
        message = 'Fast geschafft! Der Bonus ist zum Greifen nah!';
      } else if (monthlyPerc >= 75) {
        message = 'Auf der Zielgeraden! Gib nochmal Gas!';
      } else if (monthlyPerc >= 60) {
        message = 'Noch ist alles drin! Kämpf bis zum Ende!';
      } else {
        message = 'Jeder Punkt zählt! Mach weiter!';
      }
    }

    setMotivationalMessage(message);
  }, [monthlyProgress]);

  return (
    <div className="space-y-4">
      {motivationalMessage && (
        <div className="bg-gradient-to-r from-blue-50 to-purple-50 border-2 border-blue-200 rounded-xl p-4 shadow-md">
          <div className="flex items-center justify-center space-x-2">
            <Award className="w-6 h-6 text-blue-600 animate-pulse" />
            <p className="text-lg font-bold text-gray-800 text-center">
              {motivationalMessage}
            </p>
            <Award className="w-6 h-6 text-purple-600 animate-pulse" />
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <MetricCard
          title="Today's Tasks"
          value={completedTasksToday.toString()}
          total={totalTasksToday.toString()}
          percentage={totalTasksToday > 0 ? (completedTasksToday / totalTasksToday) * 100 : 0}
          icon={CheckSquare}
          showProgressBar={true}
          unit="tasks"
          onClick={() => onNavigate?.('tasks', 'today')}
        />

        <MetricCard
          title="Meine Punkte Heute"
          value={dailyGoalAchieved.toString()}
          total={dailyGoalTotal.toString()}
          percentage={dailyGoalPercentage}
          colorStatus={dailyColorStatus}
          icon={Award}
          showProgressBar={true}
          onClick={() => onNavigate?.('tasks')}
        />

        <MetricCard
          title="Meine Punkte Monatlich"
          value={monthlyAchieved.toString()}
          total={monthlyTotal.toString()}
          percentage={monthlyPercentage}
          colorStatus={monthlyColorStatus}
          icon={TrendingUp}
          showProgressBar={true}
          onClick={() => onNavigate?.('leaderboard')}
        />

        <MetricCard
          title="Team Points Today"
          value={teamAchieved.toString()}
          total={teamAchievable.toString()}
          percentage={teamPercentage}
          icon={Users}
          showProgressBar={true}
          onClick={() => onNavigate?.('leaderboard')}
        />
      </div>
    </div>
  );
}
