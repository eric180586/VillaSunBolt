import { useState, useEffect } from 'react';
import { Camera, X } from 'lucide-react';

interface PhotoRequirementDiceProps {
  onResult: (requiresPhoto: boolean) => void;
  onCancel: () => void;
}

export function PhotoRequirementDice({ onResult, onCancel }: PhotoRequirementDiceProps) {
  const [isRolling, setIsRolling] = useState(true);
  const [currentValue, setCurrentValue] = useState('🎲');
  const [finalResult, setFinalResult] = useState<boolean | null>(null);

  const symbols = ['📸', '✅', '🎯', '⭐', '🎲', '💫'];

  useEffect(() => {
    if (!isRolling) return;

    const interval = setInterval(() => {
      setCurrentValue(symbols[Math.floor(Math.random() * symbols.length)]);
    }, 80);

    return () => clearInterval(interval);
  }, [isRolling]);

  const handleStop = () => {
    setIsRolling(false);
    const requiresPhoto = Math.random() < 0.3;
    setFinalResult(requiresPhoto);

    setTimeout(() => {
      onResult(requiresPhoto);
    }, 1500);
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center p-4 z-50"
      onClick={onCancel}
    >
      <div
        className="bg-gradient-to-br from-purple-100 to-blue-100 rounded-2xl p-8 w-full max-w-md text-center relative shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onCancel}
          className="absolute top-4 right-4 text-gray-500 hover:text-gray-700"
        >
          <X className="w-6 h-6" />
        </button>

        <h3 className="text-2xl font-bold text-gray-900 mb-2">Foto-Check</h3>
        <p className="text-sm text-gray-600 mb-6">
          {isRolling ? 'Drücke STOP um zu würfeln!' : 'Ergebnis...'}
        </p>

        <div className="bg-white rounded-xl p-8 mb-6 shadow-inner">
          <div
            className={`text-8xl transition-all duration-300 ${
              isRolling ? 'animate-bounce' : 'scale-110'
            }`}
          >
            {finalResult === null ? (
              currentValue
            ) : finalResult ? (
              <span className="animate-pulse">📸</span>
            ) : (
              <span className="text-green-600">✅</span>
            )}
          </div>
        </div>

        {finalResult !== null && (
          <div className={`mb-4 p-4 rounded-lg ${
            finalResult
              ? 'bg-yellow-100 border-2 border-yellow-400'
              : 'bg-green-100 border-2 border-green-400'
          }`}>
            <p className={`font-bold text-lg ${
              finalResult ? 'text-yellow-900' : 'text-green-900'
            }`}>
              {finalResult ? '📸 Foto erforderlich!' : '✅ Kein Foto nötig!'}
            </p>
          </div>
        )}

        {isRolling ? (
          <button
            onClick={handleStop}
            className="w-full bg-gradient-to-r from-purple-600 to-blue-600 text-white px-8 py-4 rounded-xl font-bold text-xl hover:from-purple-700 hover:to-blue-700 transform hover:scale-105 transition-all shadow-lg"
          >
            🎲 STOP!
          </button>
        ) : finalResult === null ? (
          <div className="flex items-center justify-center space-x-2 text-gray-600">
            <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-purple-600"></div>
            <span>Wird ausgewertet...</span>
          </div>
        ) : (
          <div className="text-sm text-gray-500">
            Fenster schließt in Kürze...
          </div>
        )}
      </div>
    </div>
  );
}
