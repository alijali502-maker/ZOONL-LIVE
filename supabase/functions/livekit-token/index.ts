import { createClient } from "npm:@supabase/supabase-js@2";
import { AccessToken } from "npm:livekit-server-sdk@2.6.1";

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
    const apiKey = Deno.env.get("LIVEKIT_API_KEY");
    const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
    const livekitUrl = Deno.env.get("LIVEKIT_URL");
    if (!supabaseUrl || !anonKey || !serviceKey || !apiKey || !apiSecret || !livekitUrl) {
      return json({ error: "server configuration incomplete" }, 500);
    }

    const authorization = req.headers.get("Authorization") ?? "";
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
    });
    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData.user) return json({ error: "unauthorized" }, 401);

    const body = await req.json().catch(() => ({}));
    const roomId = body?.room_id;
    if (typeof roomId !== "string" || roomId.trim().length === 0) {
      return json({ error: "room_id required" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: room, error: roomError } = await admin
      .from("live_rooms")
      .select("id, owner_id, is_live, is_private, is_locked")
      .eq("id", roomId)
      .maybeSingle();
    if (roomError) return json({ error: "room lookup failed" }, 500);
    if (!room || room.is_live !== true) return json({ error: "room not live" }, 404);

    const userId = authData.user.id;
    const isHost = room.owner_id === userId;
    const { data: guestSeat, error: seatError } = await admin
      .from("room_guest_seats")
      .select("id, seat_number, is_video_enabled, is_audio_enabled")
      .eq("room_id", room.id)
      .eq("user_id", userId)
      .eq("seat_status", "occupied")
      .maybeSingle();
    if (seatError) return json({ error: "guest seat lookup failed" }, 500);
    const isGuest = !!guestSeat;

    if (!isHost && (room.is_private || room.is_locked)) {
      const { data: member } = await admin
        .from("live_room_members")
        .select("id")
        .eq("room_id", room.id)
        .eq("user_id", userId)
        .maybeSingle();
      if (!member && !isGuest) return json({ error: "not allowed" }, 403);
    }

    // Record a separate room-entry event. Do not add public viewers to
    // live_room_members: that table also grants access to locked rooms.
    const { data: activeStyle } = await admin
      .from("zoonl_live_active_styles")
      .select("active_entry_code")
      .eq("user_id", userId)
      .maybeSingle();
    const candidateEntryCode = activeStyle?.active_entry_code ?? null;
    let entryCode: string | null = null;
    if (candidateEntryCode) {
      const { data: equippedEntry } = await admin
        .from("zoonl_live_user_baggage")
        .select("expires_at")
        .eq("project_name", "ZOONL LIVE")
        .eq("user_id", userId)
        .eq("zoonl_item_code", candidateEntryCode)
        .eq("item_type", "ENTRY_EFFECT")
        .eq("is_equipped", true)
        .maybeSingle();
      const expiresAt = equippedEntry?.expires_at
        ? new Date(equippedEntry.expires_at).getTime()
        : null;
      if (equippedEntry && (expiresAt === null || expiresAt > Date.now())) {
        entryCode = candidateEntryCode;
      }
    }
    const { error: entryError } = await admin
      .from("live_room_entry_events")
      .insert({
        room_id: room.id,
        user_id: userId,
        entry_code: entryCode,
      });
    if (entryError) console.error("room entry event not recorded", entryError.message);

    const token = new AccessToken(apiKey, apiSecret, {
      identity: userId,
      ttl: "2h",
    });
    token.addGrant({
      room: room.id,
      roomJoin: true,
      canPublish: isHost || isGuest,
      canPublishData: false,
      canSubscribe: true,
    });

    return json({
      token: await token.toJwt(),
      url: livekitUrl,
      is_host: isHost,
      is_guest: isGuest,
      seat_id: guestSeat?.id ?? null,
      seat_number: guestSeat?.seat_number ?? null,
      audio_enabled: isHost || guestSeat?.is_audio_enabled === true,
      video_enabled: isHost || guestSeat?.is_video_enabled === true,
    });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
