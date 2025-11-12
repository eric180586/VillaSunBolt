import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useRealtimeSubscription } from './useRealtimeSubscription';
import type { Database } from '../lib/database.types';

type Task = Database['public']['Tables']['tasks']['Row'];
type TaskInsert = Database['public']['Tables']['tasks']['Insert'];
type TaskUpdate = Database['public']['Tables']['tasks']['Update'];

export function useTasks() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchTasks = useCallback(async () => {
    try {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const { data, error } = await supabase
        .from('tasks')
        .select('*')
        .or(`due_date.gte.${sevenDaysAgo.toISOString()},is_template.eq.true`)
        .neq('status', 'archived')
        .order('due_date', { ascending: true });

      if (error) throw error;
      setTasks(data || []);
    } catch (error) {
      console.error('Error fetching tasks:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTasks();
  }, [fetchTasks]);

  useRealtimeSubscription<Task>(
    'tasks',
    (payload) => {
      const newTask = payload.new as Task;
      setTasks((current) => {
        const exists = current.some((t) => t.id === newTask.id);
        if (exists) return current;
        return [newTask, ...current];
      });
    },
    (payload) => {
      const updatedTask = payload.new as Task;
      setTasks((current) =>
        current.map((task) => (task.id === updatedTask.id ? updatedTask : task))
      );
    },
    (payload) => {
      const oldTask = payload.old as Partial<Task>;
      setTasks((current) => current.filter((task) => task.id !== oldTask.id));
    }
  );

  useEffect(() => {
    const interval = setInterval(() => {
      fetchTasks();
    }, 30000);

    return () => clearInterval(interval);
  }, [fetchTasks]);

  const createTask = async (task: TaskInsert) => {
    const { error } = await supabase.from('tasks').insert(task);
    if (error) throw error;
  };

  const updateTask = async (id: string, updates: TaskUpdate) => {
    const { data, error } = await supabase.from('tasks').update(updates).eq('id', id).select();
    if (error) {
      console.error('Error updating task:', error);
      throw error;
    }
    return data;
  };

  const deleteTask = async (id: string) => {
    const { error } = await supabase.from('tasks').delete().eq('id', id);
    if (error) throw error;
  };

  const completeTask = async (taskId: string, userId: string) => {
    const task = tasks.find((t) => t.id === taskId);
    if (!task) return;

    await updateTask(taskId, {
      status: 'completed',
      completed_at: new Date().toISOString(),
    });
  };

  return {
    tasks,
    loading,
    createTask,
    updateTask,
    deleteTask,
    completeTask,
    refetch: fetchTasks,
  };
}
