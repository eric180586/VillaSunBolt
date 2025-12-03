// src/routes/Dashboard.tsx
export default function Dashboard() {
  return (
    <div>
      <h2 className="text-2xl font-bold mb-6">Dashboard</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="font-semibold text-lg mb-2">Willkommen!</h3>
          <p>Hier findest du alle wichtigen Infos auf einen Blick.</p>
        </div>
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="font-semibold text-lg mb-2">Benachrichtigungen</h3>
          <p>Du hast keine neuen Nachrichten.</p>
        </div>
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="font-semibold text-lg mb-2">Letzte Aktivitäten</h3>
          <p>Hier erscheinen deine letzten Aktionen.</p>
        </div>
      </div>
    </div>
  );
}
