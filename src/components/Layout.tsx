// src/Layout.tsx
import { ReactNode } from "react";
import {
  Home,
  CheckSquare,
  Award,
  User,
  Users,
  LogOut,
  Menu,
  Bell,
  BookOpen,
  MessageCircle,
  TrendingUp,
  Shield,
  Calendar,
  StickyNote,
  Smile,
} from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import { useAuth } from "./contexts/AuthContext"; // optional, je nach deinem Stand
import { useNotifications } from "./hooks/useNotifications"; // optional
import { useTranslation } from "react-i18next";

interface LayoutProps {
  children: ReactNode;
}

export default function Layout({ children }: LayoutProps) {
  const { t, i18n } = useTranslation();
  // Optionales Auth-System, falls vorhanden
  const { profile, signOut } = useAuth?.() || { profile: null, signOut: () => {} };
  const { unreadCount } = useNotifications?.() || { unreadCount: 0 };

  const location = useLocation();
  const isAdmin = profile?.role === "admin";

  // Menü-Definition
  const menuItems = [
    { to: "/", label: t("nav.dashboard"), icon: Home },
    { to: "/tasks", label: t("nav.tasks"), icon: CheckSquare },
    { to: "/patrol", label: t("nav.patrol"), icon: Shield },
    { to: "/schedules", label: t("nav.schedules"), icon: Calendar },
    { to: "/notes", label: t("nav.notes"), icon: StickyNote },
    { to: "/chat", label: t("nav.chat"), icon: MessageCircle },
    { to: "/howto", label: t("nav.howTo"), icon: BookOpen },
    {
      to: isAdmin ? "/points-manager" : "/leaderboard",
      label: isAdmin ? t("nav.pointsManager") : t("nav.leaderboard"),
      icon: Award,
    },
    ...(isAdmin
      ? [
          { to: "/monthly-points", label: t("nav.monthlyPoints"), icon: TrendingUp },
          { to: "/employees", label: t("nav.employees"), icon: Users },
          { to: "/humor-settings", label: t("nav.humorSettings"), icon: Smile },
        ]
      : []),
  ];

  return (
    <div className="min-h-screen flex bg-gray-50">
      {/* Sidebar */}
      <aside className="hidden md:flex md:flex-col w-64 bg-white border-r border-gray-200 p-6">
        <div className="flex items-center mb-8">
          <span className="text-2xl font-extrabold tracking-tight text-blue-700">Hotel Bonus App</span>
        </div>
        <nav className="flex-1 space-y-2">
          {menuItems.map((item) => {
            const Icon = item.icon;
            const active = location.pathname === item.to || (item.to !== "/" && location.pathname.startsWith(item.to));
            return (
              <Link
                key={item.to}
                to={item.to}
                className={`flex items-center px-4 py-2 rounded-lg transition-colors ${
                  active ? "bg-blue-100 text-blue-700 font-bold" : "text-gray-700 hover:bg-gray-100"
                }`}
              >
                <Icon className="w-5 h-5 mr-3" />
                {item.label}
              </Link>
            );
          })}
        </nav>
        <div className="mt-8 flex flex-col gap-3">
          <Link to="/profile" className="flex items-center p-2 hover:bg-gray-100 rounded-lg">
            <User className="w-5 h-5 mr-2" />
            <span>{profile?.full_name || "Profil"}</span>
          </Link>
          <button
            className="flex items-center p-2 hover:bg-red-100 rounded-lg text-red-600"
            onClick={signOut}
          >
            <LogOut className="w-5 h-5 mr-2" />
            Abmelden
          </button>
        </div>
      </aside>
      {/* Mobile Sidebar - kann später ausgebaut werden */}
      <div className="md:hidden fixed z-50 top-0 left-0 w-full bg-white border-b border-gray-200 flex items-center px-4 h-16">
        <span className="font-bold text-lg">Hotel Bonus App</span>
        {/* TODO: Offcanvas-Menü für Mobile */}
      </div>
      {/* Main Content */}
      <div className="flex-1 flex flex-col min-h-screen">
        {/* Topbar */}
        <header className="flex justify-between items-center bg-white shadow px-6 py-4">
          <div className="flex items-center gap-4">
            {/* Optional: Hamburger für mobile */}
          </div>
          <div className="flex items-center gap-4">
            <button className="relative">
              <Bell className="w-6 h-6" />
              {unreadCount > 0 && (
                <span className="absolute -top-1 -right-1 text-xs w-5 h-5 bg-red-500 text-white rounded-full flex items-center justify-center">
                  {unreadCount}
                </span>
              )}
            </button>
            <select
              value={i18n.language}
              onChange={(e) => i18n.changeLanguage(e.target.value)}
              className="border rounded p-1"
            >
              <option value="de">Deutsch</option>
              <option value="en">English</option>
              <option value="km">ភាសាខ្មែរ</option>
            </select>
          </div>
        </header>
        {/* Content */}
        <main className="flex-1 p-6 bg-gray-50">{children}</main>
      </div>
    </div>
  );
}
