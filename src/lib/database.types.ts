export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          full_name: string
          avatar_color: string
          role: string
          created_at: string
        }
        Insert: {
          id: string
          full_name: string
          avatar_color?: string
          role?: string
          created_at?: string
        }
        Update: {
          id?: string
          full_name?: string
          avatar_color?: string
          role?: string
          created_at?: string
        }
      }
      tasks: {
        Row: {
          id: string
          title: string
          description: string | null
          assigned_to: string | null
          created_by: string | null
          status: string | null
          priority: string | null
          due_date: string | null
          points_value: number | null
          completed_at: string | null
          created_at: string | null
          updated_at: string | null
          duration_minutes: number | null
          photo_explanation_text: string | null
          photo_urls: Json | null
          admin_photos: Json | null
          photo_required: boolean | null
          photo_required_sometimes: boolean | null
          category: string | null
          description_photo: Json | null
          photo_proof_required: boolean | null
          photo_optional: boolean | null
          items: Json | null
          recurrence: string | null
          is_template: boolean | null
          last_generated_date: string | null
          template_id: string | null
          completion_notes: string | null
          deadline_bonus_awarded: boolean | null
          initial_points_value: number | null
          secondary_assigned_to: string | null
          reopened_count: number | null
          admin_notes: string | null
          photo_url: string | null
          review_quality: string | null
          quality_bonus_points: number | null
          helper_id: string | null
          admin_reviewed: boolean | null
          admin_approved: boolean | null
          reviewed_by: string | null
          reviewed_at: string | null
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          assigned_to?: string | null
          created_by?: string | null
          status?: string | null
          priority?: string | null
          due_date?: string | null
          points_value?: number | null
          completed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          duration_minutes?: number | null
          photo_explanation_text?: string | null
          photo_urls?: Json | null
          admin_photos?: Json | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          category?: string | null
          description_photo?: Json | null
          photo_proof_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_optional?: boolean | null
          items?: Json | null
          recurrence?: string | null
          is_template?: boolean | null
          last_generated_date?: string | null
          template_id?: string | null
          completion_notes?: string | null
          deadline_bonus_awarded?: boolean | null
          initial_points_value?: number | null
          secondary_assigned_to?: string | null
          reopened_count?: number | null
          admin_notes?: string | null
          photo_url?: string | null
          review_quality?: string | null
          quality_bonus_points?: number | null
          helper_id?: string | null
          admin_reviewed?: boolean | null
          admin_approved?: boolean | null
          reviewed_by?: string | null
          reviewed_at?: string | null
        }
        Update: {
          id?: string
          title?: string
          description?: string | null
          assigned_to?: string | null
          created_by?: string | null
          status?: string | null
          priority?: string | null
          due_date?: string | null
          points_value?: number | null
          completed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          duration_minutes?: number | null
          photo_explanation_text?: string | null
          photo_urls?: Json | null
          admin_photos?: Json | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          category?: string | null
          description_photo?: Json | null
          photo_proof_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_optional?: boolean | null
          items?: Json | null
          recurrence?: string | null
          is_template?: boolean | null
          last_generated_date?: string | null
          template_id?: string | null
          completion_notes?: string | null
          deadline_bonus_awarded?: boolean | null
          initial_points_value?: number | null
          secondary_assigned_to?: string | null
          reopened_count?: number | null
          admin_notes?: string | null
          photo_url?: string | null
          review_quality?: string | null
          quality_bonus_points?: number | null
          helper_id?: string | null
          admin_reviewed?: boolean | null
          admin_approved?: boolean | null
          reviewed_by?: string | null
          reviewed_at?: string | null
        }
      }
      checklists: {
        Row: {
          id: string
          title: string
          description: string | null
          category: string | null
          recurrence: string | null
          assigned_to: string | null
          status: string | null
          points_value: number | null
          created_at: string | null
          updated_at: string | null
          created_by: string | null
          items: Json | null
          photo_requirement: string | null
          photo_explanation: string | null
          is_template: boolean | null
          last_generated_date: string | null
          duration_minutes: number | null
          photo_required: boolean | null
          photo_required_sometimes: boolean | null
          photo_explanation_text: string | null
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          category?: string | null
          recurrence?: string | null
          assigned_to?: string | null
          status?: string | null
          points_value?: number | null
          created_at?: string | null
          updated_at?: string | null
          created_by?: string | null
          items?: Json | null
          photo_requirement?: string | null
          photo_explanation?: string | null
          is_template?: boolean | null
          last_generated_date?: string | null
          duration_minutes?: number | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_explanation_text?: string | null
        }
        Update: {
          id?: string
          title?: string
          description?: string | null
          category?: string | null
          recurrence?: string | null
          assigned_to?: string | null
          status?: string | null
          points_value?: number | null
          created_at?: string | null
          updated_at?: string | null
          created_by?: string | null
          items?: Json | null
          photo_requirement?: string | null
          photo_explanation?: string | null
          is_template?: boolean | null
          last_generated_date?: string | null
          duration_minutes?: number | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_explanation_text?: string | null
        }
      }
      notifications: {
        Row: {
          id: string
          user_id: string
          title: string
          message: string
          type: string
          is_read: boolean
          link: string | null
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          title: string
          message: string
          type: string
          is_read?: boolean
          link?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          title?: string
          message?: string
          type?: string
          is_read?: boolean
          link?: string | null
          created_at?: string
        }
      }
      points_history: {
        Row: {
          id: string
          user_id: string
          points_change: number
          reason: string
          category: string
          created_at: string
          created_by: string | null
          photo_url: string | null
        }
        Insert: {
          id?: string
          user_id: string
          points_change: number
          reason: string
          category: string
          created_at?: string
          created_by?: string | null
          photo_url?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          points_change?: number
          reason?: string
          category?: string
          created_at?: string
          created_by?: string | null
          photo_url?: string | null
        }
      }
      [key: string]: {
        Row: Record<string, any>
        Insert: Record<string, any>
        Update: Record<string, any>
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}
