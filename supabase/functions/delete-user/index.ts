import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface DeleteUserRequest {
  userId: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase configuration");
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      throw new Error("Missing authorization header");
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);

    if (authError || !user) {
      throw new Error("Unauthorized");
    }

    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (!profile || profile.role !== "admin") {
      throw new Error("Unauthorized: Admin only");
    }

    const { userId }: DeleteUserRequest = await req.json();

    if (!userId) {
      throw new Error("userId is required");
    }

    if (userId === user.id) {
      throw new Error("Cannot delete your own account");
    }

    console.log(`Admin ${user.id} deleting user ${userId}`);

    // Delete all related data in correct order to avoid FK violations
    // Order matters: delete children before parents

    // 1. Read receipts
    await supabaseAdmin.from("read_receipts").delete().eq("user_id", userId);

    // 2. Patrol scans
    await supabaseAdmin.from("patrol_scans").delete().eq("user_id", userId);

    // 3. Checklist items (completed_by)
    await supabaseAdmin.from("checklist_items").delete().eq("completed_by", userId);

    // 4. Checklist instances
    await supabaseAdmin.from("checklist_instances").delete().eq("assigned_to", userId);

    // 5. Fortune wheel spins
    await supabaseAdmin.from("fortune_wheel_spins").delete().eq("user_id", userId);

    // 6. Quiz highscores
    await supabaseAdmin.from("quiz_highscores").delete().eq("user_id", userId);

    // 7. Push subscriptions
    await supabaseAdmin.from("push_subscriptions").delete().eq("user_id", userId);

    // 8. Admin logs
    await supabaseAdmin.from("admin_logs").delete().eq("admin_id", userId);

    // 9. Daily point goals
    await supabaseAdmin.from("daily_point_goals").delete().eq("user_id", userId);

    // 10. Monthly point goals
    await supabaseAdmin.from("monthly_point_goals").delete().eq("user_id", userId);

    // 11. Points history
    await supabaseAdmin.from("points_history").delete().eq("user_id", userId);
    await supabaseAdmin.from("points_history").delete().eq("created_by", userId);

    // 12. Check-ins (user_id and approved_by)
    await supabaseAdmin.from("check_ins").delete().eq("user_id", userId);
    await supabaseAdmin.from("check_ins").delete().eq("approved_by", userId);

    // 13. Tasks (assigned_to, helper_id, created_by, reviewed_by, secondary_assigned_to)
    await supabaseAdmin.from("tasks").delete().eq("assigned_to", userId);
    await supabaseAdmin.from("tasks").delete().eq("helper_id", userId);
    await supabaseAdmin.from("tasks").delete().eq("created_by", userId);
    await supabaseAdmin.from("tasks").delete().eq("reviewed_by", userId);
    await supabaseAdmin.from("tasks").delete().eq("secondary_assigned_to", userId);

    // 14. Checklists (created_by)
    await supabaseAdmin.from("checklists").delete().eq("created_by", userId);

    // 15. Notifications
    await supabaseAdmin.from("notifications").delete().eq("user_id", userId);

    // 16. Chat messages
    await supabaseAdmin.from("chat_messages").delete().eq("user_id", userId);

    // 17. Notes
    await supabaseAdmin.from("notes").delete().eq("created_by", userId);

    // 18. Shopping items
    await supabaseAdmin.from("shopping_items").delete().eq("created_by", userId);
    await supabaseAdmin.from("shopping_items").delete().eq("purchased_by", userId);

    // 19. Weekly schedules
    await supabaseAdmin.from("weekly_schedules").delete().eq("staff_id", userId);
    await supabaseAdmin.from("weekly_schedules").delete().eq("created_by", userId);

    // 20. Patrol rounds
    await supabaseAdmin.from("patrol_rounds").delete().eq("assigned_to", userId);

    // 21. Patrol schedules
    await supabaseAdmin.from("patrol_schedules").delete().eq("assigned_to", userId);
    await supabaseAdmin.from("patrol_schedules").delete().eq("created_by", userId);

    // 22. Departure requests (user_id, admin_id, approved_by)
    await supabaseAdmin.from("departure_requests").delete().eq("user_id", userId);
    await supabaseAdmin.from("departure_requests").delete().eq("admin_id", userId);
    await supabaseAdmin.from("departure_requests").delete().eq("approved_by", userId);

    // 23. Time-off requests
    await supabaseAdmin.from("time_off_requests").delete().eq("staff_id", userId);
    await supabaseAdmin.from("time_off_requests").delete().eq("admin_id", userId);
    await supabaseAdmin.from("time_off_requests").delete().eq("reviewed_by", userId);

    // 24. How-to documents
    await supabaseAdmin.from("how_to_documents").delete().eq("created_by", userId);

    // 25. Humor modules
    await supabaseAdmin.from("humor_modules").delete().eq("created_by", userId);

    // Finally delete the profile
    const { error: profileError } = await supabaseAdmin
      .from("profiles")
      .delete()
      .eq("id", userId);

    if (profileError) {
      console.error("Error deleting profile:", profileError);
      throw new Error(`Failed to delete profile: ${profileError.message}`);
    }

    console.log(`Profile and all related data deleted for user ${userId}`);

    // Delete auth user
    const { error: authDeleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (authDeleteError) {
      console.error("Error deleting auth user:", authDeleteError);
      // Don't throw - profile is already deleted
    }

    console.log(`User deleted successfully: ${userId}`);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "User deleted successfully",
        deletedUserId: userId 
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Delete user error:", error);
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message || "Failed to delete user" 
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});