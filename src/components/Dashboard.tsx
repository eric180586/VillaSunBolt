import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { useSchedules } from '../hooks/useSchedules';
import { PerformanceMetrics } from './PerformanceMetrics';
import { ProgressBar } from './ProgressBar';
import { EndOfDayRequest } from './EndOfDayRequest';
import { NotesPopup } from './NotesPopup';
import { AdminDashboard } from './AdminDashboard';
import { useTranslation } from 'react-i18next';
import { Wrench, ShoppingCart } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface DashboardProps {
  onNavigate?: (view: string, filter?: 'pending_review' | 'today' | null) => void;
  onBack?: () => void;
}

export function Dashboard({ onNavigate, onBack }: DashboardProps = {}) {
  const { profile } = useAuth();
  const { t } = useTranslation();

  if (profile?.role === 'admin') {
    return <AdminDashboard onNavigate={onNavigate} onBack={onBack} />;
  }
  const { tasks } = useTasks();
  const { schedules } = useSchedules();
  const [showNotesPopup, setShowNotesPopup] = useState(false);

  useEffect(() => {
    const checkNotesPopup = () => {
      const hasSeenNotesToday = sessionStorage.getItem('notesShownToday');
      const today = new Date().toDateString();

      if (hasSeenNotesToday !== today) {
        setShowNotesPopup(true);
      }
    };

    checkNotesPopup();
    // Checklist generation is now handled by daily-reset edge function (manual or scheduled)
  }, [profile]);

  const handleCloseNotesPopup = () => {
    setShowNotesPopup(false);
    const today = new Date().toDateString();
    sessionStorage.setItem('notesShownToday', today);
  };

  return (
    <>
      {showNotesPopup && <NotesPopup onClose={handleCloseNotesPopup} />}

      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-3xl font-bold text-gray-900">
              {t('dashboard.welcomeBack', { name: profile?.full_name })}
            </h2>
            <p className="text-gray-600 mt-1">{t('dashboard.whatsHappening')}</p>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <button
            onClick={() => onNavigate?.('tasks')}
            className="bg-gradient-to-br from-blue-500 to-blue-600 text-white rounded-xl p-6 shadow-lg hover:shadow-xl hover:from-blue-600 hover:to-blue-700 transform hover:scale-105 transition-all duration-200 active:scale-95 flex items-center justify-center space-x-3"
          >
            <Wrench className="w-8 h-8" />
            <span className="text-lg font-semibold">Create New (Repair)</span>
          </button>

          <button
            onClick={() => onNavigate?.('shopping')}
            className="bg-gradient-to-br from-green-500 to-green-600 text-white rounded-xl p-6 shadow-lg hover:shadow-xl hover:from-green-600 hover:to-green-700 transform hover:scale-105 transition-all duration-200 active:scale-95 flex items-center justify-center space-x-3"
          >
            <ShoppingCart className="w-8 h-8" />
            <span className="text-lg font-semibold">Add Item (Shopping)</span>
          </button>
        </div>

        <PerformanceMetrics onNavigate={onNavigate} />

        <ProgressBar />

        <EndOfDayRequest />
      </div>
    </>
  );
}
