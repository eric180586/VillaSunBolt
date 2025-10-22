import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { useDepartureRequests } from '../hooks/useDepartureRequests';
import { useProfiles } from '../hooks/useProfiles';
import { supabase } from '../lib/supabase';
import { Plus, TrendingUp, FileText, StickyNote, CheckCircle, Home, AlertCircle, QrCode, Users, UserCheck, ClipboardCheck, Shield, ArrowLeft, History } from 'lucide-react';
import { isSameDay, getTodayDateString } from '../lib/dateUtils';
import { CheckInOverview } from './CheckInOverview';
import { checkAndRunDailyReset } from '../lib/dailyReset';

interface ActionButtonProps {
  icon: React.ElementType;
  label: string;
  onClick: () => void;
  color: string;
}

function ActionButton({ icon: Icon, label, onClick, color }: ActionButtonProps) {
  return (
    <button
      onClick={onClick}
      className="bg-gradient-to-br from-white to-beige-50 rounded-xl p-6 shadow-lg border-2 border-beige-200 hover:shadow-xl hover:border-beige-400 transform hover:scale-105 transition-all duration-200 cursor-pointer active:scale-95"
    >
      <Icon className="w-8 h-8 text-beige-700 mb-2 mx-auto transition-transform duration-200 group-hover:scale-110" />
      <span className="text-gray-900 font-semibold text-sm text-center block">{label}</span>
    </button>
  );
}

interface DashboardCardProps {
  title: string;
  icon: React.ElementType;
  children: React.ReactNode;
  onClick?: () => void;
  action?: {
    label: string;
    onClick: () => void;
  };
}

function DashboardCard({ title, icon: Icon, children, onClick, action }: DashboardCardProps) {
  const CardWrapper = onClick ? 'button' : 'div';
  const wrapperProps = onClick ? {
    onClick,
    className: "bg-gradient-to-br from-white to-beige-50 rounded-xl p-6 shadow-lg border-2 border-beige-200 hover:shadow-xl hover:border-beige-400 transform hover:scale-105 transition-all duration-200 cursor-pointer w-full text-left active:scale-95 animate-fadeIn"
  } : {
    className: "bg-gradient-to-br from-white to-beige-50 rounded-xl p-6 shadow-lg border-2 border-beige-200 animate-fadeIn"
  };

  return (
    <CardWrapper {...wrapperProps}>
      <div className="flex items-center justify-between mb-4">
        <div className="flex flex-col items-center text-center w-full">
          <Icon className="w-6 h-6 text-beige-700 mb-2" />
          <h3 className="text-sm font-bold text-gray-900 h-10 flex items-center justify-center">{title}</h3>
        </div>
        {action && (
          <button
            onClick={(e) => {
              e.stopPropagation();
              action.onClick();
            }}
            className="text-sm font-medium text-blue-600 hover:text-blue-700 hover:underline"
          >
            {action.label}
          </button>
        )}
      </div>
      {children}
    </CardWrapper>
  );
}

interface AdminDashboardProps {
  onNavigate?: (view: string, filter?: 'pending_review' | 'today' | null) => void;
  onBack?: () => void;
}

export function AdminDashboard({ onNavigate, onBack }: AdminDashboardProps = {}) {
  const { profile } = useAuth();
  const { tasks, createTask } = useTasks();
  const { requests } = useDepartureRequests();
  const { profiles, addPoints } = useProfiles();


  const staffProfiles = profiles.filter((p) => p.role !== 'admin');

  const today = new Date();

  const todayTasks = tasks.filter((t) => {
    if (!t.due_date) return false;
    return isSameDay(t.due_date, today);
  });

  const completedTasks = todayTasks.filter((t) => t.status === 'completed');
  const pendingReview = tasks.filter((t) => t.status === 'pending_review');
  const pendingDepartures = requests.filter((r) => r.status === 'pending');

  const [pendingCheckIns, setPendingCheckIns] = useState(0);
  const [pendingChecklists, setPendingChecklists] = useState(0);
  const [teamAchievable, setTeamAchievable] = useState(0);
  const [teamAchieved, setTeamAchieved] = useState(0);
  const [totalTasksToday, setTotalTasksToday] = useState(0);
  const [completedTasksToday, setCompletedTasksToday] = useState(0);
  const [totalChecklistsToday, setTotalChecklistsToday] = useState(0);
  const [completedChecklistsToday, setCompletedChecklistsToday] = useState(0);

  // Daily reset is now only triggered manually by admin or via scheduled cron job
  // Removed automatic call on mount to prevent errors on every page load

  useEffect(() => {
    const fetchPendingCheckIns = async () => {
      const { count, error } = await supabase
        .from('check_ins')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending');

      if (!error && count !== null) {
        setPendingCheckIns(count);
      }
    };

    const fetchPendingChecklists = async () => {
      // Checklists are now integrated into Tasks
      setPendingChecklists(0);
    };

    fetchPendingCheckIns();
    fetchPendingChecklists();

    const checkInsChannel = supabase
      .channel(`check_ins_count_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'check_ins',
        },
        () => {
          fetchPendingCheckIns();
        }
      )
      .subscribe();

    const checklistsChannel = supabase
      .channel(`checklist_instances_count_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'checklist_instances',
        },
        () => {
          fetchPendingChecklists();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(checkInsChannel);
      supabase.removeChannel(checklistsChannel);
    };
  }, []);

  useEffect(() => {
    const fetchTeamPoints = async () => {
      try {
        const today = getTodayDateString();

        const { data: goalsData, error: goalsError } = await supabase
          .from('daily_point_goals')
          .select('team_achievable_points, team_points_earned')
          .eq('goal_date', today)
          .limit(1)
          .maybeSingle();

        if (goalsError) throw goalsError;

        setTeamAchievable(goalsData?.team_achievable_points || 0);
        setTeamAchieved(goalsData?.team_points_earned || 0);

        // Fetch team task counts using new RPC function (uses Cambodia date automatically)
        const { data: totalsData, error: totalsError } = await supabase
          .rpc('get_team_daily_task_counts');

        if (!totalsError && totalsData && totalsData.length > 0) {
          setTotalTasksToday(totalsData[0].total_tasks || 0);
          setCompletedTasksToday(totalsData[0].completed_tasks || 0);
        } else {
          setTotalTasksToday(0);
          setCompletedTasksToday(0);
        }

        // Fetch today's checklist instances using RPC (uses Cambodia date automatically)
        const { data: checklistsData, error: checklistsError } = await supabase
          .rpc('get_team_daily_checklist_counts');

        if (!checklistsError && checklistsData && checklistsData.length > 0) {
          setTotalChecklistsToday(checklistsData[0].total_checklists || 0);
          setCompletedChecklistsToday(checklistsData[0].completed_checklists || 0);
        } else {
          setTotalChecklistsToday(0);
          setCompletedChecklistsToday(0);
        }
      } catch (error) {
        console.error('Error fetching team points:', error);
      }
    };

    fetchTeamPoints();

    const pointsChannel = supabase
      .channel(`team_points_admin_${Date.now()}`)
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

    const totalsChannel = supabase
      .channel(`team_totals_admin_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'tasks',
        },
        () => {
          fetchTeamPoints();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(pointsChannel);
      supabase.removeChannel(totalsChannel);
    };
  }, []);


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
          <div>
            <h2 className="text-3xl font-bold text-gray-900">
              Admin Dashboard
            </h2>
            <p className="text-gray-600 mt-1">Welcome back, {profile?.full_name}</p>
          </div>
        </div>
      </div>

      {/* Erste Reihe: New Task, Manage Points */}
      <div className="grid grid-cols-2 gap-4">
        <ActionButton
          icon={Plus}
          label="New Task"
          onClick={() => onNavigate?.('tasks')}
          color=""
        />
        <ActionButton
          icon={TrendingUp}
          label="Manage Points"
          onClick={() => onNavigate?.('points-manager')}
          color=""
        />
      </div>

      {/* Zweite Reihe: New Template, New Note, Check-In Historie, Daily Reset */}
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-4">
        <ActionButton
          icon={StickyNote}
          label="New Note"
          onClick={() => onNavigate?.('notes')}
          color=""
        />
        <ActionButton
          icon={History}
          label="Check-In Historie"
          onClick={() => onNavigate?.('checkin-history')}
          color=""
        />
        <ActionButton
          icon={AlertCircle}
          label="Daily Reset"
          onClick={async () => {
            if (confirm('Daily Reset manuell ausführen? Dies generiert neue Checklisten und aktualisiert die Tagesziele.')) {
              try {
                localStorage.removeItem('last_daily_reset');
                await checkAndRunDailyReset();
                alert('Daily Reset erfolgreich ausgeführt!');
                window.location.reload();
              } catch (error) {
                const errorMessage = error instanceof Error ? error.message : 'Unbekannter Fehler';
                alert('Daily Reset fehlgeschlagen: ' + errorMessage);
              }
            }
          }}
          color=""
        />
      </div>

      {/* Dritte Reihe: Today's Tasks, Aufgaben prüfen, Checklist prüfen */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <DashboardCard
          title="Today's Tasks"
          icon={CheckCircle}
          onClick={() => onNavigate?.('tasks', 'today')}
        >
          <div className="text-center py-4">
            <div className="relative inline-block mb-3">
              <CheckCircle className={`w-16 h-16 ${
                totalTasksToday > 0 ? 'text-blue-500' : 'text-gray-400'
              }`} />
              {totalTasksToday - completedTasksToday > 0 && (
                <span className="absolute -top-2 -right-2 w-8 h-8 bg-blue-500 text-white rounded-full flex items-center justify-center text-sm font-bold">
                  {totalTasksToday - completedTasksToday}
                </span>
              )}
            </div>
            <p className="text-sm text-gray-600 mt-3">
              {totalTasksToday > 0
                ? `${completedTasksToday}/${totalTasksToday} erledigt`
                : 'Keine Tasks heute'}
            </p>
          </div>
        </DashboardCard>

        <DashboardCard
          title="Aufgaben prüfen"
          icon={AlertCircle}
          onClick={() => onNavigate?.('tasks', 'pending_review')}
        >
          <div className="text-center py-4">
            <div className="relative inline-block mb-3">
              <AlertCircle className={`w-16 h-16 ${
                pendingReview.length > 0 ? 'text-orange-500' : 'text-gray-400'
              }`} />
              {pendingReview.length > 0 && (
                <span className="absolute -top-2 -right-2 w-8 h-8 bg-red-500 text-white rounded-full flex items-center justify-center text-sm font-bold">
                  {pendingReview.length}
                </span>
              )}
            </div>
            <p className="text-sm text-gray-600 mt-3">
              {pendingReview.length > 0
                ? `${pendingReview.length} Aufgabe${pendingReview.length > 1 ? 'n' : ''} zu prüfen`
                : 'Alles geprüft'}
            </p>
          </div>
        </DashboardCard>

        <DashboardCard
          title="Checklist Review"
          icon={ClipboardCheck}
          onClick={() => onNavigate?.('checklist-review')}
        >
          <div className="flex flex-col items-center justify-center text-center py-6">
            <div className="relative inline-block mb-4">
              <ClipboardCheck className={`w-16 h-16 ${
                pendingChecklists > 0 ? 'text-green-500' : 'text-gray-400'
              }`} />
              {pendingChecklists > 0 && (
                <span className="absolute -top-2 -right-2 w-7 h-7 bg-red-500 text-white rounded-full flex items-center justify-center text-sm font-bold shadow-lg">
                  {pendingChecklists}
                </span>
              )}
            </div>
            <p className="text-sm font-semibold text-gray-700">
              {pendingChecklists > 0
                ? `${pendingChecklists} warten`
                : 'Alle reviewt'}
            </p>
          </div>
        </DashboardCard>
      </div>

      {/* Vierte Reihe: Check-In/Status/Feierabend, Team Points, Aufgaben Gesamt, Patrol Rounds */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <DashboardCard
          title="Check-In / Status / Feierabend"
          icon={UserCheck}
          onClick={() => onNavigate?.('checkin-approval')}
        >
          <div className="space-y-4 py-4">
            <div
              className="flex items-center justify-between px-4 py-3 bg-beige-50 rounded-lg hover:bg-beige-100 transition-colors cursor-pointer"
              onClick={(e) => {
                e.stopPropagation();
                onNavigate?.('checkin-approval');
              }}
            >
              <div className="flex items-center space-x-3">
                <QrCode className={`w-8 h-8 ${
                  pendingCheckIns > 0 ? 'text-orange-500' : 'text-gray-400'
                }`} />
                <span className="font-medium text-gray-700">Check-In</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className={`text-lg font-bold ${
                  pendingCheckIns > 0 ? 'text-orange-600' : 'text-gray-400'
                }`}>{pendingCheckIns}</span>
                {pendingCheckIns > 0 && (
                  <span className="px-2 py-1 bg-red-500 text-white rounded-full text-xs font-bold">!</span>
                )}
              </div>
            </div>

            <div
              className="flex items-center justify-between px-4 py-3 bg-beige-50 rounded-lg hover:bg-beige-100 transition-colors cursor-pointer"
              onClick={(e) => {
                e.stopPropagation();
                onNavigate?.('departure-requests');
              }}
            >
              <div className="flex items-center space-x-3">
                <Home className={`w-8 h-8 ${
                  pendingDepartures.length > 0 ? 'text-orange-500' : 'text-gray-400'
                }`} />
                <span className="font-medium text-gray-700">Feierabend</span>
              </div>
              <div className="flex items-center space-x-2">
                <span className={`text-lg font-bold ${
                  pendingDepartures.length > 0 ? 'text-orange-600' : 'text-gray-400'
                }`}>{pendingDepartures.length}</span>
                {pendingDepartures.length > 0 && (
                  <span className="px-2 py-1 bg-red-500 text-white rounded-full text-xs font-bold">!</span>
                )}
              </div>
            </div>
          </div>
        </DashboardCard>

        <DashboardCard
          title="Team Points Today"
          icon={Users}
          onClick={() => onNavigate?.('leaderboard')}
        >
          <div className="text-center py-4">
            <div className="flex items-baseline justify-center space-x-2">
              <span className="text-3xl font-bold text-gray-900">{teamAchieved}</span>
              <span className="text-xl text-gray-400">/</span>
              <span className="text-3xl font-bold text-gray-400">{teamAchievable}</span>
            </div>
            <p className="text-xs text-gray-600 mt-2">
              {teamAchievable > 0
                ? `${((teamAchieved / teamAchievable) * 100).toFixed(0)}% erreicht`
                : 'Kein Zeitplan'}
            </p>
          </div>
        </DashboardCard>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <DashboardCard
          title="Aufgaben Gesamt"
          icon={CheckCircle}
          onClick={() => onNavigate?.('tasks')}
        >
          <div className="text-center py-4 space-y-3">
            <div>
              <p className="text-xs font-medium text-gray-500 mb-1">Tasks</p>
              <div className="flex items-baseline justify-center space-x-2">
                <span className="text-2xl font-bold text-gray-900">{completedTasksToday}</span>
                <span className="text-lg text-gray-400">/</span>
                <span className="text-2xl font-bold text-gray-400">{totalTasksToday}</span>
              </div>
              <p className="text-xs text-gray-600 mt-1">
                {totalTasksToday > 0
                  ? `${((completedTasksToday / totalTasksToday) * 100).toFixed(0)}% erledigt`
                  : 'Keine Tasks'}
              </p>
            </div>
            <div className="border-t border-gray-200 pt-2">
              <p className="text-xs font-medium text-gray-500 mb-1">Checklists</p>
              <div className="flex items-baseline justify-center space-x-2">
                <span className="text-2xl font-bold text-gray-900">{completedChecklistsToday}</span>
                <span className="text-lg text-gray-400">/</span>
                <span className="text-2xl font-bold text-gray-400">{totalChecklistsToday}</span>
              </div>
              <p className="text-xs text-gray-600 mt-1">
                {totalChecklistsToday > 0
                  ? `${((completedChecklistsToday / totalChecklistsToday) * 100).toFixed(0)}% erledigt`
                  : 'Keine Checklists'}
              </p>
            </div>
          </div>
        </DashboardCard>

        <DashboardCard
          title="Patrol Rounds"
          icon={Shield}
          onClick={() => onNavigate?.('patrol-rounds')}
        >
          <div className="text-center py-4">
            <div className="relative inline-block mb-3">
              <Shield className="w-16 h-16 text-orange-600" />
            </div>
            <p className="text-sm text-gray-600 mt-3">
              Patrouillengänge verwalten
            </p>
          </div>
        </DashboardCard>
      </div>
    </div>
  );
}
