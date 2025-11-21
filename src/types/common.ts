// Common TypeScript interfaces for the application

export interface CheckInResult {
  success: boolean;
  message: string;
  check_in_id?: string;
  points_awarded?: number;
  status?: string;
  is_late?: boolean;
  minutes_late?: number;
}

export interface CheckIn {
  id: string;
  user_id: string;
  check_in_time: string;
  shift_type: string;
  status: string;
  approved_by?: string | null;
  approved_at?: string | null;
  points_awarded?: number;
  late_reason?: string | null;
  check_in_date?: string;
  is_late?: boolean;
  minutes_late?: number;
}

export interface ScheduleShift {
  date: string;
  shift: string;
}

export interface Schedule {
  id: string;
  user_id: string;
  week_start: string;
  shifts: ScheduleShift[];
}

export interface FortuneWheelSegment {
  id: string;
  label: string;
  points?: number;
  color: string;
  actualPoints: number;
  rewardType?: string;
  rewardValue?: number;
}

export interface WheelSegment {
  id: string;
  label: string;
  color: string;
  points: number;
}

export interface ChatMessage {
  id: string;
  user_id: string;
  message: string;
  photo_url?: string | null;
  created_at: string;
  profiles?: {
    full_name: string;
    avatar_url?: string | null;
  };
}

export interface Profile {
  id: string;
  full_name: string;
  email?: string;
  role: 'admin' | 'staff';
  avatar_url?: string | null;
  avatar_color?: string;
  points_today?: number;
  points_week?: number;
  points_month?: number;
}

export interface Task {
  id: string;
  title: string;
  description?: string;
  status: 'open' | 'in_progress' | 'pending_review' | 'completed' | 'archived';
  priority?: 'low' | 'medium' | 'high';
  assigned_to?: string | null;
  helper_id?: string | null;
  due_date?: string | null;
  created_by: string;
  created_at: string;
  points?: number;
  recurrence?: 'daily' | 'weekly' | null;
  photo_required?: boolean;
  photo_url?: string | null;
  completion_photo_url?: string | null;
  admin_review_notes?: string | null;
  review_quality?: 'excellent' | 'good' | 'needs_improvement';
}

export interface DailyGoal {
  id: string;
  user_id: string;
  goal_date: string;
  achievable_points: number;
  points_earned: number;
  team_achievable_points: number;
  team_points_earned: number;
}

export interface DepartureRequest {
  id: string;
  user_id: string;
  shift_date: string;
  shift_type: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
  admin_id?: string | null;
  processed_at?: string | null;
}
