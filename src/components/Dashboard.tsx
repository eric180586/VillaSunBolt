import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { useSchedules } from '../hooks/useSchedules';
import { PerformanceMetrics } from './PerformanceMetrics';
import { ProgressBar } from './ProgressBar';
import { EndOfDayRequest } from './EndOfDayRequest';
import { NotesPopup } from './NotesPopup';
import { AdminDashboard } from './AdminDashboard';
import { RepairRequestModal } from './RepairRequestModal';
import { FortuneWheel } from './FortuneWheel';
import { useTranslation } from 'react-i18next';
import { Wrench, ShoppingCart, Trophy, Sparkles } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { getTodayDateString } from '../lib/dateUtils';
import type { FortuneWheelSegment } from '../types/common';
interface DashboardProps {
  onNavigate?: (view: string, filter?: 'pending_review' | 'today' | null) => void;
  onBack?: () => void;
}

export function Dashboard({ onNavigate, onBack }: DashboardProps = {}) {
  const { profile } = useAuth();
  const { t } = useTranslation();
  const { refetch } = useTasks();
  useSchedules();
  const [showNotesPopup, setShowNotesPopup] = useState(false);
  const [showRepairModal, setShowRepairModal] = useState(false);
  const [showFortuneWheel, setShowFortuneWheel] = useState(false);
  const [showFortuneWheelBanner, setShowFortuneWheelBanner] = useState(false);
  const [currentCheckInId, setCurrentCheckInId] = useState<string | null>(null);

  useEffect(() => {
    if (profile?.role === 'staff') {
      const checkNotesPopup = () => {
        const hasSeenNotesToday = sessionStorage.getItem('notesShownToday');
        const today = new Date().toDateString();

        if (hasSeenNotesToday !== today) {
          setShowNotesPopup(true);
        }
      };

      checkNotesPopup();
      checkFortuneWheelEligibility();
    }
  }, [profile]);

  const checkFortuneWheelEligibility = async () => {
    if (!profile?.id) return;

    try {
      const today = getTodayDateString();

      // Check if user has already spun the wheel today
      const { data: spinData } = await supabase
        .from('fortune_wheel_spins')
        .select('id')
        .eq('user_id', profile.id)
        .eq('spin_date', today)
        .maybeSingle();

      if (spinData) {
        setShowFortuneWheelBanner(false);
        return;
      }

      // Check if user has checked in today
      const { data: checkInData } = await supabase
        .from('check_ins')
        .select('id')
        .eq('user_id', profile.id)
        .eq('check_in_date', today)
        .maybeSingle();

      if (checkInData) {
        setCurrentCheckInId(checkInData.id);
        setShowFortuneWheelBanner(true);
      } else {
        setShowFortuneWheelBanner(false);
      }
    } catch (error) {
      console.error('Error checking fortune wheel eligibility:', error);
      setShowFortuneWheelBanner(false);
    }
  };

  const handleFortuneWheelComplete = async (segment: FortuneWheelSegment) => {
    if (!profile?.id || !currentCheckInId) return;

    try {
      const today = getTodayDateString();

      const { error } = await supabase
        .from('fortune_wheel_spins')
        .insert({
          user_id: profile.id,
          check_in_id: currentCheckInId,
          spin_date: today,
          points_won: segment.actualPoints || 0,
          reward_type: segment.rewardType,
          reward_value: segment.rewardValue,
          reward_label: segment.label,
        });

      if (error) throw error;

      if (segment.rewardType === 'bonus_points' && segment.actualPoints !== 0) {
        await supabase.rpc('add_bonus_points', {
          p_user_id: profile.id,
          p_points: segment.actualPoints,
          p_reason: `${t('fortuneWheel.title')}: ${segment.label}`,
        });
      }

      setShowFortuneWheelBanner(false);
    } catch (error) {
      console.error('Error completing fortune wheel spin:', error);
    }
  };

  if (profile?.role === 'admin') {
    return <AdminDashboard onNavigate={onNavigate} onBack={onBack} />;
  }

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

        {/* Animated Fortune Wheel Banner */}
        {showFortuneWheelBanner && (
          <button
            onClick={() => setShowFortuneWheel(true)}
            className="w-full relative overflow-hidden rounded-2xl p-8 shadow-2xl transform hover:scale-[1.02] transition-all duration-300 active:scale-[0.98] border-4 border-yellow-300"
            style={{
              background: 'linear-gradient(90deg, #f59e0b 0%, #fbbf24 25%, #fcd34d 50%, #fbbf24 75%, #f59e0b 100%)',
              backgroundSize: '200% auto',
              animation: 'shimmer 3s linear infinite',
            }}
          >
            <style>
              {`
                @keyframes shimmer {
                  0% { background-position: -200% 0; }
                  100% { background-position: 200% 0; }
                }
              `}
            </style>
            <div className="flex items-center justify-center space-x-4">
              <Trophy className="w-12 h-12 text-white drop-shadow-lg animate-bounce" />
              <div className="text-center">
                <h3 className="text-3xl font-black text-white drop-shadow-lg mb-1">
                  {t('fortuneWheel.bannerTitle', '🎯 DREHE DAS GLÜCKSRAD! 🎯')}
                </h3>
                <p className="text-xl font-semibold text-white drop-shadow-md">
                  {t('fortuneWheel.bannerSubtitle', 'Gewinne bis zu 10 Bonuspunkte!')}
                </p>
              </div>
              <Sparkles className="w-12 h-12 text-white drop-shadow-lg animate-pulse" />
            </div>
          </button>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <button
            onClick={() => setShowRepairModal(true)}
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

        {showRepairModal && (
          <RepairRequestModal
            onClose={() => setShowRepairModal(false)}
            onComplete={async () => {
              setShowRepairModal(false);
              await refetch();
            }}
          />
        )}

        {showFortuneWheel && currentCheckInId && (
          <FortuneWheel
            onClose={() => {
              setShowFortuneWheel(false);
              checkFortuneWheelEligibility();
            }}
            onSpinComplete={handleFortuneWheelComplete}
          />
        )}
      </div>
    </>
  );
}
