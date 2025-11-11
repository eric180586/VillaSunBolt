import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { Shield, Search, Filter, ArrowLeft } from 'lucide-react';
import { toLocaleStringCambodia } from '../lib/dateUtils';

interface AdminLog {
  id: string;
  admin_id: string;
  action_type: string;
  target_type: string | null;
  target_id: string | null;
  target_name: string | null;
  details: any;
  created_at: string;
  admin_profile: {
    full_name: string;
    role: string;
  };
}

interface AdminLogsProps {
  onNavigate?: (view: string) => void;
}

export function AdminLogs({ onNavigate }: AdminLogsProps = {}) {
  const { profile } = useAuth();
  const [logs, setLogs] = useState<AdminLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterType, setFilterType] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    if (profile?.role === 'admin' || profile?.role === 'super_admin') {
      fetchLogs();
    }
  }, [profile]);

  const fetchLogs = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('admin_logs')
        .select(`
          *,
          admin_profile:profiles!admin_id(full_name, role)
        `)
        .order('created_at', { ascending: false })
        .limit(100);

      if (error) throw error;

      setLogs(data || []);
    } catch (error) {
      console.error('Error fetching admin logs:', error);
    } finally {
      setLoading(false);
    }
  };

  if (profile?.role !== 'admin' && profile?.role !== 'super_admin') {
    return (
      <div className="text-center py-12">
        <p className="text-gray-600">Nur für Admins verfügbar</p>
      </div>
    );
  }

  const getActionLabel = (actionType: string) => {
    const labels: { [key: string]: string } = {
      manual_checkout: 'Manuelles Auschecken',
      delete_profile: 'Profil gelöscht',
      delete_task: 'Aufgabe gelöscht',
      manual_checkin: 'Manuelles Einchecken',
      create_task: 'Aufgabe erstellt',
      update_points: 'Punkte geändert',
    };
    return labels[actionType] || actionType;
  };

  const getActionColor = (actionType: string) => {
    if (actionType.includes('delete')) return 'text-red-600 bg-red-100';
    if (actionType.includes('create')) return 'text-green-600 bg-green-100';
    if (actionType.includes('update')) return 'text-blue-600 bg-blue-100';
    return 'text-gray-600 bg-gray-100';
  };

  const filteredLogs = logs.filter((log) => {
    if (filterType !== 'all' && log.action_type !== filterType) return false;
    if (searchTerm && !log.target_name?.toLowerCase().includes(searchTerm.toLowerCase())) {
      return false;
    }
    return true;
  });

  const actionTypes = Array.from(new Set(logs.map((log) => log.action_type)));

  return (
    <div className="space-y-6">
      <div className="flex items-center space-x-4">
        {onNavigate && (
          <button
            onClick={() => onNavigate('admin-dashboard')}
            className="p-2 hover:bg-beige-100 rounded-lg transition-colors"
          >
            <ArrowLeft className="w-6 h-6 text-gray-700" />
          </button>
        )}
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Admin Activity Log</h2>
          <p className="text-gray-600 mt-1">
            {profile?.role === 'super_admin' ? 'Alle Admin Aktivitäten' : 'Deine Admin Aktivitäten'}
          </p>
        </div>
      </div>

      <div className="bg-white rounded-xl p-6 shadow-lg border border-gray-200">
        <div className="flex flex-col md:flex-row md:items-center md:space-x-4 space-y-4 md:space-y-0 mb-6">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="Suche nach Ziel..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
            />
          </div>

          <div className="flex items-center space-x-2">
            <Filter className="text-gray-600 w-5 h-5" />
            <select
              value={filterType}
              onChange={(e) => setFilterType(e.target.value)}
              className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-transparent"
            >
              <option value="all">Alle Aktionen</option>
              {actionTypes.map((type) => (
                <option key={type} value={type}>
                  {getActionLabel(type)}
                </option>
              ))}
            </select>
          </div>
        </div>

        {loading ? (
          <div className="text-center py-12">
            <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-orange-600"></div>
            <p className="text-gray-600 mt-4">Lade Logs...</p>
          </div>
        ) : filteredLogs.length === 0 ? (
          <div className="text-center py-12">
            <Shield className="w-16 h-16 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">Keine Logs gefunden</p>
          </div>
        ) : (
          <div className="space-y-3">
            {filteredLogs.map((log) => (
              <div
                key={log.id}
                className="border border-gray-200 rounded-lg p-4 hover:bg-gray-50 transition-colors"
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center space-x-3 mb-2">
                      <span
                        className={`px-3 py-1 rounded-full text-sm font-semibold ${getActionColor(
                          log.action_type
                        )}`}
                      >
                        {getActionLabel(log.action_type)}
                      </span>
                      {log.target_name && (
                        <span className="text-gray-700 font-medium">{log.target_name}</span>
                      )}
                    </div>

                    <div className="text-sm text-gray-600 space-y-1">
                      <p>
                        <span className="font-medium">Admin:</span> {log.admin_profile.full_name} (
                        {log.admin_profile.role === 'super_admin' ? 'Super Admin' : 'Admin'})
                      </p>
                      {log.target_type && (
                        <p>
                          <span className="font-medium">Typ:</span> {log.target_type}
                        </p>
                      )}
                      {log.details && Object.keys(log.details).length > 0 && (
                        <details className="mt-2">
                          <summary className="cursor-pointer text-orange-600 hover:text-orange-700">
                            Details anzeigen
                          </summary>
                          <pre className="mt-2 p-2 bg-gray-100 rounded text-xs overflow-auto">
                            {JSON.stringify(log.details, null, 2)}
                          </pre>
                        </details>
                      )}
                    </div>
                  </div>

                  <div className="text-right text-sm text-gray-500">
                    {toLocaleStringCambodia(log.created_at, 'de-DE')}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
