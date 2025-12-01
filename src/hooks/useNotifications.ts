// hooks/useNotifications.ts
import { useEffect, useState } from "react";
import {
  checkPushSupport,
  requestPushPermission,
  registerServiceWorker,
  subscribeUserToPush,
  unsubscribePush,
  PushStatus,
} from "../lib/pushNotifications";

export function useNotifications() {
  const [pushStatus, setPushStatus] = useState<PushStatus>("prompt");
  const [subscription, setSubscription] = useState<PushSubscription | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function init() {
      const support = await checkPushSupport();
      setPushStatus(support);
      if (support === "granted") {
        try {
          const reg = await registerServiceWorker();
          if (reg) {
            const sub = await subscribeUserToPush(reg);
            setSubscription(sub);
            setPushStatus("granted");
          }
        } catch (err: any) {
          setError("Push Anmeldung fehlgeschlagen.");
          setPushStatus("error");
        }
      }
    }
    init();
  }, []);

  const enablePush = async () => {
    const status = await requestPushPermission();
    setPushStatus(status);
    if (status === "granted") {
      try {
        const reg = await registerServiceWorker();
        if (reg) {
          const sub = await subscribeUserToPush(reg);
          setSubscription(sub);
        }
      } catch (err: any) {
        setError("Push Anmeldung fehlgeschlagen.");
      }
    }
  };

  const disablePush = async () => {
    try {
      const reg = await registerServiceWorker();
      if (reg) await unsubscribePush(reg);
      setSubscription(null);
      setPushStatus("prompt");
    } catch {
      setError("Push Abmeldung fehlgeschlagen.");
    }
  };

  return { pushStatus, subscription, error, enablePush, disablePush };
}
