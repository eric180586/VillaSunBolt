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

    // Delete all related data first (in correct order to avoid FK violations)

    // 1. Delete daily_point_goals
    await supabaseAdmin
      .from("daily_point_goals")
      .delete()
      .eq("user_id", userId);

    // 2. Delete monthly_point_goals
    await supabaseAdmin
      .from("monthly_point_goals")
      .delete()
      .eq("user_id", userId);

    // 3. Delete points_history
    await supabaseAdmin
      .from("points_history")
      .delete()
      .eq("user_id", userId);

    // 4. Delete check_ins
    await supabaseAdmin
      .from("check_ins")
      .delete()
      .eq("user_id", userId);

    // 5. Delete tasks assigned to user
    await supabaseAdmin
      .from("tasks")
      .delete()
      .eq("assigned_to", userId);

    // 6. Delete notifications
    await supabaseAdmin
      .from("notifications")
      .delete()
      .eq("user_id", userId);

    // 7. Delete chat messages
    await supabaseAdmin
      .from("team_chat")
      .delete()
      .eq("user_id", userId);

    // 8. Delete schedules
    await supabaseAdmin
      .from("weekly_schedules")
      .delete()
      .eq("staff_id", userId);

    // 9. Delete fortune wheel spins
    await supabaseAdmin
      .from("fortune_wheel_spins")
      .delete()
      .eq("user_id", userId);

    // 10. Delete patrol rounds
    await supabaseAdmin
      .from("patrol_rounds")
      .delete()
      .eq("user_id", userId);

    // 11. Delete departure requests
    await supabaseAdmin
      .from("departure_requests")
      .delete()
      .eq("user_id", userId);

    // 12. Delete notes
    await supabaseAdmin
      .from("notes")
      .delete()
      .eq("author_id", userId);

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

    const { error: authDeleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (authDeleteError) {
      console.error("Error deleting auth user:", authDeleteError);
      throw new Error(`Failed to delete auth user: ${authDeleteError.message}`);
    }

    console.log(`Auth user deleted: ${userId}`);

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