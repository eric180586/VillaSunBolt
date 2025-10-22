import { X, Users } from 'lucide-react';
import { useProfiles } from '../hooks/useProfiles';

interface HelperSelectionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSelectHelper: (helperId: string | null) => void;
  currentUserId?: string;
}

export function HelperSelectionModal({
  isOpen,
  onClose,
  onSelectHelper,
  currentUserId,
}: HelperSelectionModalProps) {
  const { profiles } = useProfiles();

  if (!isOpen) return null;

  const staffMembers = profiles.filter(
    (p) => p.role === 'staff' && p.id !== currentUserId
  );

  const handleSelectHelper = (helperId: string | null) => {
    onSelectHelper(helperId);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Users className="w-6 h-6 text-blue-600" />
            <h3 className="text-xl font-semibold text-gray-900">
              Hattest du Hilfe?
            </h3>
          </div>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-6 space-y-3">
          <p className="text-gray-600 mb-4">
            Hat dir jemand bei dieser Aufgabe geholfen? Die Punkte werden 50/50 aufgeteilt.
          </p>

          <button
            onClick={() => handleSelectHelper(null)}
            className="w-full px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium"
          >
            Nein, ich habe alleine gearbeitet
          </button>

          <div className="border-t border-gray-200 pt-4 mt-4">
            <p className="text-sm font-medium text-gray-700 mb-3">
              Oder wähle einen Helfer:
            </p>
            <div className="space-y-2">
              {staffMembers.map((staff) => (
                <button
                  key={staff.id}
                  onClick={() => handleSelectHelper(staff.id)}
                  className="w-full px-4 py-3 bg-blue-50 text-blue-900 rounded-lg hover:bg-blue-100 transition-colors text-left font-medium"
                >
                  {staff.full_name}
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
