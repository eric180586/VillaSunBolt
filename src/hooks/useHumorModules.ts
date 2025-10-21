import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';

export interface HumorModule {
  id: string;
  name: string;
  label: string;
  percentage: number;
  is_active: boolean;
  sort_order: number;
  icon_name: string;
  color_class: string;
  created_at: string;
  updated_at: string;
}

export function useHumorModules() {
  const [modules, setModules] = useState<HumorModule[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchModules = async () => {
    const { data, error } = await supabase
      .from('humor_modules')
      .select('*')
      .order('sort_order');

    if (error) {
      console.error('Error fetching humor modules:', error);
      return;
    }

    setModules(data || []);
    setLoading(false);
  };

  useEffect(() => {
    fetchModules();
  }, []);

  useRealtimeSubscription('humor_modules', fetchModules);

  const toggleModule = async (id: string, isActive: boolean) => {
    const { error } = await supabase
      .from('humor_modules')
      .update({ is_active: isActive, updated_at: new Date().toISOString() })
      .eq('id', id);

    if (error) {
      console.error('Error toggling humor module:', error);
      return;
    }

    await fetchModules();
  };

  return {
    modules,
    activeModules: modules.filter((m) => m.is_active),
    loading,
    toggleModule,
    refetch: fetchModules,
  };
}
