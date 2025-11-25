import { createContext, useContext, useEffect, useState, ReactNode, useCallback } from 'react';
import { User, Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import type { Database } from '../lib/database.types';
import i18n from '../lib/i18n';
import { subscribeToPushNotifications, checkPushSubscription } from '../lib/pushNotifications';

type Profile = Database['public']['Tables']['profiles']['Row'];

interface AuthContextType {
  user: User | null;
  profile: Profile | null;
  session: Session | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, fullName: string) => Promise<void>;
  signOut: () => Promise<void>;
  updateLanguage: (language: 'de' | 'en' | 'km') => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  const loadProfile = useCallback(async (userId: string, retryCount = 0) => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle() as any;

      if (error) throw error;

      if (!data && retryCount < 5) {
        await new Promise(resolve => setTimeout(resolve, 800));
        return loadProfile(userId, retryCount + 1);
      }

      if (data) {
        setProfile(data);

        if (data.preferred_language) {
          i18n.changeLanguage(data.preferred_language);
        }

        setTimeout(() => {
          if ('serviceWorker' in navigator && 'PushManager' in window) {
            navigator.serviceWorker.ready
              .then(() => checkPushSubscription())
              .then(async (existingSub) => {
                if (!existingSub && 'Notification' in window) {
                  try {
                    await subscribeToPushNotifications(userId);
                  } catch (error: any) {
                    console.log('Push notification setup skipped:', error.message || error);
                  }
                }
              })
              .catch((error: any) => {
                console.log('Push notification check skipped:', error.message || error);
              }) as any;
          } else {
            console.log('Push notifications not supported on this browser');
          }
        }, 10000);
      } else {
        console.error('Profile not found after retries, creating placeholder');
        setProfile(null);
      }

      setLoading(false);
    } catch (error: any) {
      console.error('Error loading profile:', error);
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let mounted = true;

    supabase.auth.getSession().then(({ data: { session } }: { data: { session: any } }) => {
      if (!mounted) return;
      setSession(session);
      setUser(session?.user ?? null);
      if (session?.user) {
        loadProfile(session.user.id);
      } else {
        setLoading(false);
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event: string, session: any) => {
      (async () => {
        if (!mounted) return;

        if (event === 'TOKEN_REFRESHED') {
          console.log('Token refreshed successfully');
        }

        if (event === 'SIGNED_OUT') {
          setSession(null);
          setUser(null);
          setProfile(null);
          setLoading(false);
          return;
        }

        setSession(session);
        setUser(session?.user ?? null);
        if (session?.user) {
          setLoading(true);
          await loadProfile(session.user.id);
        } else {
          setProfile(null);
          setLoading(false);
        }
      })();
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, [loadProfile]);

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    }) as any;
    if (error) throw error;
  };

  const signUp = async (email: string, password: string, fullName: string) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    }) as any;
    if (error) throw error;

    if (data.user) {
      const { error: profileError } = await supabase
        .from('profiles')
        .insert({
          id: data.user.id,
          email: data.user.email!,
          full_name: fullName,
          role: 'staff',
        }) as any;
      if (profileError) throw profileError;
    }
  };

  const signOut = async () => {
    try {
      setProfile(null);
      setUser(null);

      try {
        await supabase.auth.signOut();
      } catch (signOutError) {
        console.warn('Sign out warning:', signOutError);
      }

      localStorage.clear();
      sessionStorage.clear();

      window.location.href = '/';
    } catch (error: any) {
      console.error('Sign out error:', error);
      window.location.href = '/';
    }
  };

  const updateLanguage = async (language: 'de' | 'en' | 'km') => {
    if (!user) return;

    try {
      const { error } = await supabase
        .from('profiles')
        .update({ preferred_language: language })
        .eq('id', user.id);

      if (error) throw error;

      i18n.changeLanguage(language);

      if (profile) {
        setProfile({ ...profile, preferred_language: language }) as any;
      }
    } catch (error: any) {
      console.error('Error updating language:', error);
      throw error;
    }
  };

  return (
    <AuthContext.Provider value={{ user, profile, session, loading, signIn, signUp, signOut, updateLanguage }}>
      {children}
    </AuthContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
