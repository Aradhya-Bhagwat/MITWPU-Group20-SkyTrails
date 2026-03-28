import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function jsonResponse(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

type SpeciesRangeRow = {
  ebird_species_code: string;
  week_number: number;
  range_geojson: string;
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed" });
  }

  try {
    const body = await req.json().catch(() => null);
    const ebirdSpeciesCode = String(body?.ebirdSpeciesCode ?? "").trim();
    const weekNumber = Number(body?.weekNumber);

    if (!ebirdSpeciesCode || !Number.isFinite(weekNumber)) {
      return jsonResponse(400, {
        error: "ebirdSpeciesCode and weekNumber are required",
      });
    }

    const { data: cachedRange, error: rangeError } = await supabase
      .from("species_ranges")
      .select("ebird_species_code, week_number, range_geojson")
      .eq("ebird_species_code", ebirdSpeciesCode)
      .eq("week_number", weekNumber)
      .maybeSingle();

    if (rangeError) {
      return jsonResponse(500, { error: rangeError.message });
    }

    if (cachedRange) {
      return jsonResponse(200, {
        cacheHit: true,
        ebirdSpeciesCode,
        weekNumber,
        rangeGeoJSON: (cachedRange as SpeciesRangeRow).range_geojson,
      });
    }

    const now = new Date().toISOString();
    const { error: queueError } = await supabase
      .from("species_range_requests")
      .upsert(
        {
          ebird_species_code: ebirdSpeciesCode,
          week_number: weekNumber,
          status: "pending",
          requested_at: now,
          updated_at: now,
        },
        { onConflict: "ebird_species_code,week_number" },
      );

    if (queueError) {
      return jsonResponse(500, { error: queueError.message });
    }

    return jsonResponse(202, {
      cacheHit: false,
      queued: true,
      ebirdSpeciesCode,
      weekNumber,
      reason: "range_not_cached",
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "Unknown error",
    });
  }
});
