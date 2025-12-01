// src/App.tsx
import React, { useState } from "react";
import { Routes, Route, useNavigate, useLocation } from "react-router-dom";
import { useRealtimeSubscription } from "./hooks/useRealtimeSubscription";
import { Notifications } from "./components/Notifications";
import { ConnectionStatusIndicator } from "./components/ConnectionStatusIndicator";

import Dashboard from "./routes/Dashboard";
import TaskDetail from "./routes/TaskDetail";
import HowToDetail from "./routes/HowToDetail";
import ChecklistDetail from "./routes/ChecklistDetail";
import NotFound from "./routes/NotFound";

// Beispielinitialisierung – später aus Datenbank/State laden!
const initialNotifications = [
  // { id: "n1", type: "task", entityId: "t123", message: "Neue Aufgabe verfügbar!", timestamp: new Date().toISOString() }
];

export default function App() {
  // Echtzeit-Status für die wichtigsten Channels
  const tasks = useRealtimeSubscription("tasks-channel", "tasks", () => {});
  const howtos = useRealtimeSubscription("howto-channel", "howtos", () => {});
  const checklists = useRealtimeSubscription("checklists-channel", "checklists", () => {});
  const notificationsRealtime = useRealtimeSubscription("notifications-channel", "notifications", () => {});

  const [notifications, setNotifications] = useState(initialNotifications);

  const markAsRead = (id: string) =>
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, read: true } : n))
    );

  // Navigation nach Notification-Klick (Deep-Link)
  const navigate = useNavigate();
  const handleNotificationClick = (notification: any) => {
    if (notification.type === "task") {
      navigate(`/tasks/${notification.entityId}`);
    } else if (notification.type === "howto") {
      navigate(`/howto/${notification.entityId}`);
    } else if (notification.type === "checklist") {
      navigate(`/checklists/${notification.entityId}`);
    }
    markAsRead(notification.id);
  };

  // Status-Aggregator
  const status = [tasks.status, howtos.status, checklists.status, notificationsRealtime.status]
    .includes("disconnected")
    ? "disconnected"
    : [tasks.status, howtos.status, checklists.status, notificationsRealtime.status]
        .includes("reconnecting")
    ? "reconnecting"
    : "connected";

  const error =
    tasks.error ||
    howtos.error ||
    checklists.error ||
    notificationsRealtime.error;

  return (
    <div>
      <header>
        <h1>Hotel Bonus Mitarbeiter App</h1>
        <ConnectionStatusIndicator status={status} error={error} />
      </header>
      <main>
        <Notifications
          notifications={notifications}
          markAsRead={markAsRead}
          onClick={handleNotificationClick}
        />
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/tasks/:id" element={<TaskDetail />} />
          <Route path="/howto/:id" element={<HowToDetail />} />
          <Route path="/checklists/:id" element={<ChecklistDetail />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </main>
    </div>
  );
}
