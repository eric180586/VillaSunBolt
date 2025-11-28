import i18n from './i18n';

/**
 * Get the translated category name for a task category
 */
export function getTaskCategoryName(category: string): string {
  const categoryMap: Record<string, string> = {
    room_cleaning: i18n.t('tasks.categoryRoomCleaning'),
    small_cleaning: i18n.t('tasks.categorySmallCleaning'),
    extras: i18n.t('tasks.categoryExtras'),
    repair: i18n.t('tasks.categoryRepair'),
  };

  return categoryMap[category] || category;
}

/**
 * Get the full display title for a task including category prefix
 * E.g., "Small Cleaning Jupiter" instead of just "Jupiter"
 */
export function getTaskDisplayTitle(task: { title: string; category?: string }): string {
  if (!task.category || task.category === 'extras') {
    // For extras or no category, just show the title
    return task.title;
  }

  const categoryName = getTaskCategoryName(task.category);
  return `${categoryName} ${task.title}`;
}
