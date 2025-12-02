import React from "react";
import { useTranslation } from "react-i18next";

export default function Dashboard() {
  const { t } = useTranslation();
  return (
    <div>
      <h2>{t("dashboard_title")}</h2>
      <p>{t("dashboard_welcome")}</p>
    </div>
  );
}
