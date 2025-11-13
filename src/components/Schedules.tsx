import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { useProfiles } from '../hooks/useProfiles';
import { Calendar, ChevronLeft, ChevronRight, Clock, X, Check, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';

type ShiftType = 'early' | 'late' | 'off';

interface DayShift {
  day: string;
  date: string;
  shift: ShiftType;
}

interface WeekSchedule {
  id: string;
  staff_id: string;
  week_start_date: string;
  shifts: DayShift[];
  is_published: boolean;
}

interface TimeOffRequest {
  id: string;
  staff_id: string;
  request_date: string;
  reason: string;
  status: 'pending' | 'approved' | 'rejected';
  admin_response?: string;
  reviewed_by?: string;
  reviewed_at?: string;
  created_at: string;
}

const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const SHIFT_COLORS = {
  early: 'bg-blue-100 text-blue-800 border-blue-300',
  late: 'bg-orange-100 text-orange-800 border-orange-300',
  off: 'bg-gray-100 text-gray-800 border-gray-300',
};

const SHIFT_LABELS = {
  early: 'Early',
  late: 'Late',
  off: 'Off',
};

interface SchedulesProps {
onNavigate?: (view: string) => void;
  onBack?: () => void;
}

export function Schedules({ onNavigate, onBack }: SchedulesProps = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { profiles } = useProfiles();
  const [currentWeekStart, setCurrentWeekStart] = useState<Date>(getMonday(new Date()));
  const [weekSchedules, setWeekSchedules] = useState<WeekSchedule[]>([]);
  const [timeOffRequests, setTimeOffRequests] = useState<TimeOffRequest[]>([]);
  const [showTimeOffModal, setShowTimeOffModal] = useState(false);
  const [showRequestsModal, setShowRequestsModal] = useState(false);
  const [selectedRequest, setSelectedRequest] = useState<TimeOffRequest | null>(null);
  const [timeOffReason, setTimeOffReason] = useState('');
  const [selectedDate, setSelectedDate] = useState('');
  const [rejectionReason, setRejectionReason] = useState('');
  const [activeTab, setActiveTab] = useState<'shifts' | 'patrol'>('shifts');

  const isAdmin = profile?.role === 'admin';
  const staffMembers = profiles.filter((p) => p.role === 'staff');

  useEffect(() => {
    loadWeekSchedules();
    loadTimeOffRequests();
  }, [currentWeekStart]);

  function getMonday(date: Date): Date {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    return new Date(d.setDate(diff));
  }

  function formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  function getWeekDates(monday: Date): string[] {
    return Array.from({ length: 7 }, (_, i) => {
      const date = new Date(monday);
      date.setDate(monday.getDate() + i);
      return formatDate(date);
    });
  }

  function canRequestTimeOff(): boolean {
    const now = new Date();
    const currentDay = now.getDay();
    const currentHour = now.getHours();

    const thisWeeksMonday = getMonday(new Date());
    const nextWeeksMonday = new Date(thisWeeksMonday);
    nextWeeksMonday.setDate(nextWeeksMonday.getDate() + 7);

    const isFriday = currentDay === 5;
    const isPastFridayDeadline = isFriday && currentHour >= 13;
    const isAfterFriday = currentDay === 6 || currentDay === 0;

    const requestingForNextWeek = currentWeekStart >= nextWeeksMonday;

    if (requestingForNextWeek && (isPastFridayDeadline || isAfterFriday)) {
      return false;
    }

    return true;
  }

  const loadWeekSchedules = async () => {
    try {
      const weekStart = formatDate(currentWeekStart);
      const { data, error } = await supabase
        .from('weekly_schedules')
        .select('*')
        .eq('week_start_date', weekStart);

      if (error) throw error;
      setWeekSchedules(data || []);
    } catch (error) {
      console.error('Error loading schedules:', error);
    }
  };

  const loadTimeOffRequests = async () => {
    try {
      const weekDates = getWeekDates(currentWeekStart);
      const { data, error } = await supabase
        .from('time_off_requests')
        .select('*')
        .gte('request_date', weekDates[0])
        .lte('request_date', weekDates[6])
        .order('created_at', { ascending: false });

      if (error) throw error;
      setTimeOffRequests(data || []);
    } catch (error) {
      console.error('Error loading time-off requests:', error);
    }
  };

  const getStaffSchedule = (staffId: string): WeekSchedule | null => {
    return weekSchedules.find((s) => s.staff_id === staffId) || null;
  };

  const handleShiftClick = async (staffId: string, dayIndex: number, currentShift?: ShiftType) => {
    if (!isAdmin) return;

    const shifts: ShiftType[] = ['early', 'late', 'off'];
    const currentIndex = currentShift ? shifts.indexOf(currentShift) : -1;
    const nextShift = shifts[(currentIndex + 1) % shifts.length];

    const weekDates = getWeekDates(currentWeekStart);
    const schedule = getStaffSchedule(staffId);

    const newShifts: DayShift[] = DAYS.map((day, index) => {
      const existingShift = schedule?.shifts.find((s) => s.day === day.toLowerCase());
      if (index === dayIndex) {
        return {
          day: day.toLowerCase(),
          date: weekDates[index],
          shift: nextShift,
        };
      }
      return existingShift || {
        day: day.toLowerCase(),
        date: weekDates[index],
        shift: 'off' as ShiftType,
      };
    });

    try {
      const weekStart = formatDate(currentWeekStart);

      if (schedule) {
        const { error } = await supabase
          .from('weekly_schedules')
          .update({
            shifts: newShifts,
            updated_at: new Date().toISOString(),
          })
          .eq('id', schedule.id);

        if (error) throw error;
      } else {
        const { error } = await supabase.from('weekly_schedules').insert({
          staff_id: staffId,
          week_start_date: weekStart,
          shifts: newShifts,
          is_published: false,
          created_by: profile?.id,
        });

        if (error) throw error;
      }

      await loadWeekSchedules();
    } catch (error) {
      console.error('Error updating schedule:', error);
    }
  };

  const handlePublishSchedule = async () => {
    if (!isAdmin) return;

    try {
      const weekStart = formatDate(currentWeekStart);

      const { data: existingSchedules, error: fetchError } = await supabase
        .from('weekly_schedules')
        .select('id')
        .eq('week_start_date', weekStart);

      if (fetchError) throw fetchError;

      if (!existingSchedules || existingSchedules.length === 0) {
        alert('No schedules found for this week. Please create schedules first.');
        return;
      }

      const { error } = await supabase
        .from('weekly_schedules')
        .update({
          is_published: true,
          published_at: new Date().toISOString(),
        })
        .eq('week_start_date', weekStart);

      if (error) throw error;

      alert(`Successfully published ${existingSchedules.length} schedule(s) for this week!`);

      const staffIds = staffMembers.map((s) => s.id);
      await supabase.from('notifications').insert(
        staffIds.map((staffId) => ({
          user_id: staffId,
          title: 'Schedule Published',
          message: `Your schedule for week of ${currentWeekStart.toLocaleDateString()} has been published`,
          type: 'schedule',
        }))
      );

      await loadWeekSchedules();
    } catch (error) {
      console.error('Error publishing schedule:', error);
    }
  };

  const handleTimeOffRequest = async () => {
    if (!selectedDate || !timeOffReason.trim()) {
      alert('Please select a date and provide a reason');
      return;
    }

    if (!canRequestTimeOff()) {
      alert('Deadline passed. Time-off requests for next week must be submitted before Friday 1:00 PM');
      return;
    }

    try {
      const { error } = await supabase.from('time_off_requests').insert({
        staff_id: profile?.id,
        request_date: selectedDate,
        reason: timeOffReason,
        status: 'pending',
      });

      if (error) throw error;

      const admins = profiles.filter((p) => p.role === 'admin');
      await supabase.from('notifications').insert(
        admins.map((admin) => ({
          user_id: admin.id,
          title: 'Time-Off Request',
          message: `${profile?.full_name} requested time off on ${new Date(selectedDate).toLocaleDateString()}`,
          type: 'schedule',
        }))
      );

      setShowTimeOffModal(false);
      setSelectedDate('');
      setTimeOffReason('');
      await loadTimeOffRequests();
    } catch (error) {
      console.error('Error submitting time-off request:', error);
    }
  };

  const handleApproveRequest = async (request: TimeOffRequest) => {
    try {
      const { error } = await supabase
        .from('time_off_requests')
        .update({
          status: 'approved',
          reviewed_by: profile?.id,
          reviewed_at: new Date().toISOString(),
        })
        .eq('id', request.id);

      if (error) throw error;

      await supabase.from('notifications').insert({
        user_id: request.staff_id,
        title: 'Time-Off Approved',
        message: `Your time-off request for ${new Date(request.request_date).toLocaleDateString()} has been approved`,
        type: 'schedule',
      });

      await loadTimeOffRequests();
      setSelectedRequest(null);
    } catch (error) {
      console.error('Error approving request:', error);
    }
  };

  const handleRejectRequest = async (request: TimeOffRequest) => {
    if (!rejectionReason.trim()) {
      alert('Please provide a reason for rejection');
      return;
    }

    try {
      const { error } = await supabase
        .from('time_off_requests')
        .update({
          status: 'rejected',
          admin_response: rejectionReason,
          reviewed_by: profile?.id,
          reviewed_at: new Date().toISOString(),
        })
        .eq('id', request.id);

      if (error) throw error;

      await supabase.from('notifications').insert({
        user_id: request.staff_id,
        title: 'Time-Off Rejected',
        message: `Your time-off request for ${new Date(request.request_date).toLocaleDateString()} was not approved. Reason: ${rejectionReason}`,
        type: 'schedule',
      });

      await loadTimeOffRequests();
      setSelectedRequest(null);
      setRejectionReason('');
    } catch (error) {
      console.error('Error rejecting request:', error);
    }
  };

  const previousWeek = () => {
    const newDate = new Date(currentWeekStart);
    newDate.setDate(newDate.getDate() - 7);
    setCurrentWeekStart(newDate);
  };

  const nextWeek = () => {
    const newDate = new Date(currentWeekStart);
    newDate.setDate(newDate.getDate() + 7);
    setCurrentWeekStart(newDate);
  };

  const weekDates = getWeekDates(currentWeekStart);
  const pendingRequests = timeOffRequests.filter((r) => r.status === 'pending');
  const isPublished = weekSchedules.some((s) => s.is_published);

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
          <h2 className="text-3xl font-bold text-gray-900">Schedule</h2>
        </div>
        {isAdmin && onNavigate && (
          <button
            onClick={() => onNavigate('patrol-schedules')}
            className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
          >
            <span>Patrol Schedule</span>
          </button>
        )}
        <div className="flex items-center space-x-4">
          {!isAdmin && (
            <button
              onClick={() => setShowTimeOffModal(true)}
              className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700"
              disabled={!canRequestTimeOff()}
            >
              <Calendar className="w-5 h-5" />
              <span>Request Time Off</span>
            </button>
          )}
          {isAdmin && pendingRequests.length > 0 && (
            <button
              onClick={() => setShowRequestsModal(true)}
              className="flex items-center space-x-2 bg-orange-600 text-white px-4 py-2 rounded-lg hover:bg-orange-700"
            >
              <Clock className="w-5 h-5" />
              <span>Pending Requests ({pendingRequests.length})</span>
            </button>
          )}
          {isAdmin && (
            <button
              onClick={handlePublishSchedule}
              className="flex items-center space-x-2 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700"
            >
              <Check className="w-5 h-5" />
              <span>{isPublished ? 'Republish Schedule' : 'Publish Schedule'}</span>
            </button>
          )}
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-6">
          <button
            onClick={previousWeek}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <ChevronLeft className="w-6 h-6 text-gray-600" />
          </button>
          <div className="text-center">
            <h3 className="text-xl font-bold text-gray-900">
              Week of {currentWeekStart.toLocaleDateString()}
            </h3>
            {isPublished && (
              <span className="inline-block mt-1 px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm font-medium">
                Published
              </span>
            )}
          </div>
          <button
            onClick={nextWeek}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <ChevronRight className="w-6 h-6 text-gray-600" />
          </button>
        </div>

        <div className="overflow-x-auto -mx-6 px-6">
          <table className="w-full min-w-[600px]">
            <thead>
              <tr className="border-b-2 border-gray-200">
                <th className="text-left py-2 px-2 font-bold text-gray-900 sticky left-0 bg-white w-32">
                  <span className="text-sm">Staff</span>
                </th>
                {DAYS.map((day, index) => (
                  <th key={day} className="text-center py-2 px-1 font-bold text-gray-900">
                    <div className="text-sm">{day.slice(0, 3)}</div>
                    <div className="text-xs font-normal text-gray-500">
                      {new Date(weekDates[index]).toLocaleDateString('en-US', {
                        month: 'short',
                        day: 'numeric',
                      })}
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {staffMembers.map((staff) => {
                const schedule = getStaffSchedule(staff.id);
                return (
                  <tr key={staff.id} className="border-b border-gray-100 hover:bg-beige-50">
                    <td className="py-2 px-2 font-medium text-gray-900 sticky left-0 bg-white text-sm">
                      {staff.full_name}
                    </td>
                    {DAYS.map((day, dayIndex) => {
                      const dayShift = schedule?.shifts.find((s) => s.day === day.toLowerCase());
                      const shift = dayShift?.shift || 'off';
                      const hasTimeOffRequest = timeOffRequests.find(
                        (r) =>
                          r.staff_id === staff.id &&
                          r.request_date === weekDates[dayIndex] &&
                          r.status === 'pending'
                      );

                      return (
                        <td key={day} className="py-1 px-1 text-center">
                          <button
                            onClick={() => handleShiftClick(staff.id, dayIndex, shift)}
                            disabled={!isAdmin}
                            className={`w-full py-1.5 px-2 rounded-lg border-2 font-medium text-xs transition-colors ${
                              SHIFT_COLORS[shift]
                            } ${isAdmin ? 'hover:opacity-80 cursor-pointer' : 'cursor-default'}`}
                          >
                            {SHIFT_LABELS[shift]}
                            {hasTimeOffRequest && (
                              <span className="ml-1 text-xs">📅</span>
                            )}
                          </button>
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {!canRequestTimeOff() && !isAdmin && (
          <div className="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
            <p className="text-sm text-yellow-800">
              The deadline for next week's time-off requests has passed (Friday 1:00 PM). You can request
              time off for the week after next.
            </p>
          </div>
        )}
      </div>

      {showTimeOffModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowTimeOffModal(false);
            setSelectedDate('');
            setTimeOffReason('');
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">Request Time Off</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Date</label>
                <input
                  type="date"
                  value={selectedDate}
                  onChange={(e) => setSelectedDate(e.target.value)}
                  min={weekDates[0]}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Reason</label>
                <textarea
                  value={timeOffReason}
                  onChange={(e) => setTimeOffReason(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={3}
                  placeholder="Please provide a brief reason..."
                  required
                />
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  onClick={() => {
                    setShowTimeOffModal(false);
                    setSelectedDate('');
                    setTimeOffReason('');
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                >
                  Cancel
                </button>
                <button
                  onClick={handleTimeOffRequest}
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  Submit Request
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showRequestsModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowRequestsModal(false);
            setSelectedRequest(null);
            setRejectionReason('');
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[80vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900">Pending Time-Off Requests</h3>
              <button
                onClick={() => {
                  setShowRequestsModal(false);
                  setSelectedRequest(null);
                  setRejectionReason('');
                }}
                className="p-2 hover:bg-gray-100 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="space-y-4">
              {pendingRequests.map((request) => {
                const staff = profiles.find((p) => p.id === request.staff_id);
                return (
                  <div key={request.id} className="border border-gray-200 rounded-lg p-4">
                    <div className="flex items-start justify-between mb-3">
                      <div>
                        <h4 className="font-bold text-gray-900">{staff?.full_name}</h4>
                        <p className="text-sm text-gray-600">
                          {new Date(request.request_date).toLocaleDateString('en-US', {
                            weekday: 'long',
                            month: 'long',
                            day: 'numeric',
                            year: 'numeric',
                          })}
                        </p>
                      </div>
                      <span className="bg-orange-100 text-orange-700 px-2 py-1 rounded text-xs font-medium">
                        Pending
                      </span>
                    </div>
                    <div className="mb-3">
                      <p className="text-sm text-gray-700">
                        <span className="font-medium">Reason:</span> {request.reason}
                      </p>
                    </div>
                    {selectedRequest?.id === request.id ? (
                      <div className="space-y-3">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-1">
                            Rejection Reason (required)
                          </label>
                          <textarea
                            value={rejectionReason}
                            onChange={(e) => setRejectionReason(e.target.value)}
                            className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                            rows={2}
                            placeholder="Provide reason for rejection..."
                          />
                        </div>
                        <div className="flex space-x-2">
                          <button
                            onClick={() => handleApproveRequest(request)}
                            className="flex-1 px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm"
                          >
                            Approve
                          </button>
                          <button
                            onClick={() => handleRejectRequest(request)}
                            className="flex-1 px-3 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm"
                          >
                            Reject
                          </button>
                          <button
                            onClick={() => {
                              setSelectedRequest(null);
                              setRejectionReason('');
                            }}
                            className="px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-sm"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <div className="flex space-x-2">
                        <button
                          onClick={() => handleApproveRequest(request)}
                          className="flex-1 px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm"
                        >
                          Approve
                        </button>
                        <button
                          onClick={() => setSelectedRequest(request)}
                          className="flex-1 px-3 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm"
                        >
                          Reject
                        </button>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
