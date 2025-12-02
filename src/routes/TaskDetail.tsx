import React from "react";
import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";

export default function TaskDetail() {
  const { t } = useTranslation();
  const { id } = useParams<{ id: string }>();
  return (
    <div>
      <h2>{t("task_title", { id })}</h2>
      <p>{t("task_info")}</p>
    </div>
  );
}
