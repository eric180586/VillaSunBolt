import type { Database } from './database.types';

type Profile = Database['public']['Tables']['profiles']['Row'];

export function isAdmin(profile: Profile | null): boolean {
  return profile?.role === 'admin' || profile?.role === 'super_admin';
}

export function isSuperAdmin(profile: Profile | null): boolean {
  return profile?.role === 'super_admin';
}

export function isStaff(profile: Profile | null): boolean {
  return profile?.role === 'staff';
}
