import { useState, useEffect } from 'react';
import { Trophy, Users, X, Clock, Zap } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';

interface QuizQuestion {
  id: string;
  category: string;
  question: string;
  option_a: string;
  option_b: string;
  option_c: string;
  option_d: string;
  correct_answer: string;
  difficulty: string;
  points_value: number;
}

interface Player {
  id: string;
  name: string;
  position: number;
  points: number;
  color: string;
}

interface QuizGameProps {
  onClose: () => void;
}

const PLAYER_COLORS = ['#ef4444', '#3b82f6', '#10b981', '#f59e0b'];
const BUZZER_KEYS = ['a', 'l', 's', 'k'];
const BOARD_SIZE = 30;
const MAX_RESPONSE_TIME = 5000;

export default function QuizGame({ onClose }: QuizGameProps) {
  const { t: _t } = useTranslation();
  const { profile } = useAuth();
  const [gameState, setGameState] = useState<'setup' | 'playing' | 'question' | 'winner'>('setup');
  const [playerCount, setPlayerCount] = useState(2);
  const [players, setPlayers] = useState<Player[]>([]);
  const [currentQuestion, setCurrentQuestion] = useState<QuizQuestion | null>(null);
  const [questionStartTime, setQuestionStartTime] = useState<number>(0);
  const [buzzerLocked, setBuzzerLocked] = useState(false);
  const [activePlayer, setActivePlayer] = useState<number | null>(null);
  const [timeLeft, setTimeLeft] = useState(0);
  const [usedQuestions, setUsedQuestions] = useState<string[]>([]);
  const [allQuestions, setAllQuestions] = useState<QuizQuestion[]>([]);
  const [showFeedback, setShowFeedback] = useState<{ correct: boolean; message: string } | null>(null);

  useEffect(() => {
    loadQuestions();
  }, []);

  useEffect(() => {
    if (gameState === 'question' && !buzzerLocked) {
      const handleBuzzer = (e: KeyboardEvent) => {
        const keyIndex = BUZZER_KEYS.indexOf(e.key.toLowerCase());
        if (keyIndex !== -1 && keyIndex < players.length && !buzzerLocked) {
          handleBuzzerPress(keyIndex);
        }
      };

      window.addEventListener('keydown', handleBuzzer);
      return () => window.removeEventListener('keydown', handleBuzzer);
    }
  }, [gameState, buzzerLocked, players]);

  useEffect(() => {
    if (gameState === 'question' && buzzerLocked && activePlayer !== null && timeLeft > 0) {
      const timer = setInterval(() => {
        setTimeLeft((prev) => {
          if (prev <= 100) {
            clearInterval(timer);
            handleTimeout();
            return 0;
          }
          return prev - 100;
        }) as any;
      }, 100);

      return () => clearInterval(timer);
    }
  }, [gameState, buzzerLocked, activePlayer, timeLeft]);

  const loadQuestions = async () => {
    try {
      const { data, error } = await supabase
        .from('quiz_questions')
        .select('*')
        .eq('is_active', true);

      if (error) throw error;
      setAllQuestions(data || []);
    } catch (error) {
      console.error('Error loading questions:', error);
    }
  };

  const startGame = () => {
    const newPlayers: Player[] = [];
    for (let i = 0; i < playerCount; i++) {
      newPlayers.push({
        id: i === 0 ? profile?.id || `player-${i}` : `player-${i}`,
        name: i === 0 ? profile?.full_name || `Player ${i + 1}` : `Player ${i + 1}`,
        position: 0,
        points: 0,
        color: PLAYER_COLORS[i],
      }) as any;
    }
    setPlayers(newPlayers);
    setGameState('playing');
    loadNextQuestion();
  };

  const loadNextQuestion = () => {
    const availableQuestions = allQuestions.filter(q => !usedQuestions.includes(q.id));

    if (availableQuestions.length === 0) {
      endGame();
      return;
    }

    const randomQuestion = availableQuestions[Math.floor(Math.random() * availableQuestions.length)];
    setCurrentQuestion(randomQuestion);
    setUsedQuestions([...usedQuestions, randomQuestion.id]);
    setQuestionStartTime(Date.now());
    setBuzzerLocked(false);
    setActivePlayer(null);
    setTimeLeft(0);
    setShowFeedback(null);
    setGameState('question');
  };

  const handleBuzzerPress = (playerIndex: number) => {
    if (buzzerLocked || !currentQuestion) return;

    setBuzzerLocked(true);
    setActivePlayer(playerIndex);
    setTimeLeft(MAX_RESPONSE_TIME);
  };

  const handleAnswer = (answer: string) => {
    if (!currentQuestion || activePlayer === null) return;

    const responseTime = Date.now() - questionStartTime;
    const isCorrect = answer === currentQuestion.correct_answer;

    if (isCorrect) {
      const seconds = Math.min(5, Math.ceil(responseTime / 1000));
      const fieldsToMove = Math.max(1, 6 - seconds);

      setPlayers(prev => {
        const updated = [...prev];
        updated[activePlayer].position = Math.min(BOARD_SIZE, updated[activePlayer].position + fieldsToMove);
        updated[activePlayer].points += currentQuestion.points_value;
        return updated;
      }) as any;

      setShowFeedback({
        correct: true,
        message: `Correct! +${fieldsToMove} fields, +${currentQuestion.points_value} points!`,
      }) as any;

      setTimeout(() => {
        if (players[activePlayer].position + fieldsToMove >= BOARD_SIZE) {
          endGame();
        } else {
          loadNextQuestion();
        }
      }, 2000);
    } else {
      setShowFeedback({
        correct: false,
        message: 'Wrong answer! Next question...',
      }) as any;

      setTimeout(() => {
        loadNextQuestion();
      }, 2000);
    }
  };

  const handleTimeout = () => {
    setShowFeedback({
      correct: false,
      message: 'Time\'s up! Next question...',
    }) as any;

    setTimeout(() => {
      loadNextQuestion();
    }, 2000);
  };

  const endGame = () => {
    const winner = players.reduce((max, player) =>
      player.position > max.position ? player : max
    , players[0]);

    setPlayers(prev => prev.map(p => ({
      ...p,
      position: p.id === winner.id ? BOARD_SIZE : p.position
    })));

    setGameState('winner');
    saveGameResults(winner);
  };

  const saveGameResults = async (winner: Player) => {
    try {
      const { error: sessionError } = await supabase
        .from('quiz_sessions')
        .insert({
          created_by: profile?.id,
          player_count: playerCount,
          player_ids: players.map(p => p.id),
          player_names: players.map(p => p.name),
          questions_used: usedQuestions,
          winner_id: winner.id === profile?.id ? winner.id : null,
          points_awarded: players.reduce((acc, p) => ({ ...acc, [p.id]: p.points }), {}),
          completed_at: new Date().toISOString(),
        }) as any;

      if (sessionError) throw sessionError;

      const { data: existingScore } = await supabase
        .from('quiz_highscores')
        .select('*')
        .eq('profile_id', profile?.id)
        .maybeSingle() as any;

      const isWinner = winner.id === profile?.id;
      const currentPlayer = players.find(p => p.id === profile?.id);

      if (existingScore) {
        await supabase
          .from('quiz_highscores')
          .update({
            games_played: existingScore.games_played + 1,
            games_won: existingScore.games_won + (isWinner ? 1 : 0),
            total_points: existingScore.total_points + (currentPlayer?.points || 0),
            best_score: Math.max(existingScore.best_score, currentPlayer?.points || 0),
            updated_at: new Date().toISOString(),
          })
          .eq('profile_id', profile?.id);
      } else {
        await supabase
          .from('quiz_highscores')
          .insert({
            profile_id: profile?.id,
            games_played: 1,
            games_won: isWinner ? 1 : 0,
            total_points: currentPlayer?.points || 0,
            best_score: currentPlayer?.points || 0,
            updated_at: new Date().toISOString(),
          }) as any;
      }

      if (isWinner && currentPlayer) {
        await supabase.rpc('add_bonus_points', {
          p_profile_id: profile?.id,
          p_points: Math.floor(currentPlayer.points / 2),
          p_reason: `Quiz Game Champion - ${currentPlayer.points} points!`,
        }) as any;
      }
    } catch (error) {
      console.error('Error saving game results:', error);
    }
  };

  if (gameState === 'setup') {
    return (
      <div className="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50 p-4">
        <div className="bg-white rounded-2xl p-8 max-w-md w-full">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-2xl font-bold text-gray-900">Quiz Game Setup</h2>
            <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
              <X className="w-6 h-6" />
            </button>
          </div>

          <div className="mb-8">
            <label className="block text-gray-700 font-semibold mb-3">
              <Users className="w-5 h-5 inline mr-2" />
              Number of Players
            </label>
            <div className="grid grid-cols-3 gap-3">
              {[2, 3, 4].map(count => (
                <button
                  key={count}
                  onClick={() => setPlayerCount(count)}
                  className={`py-4 rounded-lg font-semibold transition-all ${
                    playerCount === count
                      ? 'bg-amber-500 text-white shadow-lg scale-105'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  {count}
                </button>
              ))}
            </div>
          </div>

          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
            <h3 className="font-semibold text-blue-900 mb-2">How to Play:</h3>
            <ul className="text-sm text-blue-800 space-y-1">
              <li>• Answer questions correctly to move forward</li>
              <li>• Faster answers = more fields to move (1-5)</li>
              <li>• First to reach field 30 wins!</li>
              <li>• Use buzzer keys: A, L, S, K (or touch buttons)</li>
            </ul>
          </div>

          <button
            onClick={startGame}
            disabled={allQuestions.length === 0}
            className="w-full bg-green-600 text-white py-4 rounded-lg font-bold text-lg hover:bg-green-700 transition-colors disabled:bg-gray-400 disabled:cursor-not-allowed"
          >
            Start Game
          </button>
        </div>
      </div>
    );
  }

  if (gameState === 'winner') {
    const winner = players.reduce((max, player) =>
      player.position > max.position ? player : max
    , players[0]);

    return (
      <div className="fixed inset-0 bg-gradient-to-br from-amber-500 to-yellow-600 flex items-center justify-center z-50 p-4">
        <div className="bg-white rounded-2xl p-8 max-w-2xl w-full text-center">
          <Trophy className="w-24 h-24 mx-auto text-yellow-500 mb-4" />
          <h2 className="text-4xl font-bold text-gray-900 mb-2">Congratulations!</h2>
          <p className="text-2xl text-gray-700 mb-6">{winner.name} Wins!</p>

          <div className="bg-gray-50 rounded-lg p-6 mb-6">
            <h3 className="text-xl font-semibold mb-4">Final Scores</h3>
            <div className="space-y-3">
              {players.map((player) => (
                <div
                  key={player.id}
                  className="flex items-center justify-between p-3 rounded-lg"
                  style={{ backgroundColor: `${player.color}20` }}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className="w-8 h-8 rounded-full"
                      style={{ backgroundColor: player.color }}
                    />
                    <span className="font-semibold">{player.name}</span>
                  </div>
                  <div className="text-right">
                    <div className="font-bold text-lg">{player.points} pts</div>
                    <div className="text-sm text-gray-600">Field {player.position}/{BOARD_SIZE}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {winner.id === profile?.id && (
            <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
              <p className="text-green-800 font-semibold">
                <Zap className="w-5 h-5 inline mr-2" />
                Bonus: +{Math.floor(winner.points / 2)} points added to your account!
              </p>
            </div>
          )}

          <div className="flex gap-3">
            <button
              onClick={() => {
                setGameState('setup');
                setPlayers([]);
                setUsedQuestions([]);
                setCurrentQuestion(null);
              }}
              className="flex-1 bg-amber-500 text-white py-3 rounded-lg font-semibold hover:bg-amber-600 transition-colors"
            >
              Play Again
            </button>
            <button
              onClick={onClose}
              className="flex-1 bg-gray-200 text-gray-700 py-3 rounded-lg font-semibold hover:bg-gray-300 transition-colors"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (gameState === 'question' && currentQuestion) {
    return (
      <div className="fixed inset-0 bg-gradient-to-br from-blue-900 to-purple-900 flex flex-col z-50 p-4">
        <div className="flex justify-between items-center mb-4">
          <div className="text-white text-sm bg-black bg-opacity-30 px-4 py-2 rounded-lg">
            Question {usedQuestions.length} - {currentQuestion.category.replace('_', ' ').toUpperCase()}
          </div>
          <button onClick={onClose} className="text-white hover:text-amber-400">
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="flex-1 flex flex-col items-center justify-center max-w-4xl mx-auto w-full">
          <div className="bg-white rounded-2xl p-8 w-full mb-6">
            <div className="flex items-start gap-4 mb-6">
              <div className="bg-amber-500 text-white w-12 h-12 rounded-full flex items-center justify-center text-xl font-bold flex-shrink-0">
                ?
              </div>
              <h3 className="text-2xl font-bold text-gray-900 flex-1">
                {currentQuestion.question}
              </h3>
            </div>

            {!buzzerLocked ? (
              <div className="text-center py-8">
                <p className="text-xl text-gray-700 mb-6">Press your buzzer to answer!</p>
                <div className="flex justify-center gap-4">
                  {players.map((player, index) => (
                    <button
                      key={player.id}
                      onClick={() => handleBuzzerPress(index)}
                      className="px-6 py-3 rounded-lg font-bold text-white transition-transform hover:scale-110"
                      style={{ backgroundColor: player.color }}
                    >
                      {BUZZER_KEYS[index].toUpperCase()} - {player.name}
                    </button>
                  ))}
                </div>
              </div>
            ) : activePlayer !== null && !showFeedback ? (
              <div>
                <div className="flex items-center justify-between mb-6">
                  <div className="flex items-center gap-3">
                    <div
                      className="w-8 h-8 rounded-full"
                      style={{ backgroundColor: players[activePlayer].color }}
                    />
                    <span className="font-bold text-xl">{players[activePlayer].name}'s turn</span>
                  </div>
                  <div className="flex items-center gap-2 text-red-600">
                    <Clock className="w-5 h-5" />
                    <span className="font-bold">{(timeLeft / 1000).toFixed(1)}s</span>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {['a', 'b', 'c', 'd'].map((option: string) => (
                    <button
                      key={option}
                      onClick={() => handleAnswer(option)}
                      className="p-4 text-left rounded-lg border-2 border-gray-300 hover:border-amber-500 hover:bg-amber-50 transition-all"
                    >
                      <span className="font-bold text-amber-600 mr-2">
                        {option.toUpperCase()}.
                      </span>
                      {currentQuestion[`option_${option}` as keyof QuizQuestion]}
                    </button>
                  ))}
                </div>
              </div>
            ) : showFeedback ? (
              <div className={`text-center py-12 ${showFeedback.correct ? 'text-green-600' : 'text-red-600'}`}>
                <div className="text-6xl mb-4">{showFeedback.correct ? '✓' : '✗'}</div>
                <p className="text-2xl font-bold">{showFeedback.message}</p>
                {showFeedback.correct && (
                  <p className="text-gray-600 mt-4">
                    Correct answer: {currentQuestion.correct_answer.toUpperCase()}
                  </p>
                )}
              </div>
            ) : null}
          </div>

          <div className="bg-white bg-opacity-90 rounded-xl p-6 w-full">
            <div className="flex items-center justify-between mb-4">
              {players.map((player) => (
                <div key={player.id} className="text-center">
                  <div
                    className="w-10 h-10 rounded-full mx-auto mb-2"
                    style={{ backgroundColor: player.color }}
                  />
                  <div className="text-sm font-semibold">{player.name}</div>
                  <div className="text-xs text-gray-600">{player.points} pts</div>
                </div>
              ))}
            </div>

            <div className="relative h-12 bg-gray-200 rounded-full overflow-hidden">
              {players.map((player) => (
                <div
                  key={player.id}
                  className="absolute top-0 h-full transition-all duration-500 flex items-center justify-center"
                  style={{
                    backgroundColor: player.color,
                    width: `${(player.position / BOARD_SIZE) * 100}%`,
                    left: 0,
                  }}
                >
                  {player.position > 0 && (
                    <span className="text-white font-bold text-sm">
                      {player.position}/{BOARD_SIZE}
                    </span>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return null;
}
