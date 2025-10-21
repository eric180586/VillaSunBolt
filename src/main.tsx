import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.tsx';
import './index.css';
import './lib/i18n';
import { registerServiceWorker } from './lib/pushNotifications';

registerServiceWorker().catch((error) => {
  console.error('Failed to register service worker:', error);
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
);
