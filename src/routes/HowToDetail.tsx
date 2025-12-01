import React from "react";
import { useParams } from "react-router-dom";

export default function HowToDetail() {
  const { id } = useParams<{ id: string }>();
  // Hole HowTo-Details per ID (API/Hooks)
  return (
    <div>
      <h2>How-To: {id}</h2>
      {/* Detailinfos, Tutorials usw. */}
      <p>Hier findest du Anleitungen und Tipps zu diesem Thema.</p>
    </div>
  );
}
