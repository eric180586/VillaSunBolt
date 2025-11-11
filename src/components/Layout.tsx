import { ReactNode, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useNotifications } from '../hooks/useNotifications';
import { useTranslation } from 'react-i18next';
import {
  Home,
  CheckSquare,
  Calendar,
  ClipboardList,
  StickyNote,
  Award,
  Bell,
  User,
  Users,
  LogOut,
  Menu,
  X,
  Smile,
  Shield,
  TrendingUp,
  BookOpen,
  MessageCircle,
} from 'lucide-react';

interface LayoutProps {
  children: ReactNode;
  currentView: string;
  onViewChange: (view: string) => void;
}

export function Layout({ children, currentView, onViewChange }: LayoutProps) {
  const { profile, signOut } = useAuth();
  const { unreadCount, requestPermission } = useNotifications();
  const { t } = useTranslation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  const isAdmin = profile?.role === 'admin';

  const menuItems = [
    { id: 'dashboard', label: t('nav.dashboard'), icon: Home },
    { id: 'tasks', label: t('nav.tasks'), icon: CheckSquare },
    { id: 'patrol-rounds', label: t('nav.patrol'), icon: Shield },
    { id: 'schedules', label: t('nav.schedules'), icon: Calendar },
    { id: 'notes', label: t('nav.notes'), icon: StickyNote },
    { id: 'chat', label: 'Chat', icon: MessageCircle },
    { id: 'how-to', label: 'How-To', icon: BookOpen },
    { id: 'leaderboard', label: t('nav.leaderboard'), icon: Award },
    ...(isAdmin ? [
      { id: 'employees', label: t('nav.employees'), icon: Users },
      { id: 'humor-settings', label: t('nav.humorSettings'), icon: Smile },
      { id: 'daily-points', label: 'Punkteübersicht', icon: TrendingUp }
    ] : []),
  ];

  const handleViewChange = (view: string) => {
    onViewChange(view);
    setMobileMenuOpen(false);
    if (view === 'notifications') {
      requestPermission();
    }
  };

  return (
    <div className="min-h-screen bg-beige-50">
      <nav className="bg-white border-b border-beige-200 sticky top-0 z-50 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center">
              <button
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                className="lg:hidden p-2 rounded-lg hover:bg-gray-100"
              >
                {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
              </button>
              <h1 className="text-xl font-bold text-gray-900 ml-2 lg:ml-0">
                Villa Sun Team
              </h1>
            </div>

            <div className="hidden lg:flex items-center space-x-1">
              {menuItems.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.id}
                    onClick={() => handleViewChange(item.id)}
                    className={`flex items-center px-4 py-2 rounded-lg font-medium transition-colors ${
                      currentView === item.id
                        ? 'bg-beige-200 text-beige-800'
                        : 'text-gray-700 hover:bg-beige-100'
                    }`}
                  >
                    <Icon className="w-5 h-5 mr-2" />
                    {item.label}
                  </button>
                );
              })}
            </div>

            <div className="flex items-center space-x-2">
              <button
                onClick={() => handleViewChange('notifications')}
                className="relative p-2 rounded-lg hover:bg-gray-100"
              >
                <Bell className="w-6 h-6 text-gray-700" />
                {unreadCount > 0 && (
                  <span className="absolute top-0 right-0 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
                    {unreadCount}
                  </span>
                )}
              </button>

              <button
                onClick={() => handleViewChange('profile')}
                className="flex items-center space-x-2 p-2 rounded-lg hover:bg-gray-100"
              >
                <User className="w-6 h-6 text-gray-700" />
                <span className="hidden sm:block text-sm font-medium text-gray-700">
                  {profile?.full_name}
                </span>
              </button>

              <button
                onClick={() => signOut()}
                className="p-2 rounded-lg hover:bg-gray-100 text-gray-700"
              >
                <LogOut className="w-6 h-6" />
              </button>
            </div>
          </div>
        </div>

        {mobileMenuOpen && (
          <div className="lg:hidden border-t border-gray-200 bg-white">
            <div className="px-4 py-2 space-y-1">
              {menuItems.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    key={item.id}
                    onClick={() => handleViewChange(item.id)}
                    className={`w-full flex items-center px-4 py-3 rounded-lg font-medium transition-colors ${
                      currentView === item.id
                        ? 'bg-beige-200 text-beige-800'
                        : 'text-gray-700 hover:bg-beige-100'
                    }`}
                  >
                    <Icon className="w-5 h-5 mr-3" />
                    {item.label}
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </nav>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {children}
      </main>
    </div>
  );
}
