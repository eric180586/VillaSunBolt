import { useState } from 'react';
import SunnyCharacter from './SunnyCharacter';
import SpeechBubble from './SpeechBubble';
import { ArrowRight, RotateCcw, Star } from 'lucide-react';

interface StepSummaryProps {
  stepTitle: string;
  summary: string;
  score: number;
  maxScore: number;
  bestScore: number;
  isNewBest: boolean;
  onNext: () => void;
  onRepeat: () => void;
}

export default function StepSummary({
  stepTitle,
  summary,
  score,
  maxScore,
  bestScore,
  isNewBest,
  onNext,
  onRepeat
}: StepSummaryProps) {
  const [showButtons, setShowButtons] = useState(false);

  const percentage = Math.round((score / maxScore) * 100);
  const stars = percentage >= 90 ? 5 : percentage >= 75 ? 4 : percentage >= 60 ? 3 : percentage >= 50 ? 2 : 1;

  const handleSummaryComplete = () => {
    setShowButtons(true);
  };

  return (
    <div className="fixed inset-0 bg-gradient-to-br from-green-400 via-emerald-400 to-teal-400 z-50 flex flex-col items-center justify-center p-4">
      <div className="mb-8">
        <div className="bg-white/90 backdrop-blur-sm rounded-2xl px-8 py-6 shadow-2xl text-center">
          <h2 className="text-3xl md:text-4xl font-bold text-gray-800 mb-4">{stepTitle}</h2>
          <div className="text-5xl md:text-6xl font-bold text-green-600 mb-2">
            {score} / {maxScore}
          </div>
          <div className="text-xl text-gray-600 mb-4">{percentage}% erreicht</div>

          <div className="flex justify-center gap-1 mb-4">
            {Array.from({ length: 5 }).map((_, i) => (
              <Star
                key={i}
                className={`w-8 h-8 ${
                  i < stars ? 'text-yellow-400 fill-yellow-400' : 'text-gray-300'
                }`}
              />
            ))}
          </div>

          {isNewBest && (
            <div className="bg-yellow-400 text-gray-800 font-bold py-2 px-4 rounded-lg animate-bounce">
              🎉 Neuer Bestwert!
            </div>
          )}

          {!isNewBest && bestScore > score && (
            <div className="text-sm text-gray-600">
              Dein Bestwert: {bestScore} / {maxScore}
            </div>
          )}
        </div>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center w-full max-w-4xl">
        <div className="mb-8">
          <SunnyCharacter
            size="large"
            position="center"
            expression={percentage >= 75 ? 'excited' : 'happy'}
            animate={true}
          />
        </div>

        <SpeechBubble
          text={summary}
          position="center"
          onComplete={handleSummaryComplete}
          speed={20}
          showSkip={true}
        />

        {showButtons && (
          <div className="mt-8 flex flex-col sm:flex-row gap-4 animate-fade-in">
            <button
              onClick={onRepeat}
              className="bg-white hover:bg-gray-100 text-gray-800 font-bold py-4 px-8 rounded-xl shadow-lg hover:shadow-xl transition-all flex items-center gap-2 text-lg border-2 border-yellow-400"
            >
              <RotateCcw className="w-5 h-5" />
              Wiederholen
            </button>

            <button
              onClick={onNext}
              className="bg-yellow-400 hover:bg-yellow-500 text-gray-800 font-bold py-4 px-8 rounded-xl shadow-lg hover:shadow-xl transition-all flex items-center gap-2 text-lg"
            >
              Nächster Step
              <ArrowRight className="w-5 h-5" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
