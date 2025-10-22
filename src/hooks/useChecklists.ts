import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';

export function useChecklists() {
  const [checklists, setChecklists] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchChecklists = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('tasks')
        .select('*')
        .eq('is_template', true)
        .not('items', 'is', null)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setChecklists(data || []);
    } catch (error) {
      console.error('Error fetching checklists:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchChecklists();

    const subscription = supabase
      .channel('checklist_templates_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'tasks',
          filter: 'is_template=eq.true',
        },
        () => {
          fetchChecklists();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [fetchChecklists]);

  return {
    checklists,
    loading,
    refetch: fetchChecklists,
  };
}
