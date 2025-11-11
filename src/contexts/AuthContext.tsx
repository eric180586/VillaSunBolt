import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
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
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    let profileChannel: any = null;

    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!mounted) return;
      setSession(session);
      setUser(session?.user ?? null);
      if (session?.user) {
        loadProfile(session.user.id);

        // Subscribe to profile changes for realtime role updates
        profileChannel = supabase
          .channel(`profile_${session.user.id}`)
          .on(
            'postgres_changes',
            {
              event: 'UPDATE',
              schema: 'public',
              table: 'profiles',
              filter: `id=eq.${session.user.id}`,
            },
            (payload) => {
              if (payload.new) {
                console.log('Profile updated, reloading...', payload.new);
                setProfile(payload.new as Profile);

                // Update language if changed
                const newProfile = payload.new as Profile;
                if (newProfile.preferred_language) {
                  i18n.changeLanguage(newProfile.preferred_language);
                }
              }
            }
          )
          .subscribe();
      } else {
        setLoading(false);
      }
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      (async () => {
        if (!mounted) return;
        setSession(session);
        setUser(session?.user ?? null);
        if (session?.user) {
          setLoading(true);
          await loadProfile(session.user.id);

          // Clean up old subscription
          if (profileChannel) {
            supabase.removeChannel(profileChannel);
          }

          // Create new subscription
          profileChannel = supabase
            .channel(`profile_${session.user.id}`)
            .on(
              'postgres_changes',
              {
                event: 'UPDATE',
                schema: 'public',
                table: 'profiles',
                filter: `id=eq.${session.user.id}`,
              },
              (payload) => {
                if (payload.new) {
                  console.log('Profile updated, reloading...', payload.new);
                  setProfile(payload.new as Profile);

                  const newProfile = payload.new as Profile;
                  if (newProfile.preferred_language) {
                    i18n.changeLanguage(newProfile.preferred_language);
                  }
                }
              }
            )
            .subscribe();
        } else {
          setProfile(null);
          setLoading(false);

          // Clean up subscription
          if (profileChannel) {
            supabase.removeChannel(profileChannel);
            profileChannel = null;
          }
        }
      })();
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
      if (profileChannel) {
        supabase.removeChannel(profileChannel);
      }
    };
  }, []);

  const loadProfile = async (userId: string, retryCount = 0) => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

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
                  } catch (error) {
                    console.log('Push notification setup skipped:', error.message || error);
                  }
                }
              })
              .catch((error) => {
                console.log('Push notification check skipped:', error.message || error);
              });
          } else {
            console.log('Push notifications not supported on this browser');
          }
        }, 10000);
      } else {
        console.error('Profile not found after retries, creating placeholder');
        setProfile(null);
      }

      setLoading(false);
    } catch (error) {
      console.error('Error loading profile:', error);
      setLoading(false);
    }
  };

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) throw error;
  };

  const signUp = async (email: string, password: string, fullName: string) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
    });
    if (error) throw error;

    if (data.user) {
      const { error: profileError } = await supabase
        .from('profiles')
        .insert({
          id: data.user.id,
          email: data.user.email!,
          full_name: fullName,
          role: 'staff',
        });
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
    } catch (error) {
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
        setProfile({ ...profile, preferred_language: language });
      }
    } catch (error) {
      console.error('Error updating language:', error);
      throw error;
    }
  };

  const refreshProfile = async () => {
    if (!user) return;

    console.log('Manually refreshing profile...');
    await loadProfile(user.id);
  };

  return (
    <AuthContext.Provider value={{ user, profile, session, loading, signIn, signUp, signOut, updateLanguage, refreshProfile }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
