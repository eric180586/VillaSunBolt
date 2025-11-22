import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import './lib/i18n';
import { registerServiceWorker } from './lib/pushNotifications';

// FORCE CACHE CLEAR - Aggressive approach
async function clearAllCaches() {
  try {
    // 1. Clear all cache storage
    if ('caches' in window) {
      const cacheNames = await caches.keys();
      console.log('[CACHE CLEAR] Deleting caches:', cacheNames);
      await Promise.all(cacheNames.map(name => caches.delete(name)));
      console.log('[CACHE CLEAR] All caches deleted');
    }

    // 2. Unregister old service workers
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      console.log('[SW] Unregistering old service workers:', registrations.length);
      for (const registration of registrations) {
        await registration.unregister();
      }
      console.log('[SW] All old service workers unregistered');
    }

    // 3. Clear localStorage flag
    localStorage.setItem('cache_cleared_v8', 'true');
    console.log('[CACHE CLEAR] Complete');
  } catch (error) {
    console.error('[CACHE CLEAR] Error:', error);
  }
}

// Check if we need to clear cache
const cacheCleared = localStorage.getItem('cache_cleared_v8');
if (!cacheCleared) {
  console.log('[INIT] First run with v8, clearing all caches...');
  clearAllCaches().then(() => {
    // Register new service worker
    registerServiceWorker();
  });
} else {
  // Register Service Worker for push notifications in production
  registerServiceWorker();
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
);
