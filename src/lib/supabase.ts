// lib/supabase.ts
import { createClient, SupabaseClient, RealtimeChannel } from '@supabase/supabase-js';

// --- ENV Konfiguration ---
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

// --- Singleton Supabase Client ---
const supabase: SupabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  realtime: { params: { eventsPerSecond: 10 } }
});

// --- Channel-Watchdog und Error-Monitor ---
type ChannelStatus = "connected" | "reconnecting" | "disconnected";
type WatchdogCallback = (status: ChannelStatus, error?: any) => void;

class RealtimeWatchdog {
  private channels: Map<string, RealtimeChannel> = new Map();
  private status: ChannelStatus = "connected";
  private cb: WatchdogCallback | null = null;
  private reconnectAttempts = 0;
  private maxReconnects = 3;

  public subscribe(
    name: string,
    channel: RealtimeChannel,
    cb?: WatchdogCallback
  ) {
    this.channels.set(name, channel);
    if (cb) this.cb = cb;
    channel.on('error', (err: any) => this.handleError(name, err));
    channel.on('close', () => this.handleDisconnect(name));
    // Connect sofort testen
    if (channel.state !== 'joined') {
      this.status = "reconnecting";
      this.cb && this.cb(this.status);
      this.tryReconnect(name, channel);
    }
  }

  private handleError(name: string, error: any) {
    this.status = "reconnecting";
    this.cb && this.cb(this.status, error);
    this.tryReconnect(name, this.channels.get(name)!);
  }

  private handleDisconnect(name: string) {
    this.status = "disconnected";
    this.cb && this.cb(this.status);
    this.tryReconnect(name, this.channels.get(name)!);
  }

  private async tryReconnect(name: string, channel: RealtimeChannel) {
    if (this.reconnectAttempts >= this.maxReconnects) {
      this.status = "disconnected";
      this.cb && this.cb(this.status, "Max reconnects reached");
      return;
    }
    this.reconnectAttempts++;
    setTimeout(async () => {
      try {
        await channel.subscribe();
        this.status = "connected";
        this.reconnectAttempts = 0;
        this.cb && this.cb(this.status);
      } catch (err) {
        this.handleError(name, err);
      }
    }, 2000 * this.reconnectAttempts);
  }
}

export { supabase, RealtimeWatchdog, ChannelStatus };
