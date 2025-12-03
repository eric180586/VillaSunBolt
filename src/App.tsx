import { useState } from "react";
import { Routes, Route, useNavigate } from "react-router-dom";
import Dashboard from "./routes/Dashboard";
import TaskDetail from "./routes/TaskDetail";
import HowToDetail from "./routes/HowToDetail";
import ChecklistDetail from "./routes/ChecklistDetail";
import NotFound from "./routes/NotFound";
import MainLayout from "./layout/MainLayout";

export default function App() {
  const [currentView, setCurrentView] = useState("dashboard");
  const navigate = useNavigate();

  const handleNavigate = (view: string) => {
    setCurrentView(view);
    // Routen entsprechend dem Nav-Button
    if (view === "dashboard") navigate("/");
    else if (view === "tasks") navigate("/tasks");
    else if (view === "patrol") navigate("/patrol");
    else if (view === "schedules") navigate("/schedules");
    else if (view === "notes") navigate("/notes");
    else if (view === "chat") navigate("/chat");
    else if (view === "howto") navigate("/howto");
    else if (view === "leaderboard") navigate("/leaderboard");
  };

  return (
    <MainLayout currentView={currentView} onNavigate={handleNavigate}>
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/tasks/:id" element={<TaskDetail />} />
        <Route path="/howto/:id" element={<HowToDetail />} />
        <Route path="/checklists/:id" element={<ChecklistDetail />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </MainLayout>
  );
}
