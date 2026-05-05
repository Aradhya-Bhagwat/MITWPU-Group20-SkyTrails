import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const EBIRD_TIMEOUT_MS = 3000;

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function fetchJsonWithTimeout(url: string, headers: HeadersInit) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), EBIRD_TIMEOUT_MS);
  try {
    const res = await fetch(url, { headers, signal: controller.signal });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  } finally {
    clearTimeout(timeoutId);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const EBIRD_API_KEY = (Deno.env.get("EBIRD_API_KEY") || "").trim();
    const body = await req.json().catch(() => ({}));
    const lat = Number(body.lat);
    const lng = Number(body.lng);
    const existingIds: string[] = Array.isArray(body.existingIds) ? body.existingIds : [];
    const dist = Math.max(1, Math.min(50, Number(body.dist) || 40));

    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return jsonResponse(400, { error: "lat and lng are required" });
    }

    if (!EBIRD_API_KEY) {
      return jsonResponse(500, { error: "eBird API key not configured" });
    }

    const raw = await fetchJsonWithTimeout(
      `https://api.ebird.org/v2/ref/hotspot/geo?lat=${lat}&lng=${lng}&dist=${dist}&fmt=json`,
      {
        "X-eBirdApiToken": EBIRD_API_KEY,
        "User-Agent": "SkyTrails/1.0",
      }
    );

    if (!Array.isArray(raw) || raw.length === 0) {
      return jsonResponse(200, { hotspots: [] });
    }

    const existingIdSet = new Set(existingIds);
    const hotspots = raw
      .filter((h: any) => !existingIdSet.has(h.locId))
      .map((h: any) => ({
        hotspotId: h.locId,
        name: h.locName,
        lat: h.lat,
        lon: h.lng,
        checklistCount: h.numSpeciesAllTime || 0,
        distanceKm: Number(distanceKm(lat, lng, h.lat, h.lng).toFixed(1)),
      }))
      .sort((a: any, b: any) => a.distanceKm - b.distanceKm);

    return jsonResponse(200, { hotspots });
  } catch (e: any) {
    return jsonResponse(500, { error: e.message });
  }
});
