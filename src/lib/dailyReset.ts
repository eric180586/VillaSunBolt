import { supabase } from './supabase';

const LAST_RESET_KEY = 'last_daily_reset';

export async function checkAndRunDailyReset(): Promise<boolean> {
  try {
    const today = new Date().toISOString().split('T')[0];
    const lastReset = localStorage.getItem(LAST_RESET_KEY);

    if (lastReset === today) {
      return true; // Already ran today, consider it successful
    }

    const { data, error } = await supabase.functions.invoke('daily-reset', {
      body: {},
    });

    if (error) {
      throw error;
    }

    if (data && !data.success) {
      throw new Error(data.error || 'Daily reset failed');
    }

    localStorage.setItem(LAST_RESET_KEY, today);
    return true;
  } catch (error) {
    console.error('Daily reset error:', error);
    throw error; // Let the caller handle the error and show appropriate message
  }
}

export function shouldRunDailyReset(): boolean {
  const today = new Date().toISOString().split('T')[0];
  const lastReset = localStorage.getItem(LAST_RESET_KEY);
  return lastReset !== today;
}
