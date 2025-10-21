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
        }
      }
    }
  }
}
