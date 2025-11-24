import { useState, useEffect, useCallback } from 'react';
import { ChevronLeft, ChevronRight, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useTranslation } from 'react-i18next';

interface TutorialSlide {
  id: string;
  order_index: number;
  image_url: string;
  title: string;
  description: string;
}

interface TutorialViewerProps {
  onComplete: () => void;
  onClose: () => void;
}

export default function TutorialViewer({ onComplete, onClose }: TutorialViewerProps) {
  const { t } = useTranslation();
  const [slides, setSlides] = useState<TutorialSlide[]>([]);
  const [currentSlide, setCurrentSlide] = useState(0);
  const [loading, setLoading] = useState(true);
  const [touchStart, setTouchStart] = useState<number | null>(null);
  const [touchEnd, setTouchEnd] = useState<number | null>(null);

  const minSwipeDistance = 50;

  const loadSlides = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('tutorial_slides')
        .select('*')
        .order('order_index');

      if (error) throw error;
      setSlides(data || []);
    } catch (error: any) {
      console.error('Error loading tutorial slides:', error);
      // Show error in console but don't block - empty state will handle it
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadSlides();
  }, [loadSlides]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') goToPrevious();
      if (e.key === 'ArrowRight') goToNext();
      if (e.key === 'Escape') onClose();
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentSlide, goToNext, goToPrevious, onClose]);
  const goToNext = useCallback(() => {
    if (currentSlide < slides.length - 1) {
      setCurrentSlide((prev) => prev + 1);
    } else {
      onComplete();
    }
  }, [currentSlide, onComplete, slides.length]);

  const goToPrevious = useCallback(() => {
    if (currentSlide > 0) {
      setCurrentSlide((prev) => prev - 1);
    }
  }, [currentSlide]);

  const onTouchStart = (e: React.TouchEvent) => {
    setTouchEnd(null);
    setTouchStart(e.targetTouches[0].clientX);
  };

  const onTouchMove = (e: React.TouchEvent) => {
    setTouchEnd(e.targetTouches[0].clientX);
  };

  const onTouchEnd = () => {
    if (!touchStart || !touchEnd) return;

    const distance = touchStart - touchEnd;
    const isLeftSwipe = distance > minSwipeDistance;
    const isRightSwipe = distance < -minSwipeDistance;

    if (isLeftSwipe) {
      goToNext();
    } else if (isRightSwipe) {
      goToPrevious();
    }
  };

  if (loading) {
    return (
      <div className="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50">
        <div className="text-white text-xl">{t('common.loading')}</div>
      </div>
    );
  }

  if (slides.length === 0) {
    return (
      <div className="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50">
        <div className="bg-white rounded-lg p-8 max-w-md">
          <h3 className="text-xl font-bold text-red-600 mb-4">No Tutorial Available</h3>
          <p className="text-gray-700 mb-6">Tutorial slides are not configured yet.</p>
          <button
            onClick={onClose}
            className="w-full bg-amber-500 text-white py-3 rounded-lg font-semibold hover:bg-amber-600 transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    );
  }

  const slide = slides[currentSlide];

  return (
    <div className="fixed inset-0 bg-black bg-opacity-95 flex items-center justify-center z-50 p-4">
      <button
        onClick={onClose}
        className="absolute top-4 right-4 text-white hover:text-amber-400 transition-colors z-10"
      >
        <X className="w-8 h-8" />
      </button>

      <div className="max-w-5xl w-full h-full flex flex-col items-center justify-center">
        <div
          className="relative w-full flex-1 flex items-center justify-center"
          onTouchStart={onTouchStart}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
        >
          <img
            src={slide.image_url}
            alt={slide.title}
            className="max-w-full max-h-[70vh] object-contain rounded-lg shadow-2xl"
          />
        </div>

        <div className="mt-6 text-center text-white">
          <h2 className="text-2xl md:text-3xl font-bold mb-2">{slide.title}</h2>
          {slide.description && (
            <p className="text-lg md:text-xl text-gray-300">{slide.description}</p>
          )}
        </div>

        <div className="mt-8 flex items-center gap-6">
          <button
            onClick={goToPrevious}
            disabled={currentSlide === 0}
            className={`p-3 rounded-full transition-colors ${
              currentSlide === 0
                ? 'bg-gray-700 text-gray-500 cursor-not-allowed'
                : 'bg-amber-500 text-white hover:bg-amber-600'
            }`}
          >
            <ChevronLeft className="w-6 h-6" />
          </button>

          <div className="text-white text-lg font-semibold">
            {currentSlide + 1} / {slides.length}
          </div>

          <button
            onClick={goToNext}
            className="p-3 rounded-full bg-amber-500 text-white hover:bg-amber-600 transition-colors"
          >
            <ChevronRight className="w-6 h-6" />
          </button>
        </div>

        <div className="mt-4 flex gap-2">
          {slides.map((_, index) => (
            <button
              key={index}
              onClick={() => setCurrentSlide(index)}
              className={`w-3 h-3 rounded-full transition-colors ${
                index === currentSlide ? 'bg-amber-500' : 'bg-gray-600 hover:bg-gray-500'
              }`}
            />
          ))}
        </div>

        {currentSlide === slides.length - 1 && (
          <button
            onClick={onComplete}
            className="mt-6 bg-green-600 text-white px-8 py-3 rounded-lg font-semibold hover:bg-green-700 transition-colors text-lg"
          >
            Start Quiz Game
          </button>
        )}
      </div>

      <div className="absolute bottom-4 left-4 text-gray-400 text-sm">
        Use arrow keys (← →) or swipe to navigate
      </div>
    </div>
  );
}
