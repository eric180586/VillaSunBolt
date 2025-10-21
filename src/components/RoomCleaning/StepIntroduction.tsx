import { useState } from 'react';
import SunnyCharacter from './SunnyCharacter';
import SpeechBubble from './SpeechBubble';
import { ArrowRight } from 'lucide-react';

interface StepIntroductionProps {
  stepTitle: string;
  introduction: string;
  whyImportant: string;
  onContinue: () => void;
}

export default function StepIntroduction({
  stepTitle,
  introduction,
  whyImportant,
  onContinue
}: StepIntroductionProps) {
  const [phase, setPhase] = useState<'intro' | 'why' | 'ready'>('intro');
  const [showContinueButton, setShowContinueButton] = useState(false);

  const handleIntroComplete = () => {
    setShowContinueButton(true);
  };

  const handleContinueClick = () => {
    if (phase === 'intro') {
      setPhase('why');
      setShowContinueButton(false);
    } else if (phase === 'why') {
      setPhase('ready');
      setShowContinueButton(false);
    } else {
      onContinue();
    }
  };

  const getCurrentText = () => {
    if (phase === 'intro') return introduction;
    if (phase === 'why') return whyImportant;
    return "Bereit? Lass uns anfangen! 🌟";
  };

  const getButtonText = () => {
    if (phase === 'intro') return "Weiter";
    if (phase === 'why') return "Verstanden!";
    return "Los geht's!";
  };

  return (
    <div className="fixed inset-0 bg-gradient-to-br from-sky-400 via-blue-400 to-indigo-400 z-50 flex flex-col items-center justify-center p-4">
      <div className="mb-8 text-center">
        <div className="inline-block bg-white/90 backdrop-blur-sm rounded-2xl px-8 py-4 shadow-2xl">
          <h2 className="text-3xl md:text-4xl font-bold text-gray-800">{stepTitle}</h2>
        </div>
      </div>

      <div className="flex-1 flex flex-col items-center justify-center w-full max-w-4xl">
        <div className="mb-8">
          <SunnyCharacter
            size="large"
            position="center"
            expression={phase === 'ready' ? 'excited' : 'happy'}
            animate={true}
          />
        </div>

        <SpeechBubble
          key={phase}
          text={getCurrentText()}
          position="center"
          onComplete={handleIntroComplete}
          speed={25}
          showSkip={true}
        />

        {showContinueButton && (
          <button
            onClick={handleContinueClick}
            className="mt-8 bg-yellow-400 hover:bg-yellow-500 text-gray-800 font-bold py-4 px-8 rounded-xl shadow-lg hover:shadow-xl transition-all flex items-center gap-2 text-lg animate-fade-in"
          >
            {getButtonText()}
            <ArrowRight className="w-5 h-5" />
          </button>
        )}
      </div>

      <div className="mb-8 flex gap-2">
        {['intro', 'why', 'ready'].map((p, index) => (
          <div
            key={p}
            className={`w-3 h-3 rounded-full transition-all ${
              phase === p
                ? 'bg-yellow-400 w-8'
                : index < ['intro', 'why', 'ready'].indexOf(phase)
                ? 'bg-yellow-300'
                : 'bg-white/50'
            }`}
          />
        ))}
      </div>
    </div>
  );
}
