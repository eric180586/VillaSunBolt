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
      chat_messages: {
        Row: {
          id: string
          user_id: string
          message: string
          photo_url: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          message: string
          photo_url?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          message?: string
          photo_url?: string | null
          created_at?: string | null
        }
      }
      check_ins: {
        Row: {
          id: string
          user_id: string
          check_in_time: string
          check_out_time: string | null
          photo_url: string | null
          is_late: boolean | null
          late_reason: string | null
          minutes_late: number | null
          points_awarded: number | null
          status: string | null
          approved_by: string | null
          approved_at: string | null
          created_at: string | null
          check_in_date: string | null
        }
        Insert: {
          id?: string
          user_id: string
          check_in_time: string
          check_out_time?: string | null
          photo_url?: string | null
          is_late?: boolean | null
          late_reason?: string | null
          minutes_late?: number | null
          points_awarded?: number | null
          status?: string | null
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string | null
          check_in_date?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          check_in_time?: string
          check_out_time?: string | null
          photo_url?: string | null
          is_late?: boolean | null
          late_reason?: string | null
          minutes_late?: number | null
          points_awarded?: number | null
          status?: string | null
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string | null
          check_in_date?: string | null
        }
      }
      checklist_instances: {
        Row: {
          id: string
          checklist_id: string | null
          title: string
          instance_date: string
          assigned_to: string | null
          status: string | null
          items: Json | null
          points_awarded: number | null
          completed_at: string | null
          created_at: string | null
          updated_at: string | null
          admin_reviewed: boolean | null
          admin_approved: boolean | null
          admin_rejection_reason: string | null
          reviewed_by: string | null
          reviewed_at: string | null
          admin_photo: string | null
          photo_urls: Json | null
          admin_photos: Json | null
          photo_explanation_text: string | null
        }
        Insert: {
          id?: string
          checklist_id?: string | null
          title: string
          instance_date: string
          assigned_to?: string | null
          status?: string | null
          items?: Json | null
          points_awarded?: number | null
          completed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          admin_reviewed?: boolean | null
          admin_approved?: boolean | null
          admin_rejection_reason?: string | null
          reviewed_by?: string | null
          reviewed_at?: string | null
          admin_photo?: string | null
          photo_urls?: Json | null
          admin_photos?: Json | null
          photo_explanation_text?: string | null
        }
        Update: {
          id?: string
          checklist_id?: string | null
          title?: string
          instance_date?: string
          assigned_to?: string | null
          status?: string | null
          items?: Json | null
          points_awarded?: number | null
          completed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          admin_reviewed?: boolean | null
          admin_approved?: boolean | null
          admin_rejection_reason?: string | null
          reviewed_by?: string | null
          reviewed_at?: string | null
          admin_photo?: string | null
          photo_urls?: Json | null
          admin_photos?: Json | null
          photo_explanation_text?: string | null
        }
      }
      checklists: {
        Row: {
          id: string
          title: string
          description: string | null
          category: string | null
          created_by: string | null
          created_at: string | null
          updated_at: string | null
          points_value: number | null
          one_time: boolean | null
          duration_minutes: number | null
          photo_requirement: string | null
          photo_explanation: string | null
          photo_required: boolean | null
          photo_required_sometimes: boolean | null
          photo_explanation_text: string | null
          items: Json | null
          due_date: string | null
          recurrence: string | null
          is_template: boolean | null
          photo_optional: boolean | null
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          category?: string | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          points_value?: number | null
          one_time?: boolean | null
          duration_minutes?: number | null
          photo_requirement?: string | null
          photo_explanation?: string | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_explanation_text?: string | null
          items?: Json | null
          due_date?: string | null
          recurrence?: string | null
          is_template?: boolean | null
          photo_optional?: boolean | null
        }
        Update: {
          id?: string
          title?: string
          description?: string | null
          category?: string | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          points_value?: number | null
          one_time?: boolean | null
          duration_minutes?: number | null
          photo_requirement?: string | null
          photo_explanation?: string | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_explanation_text?: string | null
          items?: Json | null
          due_date?: string | null
          recurrence?: string | null
          is_template?: boolean | null
          photo_optional?: boolean | null
        }
      }
      daily_point_goals: {
        Row: {
          id: string
          user_id: string
          goal_date: string
          theoretically_achievable_points: number | null
          achieved_points: number | null
          team_achievable_points: number | null
          team_points_earned: number | null
          percentage: number | null
          color_status: string | null
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          goal_date: string
          theoretically_achievable_points?: number | null
          achieved_points?: number | null
          team_achievable_points?: number | null
          team_points_earned?: number | null
          percentage?: number | null
          color_status?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          goal_date?: string
          theoretically_achievable_points?: number | null
          achieved_points?: number | null
          team_achievable_points?: number | null
          team_points_earned?: number | null
          percentage?: number | null
          color_status?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
      }
      departure_requests: {
        Row: {
          id: string
          user_id: string
          request_time: string | null
          reason: string | null
          status: string | null
          approved_by: string | null
          approved_at: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          request_time?: string | null
          reason?: string | null
          status?: string | null
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          request_time?: string | null
          reason?: string | null
          status?: string | null
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string | null
        }
      }
      fortune_wheel_spins: {
        Row: {
          id: string
          user_id: string
          points_won: number
          spin_date: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          points_won: number
          spin_date?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          points_won?: number
          spin_date?: string | null
          created_at?: string | null
        }
      }
      how_to_documents: {
        Row: {
          id: string
          title: string
          description: string | null
          category: string
          created_by: string | null
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          category: string
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          title?: string
          description?: string | null
          category?: string
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
      }
      humor_modules: {
        Row: {
          id: string
          title: string
          description: string | null
          joke_text: string | null
          image_url: string | null
          category: string | null
          is_active: boolean | null
          created_by: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          joke_text?: string | null
          image_url?: string | null
          category?: string | null
          is_active?: boolean | null
          created_by?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          title?: string
          description?: string | null
          joke_text?: string | null
          image_url?: string | null
          category?: string | null
          is_active?: boolean | null
          created_by?: string | null
          created_at?: string | null
        }
      }
      notes: {
        Row: {
          id: string
          title: string
          content: string
          category: string | null
          is_important: boolean | null
          created_by: string | null
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          title: string
          content: string
          category?: string | null
          is_important?: boolean | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          title?: string
          content?: string
          category?: string | null
          is_important?: boolean | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
      }
      notifications: {
        Row: {
          id: string
          user_id: string
          title: string
          message: string
          type: string | null
          is_read: boolean | null
          link: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          title: string
          message: string
          type?: string | null
          is_read?: boolean | null
          link?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          title?: string
          message?: string
          type?: string | null
          is_read?: boolean | null
          link?: string | null
          created_at?: string | null
        }
      }
      patrol_locations: {
        Row: {
          id: string
          name: string
          qr_code: string
          description: string
          order_index: number
          created_at: string | null
          photo_explanation: string | null
        }
        Insert: {
          id?: string
          name: string
          qr_code: string
          description: string
          order_index: number
          created_at?: string | null
          photo_explanation?: string | null
        }
        Update: {
          id?: string
          name?: string
          qr_code?: string
          description?: string
          order_index?: number
          created_at?: string | null
          photo_explanation?: string | null
        }
      }
      patrol_rounds: {
        Row: {
          id: string
          date: string
          time_slot: string
          assigned_to: string | null
          completed_at: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          date: string
          time_slot: string
          assigned_to?: string | null
          completed_at?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          date?: string
          time_slot?: string
          assigned_to?: string | null
          completed_at?: string | null
          created_at?: string | null
        }
      }
      patrol_scans: {
        Row: {
          id: string
          patrol_round_id: string | null
          location_id: string | null
          user_id: string | null
          scanned_at: string | null
          photo_url: string | null
          photo_requested: boolean | null
          created_at: string | null
        }
        Insert: {
          id?: string
          patrol_round_id?: string | null
          location_id?: string | null
          user_id?: string | null
          scanned_at?: string | null
          photo_url?: string | null
          photo_requested?: boolean | null
          created_at?: string | null
        }
        Update: {
          id?: string
          patrol_round_id?: string | null
          location_id?: string | null
          user_id?: string | null
          scanned_at?: string | null
          photo_url?: string | null
          photo_requested?: boolean | null
          created_at?: string | null
        }
      }
      patrol_schedules: {
        Row: {
          id: string
          date: string
          shift: string
          assigned_to: string | null
          created_by: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          date: string
          shift: string
          assigned_to?: string | null
          created_by?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          date?: string
          shift?: string
          assigned_to?: string | null
          created_by?: string | null
          created_at?: string | null
        }
      }
      points_history: {
        Row: {
          id: string
          user_id: string
          points_change: number
          reason: string
          category: string | null
          created_by: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          points_change: number
          reason: string
          category?: string | null
          created_by?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          points_change?: number
          reason?: string
          category?: string | null
          created_by?: string | null
          created_at?: string | null
        }
      }
      profiles: {
        Row: {
          id: string
          email: string
          full_name: string
          role: string
          avatar_url: string | null
          total_points: number | null
          created_at: string | null
          updated_at: string | null
          preferred_language: string | null
        }
        Insert: {
          id: string
          email: string
          full_name: string
          role?: string
          avatar_url?: string | null
          total_points?: number | null
          created_at?: string | null
          updated_at?: string | null
          preferred_language?: string | null
        }
        Update: {
          id?: string
          email?: string
          full_name?: string
          role?: string
          avatar_url?: string | null
          total_points?: number | null
          created_at?: string | null
          updated_at?: string | null
          preferred_language?: string | null
        }
      }
      quiz_highscores: {
        Row: {
          id: string
          user_id: string
          score: number
          time_seconds: number
          created_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          score: number
          time_seconds: number
          created_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          score?: number
          time_seconds?: number
          created_at?: string | null
        }
      }
      read_receipts: {
        Row: {
          id: string
          user_id: string
          note_id: string
          read_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          note_id: string
          read_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          note_id?: string
          read_at?: string | null
        }
      }
      schedules: {
        Row: {
          id: string
          staff_id: string | null
          title: string
          start_time: string
          end_time: string
          location: string | null
          notes: string | null
          color: string | null
          created_by: string | null
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          staff_id?: string | null
          title: string
          start_time: string
          end_time: string
          location?: string | null
          notes?: string | null
          color?: string | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          staff_id?: string | null
          title?: string
          start_time?: string
          end_time?: string
          location?: string | null
          notes?: string | null
          color?: string | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
      }
      shopping_items: {
        Row: {
          id: string
          item_name: string
          description: string | null
          photo_url: string | null
          is_purchased: boolean | null
          created_by: string | null
          purchased_by: string | null
          created_at: string | null
          purchased_at: string | null
        }
        Insert: {
          id?: string
          item_name: string
          description?: string | null
          photo_url?: string | null
          is_purchased?: boolean | null
          created_by?: string | null
          purchased_by?: string | null
          created_at?: string | null
          purchased_at?: string | null
        }
        Update: {
          id?: string
          item_name?: string
          description?: string | null
          photo_url?: string | null
          is_purchased?: boolean | null
          created_by?: string | null
          purchased_by?: string | null
          created_at?: string | null
          purchased_at?: string | null
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
          deadline_bonus_awarded: boolean | null
          initial_points_value: number | null
          secondary_assigned_to: string | null
          reopened_count: number | null
          admin_notes: string | null
          photo_url: string | null
          duration_minutes: number | null
          photo_explanation_text: string | null
          photo_urls: Json | null
          admin_photos: Json | null
          category: string | null
          description_photo: Json | null
          photo_proof_required: boolean | null
          photo_required_sometimes: boolean | null
          photo_optional: boolean | null
          items: Json | null
          recurrence: string | null
          is_template: boolean | null
          last_generated_date: string | null
          template_id: string | null
          completion_notes: string | null
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
          deadline_bonus_awarded?: boolean | null
          initial_points_value?: number | null
          secondary_assigned_to?: string | null
          reopened_count?: number | null
          admin_notes?: string | null
          photo_url?: string | null
          duration_minutes?: number | null
          photo_explanation_text?: string | null
          photo_urls?: Json | null
          admin_photos?: Json | null
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
          deadline_bonus_awarded?: boolean | null
          initial_points_value?: number | null
          secondary_assigned_to?: string | null
          reopened_count?: number | null
          admin_notes?: string | null
          photo_url?: string | null
          duration_minutes?: number | null
          photo_explanation_text?: string | null
          photo_urls?: Json | null
          admin_photos?: Json | null
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
        }
      }
      tutorial_slides: {
        Row: {
          id: string
          category: string
          slide_number: number
          title: string
          content: string
          image_url: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          category: string
          slide_number: number
          title: string
          content: string
          image_url?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          category?: string
          slide_number?: number
          title?: string
          content?: string
          image_url?: string | null
          created_at?: string | null
        }
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
