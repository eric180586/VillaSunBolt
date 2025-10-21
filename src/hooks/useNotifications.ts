import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import { useAuth } from '../contexts/AuthContext';
import type { Database } from '../lib/database.types';

type Notification = Database['public']['Tables']['notifications']['Row'];
type NotificationInsert = Database['public']['Tables']['notifications']['Insert'];

export function useNotifications() {
  const { user } = useAuth();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);

  const fetchNotifications = useCallback(async () => {
    if (!user) return;

    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
        .limit(50);

      if (error) throw error;
      setNotifications(data || []);
      setUnreadCount((data || []).filter((n) => !n.is_read).length);
    } catch (error) {
      console.error('Error fetching notifications:', error);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications]);

  useRealtimeSubscription<Notification>(
    'notifications',
    (payload) => {
      if (payload.new.user_id === user?.id) {
        setNotifications((current) => [payload.new as Notification, ...current]);
        setUnreadCount((count) => count + 1);

        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification(payload.new.title, {
            body: payload.new.message,
            icon: '/icon.png',
          });
        }
      }
    },
    (payload) => {
      if (payload.new.user_id === user?.id) {
        setNotifications((current) =>
          current.map((n) => (n.id === payload.new.id ? (payload.new as Notification) : n))
        );
        fetchNotifications();
      }
    },
    (payload) => {
      setNotifications((current) => current.filter((n) => n.id !== payload.old.id));
    }
  );

  const markAsRead = async (id: string) => {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', id);

    if (error) throw error;
  };

  const markAllAsRead = async () => {
    if (!user) return;

    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', user.id)
      .eq('is_read', false);

    if (error) throw error;
    setUnreadCount(0);
  };

  const createNotification = async (notification: NotificationInsert) => {
    const { error } = await supabase.from('notifications').insert(notification);
    if (error) throw error;
  };

  const requestPermission = async () => {
    if ('Notification' in window && Notification.permission === 'default') {
      await Notification.requestPermission();
    }
  };

  return {
    notifications,
    unreadCount,
    loading,
    markAsRead,
    markAllAsRead,
    createNotification,
    requestPermission,
    refetch: fetchNotifications,
  };
}
