import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import type { Database } from '../lib/database.types';

type Note = Database['public']['Tables']['notes']['Row'];
type NoteInsert = Database['public']['Tables']['notes']['Insert'];
type NoteUpdate = Database['public']['Tables']['notes']['Update'];

export function useNotes() {
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchNotes = useCallback(async () => {
    try {
      const { data, error } = await supabase
        .from('notes')
        .select('*')
        .order('is_important', { ascending: false })
        .order('created_at', { ascending: false });

      if (error) throw error;
      setNotes(data || []);
    } catch (error) {
      console.error('Error fetching notes:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchNotes();
  }, [fetchNotes]);

  useRealtimeSubscription<Note>(
    'notes',
    (payload) => {
      setNotes((current) => [payload.new as Note, ...current]);
    },
    (payload) => {
      setNotes((current) =>
        current.map((note) => (note.id === payload.new.id ? (payload.new as Note) : note))
      );
    },
    (payload) => {
      setNotes((current) => current.filter((note) => note.id !== payload.old.id));
    }
  );

  const createNote = async (note: NoteInsert) => {
    const { error } = await supabase.from('notes').insert(note);
    if (error) throw error;
  };

  const updateNote = async (id: string, updates: NoteUpdate) => {
    const { error } = await supabase.from('notes').update(updates).eq('id', id);
    if (error) throw error;
  };

  const deleteNote = async (id: string) => {
    const { error } = await supabase.from('notes').delete().eq('id', id);
    if (error) throw error;
  };

  return {
    notes,
    loading,
    createNote,
    updateNote,
    deleteNote,
    refetch: fetchNotes,
  };
}
