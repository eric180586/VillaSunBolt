import { useState, useEffect } from 'react';

interface SunnyCharacterProps {
  size?: 'small' | 'large';
  position?: 'left' | 'right' | 'center';
  expression?: 'happy' | 'thinking' | 'excited' | 'confused';
  animate?: boolean;
}

export default function SunnyCharacter({
  size = 'large',
  position = 'left',
  expression = 'happy',
  animate = true
}: SunnyCharacterProps) {
  const [bounce, setBounce] = useState(false);

  useEffect(() => {
    if (animate) {
      const interval = setInterval(() => {
        setBounce(true);
        setTimeout(() => setBounce(false), 600);
      }, 3000);
      return () => clearInterval(interval);
    }
  }, [animate]);

  const sizeClasses = {
    small: 'w-20 h-20',
    large: 'w-32 h-32 md:w-40 md:h-40'
  };

  const positionClasses = {
    left: 'left-4 md:left-8',
    right: 'right-4 md:right-8',
    center: 'left-1/2 -translate-x-1/2'
  };

  return (
    <div
      className={`
        ${sizeClasses[size]}
        ${positionClasses[position]}
        transition-all duration-300
        ${bounce ? 'animate-bounce' : ''}
      `}
    >
      <div className="relative w-full h-full">
        <svg
          viewBox="0 0 120 120"
          className="w-full h-full drop-shadow-2xl"
        >
          <defs>
            <radialGradient id="sunGradient" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#FFD700" />
              <stop offset="70%" stopColor="#FFA500" />
              <stop offset="100%" stopColor="#FF8C00" />
            </radialGradient>
            <filter id="glow">
              <feGaussianBlur stdDeviation="2" result="coloredBlur"/>
              <feMerge>
                <feMergeNode in="coloredBlur"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>

          <circle
            cx="60"
            cy="60"
            r="35"
            fill="url(#sunGradient)"
            filter="url(#glow)"
            className="animate-pulse"
            style={{ animationDuration: '3s' }}
          />

          <g className="sun-rays">
            {[0, 45, 90, 135, 180, 225, 270, 315].map((angle, i) => {
              const rad = (angle * Math.PI) / 180;
              const x1 = 60 + Math.cos(rad) * 40;
              const y1 = 60 + Math.sin(rad) * 40;
              const x2 = 60 + Math.cos(rad) * 50;
              const y2 = 60 + Math.sin(rad) * 50;

              return (
                <line
                  key={i}
                  x1={x1}
                  y1={y1}
                  x2={x2}
                  y2={y2}
                  stroke="#FFD700"
                  strokeWidth="3"
                  strokeLinecap="round"
                  className="animate-pulse"
                  style={{ animationDelay: `${i * 0.1}s`, animationDuration: '2s' }}
                />
              );
            })}
          </g>

          {expression === 'happy' && (
            <>
              <circle cx="50" cy="55" r="4" fill="#333" />
              <circle cx="70" cy="55" r="4" fill="#333" />
              <path
                d="M 45 70 Q 60 80 75 70"
                stroke="#333"
                strokeWidth="3"
                fill="none"
                strokeLinecap="round"
              />
            </>
          )}

          {expression === 'excited' && (
            <>
              <circle cx="50" cy="55" r="5" fill="#333" />
              <circle cx="70" cy="55" r="5" fill="#333" />
              <circle cx="60" cy="72" r="8" fill="#333" />
            </>
          )}

          {expression === 'thinking' && (
            <>
              <circle cx="50" cy="55" r="4" fill="#333" />
              <circle cx="70" cy="55" r="4" fill="#333" />
              <path
                d="M 50 72 L 70 72"
                stroke="#333"
                strokeWidth="3"
                strokeLinecap="round"
              />
              <circle cx="80" cy="35" r="3" fill="#FFD700" opacity="0.7" />
              <circle cx="85" cy="28" r="4" fill="#FFD700" opacity="0.8" />
              <circle cx="90" cy="20" r="5" fill="#FFD700" opacity="0.9" />
            </>
          )}

          {expression === 'confused' && (
            <>
              <path d="M 47 58 L 53 52" stroke="#333" strokeWidth="3" strokeLinecap="round" />
              <path d="M 53 58 L 47 52" stroke="#333" strokeWidth="3" strokeLinecap="round" />
              <path d="M 67 58 L 73 52" stroke="#333" strokeWidth="3" strokeLinecap="round" />
              <path d="M 73 58 L 67 52" stroke="#333" strokeWidth="3" strokeLinecap="round" />
              <path
                d="M 50 75 Q 60 70 70 75"
                stroke="#333"
                strokeWidth="3"
                fill="none"
                strokeLinecap="round"
              />
            </>
          )}
        </svg>

        {animate && (
          <div
            className="absolute -top-2 -right-2 w-6 h-6 bg-yellow-300 rounded-full animate-ping"
            style={{ animationDuration: '2s' }}
          />
        )}
      </div>
    </div>
  );
}
