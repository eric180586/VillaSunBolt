import { useState, useEffect } from 'react';

interface SpeechBubbleProps {
  text: string;
  position?: 'left' | 'right' | 'center';
  onComplete?: () => void;
  speed?: number;
  showSkip?: boolean;
}

export default function SpeechBubble({
  text,
  position = 'left',
  onComplete,
  speed = 30,
  showSkip = true
}: SpeechBubbleProps) {
  const [displayedText, setDisplayedText] = useState('');
  const [isComplete, setIsComplete] = useState(false);
  const [isSkipped, setIsSkipped] = useState(false);

  useEffect(() => {
    if (isSkipped) {
      setDisplayedText(text);
      setIsComplete(true);
      if (onComplete) {
        setTimeout(onComplete, 500);
      }
      return;
    }

    setDisplayedText('');
    setIsComplete(false);
    let currentIndex = 0;

    const interval = setInterval(() => {
      if (currentIndex < text.length) {
        setDisplayedText(text.slice(0, currentIndex + 1));
        currentIndex++;
      } else {
        setIsComplete(true);
        clearInterval(interval);
        if (onComplete) {
          setTimeout(onComplete, 500);
        }
      }
    }, speed);

    return () => clearInterval(interval);
  }, [text, speed, onComplete, isSkipped]);

  const handleSkip = () => {
    setIsSkipped(true);
  };

  const bubblePositionClasses = {
    left: 'items-start',
    right: 'items-end',
    center: 'items-center'
  };

  return (
    <div className={`w-full max-w-2xl mx-auto px-4 flex flex-col ${bubblePositionClasses[position]}`}>
      <div className="relative bg-white rounded-2xl shadow-2xl border-4 border-yellow-400 p-6 max-w-xl animate-fade-in">
        <div className="text-gray-800 text-lg md:text-xl font-medium leading-relaxed whitespace-pre-wrap">
          {displayedText}
          {!isComplete && (
            <span className="inline-block w-2 h-5 ml-1 bg-yellow-400 animate-pulse" />
          )}
        </div>

        <div
          className="absolute bottom-0 w-0 h-0 border-l-[20px] border-l-transparent border-r-[20px] border-r-transparent border-t-[20px] border-t-yellow-400"
          style={{
            left: position === 'left' ? '20px' : position === 'right' ? 'auto' : '50%',
            right: position === 'right' ? '20px' : 'auto',
            transform: position === 'center' ? 'translateX(-50%) translateY(100%)' : 'translateY(100%)'
          }}
        />
        <div
          className="absolute bottom-0 w-0 h-0 border-l-[16px] border-l-transparent border-r-[16px] border-r-transparent border-t-[16px] border-t-white"
          style={{
            left: position === 'left' ? '24px' : position === 'right' ? 'auto' : '50%',
            right: position === 'right' ? '24px' : 'auto',
            transform: position === 'center' ? 'translateX(-50%) translateY(95%)' : 'translateY(95%)'
          }}
        />
      </div>

      {showSkip && !isComplete && (
        <button
          onClick={handleSkip}
          className="mt-4 px-4 py-2 bg-yellow-400 hover:bg-yellow-500 text-gray-800 font-semibold rounded-lg transition text-sm"
        >
          Skip →
        </button>
      )}
    </div>
  );
}
