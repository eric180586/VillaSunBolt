import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import webpush from 'npm:web-push@3.6.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface PushPayload {
  user_ids?: string[];
  role?: string;
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  data?: any;
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
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // VAPID keys should be set as environment variables
    const vapidPublicKey = Deno.env.get('VAPID_PUBLIC_KEY');
    const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY');
    const vapidEmail = Deno.env.get('VAPID_EMAIL') || 'mailto:admin@villasun.com';

    if (!vapidPublicKey || !vapidPrivateKey) {
      console.warn('VAPID keys not configured. Push notifications will not be sent.');
      return new Response(
        JSON.stringify({
          success: false,
          error: 'VAPID keys not configured',
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    webpush.setVapidDetails(
      vapidEmail,
      vapidPublicKey,
      vapidPrivateKey
    );

    const payload: PushPayload = await req.json();
    const { user_ids, role, title, body, icon, badge, data } = payload;

    let targetUserIds: string[] = [];

    // Determine target users
    if (user_ids && user_ids.length > 0) {
      targetUserIds = user_ids;
    } else if (role) {
      const { data: profiles, error } = await supabase
        .from('profiles')
        .select('id')
        .eq('role', role);

      if (error) throw error;
      targetUserIds = profiles?.map((p) => p.id) || [];
    } else {
      throw new Error('Either user_ids or role must be specified');
    }

    if (targetUserIds.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          message: 'No target users found',
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Get push subscriptions for target users
    const { data: subscriptions, error: subError } = await supabase
      .from('push_subscriptions')
      .select('*')
      .in('user_id', targetUserIds);

    if (subError) throw subError;

    if (!subscriptions || subscriptions.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          sent: 0,
          message: 'No active push subscriptions found',
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Send push notifications
    const pushPromises = subscriptions.map(async (sub) => {
      try {
        const pushSubscription = {
          endpoint: sub.endpoint,
          keys: {
            p256dh: sub.p256dh,
            auth: sub.auth,
          },
        };

        const notificationPayload = JSON.stringify({
          title,
          body,
          icon: icon || '/icon-192.png',
          badge: badge || '/badge-72.png',
          data: data || {},
        });

        await webpush.sendNotification(pushSubscription, notificationPayload);
        return { success: true, subscription_id: sub.id };
      } catch (error) {
        console.error(`Failed to send push to subscription ${sub.id}:`, error);
        
        // If subscription is invalid/expired, delete it
        if (error.statusCode === 410 || error.statusCode === 404) {
          await supabase
            .from('push_subscriptions')
            .delete()
            .eq('id', sub.id);
        }
        
        return { success: false, subscription_id: sub.id, error: error.message };
      }
    });

    const results = await Promise.allSettled(pushPromises);
    const successCount = results.filter(
      (r) => r.status === 'fulfilled' && r.value.success
    ).length;

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        total: subscriptions.length,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Push notification error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
