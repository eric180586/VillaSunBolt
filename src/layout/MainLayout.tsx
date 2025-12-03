import { ReactNode, useState } from "react";
import { LogOut, Menu, X, Bell, User } from "lucide-react";
import { useAuth } from "../contexts/AuthContext";
import { useTranslation } from "react-i18next";

const navItems = [
  { id: "dashboard", label: "Dashboard" },
  { id: "tasks", label: "Tasks" },
  { id: "patrol", label: "Patrol Rounds" },
  { id: "schedules", label: "Schedules" },
  { id: "notes", label: "Notes" },
  { id: "chat", label: "Chat" },
  { id: "howto", label: "How-To" },
  { id: "leaderboard", label: "Leaderboard" },
];

interface Props {
  children: ReactNode;
  onNavigate?: (id: string) => void;
  currentView?: string;
}

export default function MainLayout({ children, onNavigate, currentView }: Props) {
  const { profile, signOut } = useAuth();
  const { t, i18n } = useTranslation();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen flex bg-gradient-to-br from-white via-beige-50 to-beige-100">
      {/* Sidebar */}
      <div
        className={`fixed inset-y-0 left-0 z-30 w-64 bg-white shadow-lg border-r border-beige-200 flex flex-col transition-transform duration-300 ${
          sidebarOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"
        }`}
      >
        <div className="h-16 flex items-center px-6 border-b">
          <span className="text-xl font-bold text-beige-900 tracking-tight">Villa Sun</span>
          <button
            className="lg:hidden ml-auto p-2"
            onClick={() => setSidebarOpen(false)}
          >
            <X className="w-6 h-6" />
          </button>
        </div>
        <nav className="flex-1 py-6 space-y-1">
          {navItems.map((item) => (
            <button
              key={item.id}
              onClick={() => onNavigate?.(item.id)}
              className={`w-full text-left px-6 py-2 rounded-lg flex items-center gap-3 text-lg font-medium ${
                currentView === item.id
                  ? "bg-beige-200 text-beige-900"
                  : "text-gray-700 hover:bg-beige-100"
              }`}
            >
              <span>{t(`nav.${item.id}`, item.label)}</span>
            </button>
          ))}
        </nav>
        <div className="border-t px-6 py-4 flex items-center gap-3">
          <User className="w-6 h-6" />
          <span className="font-medium flex-1 truncate">{profile?.full_name || "Profil"}</span>
          <button onClick={signOut} title={t("logout")}>
            <LogOut className="w-6 h-6 text-gray-400 hover:text-red-500" />
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Topbar */}
        <header className="h-16 flex items-center px-4 lg:px-8 bg-white border-b shadow-sm">
          <button
            className="lg:hidden mr-4"
            onClick={() => setSidebarOpen(true)}
          >
            <Menu className="w-6 h-6" />
          </button>
          <span className="text-lg font-bold text-beige-900 flex-1">Villa Sun Mitarbeiter-Portal</span>
          <select
            value={i18n.language}
            onChange={(e) => i18n.changeLanguage(e.target.value)}
            className="border rounded px-2 py-1 mr-2 bg-beige-50"
          >
            <option value="de">DE</option>
            <option value="en">EN</option>
            <option value="km">ខ្មែរ</option>
          </select>
          <button className="relative p-2 ml-2">
            <Bell className="w-6 h-6 text-beige-900" />
            {/* TODO: Notification badge */}
          </button>
        </header>
        {/* Main Content */}
        <main className="flex-1 px-4 py-6 lg:px-10 bg-beige-50">{children}</main>
      </div>
    </div>
  );
}
