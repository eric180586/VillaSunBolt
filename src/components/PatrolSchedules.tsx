import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useProfiles } from '../hooks/useProfiles';
import { Shield, ChevronLeft, ChevronRight, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

interface PatrolSchedule {
  date: string;
  shift: 'early' | 'late';
  assigned_to: string | null;
  staff_name?: string;
}

interface PatrolSchedulesProps {
onNavigate?: (view: string) => void;
  onBack?: () => void;
}

export function PatrolSchedules({ onNavigate, onBack }: PatrolSchedulesProps = {}) {
  const { profile } = useAuth();
  const { profiles } = useProfiles();
  const [currentWeekStart, setCurrentWeekStart] = useState<Date>(getMonday(new Date()));
  const [schedules, setSchedules] = useState<PatrolSchedule[]>([]);
  const [loading, setLoading] = useState(false);

  const isAdmin = profile?.role === 'admin' || profile?.role === 'super_admin';
  const staffMembers = profiles.filter((p) => p.role === 'staff');

  useEffect(() => {
    loadSchedules();
  }, [currentWeekStart]);

  function getMonday(date: Date): Date {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(d.setDate(diff));
  }

  function formatDate(date: Date): string {
    return date.toISOString().split('T')[0];
  }

  function addDays(date: Date, days: number): Date {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result;
  }

  const loadSchedules = async () => {
    setLoading(true);
    try {
      const weekDates = Array.from({ length: 7 }, (_, i) =>
        formatDate(addDays(currentWeekStart, i))
      );

      const { data, error } = await supabase
        .from('patrol_schedules')
        .select(`
          *,
          profiles:assigned_to(full_name)
        `)
        .in('date', weekDates);

      if (error) throw error;

      const scheduleMap: PatrolSchedule[] = [];
      weekDates.forEach((date) => {
        ['early', 'late'].forEach((shift) => {
          const existing = data?.find((s) => s.date === date && s.shift === shift);
          scheduleMap.push({
            date,
            shift: shift as 'early' | 'late',
            assigned_to: existing?.assigned_to || null,
            staff_name: existing?.profiles?.full_name || null,
          });
        });
      });

      setSchedules(scheduleMap);
    } catch (error) {
      console.error('Error loading patrol schedules:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAssignment = async (date: string, shift: 'early' | 'late', currentStaffId: string | null) => {
    if (!isAdmin) return;

    const currentIndex = currentStaffId
      ? staffMembers.findIndex((s) => s.id === currentStaffId)
      : -1;

    const nextIndex = (currentIndex + 1) % (staffMembers.length + 1);

    try {
      const { error: deleteError } = await supabase
        .from('patrol_schedules')
        .delete()
        .eq('date', date)
        .eq('shift', shift);

      if (deleteError) throw deleteError;

      if (nextIndex < staffMembers.length) {
        const nextStaff = staffMembers[nextIndex];

        const { error: insertError } = await supabase
          .from('patrol_schedules')
          .insert({
            date,
            shift,
            assigned_to: nextStaff.id,
            created_by: profile?.id,
          });

        if (insertError) throw insertError;
      }

      await loadSchedules();
    } catch (error) {
      console.error('Error updating patrol assignment:', error);
    }
  };

  const handlePreviousWeek = () => {
    setCurrentWeekStart(addDays(currentWeekStart, -7));
  };

  const handleNextWeek = () => {
    setCurrentWeekStart(addDays(currentWeekStart, 7));
  };

  const weekDates = Array.from({ length: 7 }, (_, i) => addDays(currentWeekStart, i));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Patrol Schedules</h2>
          <p className="text-gray-600 mt-1">Assign staff to daily patrol rounds</p>
        </div>
        <div className="flex items-center space-x-3">
          {isAdmin && onNavigate && (
            <button
              onClick={() => onNavigate('patrol-qrcodes')}
              className="flex items-center space-x-2 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors"
            >
              <span>View QR Codes</span>
            </button>
          )}
          <Shield className="w-8 h-8 text-blue-600" />
        </div>
      </div>

      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
        <div className="flex items-center justify-between mb-6">
          <button
            onClick={handlePreviousWeek}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <h3 className="text-lg font-semibold text-gray-900">
            Week of {currentWeekStart.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })}
          </h3>
          <button
            onClick={handleNextWeek}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin mx-auto" />
          </div>
        ) : (
          <div className="overflow-x-auto -mx-6 px-6">
            <table className="w-full min-w-[600px]">
              <thead>
                <tr>
                  <th className="text-left p-2 bg-beige-100 font-semibold text-gray-700 text-sm w-24">Shift</th>
                  {DAYS.map((day, index) => (
                    <th key={day} className="text-center p-2 bg-beige-100 font-semibold text-gray-700">
                      <div className="text-sm">{day.slice(0, 3)}</div>
                      <div className="text-xs text-gray-500 font-normal">
                        {weekDates[index].toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                      </div>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {['early', 'late'].map((shift) => (
                  <tr key={shift} className="border-t border-gray-200 hover:bg-beige-50">
                    <td className="p-2 font-medium text-gray-900 capitalize bg-beige-50 text-sm">
                      {shift === 'early' ? 'Early' : 'Late'}
                    </td>
                    {weekDates.map((date, dayIndex) => {
                      const dateStr = formatDate(date);
                      const schedule = schedules.find(
                        (s) => s.date === dateStr && s.shift === shift
                      );

                      return (
                        <td key={dayIndex} className="p-1 text-center">
                          {isAdmin ? (
                            <button
                              onClick={() => handleAssignment(dateStr, shift as 'early' | 'late', schedule?.assigned_to || null)}
                              className={`w-full px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                                schedule?.assigned_to
                                  ? shift === 'early'
                                    ? 'bg-blue-100 text-blue-800 hover:bg-blue-200'
                                    : 'bg-orange-100 text-orange-800 hover:bg-orange-200'
                                  : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                              }`}
                            >
                              {schedule?.staff_name || 'Click to assign'}
                            </button>
                          ) : (
                            <div
                              className={`w-full px-3 py-2 rounded-lg text-sm font-medium ${
                                schedule?.assigned_to
                                  ? shift === 'early'
                                    ? 'bg-blue-100 text-blue-800'
                                    : 'bg-orange-100 text-orange-800'
                                  : 'bg-gray-100 text-gray-500'
                              }`}
                            >
                              {schedule?.staff_name || 'Not assigned'}
                            </div>
                          )}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {isAdmin && (
          <div className="mt-6 p-4 bg-blue-50 rounded-lg">
            <p className="text-sm text-blue-900">
              <strong>How it works:</strong> Click on any cell to cycle through staff members.
              The assigned staff will be responsible for all patrol rounds on that day during their shift.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
