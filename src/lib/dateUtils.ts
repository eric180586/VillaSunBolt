export const TIMEZONE_OFFSET = 7;

export function getLocalDate(date?: Date | string): Date {
  const d = date ? new Date(date) : new Date();
  return d;
}

export function formatDateForDisplay(date: Date | string): string {
  const d = new Date(date);

  // Create formatter for Cambodia timezone (UTC+7)
  const options: Intl.DateTimeFormatOptions = {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  };

  const formatter = new Intl.DateTimeFormat('en-US', options);
  const parts = formatter.formatToParts(d);

  const getPart = (type: string) => parts.find(p => p.type === type)?.value || '';

  const month = getPart('month');
  const day = getPart('day');
  const year = getPart('year');

  return `${month}/${day}/${year}`;
}

export function formatDateTimeForDisplay(date: Date | string): string {
  const d = new Date(date);

  // Create formatter for Cambodia timezone (UTC+7)
  const options: Intl.DateTimeFormatOptions = {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  };

  const formatter = new Intl.DateTimeFormat('en-US', options);
  const parts = formatter.formatToParts(d);

  const getPart = (type: string) => parts.find(p => p.type === type)?.value || '';

  const month = getPart('month');
  const day = getPart('day');
  const year = getPart('year');
  const hours = getPart('hour');
  const minutes = getPart('minute');

  return `${month}/${day}/${year}, ${hours}:${minutes}`;
}

export function formatDateForInput(date: Date | string): string {
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function formatTimeForInput(date: Date | string): string {
  const d = new Date(date);
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  return `${hours}:${minutes}`;
}

export function getTodayDateString(): string {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  return formatter.format(now);
}

export function isSameDay(date1: Date | string, date2: Date | string): boolean {
  const d1 = new Date(date1);
  const d2 = new Date(date2);
  return (
    d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate()
  );
}

export function getTodayStart(): Date {
  const todayStr = getTodayDateString();
  return new Date(`${todayStr}T00:00:00+07:00`);
}

export function getTodayEnd(): Date {
  const todayStr = getTodayDateString();
  return new Date(`${todayStr}T23:59:59+07:00`);
}

export function combineDateAndTime(date: string, time: string): string {
  const combined = `${date}T${time}:00+07:00`;
  const localDate = new Date(combined);
  return localDate.toISOString();
}

export function formatTimeForInputFromUTC(date: Date | string): string {
  const d = new Date(date);
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Phnom_Penh',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
  const parts = formatter.formatToParts(d);
  const hours = parts.find(p => p.type === 'hour')?.value || '00';
  const minutes = parts.find(p => p.type === 'minute')?.value || '00';
  return `${hours}:${minutes}`;
}

export function formatDateForInputFromUTC(date: Date | string): string {
  const d = new Date(date);
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  return formatter.format(d);
}
