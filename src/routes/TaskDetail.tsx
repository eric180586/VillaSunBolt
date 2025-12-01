import React from "react";
import { useParams } from "react-router-dom";

export default function TaskDetail() {
  const { id } = useParams<{ id: string }>();
  // Hole Task-Details per ID (API/Hooks)
  return (
    <div>
      <h2>Aufgabe: {id}</h2>
      {/* Detailinfos, Aktionen usw. */}
      <p>Hier erscheinen alle Infos zur gewählten Aufgabe.</p>
    </div>
  );
}
