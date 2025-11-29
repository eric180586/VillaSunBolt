import { useEffect, useState } from 'react';
import { Bell, BellOff, Loader } from 'lucide-react';
import {
  subscribeToPushNotifications,
  unsubscribeFromPush,
  checkPushSubscription,
  requestNotificationPermission,
} from '../lib/pushNotifications';
import { useAuth } from '../contexts/AuthContext';

/**
 * A small UI component that allows the current user to opt‑in or opt‑out of
 * browser push notifications. It checks for an existing subscription on mount
 * and provides a toggle button to enable or disable notifications. When enabling,
 * the component requests notification permissions if not already granted.
 */
export function PushNotificationToggle() {
  const { user } = useAuth();
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [loading, setLoading] = useState(true);

  // On mount, determine if the user already has an active push subscription
  useEffect(() => {
    let cancelled = false;
    async function checkSub() {
      if (!user) {
        setEnabled(false);
        setLoading(false);
        return;
      }
      try {
        const sub = await checkPushSubscription();
        if (!cancelled) {
          setEnabled(!!sub);
        }
      } catch {
        // ignore errors and assume disabled
        if (!cancelled) {
          setEnabled(false);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }
    checkSub();
    return () => {
      cancelled = true;
    };
  }, [user]);

  // Handle toggling notifications on or off
  const handleToggle = async () => {
    if (!user || loading || enabled === null) return;

    if (enabled) {
      // Unsubscribe from push notifications
      try {
        setLoading(true);
        await unsubscribeFromPush(user.id);
        setEnabled(false);
      } catch (error) {
        console.error('Failed to unsubscribe from push notifications:', error);
        alert('Failed to disable notifications. Please try again.');
      } finally {
        setLoading(false);
      }
    } else {
      // Request permission if needed and subscribe
      try {
        setLoading(true);
        // Ask the browser for permission if not already granted/denied
        const permission = await requestNotificationPermission();
        if (permission !== 'granted') {
          alert(
            'Push notifications are not enabled in your browser. Please allow notifications in your browser settings.'
          );
          return;
        }
        const sub = await subscribeToPushNotifications(user.id);
        setEnabled(!!sub);
      } catch (error) {
        console.error('Failed to subscribe to push notifications:', error);
        alert('Failed to enable notifications. Please try again.');
      } finally {
        setLoading(false);
      }
    }
  };

  // Determine button content based on state
  const buttonContent = () => {
    if (loading || enabled === null) {
      return (
        <>
          <Loader className="w-4 h-4 animate-spin" />
          <span>Checking…</span>
        </>
      );
    }
    if (enabled) {
      return (
        <>
          <Bell className="w-4 h-4" />
          <span>Notifications enabled</span>
        </>
      );
    }
    return (
      <>
        <BellOff className="w-4 h-4" />
        <span>Enable notifications</span>
      </>
    );
  };

  return (
    <button
      type="button"
      onClick={handleToggle}
      disabled={loading || enabled === null}
      className={`flex items-center space-x-2 px-3 py-1 border border-gray-300 rounded-lg text-sm font-medium transition-colors \
        ${enabled ? 'bg-green-50 text-green-700 hover:bg-green-100' : 'bg-red-50 text-red-700 hover:bg-red-100'} \
        ${loading ? 'opacity-70 cursor-not-allowed' : 'cursor-pointer'}`}
    >
      {buttonContent()}
    </button>
  );
}