import { createClient } from "npm:@supabase/supabase-js@2";
import { RoomServiceClient } from "npm:livekit-server-sdk@2.6.1";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    const apiKey = Deno.env.get("LIVEKIT_API_KEY");
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
    if (!supabaseUrl || !anonKey || !serviceKey || !livekitUrl || !apiKey || !apiSecret) {
      return json({ error: "server configuration incomplete" }, 500);
    }

    const authHeader = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const roomId = body?.room_id;
    const identity = body?.participant_identity;
    if (typeof roomId !== "string" || typeof identity !== "string" || !identity.trim()) {
      return json({ error: "room_id and participant_identity are required" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: room, error } = await admin
      .from("live_rooms")
      .select("id, owner_id, is_live")
      .eq("id", roomId)
      .maybeSingle();
    if (error) return json({ error: "room lookup failed" }, 500);
    if (!room || room.owner_id !== authData.user.id) {
      return json({ error: "host only" }, 403);
    }

    const service = new RoomServiceClient(livekitUrl, apiKey, apiSecret);
    await service.removeParticipant(room.id, identity.trim());
    return json({ success: true });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
