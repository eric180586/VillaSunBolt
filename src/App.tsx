// src/App.tsx
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import Layout from "./Layout";

// Pages, ggf. Dummy-Pages anlegen, wenn noch nicht vorhanden!
import Dashboard from "./routes/Dashboard";
import TaskDetail from "./routes/TaskDetail";
import HowToDetail from "./routes/HowToDetail";
import ChecklistDetail from "./routes/ChecklistDetail";
import NotFound from "./routes/NotFound";
// ... weitere Seiten

export default function App() {
  return (
    <BrowserRouter>
      <Layout>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/tasks/:id" element={<TaskDetail />} />
          <Route path="/howto/:id" element={<HowToDetail />} />
          <Route path="/checklists/:id" element={<ChecklistDetail />} />
          {/* Beispiel für weitere Seiten */}
          {/* <Route path="/profile" element={<Profile />} /> */}
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Layout>
    </BrowserRouter>
  );
}
