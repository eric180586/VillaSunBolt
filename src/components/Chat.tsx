import { useState, useEffect, useRef } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useProfiles } from '../hooks/useProfiles';
import { supabase } from '../lib/supabase';
import { Send, Image as ImageIcon, X, Loader, ArrowLeft } from 'lucide-react';
import { toLocaleTimeStringCambodia, toLocaleDateStringCambodia } from '../lib/dateUtils';
import { useTranslation } from 'react-i18next';

interface ChatMessage {
  id: string;
  user_id: string;
  message: string;
  photo_url: string | null;
  created_at: string;
  profiles?: {
    full_name: string;
    avatar_url: string | null;
  };
}

export function Chat({ onBack }: { onBack?: () => void } = {}) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const { profiles } = useProfiles();
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [messageText, setMessageText] = useState('');
  const [selectedPhoto, setSelectedPhoto] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [showLanguage, setShowLanguage] = useState<'original' | 'de' | 'km'>('original');
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    fetchMessages();
    subscribeToMessages();
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const fetchMessages = async () => {
    try {
      const { data, error } = await supabase
        .from('chat_messages')
        .select('*')
        .order('created_at', { ascending: true })
        .limit(100);

      if (error) throw error;

      const messagesWithProfiles = await Promise.all(
        (data || []).map(async (msg) => {
          const { data: profileData } = await supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', msg.user_id)
            .maybeSingle();

          return {
            ...msg,
            profiles: profileData
          };
        })
      );

      setMessages(messagesWithProfiles);
    } catch (error) {
      console.error('Error fetching messages:', error);
    }
  };

  const subscribeToMessages = () => {
    const channel = supabase
      .channel(`chat_messages_changes_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'chat_messages',
        },
        async (payload) => {
          if (payload.eventType === 'INSERT') {
            const { data: profileData } = await supabase
              .from('profiles')
              .select('full_name, avatar_url')
              .eq('id', payload.new.user_id)
              .maybeSingle();

            const newMessage = {
              ...payload.new,
              profiles: profileData
            };

            setMessages((prev) => [...prev, newMessage as ChatMessage]);
          } else if (payload.eventType === 'DELETE') {
            setMessages((prev) => prev.filter((msg) => msg.id !== payload.old.id));
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  };

  const uploadPhoto = async (file: File): Promise<string> => {
    const fileExt = file.name.split('.').pop();
    const fileName = `${profile?.id}/${Math.random().toString(36).substring(2)}_${Date.now()}.${fileExt}`;

    const { error: uploadError } = await supabase.storage
      .from('chat-photos')
      .upload(fileName, file);

    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage
      .from('chat-photos')
      .getPublicUrl(fileName);

    return urlData.publicUrl;
  };

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if ((!messageText.trim() && !selectedPhoto) || !profile?.id || sending) return;

    setSending(true);
    try {
      let photoUrl = null;
      if (selectedPhoto) {
        photoUrl = await uploadPhoto(selectedPhoto);
      }

      const messageContent = messageText.trim();

      const { error } = await supabase.from('chat_messages').insert({
        user_id: profile.id,
        message: messageContent || '[Photo]',
        photo_url: photoUrl,
      });

      if (error) throw error;

      setMessageText('');
      setSelectedPhoto(null);
      setPhotoPreview(null);
    } catch (error) {
      console.error('Error sending message:', error);
      alert(t('howTo.errorSendingMessage'));
    } finally {
      setSending(false);
    }
  };

  const handlePhotoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedPhoto(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setPhotoPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  const handleDeleteMessage = async (messageId: string) => {
    if (!confirm('Nachricht wirklich löschen?')) return;

    try {
      const { error } = await supabase
        .from('chat_messages')
        .delete()
        .eq('id', messageId);

      if (error) throw error;
    } catch (error) {
      console.error('Error deleting message:', error);
      alert(t('howTo.errorDeleting'));
    }
  };

  const getDisplayMessage = (msg: ChatMessage) => {
    return msg.message;
  };

  const formatTime = (timestamp: string) => {
    const date = new Date(timestamp);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();

    if (isToday) {
      return toLocaleTimeStringCambodia(date, 'de-DE', { hour: '2-digit', minute: '2-digit' });
    } else {
      return toLocaleDateStringCambodia(date, 'de-DE', { day: '2-digit', month: '2-digit' }) + ' ' +
             toLocaleTimeStringCambodia(date, 'de-DE', { hour: '2-digit', minute: '2-digit' });
    }
  };

  return (
    <div className="flex flex-col h-[calc(100vh-12rem)] bg-gradient-to-br from-white to-beige-50 rounded-xl shadow-lg border-2 border-beige-200">
      <div className="flex items-center justify-between p-4 border-b-2 border-beige-200 bg-gradient-to-r from-beige-50 to-orange-50">
        <div className="flex items-center space-x-3">
          {onBack && (
            <button
              onClick={onBack}
              className="p-2 hover:bg-beige-100 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-gray-700" />
            </button>
          )}
          <h2 className="text-2xl font-bold text-gray-900">Team Chat</h2>
        </div>
        <div className="flex space-x-2">
          <button
            onClick={() => setShowLanguage('original')}
            className={`px-3 py-1 rounded-lg text-sm font-medium transition-all duration-200 ${
              showLanguage === 'original'
                ? 'bg-orange-500 text-white shadow-md'
                : 'bg-beige-100 text-gray-700 hover:bg-beige-200'
            }`}
          >
            Original
          </button>
          <button
            onClick={() => setShowLanguage('de')}
            className={`px-3 py-1 rounded-lg text-sm font-medium transition-all duration-200 ${
              showLanguage === 'de'
                ? 'bg-orange-500 text-white shadow-md'
                : 'bg-beige-100 text-gray-700 hover:bg-beige-200'
            }`}
          >
            Deutsch
          </button>
          <button
            onClick={() => setShowLanguage('km')}
            className={`px-3 py-1 rounded-lg text-sm font-medium transition-all duration-200 ${
              showLanguage === 'km'
                ? 'bg-orange-500 text-white shadow-md'
                : 'bg-beige-100 text-gray-700 hover:bg-beige-200'
            }`}
          >
            ខ្មែរ
          </button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg) => {
          const isOwnMessage = msg.user_id === profile?.id;
          const sender = profiles.find(p => p.id === msg.user_id);

          return (
            <div
              key={msg.id}
              className={`flex ${isOwnMessage ? 'justify-end' : 'justify-start'}`}
            >
              <div className={`flex ${isOwnMessage ? 'flex-row-reverse' : 'flex-row'} items-end space-x-2 max-w-[70%]`}>
                {!isOwnMessage && (
                  <div className="w-8 h-8 rounded-full bg-blue-500 flex items-center justify-center text-white text-sm font-bold flex-shrink-0">
                    {sender?.full_name?.charAt(0).toUpperCase() || '?'}
                  </div>
                )}

                <div>
                  {!isOwnMessage && (
                    <div className="text-xs text-gray-500 mb-1 ml-2">
                      {sender?.full_name || 'Unknown User'}
                    </div>
                  )}

                  <div
                    className={`rounded-2xl px-4 py-2 shadow-md ${
                      isOwnMessage
                        ? 'bg-gradient-to-br from-orange-500 to-orange-600 text-white'
                        : 'bg-gradient-to-br from-beige-100 to-beige-50 text-gray-900 border border-beige-200'
                    }`}
                  >
                    {msg.photo_url && (
                      <img
                        src={msg.photo_url}
                        alt="Chat photo"
                        className="rounded-lg mb-2 max-w-xs cursor-pointer"
                        onClick={() => window.open(msg.photo_url!, '_blank')}
                      />
                    )}
                    {msg.message && msg.message !== '[Photo]' && (
                      <p className="whitespace-pre-wrap break-words">
                        {getDisplayMessage(msg)}
                      </p>
                    )}
                    <div className={`text-xs mt-1 ${isOwnMessage ? 'text-orange-100' : 'text-gray-500'}`}>
                      {formatTime(msg.created_at)}
                    </div>
                  </div>

                  {isOwnMessage && (
                    <button
                      onClick={() => handleDeleteMessage(msg.id)}
                      className="text-xs text-red-600 hover:text-red-700 mt-1 ml-2"
                    >
                      Löschen
                    </button>
                  )}
                </div>

                {isOwnMessage && (
                  <div className="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center text-white text-sm font-bold flex-shrink-0 ml-2">
                    {profile?.full_name?.charAt(0).toUpperCase() || '?'}
                  </div>
                )}
              </div>
            </div>
          );
        })}
        <div ref={messagesEndRef} />
      </div>

      {photoPreview && (
        <div className="px-4 py-2 border-t border-gray-200 bg-gray-50">
          <div className="relative inline-block">
            <img src={photoPreview} alt="Preview" className="h-20 rounded-lg" />
            <button
              onClick={() => {
                setSelectedPhoto(null);
                setPhotoPreview(null);
              }}
              className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      <form onSubmit={handleSendMessage} className="p-4 border-t border-gray-200">
        <div className="flex items-center space-x-2">
          <input
            type="file"
            ref={fileInputRef}
            onChange={handlePhotoSelect}
            accept="image/*"
            className="hidden"
          />
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="p-2 text-gray-500 hover:bg-gray-100 rounded-lg"
            disabled={sending}
          >
            <ImageIcon className="w-5 h-5" />
          </button>

          <input
            type="text"
            value={messageText}
            onChange={(e) => setMessageText(e.target.value)}
            placeholder="Nachricht schreiben..."
            className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            disabled={sending}
          />

          <button
            type="submit"
            disabled={(!messageText.trim() && !selectedPhoto) || sending}
            className="p-2 bg-gradient-to-r from-orange-500 to-orange-600 text-white rounded-lg hover:from-orange-600 hover:to-orange-700 disabled:opacity-50 disabled:cursor-not-allowed shadow-md transition-all duration-200 active:scale-95"
          >
            {sending ? <Loader className="w-5 h-5 animate-spin" /> : <Send className="w-5 h-5" />}
          </button>
        </div>
      </form>
    </div>
  );
}
