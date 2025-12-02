import React from "react";
import { useTranslation } from "react-i18next";

interface Props {
  status: "connected" | "reconnecting" | "disconnected";
  error?: any;
}

export const ConnectionStatusIndicator: React.FC<Props> = ({ status, error }) => {
  const { t } = useTranslation();
  let color = "green";
  let text = t("status_live");
  if (status === "reconnecting") {
    color = "orange";
    text = t("status_reconnecting");
  }
  if (status === "disconnected") {
    color = "red";
    text = t("status_disconnected");
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
