// components/Notifications.tsx
import React from "react";
import { useNotifications } from "../hooks/useNotifications";
import { useNavigate } from "react-router-dom"; // ggf. ersetzen je nach Router

type Notification = {
  id: string;
  type: "task" | "howto" | "checklist" | "info" | string;
  entityId?: string;
  message: string;
  timestamp: string;
  read?: boolean;
};

interface Props {
  notifications: Notification[];
  markAsRead: (id: string) => void;
}

export const Notifications: React.FC<Props> = ({ notifications, markAsRead }) => {
  const { pushStatus, error } = useNotifications();
  const navigate = useNavigate();

  const handleNotificationClick = (notification: Notification) => {
    if (notification.type === "task") {
      navigate(`/tasks/${notification.entityId}`);
    } else if (notification.type === "howto") {
      navigate(`/howto/${notification.entityId}`);
    } else if (notification.type === "checklist") {
      navigate(`/checklists/${notification.entityId}`);
    }
    markAsRead(notification.id);
  };

  return (
    <div className="notifications-list">
      <h2>Benachrichtigungen</h2>
      {error && <div className="error">{error}</div>}
      {pushStatus === "not_supported" && (
        <div className="warning">Push-Benachrichtigungen werden nicht unterstützt.</div>
      )}
      {notifications.length === 0 && <div>Keine Benachrichtigungen vorhanden.</div>}
      <ul>
        {notifications.map((n) => (
          <li
            key={n.id}
            className={`notification ${n.read ? "read" : "unread"}`}
            onClick={() => handleNotificationClick(n)}
            style={{ cursor: n.entityId ? "pointer" : "default" }}
            tabIndex={0}
            onKeyDown={(e) => (e.key === "Enter" ? handleNotificationClick(n) : undefined)}
          >
            <div className="notification-message">{n.message}</div>
            <div className="notification-meta">
              <span>{new Date(n.timestamp).toLocaleString()}</span>
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
};
