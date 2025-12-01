import React from "react";
import { useParams } from "react-router-dom";

export default function ChecklistDetail() {
  const { id } = useParams<{ id: string }>();
  // Hole Checklist-Details per ID (API/Hooks)
  return (
    <div>
      <h2>Checkliste: {id}</h2>
      {/* Checklist-Infos, Abhaken usw. */}
      <p>Alle Einträge und Schritte dieser Checkliste werden hier angezeigt.</p>
    </div>
  );
}
