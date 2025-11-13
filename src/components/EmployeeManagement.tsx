import { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { Plus, X, Edit2, Trash2, Users, Mail, Shield, Award, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useTranslation } from 'react-i18next';

interface Employee {
  id: string;
  email: string;
  full_name: string;
  role: 'admin' | 'staff';
  total_points: number;
  created_at: string;
}

export function EmployeeManagement({ onBack }: { onBack?: () => void } = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [editingEmployee, setEditingEmployee] = useState<Employee | null>(null);
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    full_name: '',
    role: 'staff' as 'admin' | 'staff',
  });

  const isAdmin = profile?.role === 'admin';

  useEffect(() => {
    if (isAdmin) {
      loadEmployees();
    }
  }, [isAdmin]);

  const loadEmployees = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      setEmployees(data || []);
    } catch (error) {
      console.error('Error loading employees:', error);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (editingEmployee) {
      await handleUpdate();
    } else {
      await handleCreate();
    }
  };

  const handleCreate = async () => {
    try {
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: formData.email,
        password: formData.password,
        options: {
          emailRedirectTo: undefined,
          data: {
            full_name: formData.full_name,
            role: formData.role,
          },
        },
      });

      if (authError) throw authError;

      if (!authData.user) {
        throw new Error('Benutzer konnte nicht erstellt werden');
      }

      await new Promise(resolve => setTimeout(resolve, 2000));

      const { error: profileError } = await supabase
        .from('profiles')
        .update({
          full_name: formData.full_name,
          role: formData.role,
        })
        .eq('id', authData.user.id);

      if (profileError) {
        console.error('Error updating profile:', profileError);
      }

      if (authData.user.identities && authData.user.identities.length === 0) {
        alert(t('employees.employeeCreatedEmailConfirm'));
      } else {
        alert('Mitarbeiter erfolgreich erstellt! Login ist jetzt möglich.');
      }

      setShowModal(false);
      setFormData({ email: '', password: '', full_name: '', role: 'staff' });
      await loadEmployees();
    } catch (error: any) {
      console.error('Error creating employee:', error);

      if (error.message?.includes('User already registered')) {
        alert('Diese Email-Adresse ist bereits registriert.');
      } else if (error.message?.includes('Email rate limit')) {
        alert(t('employees.tooManyRequests'));
      } else {
        alert(error.message || t('employees.errorCreatingEmployee'));
      }
    }
  };

  const handleUpdate = async () => {
    if (!editingEmployee) return;

    try {
      const { error } = await supabase
        .from('profiles')
        .update({
          full_name: formData.full_name,
          role: formData.role,
        })
        .eq('id', editingEmployee.id);

      if (error) throw error;

      setShowModal(false);
      setEditingEmployee(null);
      setFormData({ email: '', password: '', full_name: '', role: 'staff' });
      await loadEmployees();
    } catch (error) {
      console.error('Error updating employee:', error);
      alert('Failed to update employee');
    }
  };

  const handleEdit = (employee: Employee) => {
    setEditingEmployee(employee);
    setFormData({
      email: employee.email,
      password: '',
      full_name: employee.full_name,
      role: employee.role,
    });
    setShowModal(true);
  };

  const handleDelete = async (employeeId: string) => {
    if (employeeId === profile?.id) {
      alert('You cannot delete your own account');
      return;
    }

    if (!confirm('Are you sure you want to delete this employee? This action cannot be undone.')) {
      return;
    }

    try {
      const { data: { session } } = await supabase.auth.getSession();

      if (!session) {
        throw new Error('Not authenticated');
      }

      const response = await fetch(
        `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/delete-user`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${session.access_token}`,
            'apikey': import.meta.env.VITE_SUPABASE_ANON_KEY,
          },
          body: JSON.stringify({ userId: employeeId }),
        }
      );

      const result = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(result.error || 'Failed to delete user');
      }

      alert('Employee successfully deleted');
      await loadEmployees();
    } catch (error: any) {
      console.error('Error deleting employee:', error);
      alert('Failed to delete employee: ' + (error.message || 'Unknown error'));
    }
  };

  if (!isAdmin) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500">Access denied. Admin only.</p>
      </div>
    );
  }

  const adminCount = employees.filter((e) => e.role === 'admin').length;
  const staffCount = employees.filter((e) => e.role === 'staff').length;

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
          <h2 className="text-3xl font-bold text-gray-900">Employee Management</h2>
        </div>
        <button
          onClick={() => {
            setEditingEmployee(null);
            setFormData({ email: '', password: '', full_name: '', role: 'staff' });
            setShowModal(true);
          }}
          className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          <Plus className="w-5 h-5" />
          <span>Add Employee</span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <Users className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Total Employees</p>
              <p className="text-2xl font-bold text-gray-900">{employees.length}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <Shield className="w-6 h-6 text-purple-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Admins</p>
              <p className="text-2xl font-bold text-gray-900">{adminCount}</p>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
          <div className="flex items-center space-x-3">
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <Users className="w-6 h-6 text-green-600" />
            </div>
            <div>
              <p className="text-sm text-gray-600">Staff</p>
              <p className="text-2xl font-bold text-gray-900">{staffCount}</p>
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-6 font-semibold text-gray-900">Name</th>
                <th className="text-left py-3 px-6 font-semibold text-gray-900">Email</th>
                <th className="text-left py-3 px-6 font-semibold text-gray-900">Role</th>
                <th className="text-left py-3 px-6 font-semibold text-gray-900">Points</th>
                <th className="text-left py-3 px-6 font-semibold text-gray-900">Joined</th>
                <th className="text-right py-3 px-6 font-semibold text-gray-900">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {employees.map((employee) => (
                <tr key={employee.id} className="hover:bg-gray-50">
                  <td className="py-4 px-6">
                    <div className="flex items-center space-x-3">
                      <div className="w-10 h-10 bg-gradient-to-br from-blue-500 to-blue-600 rounded-full flex items-center justify-center text-white font-bold">
                        {employee.full_name.charAt(0)}
                      </div>
                      <span className="font-medium text-gray-900">{employee.full_name}</span>
                    </div>
                  </td>
                  <td className="py-4 px-6 text-gray-600">{employee.email}</td>
                  <td className="py-4 px-6">
                    <span
                      className={`px-3 py-1 rounded-full text-sm font-medium ${
                        employee.role === 'admin'
                          ? 'bg-purple-100 text-purple-700'
                          : 'bg-green-100 text-green-700'
                      }`}
                    >
                      {employee.role}
                    </span>
                  </td>
                  <td className="py-4 px-6">
                    <div className="flex items-center space-x-2">
                      <Award className="w-4 h-4 text-yellow-500" />
                      <span className="font-medium text-gray-900">{employee.total_points}</span>
                    </div>
                  </td>
                  <td className="py-4 px-6 text-gray-600">
                    {new Date(employee.created_at).toLocaleDateString()}
                  </td>
                  <td className="py-4 px-6">
                    <div className="flex items-center justify-end space-x-2">
                      <button
                        onClick={() => handleEdit(employee)}
                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                        title="Edit"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      {employee.id !== profile?.id && (
                        <button
                          onClick={() => handleDelete(employee.id)}
                          className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowModal(false);
            setEditingEmployee(null);
            setFormData({ email: '', password: '', full_name: '', role: 'staff' });
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900">
                {editingEmployee ? 'Edit Employee' : 'Add New Employee'}
              </h3>
              <button
                onClick={() => {
                  setShowModal(false);
                  setEditingEmployee(null);
                  setFormData({ email: '', password: '', full_name: '', role: 'staff' });
                }}
                className="p-2 hover:bg-gray-100 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                <input
                  type="text"
                  value={formData.full_name}
                  onChange={(e) => setFormData({ ...formData, full_name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                  disabled={!!editingEmployee}
                />
              </div>

              {!editingEmployee && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
                  <input
                    type="password"
                    value={formData.password}
                    onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    required
                    minLength={6}
                  />
                  <p className="text-xs text-gray-500 mt-1">Minimum 6 characters</p>
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
                <select
                  value={formData.role}
                  onChange={(e) => setFormData({ ...formData, role: e.target.value as 'admin' | 'staff' })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  required
                >
                  <option value="staff">Staff</option>
                  <option value="admin">Admin</option>
                </select>
              </div>

              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false);
                    setEditingEmployee(null);
                    setFormData({ email: '', password: '', full_name: '', role: 'staff' });
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  {editingEmployee ? 'Update' : 'Create'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
