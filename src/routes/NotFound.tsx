import React from "react";
import { useTranslation } from "react-i18next";

export default function NotFound() {
  const { t } = useTranslation();
  return (
    <div>
      <h2>{t("notfound_title")}</h2>
      <p>{t("notfound_back")}</p>
    </div>
  );
}
