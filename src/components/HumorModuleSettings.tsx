import { useHumorModules } from '../hooks/useHumorModules';
import { ToggleLeft, ToggleRight, ArrowLeft } from 'lucide-react';

export function HumorModuleSettings({ onBack }: { onBack?: () => void } = {}) {
  const { modules, loading, toggleModule } = useHumorModules();

  if (loading) {
    return (
      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
        <p className="text-gray-500">Loading...</p>
      </div>
    );
  }

  return (
    <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
      <h2 className="text-2xl font-bold text-gray-900 mb-4">Progress Bar Humor Modules</h2>
      <p className="text-gray-600 mb-6">
        Enable or disable humor modules that appear on the dashboard progress bar.
      </p>

      <div className="space-y-4">
        {modules.map((module) => (
          <div
            key={module.id}
            className="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <div className="flex-1">
              <h3 className="font-semibold text-gray-900">{module.label}</h3>
              <p className="text-sm text-gray-600 mt-1">
                {module.percentage}% of daily todo time
              </p>
            </div>
            <button
              onClick={() => toggleModule(module.id, !module.is_active)}
              className={`flex items-center space-x-2 px-4 py-2 rounded-lg font-medium transition-all ${
                module.is_active
                  ? 'bg-green-100 text-green-700 hover:bg-green-200'
                  : 'bg-gray-200 text-gray-600 hover:bg-gray-300'
              }`}
            >
              {module.is_active ? (
                <>
                  <ToggleRight className="w-5 h-5" />
                  <span>Active</span>
                </>
              ) : (
                <>
                  <ToggleLeft className="w-5 h-5" />
                  <span>Inactive</span>
                </>
              )}
            </button>
          </div>
        ))}
      </div>

      <div className="mt-6 p-4 bg-blue-50 rounded-lg">
        <p className="text-sm text-blue-800">
          <strong>Tip:</strong> Active modules will appear automatically on the staff dashboard
          progress bar. They show estimated time based on the percentage of daily work hours.
        </p>
      </div>
    </div>
  );
}
