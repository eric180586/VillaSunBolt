import { createClient } from 'npm:@supabase/supabase-js@2.57.4';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface ResetResult {
  checklists_generated: number;
  goals_updated: boolean;
  tasks_archived: number;
  checklists_archived: number;
  timestamp: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing environment variables');
    }
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log('Starting daily reset...');

    // 1. Generate due checklists
    const { data: checklistData, error: checklistError } = await supabase
      .rpc('generate_due_checklists');

    if (checklistError) {
      console.error('Error generating checklists:', checklistError);
      // Don't throw, continue with goals
    }

    console.log('Checklists generated:', checklistData);

    // 2. Initialize daily goals for today
    const { error: goalsError } = await supabase
      .rpc('initialize_daily_goals_for_today');

    if (goalsError) {
      console.error('Error initializing daily goals:', goalsError);
      // Don't throw, continue with cleanup
    }

    console.log('Daily goals initialized');

    // 3. Cleanup old notifications (older than 30 days)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const { error: cleanupError } = await supabase
      .from('notifications')
      .delete()
      .lt('created_at', thirtyDaysAgo.toISOString());

    if (cleanupError) {
      console.error('Error cleaning up notifications:', cleanupError);
    }

    console.log('Old notifications cleaned up');

    // 4. Archive completed tasks and checklists from previous days
    const { data: archiveData, error: archiveError } = await supabase
      .rpc('archive_old_completed_tasks');

    if (archiveError) {
      console.error('Error archiving old tasks:', archiveError);
    }

    console.log('Old completed tasks archived:', archiveData);

    const result: ResetResult = {
      checklists_generated: checklistData || 0,
      goals_updated: !goalsError,
      tasks_archived: archiveData?.tasks_archived || 0,
      checklists_archived: archiveData?.checklists_archived || 0,
      timestamp: new Date().toISOString(),
    };

    console.log('Daily reset completed:', result);

    return new Response(
      JSON.stringify({
        success: true,
        result,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Daily reset error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});