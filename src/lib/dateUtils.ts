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
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  return formatter.format(d);
}

export function formatTimeForInput(date: Date | string): string {
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
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  const dateStr1 = formatter.format(new Date(date1));
  const dateStr2 = formatter.format(new Date(date2));
  return dateStr1 === dateStr2;
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

export function getCurrentCambodiaTime(): Date {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
  const parts = formatter.formatToParts(now);
  const getPart = (type: string) => parts.find(p => p.type === type)?.value || '0';

  const year = parseInt(getPart('year'));
  const month = parseInt(getPart('month')) - 1;
  const day = parseInt(getPart('day'));
  const hour = parseInt(getPart('hour'));
  const minute = parseInt(getPart('minute'));
  const second = parseInt(getPart('second'));

  return new Date(Date.UTC(year, month, day, hour - 7, minute, second));
}

export function formatCambodiaDateTime(date: Date | string): string {
  const d = new Date(date);
  const formatter = new Intl.DateTimeFormat('de-DE', {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
  return formatter.format(d);
}

export function formatCambodiaDate(date: Date | string): string {
  const d = new Date(date);
  const formatter = new Intl.DateTimeFormat('de-DE', {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  return formatter.format(d);
}

export function formatCambodiaTime(date: Date | string): string {
  const d = new Date(date);
  const formatter = new Intl.DateTimeFormat('de-DE', {
    timeZone: 'Asia/Phnom_Penh',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  });
  return formatter.format(d);
}

// Helper functions to replace toLocaleString/toLocaleDateString/toLocaleTimeString
export function toLocaleStringCambodia(date: Date | string, locale: string = 'de-DE', options?: Intl.DateTimeFormatOptions): string {
  const d = new Date(date);
  const defaultOptions: Intl.DateTimeFormatOptions = {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    ...options
  };
  const formatter = new Intl.DateTimeFormat(locale, defaultOptions);
  return formatter.format(d);
}

export function toLocaleDateStringCambodia(date: Date | string, locale: string = 'de-DE', options?: Intl.DateTimeFormatOptions): string {
  const d = new Date(date);
  const defaultOptions: Intl.DateTimeFormatOptions = {
    timeZone: 'Asia/Phnom_Penh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    ...options
  };
  const formatter = new Intl.DateTimeFormat(locale, defaultOptions);
  return formatter.format(d);
}

export function toLocaleTimeStringCambodia(date: Date | string, locale: string = 'de-DE', options?: Intl.DateTimeFormatOptions): string {
  const d = new Date(date);
  const defaultOptions: Intl.DateTimeFormatOptions = {
    timeZone: 'Asia/Phnom_Penh',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    ...options
  };
  const formatter = new Intl.DateTimeFormat(locale, defaultOptions);
  return formatter.format(d);
}
