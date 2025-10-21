import { supabase } from './supabase';

export interface PushSubscriptionData {
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
}

export async function registerServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  if (!('serviceWorker' in navigator)) {
    console.log('Service Worker not supported');
    return null;
  }

  try {
    const existingRegistration = await navigator.serviceWorker.getRegistration('/');
    if (existingRegistration) {
      console.log('Service Worker already registered:', existingRegistration);
      return existingRegistration;
    }

    const registration = await navigator.serviceWorker.register('/service-worker.js', {
      scope: '/',
    });
    console.log('Service Worker registered:', registration);
    await navigator.serviceWorker.ready;
    return registration;
  } catch (error) {
    console.error('Service Worker registration failed:', error);
    return null;
  }
}

export async function requestNotificationPermission(): Promise<NotificationPermission> {
  if (!('Notification' in window)) {
    console.log('Notifications not supported');
    return 'denied';
  }

  const permission = await Notification.requestPermission();
  console.log('Notification permission:', permission);
  return permission;
}

export async function subscribeToPushNotifications(
  userId: string
): Promise<PushSubscription | null> {
  try {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      console.log('Push notifications not supported');
      return null;
    }

    await navigator.serviceWorker.ready;

    const registration = await navigator.serviceWorker.getRegistration('/');
    if (!registration) {
      console.error('No service worker registration found');
      return null;
    }

    const existingSubscription = await registration.pushManager.getSubscription();
    if (existingSubscription) {
      console.log('Push subscription already exists');
      return existingSubscription;
    }

    const permission = await requestNotificationPermission();
    if (permission !== 'granted') {
      console.log('Notification permission not granted');
      return null;
    }

    const vapidKey = import.meta.env.VITE_VAPID_PUBLIC_KEY;
    if (!vapidKey) {
      console.error('VAPID public key not configured');
      return null;
    }

    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(vapidKey),
    });

    await savePushSubscription(userId, subscription);
    console.log('Push subscription created successfully');
    return subscription;
  } catch (error) {
    console.error('Push subscription failed:', error);
    return null;
  }
}

export async function savePushSubscription(
  userId: string,
  subscription: PushSubscription
): Promise<void> {
  const subData = subscription.toJSON();
  const keys = subData.keys;

  if (!keys?.p256dh || !keys?.auth) {
    throw new Error('Invalid subscription data');
  }

  const { error } = await supabase.from('push_subscriptions').insert({
    user_id: userId,
    endpoint: subData.endpoint || '',
    p256dh: keys.p256dh,
    auth: keys.auth,
    user_agent: navigator.userAgent,
  });

  if (error && error.code !== '23505') {
    console.error('Error saving push subscription:', error);
    throw error;
  }
}

export async function unsubscribeFromPush(userId: string): Promise<void> {
  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.getSubscription();

  if (subscription) {
    await subscription.unsubscribe();
  }

  const { error } = await supabase
    .from('push_subscriptions')
    .delete()
    .eq('user_id', userId);

  if (error) {
    console.error('Error removing push subscription:', error);
    throw error;
  }
}

export async function checkPushSubscription(): Promise<PushSubscription | null> {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    return null;
  }

  try {
    const registration = await navigator.serviceWorker.getRegistration('/');
    if (!registration) {
      return null;
    }

    const subscription = await registration.pushManager.getSubscription();
    return subscription;
  } catch (error) {
    console.log('Push subscription check failed:', error);
    return null;
  }
}

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

export async function sendPushNotification(params: {
  user_ids?: string[];
  role?: string;
  title: string;
  body: string;
  icon?: string;
  data?: any;
}): Promise<void> {
  const { data, error } = await supabase.functions.invoke('send-push-notification', {
    body: params,
  });

  if (error) {
    console.error('Error sending push notification:', error);
    throw error;
  }

  console.log('Push notification sent:', data);
}
