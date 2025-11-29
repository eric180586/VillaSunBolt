import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log("🔔 Checking scheduled notifications...");

    // 1. Check for patrol rounds that are 5+ minutes overdue
    const { data: overduePatrols, error: patrolError } = await supabase
      .from("patrol_rounds")
      .select("id, assigned_to, scheduled_time")
      .eq("status", "pending")
      .lt("scheduled_time", new Date(Date.now() - 5 * 60 * 1000).toISOString())
      .is("notification_sent", false);

    if (patrolError) {
      console.error("Error fetching overdue patrols:", patrolError);
    } else if (overduePatrols && overduePatrols.length > 0) {
      console.log(`Found ${overduePatrols.length} overdue patrols`);
      
      for (const patrol of overduePatrols) {
        // Call the notify function
        const { error: notifyError } = await supabase.rpc(
          "notify_patrol_due",
          { p_patrol_id: patrol.id }
        );

        if (notifyError) {
          console.error(`Error notifying patrol ${patrol.id}:`, notifyError);
        } else {
          // Mark notification as sent
          await supabase
            .from("patrol_rounds")
            .update({ notification_sent: true })
            .eq("id", patrol.id);
          
          console.log(`✓ Notified patrol ${patrol.id}`);
        }
      }
    }

    // 2. Check for tasks approaching deadline
    const { error: deadlineError } = await supabase.rpc(
      "notify_task_deadline_approaching"
    );

    if (deadlineError) {
      console.error("Error checking task deadlines:", deadlineError);
    } else {
      console.log("✓ Checked task deadlines");
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Scheduled notifications checked",
        overduePatrolsCount: overduePatrols?.length || 0,
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Error in scheduled notifications:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
