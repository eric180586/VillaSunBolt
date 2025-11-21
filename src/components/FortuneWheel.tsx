import { useState } from 'react';
import { Trophy, X, Star } from 'lucide-react';
import { useTranslation } from 'react-i18next';

interface WheelSegment {
  id: string;
  label: string;
  rewardType: 'bonus_points';
  rewardValue: number;
  actualPoints: number;
  points?: number;
  color: string;
  icon: React.ElementType;
}

const getWheelSegments = (t: any): WheelSegment[] => [
  {
    id: '1',
    label: t('fortuneWheel.segment1Point'),
    rewardType: 'bonus_points',
    rewardValue: 1,
    actualPoints: -4,
    color: '#EF4444',
    icon: Star,
  },
  {
    id: '2',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#3B82F6',
    icon: Star,
  },
  {
    id: '3',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#10B981',
    icon: Star,
  },
  {
    id: '4',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#F59E0B',
    icon: Star,
  },
  {
    id: '5',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#8B5CF6',
    icon: Star,
  },
  {
    id: '6',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#EC4899',
    icon: Star,
  },
  {
    id: '7',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#14B8A6',
    icon: Star,
  },
  {
    id: '8',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#F97316',
    icon: Star,
  },
  {
    id: '9',
    label: t('fortuneWheel.segment5Points'),
    rewardType: 'bonus_points',
    rewardValue: 5,
    actualPoints: 0,
    color: '#6366F1',
    icon: Star,
  },
  {
    id: '10',
    label: t('fortuneWheel.segment10Points'),
    rewardType: 'bonus_points',
    rewardValue: 10,
    actualPoints: 5,
    color: '#22C55E',
    icon: Star,
  },
];

interface FortuneWheelProps {
  onClose: () => void;
  onSpinComplete: (segment: WheelSegment) => void;
}

export function FortuneWheel({ onClose, onSpinComplete }: FortuneWheelProps) {
  const { t } = useTranslation();
  const WHEEL_SEGMENTS = getWheelSegments(t);

  const [rotation, setRotation] = useState(0);
  const [isSpinning, setIsSpinning] = useState(false);
  const [selectedSegment, setSelectedSegment] = useState<WheelSegment | null>(null);
  const [showResult, setShowResult] = useState(false);
  const [currentRotation, setCurrentRotation] = useState(0);
  const [spinInterval, setSpinInterval] = useState<NodeJS.Timeout | null>(null);


  const stopWheel = () => {
    if (!isSpinning) return;

    if (spinInterval) {
      clearInterval(spinInterval);
      setSpinInterval(null);
    }

    const currentAngle = currentRotation % 360;
    const segmentAngle = 360 / WHEEL_SEGMENTS.length;
    const pointerAngle = 90;

    const winnerIndex = Math.floor(((360 - currentAngle + pointerAngle) % 360) / segmentAngle) % WHEEL_SEGMENTS.length;
    const winner = WHEEL_SEGMENTS[winnerIndex];

    setIsSpinning(false);
    setSelectedSegment(winner);
    setShowResult(true);
    onSpinComplete(winner);
  };

  const startSpinning = () => {
    setIsSpinning(true);

    const interval = setInterval(() => {
      setCurrentRotation(prev => {
        const newRotation = (prev + 15) % 360;
        setRotation(prev + 15);
        return newRotation;
      }) as any;
    }, 50);

    setSpinInterval(interval);
  };

  const getRewardDescription = (segment: WheelSegment) => {
    const plural = segment.rewardValue !== 1 ? 's' : '';
    return t('fortuneWheel.rewardDescription', { points: segment.rewardValue, plural }) as any;
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-70 flex items-center justify-center z-50 p-4"
      onClick={onClose}
    >
      <div
        className="bg-gradient-to-br from-yellow-50 to-orange-50 rounded-3xl p-8 max-w-2xl w-full shadow-2xl relative"
        onClick={(e) => e.stopPropagation()}
      >
        {!showResult && (
          <button
            onClick={onClose}
            className="absolute top-4 right-4 text-gray-500 hover:text-gray-700"
          >
            <X className="w-6 h-6" />
          </button>
        )}

        <div className="text-center mb-8">
          <div className="flex items-center justify-center space-x-3 mb-2">
            <Trophy className="w-10 h-10 text-yellow-600" />
            <h2 className="text-4xl font-bold text-gray-900">{t('fortuneWheel.title')}</h2>
            <Trophy className="w-10 h-10 text-yellow-600" />
          </div>
          <p className="text-gray-600 text-lg">{t('fortuneWheel.description')}</p>
        </div>

        {!showResult ? (
          <div className="relative">
            <div className="relative w-96 h-96 mx-auto">
              <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-full h-full">
                <svg
                  viewBox="0 0 400 400"
                  className="w-full h-full"
                  style={{
                    transform: `rotate(${rotation}deg)`,
                    transition: 'none',
                  }}
                >
                  {WHEEL_SEGMENTS.map((segment, index) => {
                    const angle = (360 / WHEEL_SEGMENTS.length) * index;
                    const nextAngle = angle + (360 / WHEEL_SEGMENTS.length);

                    const startX = 200 + 180 * Math.cos((angle - 90) * Math.PI / 180);
                    const startY = 200 + 180 * Math.sin((angle - 90) * Math.PI / 180);
                    const endX = 200 + 180 * Math.cos((nextAngle - 90) * Math.PI / 180);
                    const endY = 200 + 180 * Math.sin((nextAngle - 90) * Math.PI / 180);

                    return (
                      <g key={segment.id}>
                        <path
                          d={`M 200 200 L ${startX} ${startY} A 180 180 0 0 1 ${endX} ${endY} Z`}
                          fill={segment.color}
                          stroke="white"
                          strokeWidth="3"
                        />
                        <text
                          x="200"
                          y="200"
                          fill="white"
                          fontSize="14"
                          fontWeight="bold"
                          textAnchor="middle"
                          transform={`rotate(${angle + (360 / WHEEL_SEGMENTS.length) / 2}, 200, 200) translate(0, -120)`}
                        >
                          {segment.label}
                        </text>
                      </g>
                    );
                  })}

                  <circle cx="200" cy="200" r="30" fill="white" stroke="#333" strokeWidth="3" />
                  <circle cx="200" cy="200" r="15" fill="#333" />
                </svg>
              </div>

              <div
                className="absolute top-0 left-1/2 transform -translate-x-1/2 -translate-y-4 z-10"
                style={{ width: 0, height: 0, borderLeft: '20px solid transparent', borderRight: '20px solid transparent', borderTop: '40px solid #EF4444' }}
              />
            </div>

            <div className="text-center mt-8">
              {!isSpinning ? (
                <button
                  onClick={startSpinning}
                  className="px-12 py-4 bg-gradient-to-r from-green-500 to-green-600 text-white rounded-xl font-bold text-xl hover:from-green-600 hover:to-green-700 transition-all transform hover:scale-105 shadow-lg"
                >
                  {t('fortuneWheel.startButton')}
                </button>
              ) : (
                <button
                  onClick={stopWheel}
                  className="px-12 py-4 bg-gradient-to-r from-red-500 to-red-600 text-white rounded-xl font-bold text-xl hover:from-red-600 hover:to-red-700 transition-all transform hover:scale-105 shadow-lg"
                >
                  {t('fortuneWheel.stopButton')}
                </button>
              )}
            </div>
          </div>
        ) : (
          <div className="text-center space-y-6 py-8">
            <div className="inline-flex items-center justify-center w-32 h-32 rounded-full mx-auto mb-4 animate-bounce"
              style={{ backgroundColor: selectedSegment?.color }}>
              {selectedSegment && (
                <selectedSegment.icon className="w-16 h-16 text-white" />
              )}
            </div>

            <h3 className="text-4xl font-bold text-gray-900">
              {selectedSegment?.label}
            </h3>

            <p className="text-xl text-gray-700">
              {selectedSegment && getRewardDescription(selectedSegment)}
            </p>

            <div className="flex justify-center space-x-4 mt-8">
              <button
                onClick={onClose}
                className="px-8 py-4 bg-gradient-to-r from-green-500 to-green-600 text-white rounded-xl font-bold text-lg hover:from-green-600 hover:to-green-700 transition-all transform hover:scale-105 shadow-lg"
              >
                {t('fortuneWheel.continueButton')}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
