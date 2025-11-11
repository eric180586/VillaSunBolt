import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { ArrowLeft, Calendar, Download, Filter } from 'lucide-react';

interface CheckInRecord {
  id: string;
  user_id: string;
  check_in_time: string;
  checkout_time: string | null;
  shift_type: string;
  is_late: boolean;
  minutes_late: number;
  points_awarded: number;
  status: string;
  approved_by: string | null;
  approved_at: string | null;
  rejection_reason: string | null;
  profiles: {
    full_name: string;
  };
}

export function CheckInHistory({ onBack }: { onBack?: () => void } = {}) {
  const { profile } = useAuth();
  const [checkIns, setCheckIns] = useState<CheckInRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [currentPage, setCurrentPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const itemsPerPage = 50;

  useEffect(() => {
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
    const today = new Date();

    setStartDate(sixMonthsAgo.toISOString().split('T')[0]);
    setEndDate(today.toISOString().split('T')[0]);
  }, []);

  useEffect(() => {
    if (startDate && endDate && (profile?.role === 'admin' || profile?.role === 'super_admin')) {
      fetchCheckIns();
    }
  }, [startDate, endDate, statusFilter, currentPage, profile]);

  const fetchCheckIns = async () => {
    try {
      setLoading(true);

      const startDateTime = `${startDate}T00:00:00+07:00`;
      const endDateTime = `${endDate}T23:59:59+07:00`;

      let query = supabase
        .from('check_ins')
        .select(`
          *,
          profiles:user_id (full_name)
        `, { count: 'exact' })
        .gte('check_in_time', startDateTime)
        .lte('check_in_time', endDateTime)
        .order('check_in_time', { ascending: false })
        .range((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage - 1);

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter);
      }

      const { data, error, count } = await query;

      if (error) throw error;

      setCheckIns(data || []);
      setTotalCount(count || 0);
    } catch (error) {
      console.error('Error fetching check-in history:', error);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved':
        return 'bg-green-100 text-green-700 border-green-200';
      case 'rejected':
        return 'bg-red-100 text-red-700 border-red-200';
      case 'pending':
        return 'bg-yellow-100 text-yellow-700 border-yellow-200';
      default:
        return 'bg-gray-100 text-gray-700 border-gray-200';
    }
  };

  const formatDateTime = (dateString: string) => {
    return new Date(dateString).toLocaleString('de-DE', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const totalPages = Math.ceil(totalCount / itemsPerPage);

  if (profile?.role !== 'admin') {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600">Nur für Admins verfügbar</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
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
          <h2 className="text-3xl font-bold text-gray-900">Check-In Historie</h2>
          <p className="text-gray-600 mt-1">
            Alle Check-In Einträge der letzten 6 Monate
          </p>
        </div>
      </div>

      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <div className="flex items-center space-x-2 mb-4">
          <Filter className="w-5 h-5 text-gray-600" />
          <h3 className="text-lg font-semibold text-gray-900">Filter</h3>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Von
            </label>
            <input
              type="date"
              value={startDate}
              onChange={(e) => {
                setStartDate(e.target.value);
                setCurrentPage(1);
              }}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Bis
            </label>
            <input
              type="date"
              value={endDate}
              onChange={(e) => {
                setEndDate(e.target.value);
                setCurrentPage(1);
              }}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Status
            </label>
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setCurrentPage(1);
              }}
              className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500"
            >
              <option value="all">Alle</option>
              <option value="pending">Ausstehend</option>
              <option value="approved">Bestätigt</option>
              <option value="rejected">Abgelehnt</option>
            </select>
          </div>

          <div className="flex items-end">
            <button
              onClick={() => {
                setStatusFilter('all');
                const sixMonthsAgo = new Date();
                sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
                setStartDate(sixMonthsAgo.toISOString().split('T')[0]);
                setEndDate(new Date().toISOString().split('T')[0]);
                setCurrentPage(1);
              }}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Zurücksetzen
            </button>
          </div>
        </div>

        <div className="mt-4 text-sm text-gray-600">
          {totalCount} Einträge gefunden
        </div>
      </div>

      {loading ? (
        <div className="bg-white rounded-xl p-12 shadow-lg border border-gray-200 text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-orange-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Lädt...</p>
        </div>
      ) : checkIns.length === 0 ? (
        <div className="bg-white rounded-xl p-12 shadow-lg border border-gray-200 text-center">
          <Calendar className="w-16 h-16 text-gray-300 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-900 mb-2">Keine Einträge</h3>
          <p className="text-gray-600">Keine Check-Ins im gewählten Zeitraum</p>
        </div>
      ) : (
        <>
          <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead className="bg-gray-50 border-b border-gray-200">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Mitarbeiter
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Check-In
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Check-Out
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Schicht
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Verspätung
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Punkte
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {checkIns.map((checkIn) => (
                    <tr key={checkIn.id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">
                          {checkIn.profiles.full_name}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">
                          {formatDateTime(checkIn.check_in_time)}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">
                          {checkIn.checkout_time
                            ? formatDateTime(checkIn.checkout_time)
                            : '-'}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900 capitalize">
                          {checkIn.shift_type}schicht
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        {checkIn.is_late ? (
                          <span className="text-sm text-orange-600 font-medium">
                            +{checkIn.minutes_late} Min
                          </span>
                        ) : (
                          <span className="text-sm text-green-600">Pünktlich</span>
                        )}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span
                          className={`text-sm font-semibold ${
                            checkIn.points_awarded > 0
                              ? 'text-green-600'
                              : checkIn.points_awarded < 0
                              ? 'text-red-600'
                              : 'text-gray-600'
                          }`}
                        >
                          {checkIn.points_awarded > 0 ? '+' : ''}
                          {checkIn.points_awarded}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span
                          className={`px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full border ${getStatusColor(
                            checkIn.status
                          )}`}
                        >
                          {checkIn.status === 'approved'
                            ? 'Bestätigt'
                            : checkIn.status === 'rejected'
                            ? 'Abgelehnt'
                            : 'Ausstehend'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          {totalPages > 1 && (
            <div className="flex items-center justify-between bg-white px-6 py-4 rounded-xl shadow-lg border border-gray-200">
              <div className="text-sm text-gray-600">
                Seite {currentPage} von {totalPages}
              </div>
              <div className="flex space-x-2">
                <button
                  onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Zurück
                </button>
                <button
                  onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Weiter
                </button>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}
