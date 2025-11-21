import type { Database } from './database.types';

type Task = Database['public']['Tables']['tasks']['Row'];

export function isSameDay(date1: Date | string, date2: Date | string): boolean {
  const d1 = new Date(date1);
  const d2 = new Date(date2);
  d1.setHours(0, 0, 0, 0);
  d2.setHours(0, 0, 0, 0);
  return d1.getTime() === d2.getTime();
}

export function getTodayTasks(tasks: Task[]): Task[] {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  return tasks.filter((task) => {
    if (task.status === 'archived') return false;

    if (task.recurrence === 'daily') return true;

    if (!task.due_date) return false;

    return isSameDay(task.due_date, today);
  }) as any;
}

export function getMyTasks(tasks: Task[], userId: string | undefined): Task[] {
  if (!userId) return [];

  return tasks.filter((task) =>
    task.assigned_to === userId ||
    task.secondary_assigned_to === userId ||
    task.assigned_to === null
  );
}

export function getTodayMyTasks(tasks: Task[], userId: string | undefined): Task[] {
  const todayTasks = getTodayTasks(tasks);
  return getMyTasks(todayTasks, userId);
}
