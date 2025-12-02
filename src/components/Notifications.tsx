import React from "react";

type Notification = {
  id: string;
  type: string;
  entityId?: string;
  message: string;
  timestamp: string;
  read?: boolean;
};

interface Props {
  notifications: Notification[];
  markAsRead: (id: string) => void;
  onClick: (notification: Notification) => void;
}

export const Notifications: React.FC<Props> = ({
  notifications,
  markAsRead,
  onClick,
}) => (
  <div className="notifications-list">
    <h2>Benachrichtigungen</h2>
    {notifications.length === 0 && (
      <div>Keine Benachrichtigungen vorhanden.</div>
    )}
    <ul>
      {notifications.map((n) => (
        <li
          key={n.id}
          className={`notification ${n.read ? "read" : "unread"}`}
          onClick={() => n.entityId && onClick(n)}
          style={{ cursor: n.entityId ? "pointer" : "default" }}
          tabIndex={0}
          onKeyDown={(e) => e.key === "Enter" && n.entityId && onClick(n)}
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
