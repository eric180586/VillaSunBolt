import React from "react";
import { useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";

export default function HowToDetail() {
  const { t } = useTranslation();
  const { id } = useParams<{ id: string }>();
  return (
    <div>
      <h2>{t("howto_title", { id })}</h2>
      <p>{t("howto_info")}</p>
    </div>
  );
}
