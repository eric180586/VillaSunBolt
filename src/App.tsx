import { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { Auth } from './components/Auth';
import { Layout } from './components/Layout';
import { Dashboard } from './components/Dashboard';
import { Tasks } from './components/Tasks';
import { Schedules } from './components/Schedules';
import { Notes } from './components/Notes';
import { Leaderboard } from './components/Leaderboard';
import { Notifications } from './components/Notifications';
import { Profile } from './components/Profile';
import { EmployeeManagement } from './components/EmployeeManagement';
import { HumorModuleSettings } from './components/HumorModuleSettings';
import { PointsManager } from './components/PointsManager';
import { CheckIn } from './components/CheckIn';
import { CheckInOverview } from './components/CheckInOverview';
import { CheckInHistory } from './components/CheckInHistory';
import { ShoppingList } from './components/ShoppingList';
import { PatrolRounds } from './components/PatrolRounds';
import { PatrolSchedules } from './components/PatrolSchedules';
import { PatrolQRCodes } from './components/PatrolQRCodes';
import { CheckInPopup } from './components/CheckInPopup';
import { DailyPointsOverview } from './components/DailyPointsOverview';
import { MonthlyPointsOverview } from './components/MonthlyPointsOverview';
import { DepartureRequestAdmin } from './components/DepartureRequestAdmin';
import { HowTo } from './components/HowTo';
import { Chat } from './components/Chat';
import { supabase } from './lib/supabase';

function AppContent() {
  const { user, profile, loading } = useAuth();
  const [currentView, setCurrentView] = useState('dashboard');
  const [taskFilter, setTaskFilter] = useState<'pending_review' | 'today' | null>(null);
  const [showCheckInPopup, setShowCheckInPopup] = useState(false);

  const handleNavigate = (view: string, filter?: 'pending_review' | 'today' | null) => {
    setCurrentView(view);
    if (view === 'tasks') {
      setTaskFilter(filter || null);
    } else {
      setTaskFilter(null);
    }
  };

  const handleBack = () => {
    setCurrentView('dashboard');
    setTaskFilter(null);
  };

  useEffect(() => {
    const checkForTodayCheckIn = async () => {
      if (!user || !profile?.id) return;

      if (profile.role === 'admin') {
        return;
      }

      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);

      const { data, error } = await supabase
        .from('check_ins')
        .select('id')
        .eq('user_id', profile.id)
        .gte('check_in_time', todayStart.toISOString())
        .maybeSingle();

      if (!error && !data) {
        setShowCheckInPopup(true);
      } else if (data) {
        setShowCheckInPopup(false);
      }
    };

    checkForTodayCheckIn();

    const checkInChannel = supabase
      .channel(`check_ins_app_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'check_ins',
          filter: `user_id=eq.${profile?.id}`,
        },
        () => {
          setShowCheckInPopup(false);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(checkInChannel);
    };
  }, [user, profile]);

  const handleCloseCheckInPopup = () => {
    setShowCheckInPopup(false);
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-beige-50 to-orange-50 flex items-center justify-center">
        <div className="text-center animate-fadeIn">
          <div className="w-20 h-20 border-4 border-orange-500 border-t-transparent rounded-full animate-spin mx-auto mb-6" />
          <h2 className="text-2xl font-bold text-gray-800 mb-2">Villa Sun Team</h2>
          <p className="text-gray-600 animate-pulse">Loading your workspace...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Auth />;
  }

  const renderView = () => {
    switch (currentView) {
      case 'dashboard':
        return <Dashboard onNavigate={handleNavigate} onBack={currentView !== 'dashboard' ? handleBack : undefined} />;
      case 'tasks':
        return <Tasks onNavigate={handleNavigate} filterStatus={taskFilter} onBack={handleBack} />;
      case 'shopping':
        return <ShoppingList onBack={handleBack} />;
      case 'schedules':
        return <Schedules onNavigate={handleNavigate} onBack={handleBack} />;
      case 'patrol-schedules':
        return <PatrolSchedules onNavigate={handleNavigate} onBack={handleBack} />;
      case 'patrol-rounds':
        return <PatrolRounds onBack={handleBack} />;
      case 'patrol-qrcodes':
        return <PatrolQRCodes onBack={handleBack} />;
      case 'checklists':
        return <Tasks onBack={handleBack} />;
      case 'notes':
        return <Notes onBack={handleBack} />;
      case 'chat':
        return <Chat onBack={handleBack} />;
      case 'how-to':
        return <HowTo onBack={handleBack} />;
      case 'leaderboard':
        return <Leaderboard onBack={handleBack} />;
      case 'notifications':
        return <Notifications onBack={handleBack} />;
      case 'profile':
        return <Profile onBack={handleBack} />;
      case 'employees':
        return <EmployeeManagement onBack={handleBack} />;
      case 'humor-settings':
        return <HumorModuleSettings onBack={handleBack} />;
      case 'points-manager':
        return <PointsManager onBack={handleBack} />;
      case 'checkin':
        return <CheckIn onBack={handleBack} />;
      case 'checkin-approval':
        return <CheckInOverview onBack={handleBack} onNavigate={handleNavigate} />;
      case 'checkin-history':
        return <CheckInHistory onBack={handleBack} />;
      case 'checklist-review':
        return <Tasks onBack={handleBack} filterStatus="pending_review" />;
      case 'daily-points':
        return <DailyPointsOverview onBack={handleBack} />;
      case 'monthly-points':
        return <MonthlyPointsOverview />;
      case 'departure-requests':
        return <DepartureRequestAdmin onBack={handleBack} />;
      case 'today-tasks-overview':
        return <Tasks onNavigate={handleNavigate} filterStatus="today" onBack={handleBack} />;
      default:
        return <Dashboard onNavigate={handleNavigate} />;
    }
  };

  return (
    <>
      <Layout currentView={currentView} onViewChange={handleNavigate}>
        {renderView()}
      </Layout>
      {showCheckInPopup && <CheckInPopup onClose={handleCloseCheckInPopup} />}
    </>
  );
}

function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}

export default App;
