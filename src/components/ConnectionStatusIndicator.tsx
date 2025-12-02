import React from "react";

interface Props {
  status: "connected" | "reconnecting" | "disconnected";
  error?: any;
}

export const ConnectionStatusIndicator: React.FC<Props> = ({ status, error }) => {
  let color = "green";
  let text = "Live";
  if (status === "reconnecting") {
    color = "orange";
    text = "Verbindung wird wiederhergestellt...";
  }
  if (status === "disconnected") {
    color = "red";
    text = "Offline – Bitte Verbindung prüfen!";
  }
  return (
    <div
      className="connection-status-indicator"
      style={{
        display: "inline-block",
        padding: "6px 18px",
        borderRadius: "20px",
        background: color,
        color: "#fff",
        fontWeight: "bold",
        margin: "0 8px"
      }}
      title={error ? `Fehler: ${error}` : ""}
    >
      {text}
    </div>
  );
};
