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
      admin_logs: {
        Row: {
          id: string
          admin_id: string | null
          action_type: string
          target_table: string
          target_id: string | null
          target_name: string | null
          old_data: Json | null
          new_data: Json | null
          reason: string | null
          ip_address: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          admin_id?: string | null
          action_type: string
          target_table: string
          target_id?: string | null
          target_name?: string | null
          old_data?: Json | null
          new_data?: Json | null
          reason?: string | null
          ip_address?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          admin_id?: string | null
          action_type?: string
          target_table?: string
          target_id?: string | null
          target_name?: string | null
          old_data?: Json | null
          new_data?: Json | null
          reason?: string | null
          ip_address?: string | null
          created_at?: string | null
        }
      }
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
          shift_type: string | null
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
          shift_type?: string | null
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
          shift_type?: string | null
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
          photo_urls?: Json | null
          admin_photos?: Json | null
          photo_explanation_text?: string | null
        }
      }
      checklist_items: {
        Row: {
          id: string
          checklist_id: string
          title: string
          description: string | null
          order_index: number | null
          is_completed: boolean | null
          completed_by: string | null
          completed_at: string | null
          created_at: string | null
          updated_at: string | null
          title_de: string | null
          title_en: string | null
          title_km: string | null
          description_de: string | null
          description_en: string | null
          description_km: string | null
        }
        Insert: {
          id?: string
          checklist_id: string
          title: string
          description?: string | null
          order_index?: number | null
          is_completed?: boolean | null
          completed_by?: string | null
          completed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          description_de?: string | null
          description_en?: string | null
          description_km?: string | null
        }
        Update: {
          id?: string
          checklist_id?: string
          title?: string
          description?: string | null
          order_index?: number | null
          is_completed?: boolean | null
          completed_by?: string | null
          completed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          description_de?: string | null
          description_en?: string | null
          description_km?: string | null
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
          recurrence: string | null
          due_date: string | null
          points_value: number | null
          is_template: boolean | null
          last_generated_date: string | null
          one_time: boolean | null
          duration_minutes: number | null
          photo_requirement: string | null
          photo_explanation: string | null
          photo_required: boolean | null
          photo_required_sometimes: boolean | null
          photo_explanation_text: string | null
          items: Json | null
          photo_optional: boolean | null
          title_de: string | null
          title_en: string | null
          title_km: string | null
          description_de: string | null
          description_en: string | null
          description_km: string | null
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          category?: string | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          recurrence?: string | null
          due_date?: string | null
          points_value?: number | null
          is_template?: boolean | null
          last_generated_date?: string | null
          one_time?: boolean | null
          duration_minutes?: number | null
          photo_requirement?: string | null
          photo_explanation?: string | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_explanation_text?: string | null
          items?: Json | null
          photo_optional?: boolean | null
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          description_de?: string | null
          description_en?: string | null
          description_km?: string | null
        }
        Update: {
          id?: string
          title?: string
          description?: string | null
          category?: string | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          recurrence?: string | null
          due_date?: string | null
          points_value?: number | null
          is_template?: boolean | null
          last_generated_date?: string | null
          one_time?: boolean | null
          duration_minutes?: number | null
          photo_requirement?: string | null
          photo_explanation?: string | null
          photo_required?: boolean | null
          photo_required_sometimes?: boolean | null
          photo_explanation_text?: string | null
          items?: Json | null
          photo_optional?: boolean | null
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          description_de?: string | null
          description_en?: string | null
          description_km?: string | null
        }
      }
      daily_point_goals: {
        Row: {
          id: string
          goal_date: string
          team_achievable_points: number | null
          team_points_earned: number | null
          created_at: string | null
          updated_at: string | null
          user_id: string
          theoretically_achievable_points: number | null
          achieved_points: number | null
          percentage: number | null
          color_status: string | null
        }
        Insert: {
          id?: string
          goal_date: string
          team_achievable_points?: number | null
          team_points_earned?: number | null
          created_at?: string | null
          updated_at?: string | null
          user_id: string
          theoretically_achievable_points?: number | null
          achieved_points?: number | null
          percentage?: number | null
          color_status?: string | null
        }
        Update: {
          id?: string
          goal_date?: string
          team_achievable_points?: number | null
          team_points_earned?: number | null
          created_at?: string | null
          updated_at?: string | null
          user_id?: string
          theoretically_achievable_points?: number | null
          achieved_points?: number | null
          percentage?: number | null
          color_status?: string | null
        }
      }
      departure_requests: {
        Row: {
          id: string
          user_id: string
          request_time: string | null
          reason: string | null
          status: string
          approved_by: string | null
          approved_at: string | null
          created_at: string | null
          shift_date: string | null
          shift_type: string | null
          admin_id: string | null
          processed_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          request_time?: string | null
          reason?: string | null
          status?: string
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string | null
          shift_date?: string | null
          shift_type?: string | null
          admin_id?: string | null
          processed_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          request_time?: string | null
          reason?: string | null
          status?: string
          approved_by?: string | null
          approved_at?: string | null
          created_at?: string | null
          shift_date?: string | null
          shift_type?: string | null
          admin_id?: string | null
          processed_at?: string | null
        }
      }
      fortune_wheel_spins: {
        Row: {
          id: string
          user_id: string
          points_won: number
          spin_date: string | null
          created_at: string | null
          check_in_id: string | null
          reward_type: string | null
          reward_value: number | null
          reward_label: string | null
        }
        Insert: {
          id?: string
          user_id: string
          points_won: number
          spin_date?: string | null
          created_at?: string | null
          check_in_id?: string | null
          reward_type?: string | null
          reward_value?: number | null
          reward_label?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          points_won?: number
          spin_date?: string | null
          created_at?: string | null
          check_in_id?: string | null
          reward_type?: string | null
          reward_value?: number | null
          reward_label?: string | null
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
          sort_order: number | null
          file_paths: Json | null
          file_url: string
          file_type: string
          file_name: string
          file_size: number
        }
        Insert: {
          id?: string
          title: string
          description?: string | null
          category: string
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          sort_order?: number | null
          file_paths?: Json | null
          file_url?: string
          file_type?: string
          file_name?: string
          file_size?: number
        }
        Update: {
          id?: string
          title?: string
          description?: string | null
          category?: string
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          sort_order?: number | null
          file_paths?: Json | null
          file_url?: string
          file_type?: string
          file_name?: string
          file_size?: number
        }
      }
      how_to_steps: {
        Row: {
          id: string
          document_id: string
          step_number: number
          title: string
          description: string
          photo_url: string | null
          video_url: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          document_id: string
          step_number: number
          title: string
          description: string
          photo_url?: string | null
          video_url?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          document_id?: string
          step_number?: number
          title?: string
          description?: string
          photo_url?: string | null
          video_url?: string | null
          created_at?: string | null
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
          sort_order: number | null
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
          sort_order?: number | null
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
          sort_order?: number | null
        }
      }
      monthly_point_goals: {
        Row: {
          id: string
          user_id: string
          month: string
          total_achievable_points: number | null
          total_achieved_points: number | null
          percentage: number | null
          color_status: string | null
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          month: string
          total_achievable_points?: number | null
          total_achieved_points?: number | null
          percentage?: number | null
          color_status?: string | null
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          month?: string
          total_achievable_points?: number | null
          total_achieved_points?: number | null
          percentage?: number | null
          color_status?: string | null
          created_at?: string | null
          updated_at?: string | null
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
          title_de: string | null
          title_en: string | null
          title_km: string | null
          content_de: string | null
          content_en: string | null
          content_km: string | null
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
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          content_de?: string | null
          content_en?: string | null
          content_km?: string | null
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
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          content_de?: string | null
          content_en?: string | null
          content_km?: string | null
        }
      }
      notification_translations: {
        Row: {
          key: string
          title_de: string
          title_en: string
          title_km: string
          message_template_de: string
          message_template_en: string
          message_template_km: string
          created_at: string | null
        }
        Insert: {
          key: string
          title_de: string
          title_en: string
          title_km: string
          message_template_de: string
          message_template_en: string
          message_template_km: string
          created_at?: string | null
        }
        Update: {
          key?: string
          title_de?: string
          title_en?: string
          title_km?: string
          message_template_de?: string
          message_template_en?: string
          message_template_km?: string
          created_at?: string | null
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
          title_de: string | null
          title_en: string | null
          title_km: string | null
          message_de: string | null
          message_en: string | null
          message_km: string | null
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
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          message_de?: string | null
          message_en?: string | null
          message_km?: string | null
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
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          message_de?: string | null
          message_en?: string | null
          message_km?: string | null
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
        }
        Insert: {
          id?: string
          name: string
          qr_code: string
          description: string
          order_index: number
          created_at?: string | null
        }
        Update: {
          id?: string
          name?: string
          qr_code?: string
          description?: string
          order_index?: number
          created_at?: string | null
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
          notification_sent: boolean | null
          scheduled_time: string | null
          points_awarded: number | null
          points_calculated: boolean | null
        }
        Insert: {
          id?: string
          date: string
          time_slot: string
          assigned_to?: string | null
          completed_at?: string | null
          created_at?: string | null
          notification_sent?: boolean | null
          scheduled_time?: string | null
          points_awarded?: number | null
          points_calculated?: boolean | null
        }
        Update: {
          id?: string
          date?: string
          time_slot?: string
          assigned_to?: string | null
          completed_at?: string | null
          created_at?: string | null
          notification_sent?: boolean | null
          scheduled_time?: string | null
          points_awarded?: number | null
          points_calculated?: boolean | null
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
      point_templates: {
        Row: {
          id: string
          category: string
          name: string
          points: number
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          category: string
          name: string
          points?: number
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          category?: string
          name?: string
          points?: number
          created_at?: string | null
          updated_at?: string | null
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
          photo_url: string | null
          daily_achievable_points: number | null
          daily_achieved_points: number | null
          daily_percentage: number | null
        }
        Insert: {
          id?: string
          user_id: string
          points_change: number
          reason: string
          category?: string | null
          created_by?: string | null
          created_at?: string | null
          photo_url?: string | null
          daily_achievable_points?: number | null
          daily_achieved_points?: number | null
          daily_percentage?: number | null
        }
        Update: {
          id?: string
          user_id?: string
          points_change?: number
          reason?: string
          category?: string | null
          created_by?: string | null
          created_at?: string | null
          photo_url?: string | null
          daily_achievable_points?: number | null
          daily_achieved_points?: number | null
          daily_percentage?: number | null
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
          avatar_color: string
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
          avatar_color?: string
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
          avatar_color?: string
        }
      }
      push_subscriptions: {
        Row: {
          id: string
          user_id: string
          endpoint: string
          p256dh: string
          auth: string
          user_agent: string | null
          created_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          endpoint: string
          p256dh: string
          auth: string
          user_agent?: string | null
          created_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          endpoint?: string
          p256dh?: string
          auth?: string
          user_agent?: string | null
          created_at?: string | null
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
          deadline_bonus_awarded: boolean | null
          initial_points_value: number | null
          secondary_assigned_to: string | null
          reopened_count: number | null
          admin_notes: string | null
          review_quality: string | null
          quality_bonus_points: number | null
          helper_id: string | null
          admin_reviewed: boolean | null
          admin_approved: boolean | null
          reviewed_by: string | null
          reviewed_at: string | null
          title_de: string | null
          title_en: string | null
          title_km: string | null
          description_de: string | null
          description_en: string | null
          description_km: string | null
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
          review_quality?: string | null
          quality_bonus_points?: number | null
          helper_id?: string | null
          admin_reviewed?: boolean | null
          admin_approved?: boolean | null
          reviewed_by?: string | null
          reviewed_at?: string | null
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          description_de?: string | null
          description_en?: string | null
          description_km?: string | null
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
          review_quality?: string | null
          quality_bonus_points?: number | null
          helper_id?: string | null
          admin_reviewed?: boolean | null
          admin_approved?: boolean | null
          reviewed_by?: string | null
          reviewed_at?: string | null
          title_de?: string | null
          title_en?: string | null
          title_km?: string | null
          description_de?: string | null
          description_en?: string | null
          description_km?: string | null
        }
      }
      time_off_requests: {
        Row: {
          id: string
          staff_id: string
          request_date: string
          reason: string | null
          status: string
          admin_id: string | null
          processed_at: string | null
          created_at: string | null
          updated_at: string | null
          admin_response: string | null
          reviewed_at: string | null
          reviewed_by: string | null
        }
        Insert: {
          id?: string
          staff_id: string
          request_date: string
          reason?: string | null
          status?: string
          admin_id?: string | null
          processed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          admin_response?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
        }
        Update: {
          id?: string
          staff_id?: string
          request_date?: string
          reason?: string | null
          status?: string
          admin_id?: string | null
          processed_at?: string | null
          created_at?: string | null
          updated_at?: string | null
          admin_response?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
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
      weekly_schedules: {
        Row: {
          id: string
          staff_id: string
          week_start_date: string
          shifts: Json
          is_published: boolean | null
          created_by: string | null
          created_at: string | null
          updated_at: string | null
          published_at: string | null
        }
        Insert: {
          id?: string
          staff_id: string
          week_start_date: string
          shifts?: Json
          is_published?: boolean | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          published_at?: string | null
        }
        Update: {
          id?: string
          staff_id?: string
          week_start_date?: string
          shifts?: Json
          is_published?: boolean | null
          created_by?: string | null
          created_at?: string | null
          updated_at?: string | null
          published_at?: string | null
        }
      }
    }
    Functions: {
      [_ in never]: never
    }
  }
}
