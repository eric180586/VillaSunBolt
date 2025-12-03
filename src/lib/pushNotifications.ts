export type PushStatus = "supported" | "not_supported" | "granted" | "denied" | "prompt" | "error";

export async function checkPushSupport(): Promise<PushStatus> {
  if (!("Notification" in window) || !("serviceWorker" in navigator) || !("PushManager" in window)) {
    return "not_supported";
  }
  if (Notification.permission === "granted") return "granted";
  if (Notification.permission === "denied") return "denied";
  return "prompt";
}

export async function requestPushPermission(): Promise<PushStatus> {
  try {
    const status = await Notification.requestPermission();
    if (status === "granted") return "granted";
    if (status === "denied") return "denied";
    return "prompt";
  } catch {
    return "error";
  }
}

export async function registerServiceWorker(): Promise<ServiceWorkerRegistration | null> {
  if ("serviceWorker" in navigator) {
    try {
      const reg = await navigator.serviceWorker.register("/sw.js");
      return reg;
    } catch (err) {
      return null;
    }
  }
  return null;
}

export async function subscribeUserToPush(reg: ServiceWorkerRegistration): Promise<PushSubscription | null> {
  if (!reg.pushManager) return null;
  try {
    const subscription = await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: import.meta.env.VITE_VAPID_PUBLIC_KEY
    });
    return subscription;
  } catch (err) {
    return null;
  }
}

export async function unsubscribePush(reg: ServiceWorkerRegistration): Promise<boolean> {
  const sub = await reg.pushManager.getSubscription();
  if (sub) {
    await sub.unsubscribe();
    return true;
  }
  return false;
}

export async function subscribeToPushNotifications(userId: string): Promise<PushSubscription | null> {
  const reg = await registerServiceWorker();
  if (!reg) return null;

  const subscription = await subscribeUserToPush(reg);
  if (!subscription) return null;

  return subscription;
}

export async function checkPushSubscription(): Promise<PushSubscription | null> {
  if (!("serviceWorker" in navigator)) return null;

  try {
    const reg = await navigator.serviceWorker.getRegistration();
    if (!reg || !reg.pushManager) return null;

    const subscription = await reg.pushManager.getSubscription();
    return subscription;
  } catch {
    return null;
  }
}
