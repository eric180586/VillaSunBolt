import React from "react";
import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";

export default function ChecklistDetail() {
  const { t } = useTranslation();
  const { id } = useParams<{ id: string }>();
  return (
    <div>
      <h2>{t("checklist_title", { id })}</h2>
      <p>{t("checklist_info")}</p>
    </div>
  );
}
