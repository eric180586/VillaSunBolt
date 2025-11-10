import { useEffect, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useTasks } from '../hooks/useTasks';
import { supabase } from '../lib/supabase';
import { Clock } from 'lucide-react';

export function ShiftProjection() {
  const { profile } = useAuth();
  const { tasks } = useTasks();
  const [projectedEndTime, setProjectedEndTime] = useState<string>('');
  const [message, setMessage] = useState<string>('');

  useEffect(() => {
    const calculateProjection = async () => {
      const today = new Date();
      today.setHours(0, 0, 0, 0);

      // Hole alle eingestempelten Mitarbeiter (approved check-ins) von heute
      const { data: checkedInUsers, error } = await supabase
        .from('check_ins')
        .select('user_id')
        .gte('check_in_time', today.toISOString())
        .eq('status', 'approved');

      if (error) {
        console.error('Error fetching check-ins:', error);
        return;
      }

      const checkedInCount = checkedInUsers?.length || 0;

      // Prüfe ob aktueller User eingecheckt ist
      const isCheckedIn = checkedInUsers?.some(ci => ci.user_id === profile?.id);

      if (!isCheckedIn) {
        setMessage('Please check in first');
        return;
      }

      // Hole alle offenen Tasks von heute (inkl. templates die heute relevant sind)
      const todayTasks = tasks.filter((t) => {
        if (t.status === 'completed' || t.status === 'cancelled' || t.status === 'archived') return false;

        // Tasks created today
        const createdDate = new Date(t.created_at);
        createdDate.setHours(0, 0, 0, 0);
        return createdDate.getTime() === today.getTime();
      });

      // Berechne estimated time für aktuellen User
      let minutesForCurrentUser = 0;

      todayTasks.forEach((task) => {
        const duration = task.duration_minutes || 0;

        if (task.assigned_to === profile?.id) {
          // Task ist mir zugewiesen
          minutesForCurrentUser += duration;
        } else if (task.helper_id === profile?.id) {
          // Ich bin Helper (geteilte Arbeit)
          minutesForCurrentUser += duration / 2;
        } else if (!task.assigned_to && !task.helper_id) {
          // Unassigned task - wird durch alle anwesenden Mitarbeiter geteilt
          minutesForCurrentUser += checkedInCount > 0 ? duration / checkedInCount : duration;
        }
        // Else: Task ist jemand anderem zugewiesen, zählt nicht für mich
      });

      const minutesPerPerson = minutesForCurrentUser;

      // Formatiere die Zeit
      const totalHours = Math.floor(minutesPerPerson / 60);
      const remainingMinutes = Math.round(minutesPerPerson % 60);
      const taskCount = todayTasks.length;

      if (taskCount === 0) {
        setMessage('All tasks done! Time to chill!');
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
          setMessage('All tasks done! Time to chill!');
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
              Based on remaining tasks and checked-in staff
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
