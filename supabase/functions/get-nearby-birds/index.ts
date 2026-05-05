import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const GRID_SIZE = 0.5;
const MAX_DISPLAY_HOTSPOTS = 5;
const MAX_ACTIVITY_CHECK_HOTSPOTS = 10;
const MAX_SPECIES_PER_HOTSPOT = 50;
const RECENT_SIGHTING_BOOST = 20;
const RECENT_ONLY_PROBABILITY = 80;
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const EBIRD_TIMEOUT_MS = 2500;

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

function getWeekNumber(): number {
  const now = new Date();
  const target = new Date(now.valueOf());
  const dayNr = (now.getDay() + 6) % 7;
  target.setDate(target.getDate() - dayNr + 3);
  const firstThursday = target.valueOf();
  target.setMonth(0, 1);
  if (target.getDay() !== 4) {
    target.setMonth(0, 1 + ((4 - target.getDay() + 7) % 7));
  }
  return 1 + Math.ceil((firstThursday - target.valueOf()) / 604800000);
}

function snapToGrid(value: number): number {
  return Math.floor(value / GRID_SIZE) * GRID_SIZE;
}

function gridId(lat: number, lng: number): string {
  return `${snapToGrid(lat).toFixed(1)}_${snapToGrid(lng).toFixed(1)}`;
}

function isFresh(updatedAt?: string | null) {
  if (!updatedAt) return false;
  return Date.now() - new Date(updatedAt).getTime() < CACHE_TTL_MS;
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

function normalizeSpecies(raw: any) {
  const code = raw.ebirdSpeciesCode ?? raw.ebird_species_code ?? raw.speciesCode ?? raw.id;
  const commonName = raw.commonName ?? raw.common_name ?? raw.comName ?? raw.name;
  if (!code || !commonName) return null;

  return {
    ebirdSpeciesCode: String(code),
    commonName: String(commonName),
    scientificName: raw.scientificName ?? raw.scientific_name ?? raw.sciName ?? null,
    imageName: raw.imageName ?? raw.image_name ?? null,
    probability: Math.max(1, Math.min(100, Number(raw.probability ?? raw.likelihood ?? 70))),
    weekNumber: raw.weekNumber ?? raw.week_number ?? null,
    residencyStatus: raw.residencyStatus ?? raw.residency_status ?? "Expected",
  };
}

function speciesFromPredictions(rows: any[], currentWeek: number) {
  return rows
    .map((row) =>
      normalizeSpecies({
        ebirdSpeciesCode: row.ebird_species_code,
        commonName: row.common_name,
        scientificName: row.scientific_name,
        imageName: row.image_name,
        probability: row.probability,
        weekNumber: `Week ${row.week_number ?? currentWeek}`,
        residencyStatus: row.residency_status ?? "Expected",
      })
    )
    .filter(Boolean);
}

function buildSpeciesList(trendsSpecies: any[], recentSpecies: any[], currentWeek: number) {
  const speciesMap = new Map<string, any>();

  for (const sp of trendsSpecies) {
    const code = sp.id ?? sp.ebirdSpeciesCode ?? sp.ebird_species_code;
    if (!code) continue;
    speciesMap.set(String(code), {
      ebirdSpeciesCode: String(code),
      commonName: sp.name ?? sp.commonName ?? sp.common_name,
      scientificName: sp.scientificName ?? sp.scientific_name ?? null,
      imageName: sp.imageName ?? sp.image_name ?? null,
      probability: Math.max(1, Math.min(100, Math.round(Number(sp.score ?? sp.probability ?? 0.7) * 100))),
      weekNumber: `Week ${currentWeek}`,
      residencyStatus: "Expected",
    });
  }

  for (const raw of recentSpecies) {
    const sp = normalizeSpecies(raw);
    if (!sp) continue;
    const existing = speciesMap.get(sp.ebirdSpeciesCode);
    if (existing) {
      existing.residencyStatus = "Recently spotted";
      existing.probability = Math.min(100, existing.probability + RECENT_SIGHTING_BOOST);
      existing.scientificName = existing.scientificName ?? sp.scientificName;
    } else {
      speciesMap.set(sp.ebirdSpeciesCode, {
        ...sp,
        probability: RECENT_ONLY_PROBABILITY,
        weekNumber: `Week ${currentWeek}`,
        residencyStatus: "Recently spotted",
      });
    }
  }

  return Array.from(speciesMap.values())
    .sort((a, b) => {
      if (a.residencyStatus === "Recently spotted" && b.residencyStatus !== "Recently spotted") return -1;
      if (b.residencyStatus === "Recently spotted" && a.residencyStatus !== "Recently spotted") return 1;
      return b.probability - a.probability;
    })
    .slice(0, MAX_SPECIES_PER_HOTSPOT);
}

function hotspotCard(h: any, species: any[] = []) {
  const distance = Number(h.distanceKm ?? 0);
  return {
    hotspotId: h.hotspot_id,
    placeName: h.name,
    locationDetail: h.locality ?? h.name,
    speciesCount: h.checklist_count || species.length,
    distanceKm: Number(distance.toFixed(1)),
    distanceString: distance < 1 ? "Nearby" : `${Math.round(distance)} km`,
    center: { lat: h.lat, lng: h.lon ?? h.lng },
    species,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const EBIRD_API_KEY = (Deno.env.get("EBIRD_API_KEY") || "").trim();
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const body = await req.json().catch(() => ({}));

    if (body.ebirdSpeciesCode) {
      const ebirdSpeciesCode = String(body.ebirdSpeciesCode).trim();
      const weekNumber = Number(body.weekNumber);
      const { data: cachedRange } = await supabase
        .from("species_ranges")
        .select("range_geojson")
        .eq("ebird_species_code", ebirdSpeciesCode)
        .eq("week_number", weekNumber)
        .maybeSingle();

      if (cachedRange) {
        return jsonResponse(200, {
          cacheHit: true,
          ebirdSpeciesCode,
          weekNumber,
          rangeGeoJSON: cachedRange.range_geojson,
        });
      }

      return jsonResponse(202, {
        cacheHit: false,
        ebirdSpeciesCode,
        weekNumber,
        reason: "range_not_available",
      });
    }

    const lat = Number(body.lat);
    const lng = Number(body.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return jsonResponse(400, { error: "lat/lng required" });
    }

    const requestedHotspotId = body.hotspotId ? String(body.hotspotId) : null;
    const currentWeek = getWeekNumber();
    const grid = gridId(lat, lng);
    const ebirdHeaders = {
      "X-eBirdApiToken": EBIRD_API_KEY,
      "User-Agent": "SkyTrails/1.0",
    };

    const { data: gridRow } = await supabase
      .from("grid_hotspots")
      .select("hotspots")
      .eq("grid_id", grid)
      .maybeSingle();

    let hotspotList: any[] = gridRow?.hotspots || [];
    if (hotspotList.length === 0 && EBIRD_API_KEY) {
      const raw = await fetchJsonWithTimeout(
        `https://api.ebird.org/v2/ref/hotspot/geo?lat=${lat}&lng=${lng}&dist=40&fmt=json`,
        ebirdHeaders
      );
      hotspotList = Array.isArray(raw)
        ? raw.map((h: any) => ({
            hotspot_id: h.locId,
            name: h.locName,
            lat: h.lat,
            lon: h.lng,
            checklist_count: h.numSpeciesAllTime || 0,
          }))
        : [];
    }

    if (hotspotList.length === 0) {
      return jsonResponse(200, { card: null, nearbyHotspots: [], reason: "no_hotspots_found" });
    }

    const sorted = hotspotList
      .map((h: any) => ({
        ...h,
        distanceKm: distanceKm(lat, lng, h.lat, h.lon ?? h.lng),
      }))
      .sort((a: any, b: any) => a.distanceKm - b.distanceKm);

    const requestedHotspot = requestedHotspotId
      ? sorted.find((h: any) => h.hotspot_id === requestedHotspotId) ?? {
          hotspot_id: requestedHotspotId,
          name: "Selected hotspot",
          lat,
          lon: lng,
          checklist_count: 0,
          distanceKm: 0,
        }
      : null;

    let finalHotspots: any[];
    if (requestedHotspot) {
      finalHotspots = [
        requestedHotspot,
        ...sorted.filter((h: any) => h.hotspot_id !== requestedHotspot.hotspot_id),
      ].slice(0, MAX_DISPLAY_HOTSPOTS);
    } else {
      const activityCandidates = sorted.slice(0, MAX_ACTIVITY_CHECK_HOTSPOTS);
      const hotspotsWithActivity = await Promise.all(
        activityCandidates.map(async (h: any) => {
          const data = EBIRD_API_KEY
            ? await fetchJsonWithTimeout(
                `https://api.ebird.org/v2/data/obs/${h.hotspot_id}/recent?back=30&detail=simple&maxResults=1`,
                ebirdHeaders
              )
            : null;
          return { ...h, hasRecent: Array.isArray(data) && data.length > 0 };
        })
      );
      const activeHotspots = hotspotsWithActivity.filter((h) => h.hasRecent);
      const inactiveHotspots = [
        ...hotspotsWithActivity.filter((h) => !h.hasRecent),
        ...sorted.slice(MAX_ACTIVITY_CHECK_HOTSPOTS),
      ];
      finalHotspots = [...activeHotspots, ...inactiveHotspots].slice(0, MAX_DISPLAY_HOTSPOTS);
    }

    const targetHotspot = requestedHotspot ?? finalHotspots[0];
    const targetHotspotId = targetHotspot?.hotspot_id;

    let hotspotGeoId: string | null = null;
    if (targetHotspotId) {
      const { data: geoRow } = await supabase
        .from("hotspots_geo")
        .select("hotspot_geo_id")
        .eq("ebird_hotspot_id", targetHotspotId)
        .maybeSingle();
      hotspotGeoId = geoRow?.hotspot_geo_id ?? null;
    }

    let speciesList: any[] = [];
    let cacheSource: string | null = null;

    if (hotspotGeoId) {
      const { data: predictionRows } = await supabase
        .from("spot_species_predictions")
        .select("ebird_species_code, common_name, scientific_name, image_name, probability, week_number, residency_status, rank_score, updated_at")
        .eq("hotspot_geo_id", hotspotGeoId)
        .eq("week_number", currentWeek)
        .order("rank_score", { ascending: false, nullsFirst: false })
        .order("probability", { ascending: false, nullsFirst: false })
        .limit(MAX_SPECIES_PER_HOTSPOT);

      if (predictionRows?.length && predictionRows.some((row: any) => isFresh(row.updated_at))) {
        speciesList = speciesFromPredictions(predictionRows, currentWeek);
        cacheSource = "spot_species_predictions";
      }

      if (speciesList.length === 0) {
        const { data: speciesCache } = await supabase
          .from("hotspot_species_cache")
          .select("species_json, updated_at")
          .eq("hotspot_geo_id", hotspotGeoId)
          .eq("week_number", currentWeek)
          .maybeSingle();

        if (speciesCache && isFresh(speciesCache.updated_at)) {
          speciesList = Array.isArray(speciesCache.species_json)
            ? speciesCache.species_json.map(normalizeSpecies).filter(Boolean).slice(0, MAX_SPECIES_PER_HOTSPOT)
            : [];
          cacheSource = "hotspot_species_cache";
        }
      }
    }

    if (speciesList.length === 0) {
      const { data: trendsRow } = await supabase
        .from("regional_trends")
        .select("species_data")
        .eq("grid_id", grid)
        .eq("week_number", currentWeek)
        .maybeSingle();

      let recentSpecies: any[] = [];
      let recentFromCache = false;
      if (hotspotGeoId) {
        const { data: recentCache } = await supabase
          .from("hotspot_recent_observations_cache")
          .select("species_json, updated_at")
          .eq("hotspot_geo_id", hotspotGeoId)
          .maybeSingle();

        if (recentCache && isFresh(recentCache.updated_at)) {
          recentSpecies = Array.isArray(recentCache.species_json)
            ? recentCache.species_json.map(normalizeSpecies).filter(Boolean)
            : [];
          recentFromCache = recentSpecies.length > 0;
        }
      }

      if (targetHotspotId && EBIRD_API_KEY) {
        if (recentSpecies.length === 0) {
          const recentData = await fetchJsonWithTimeout(
            `https://api.ebird.org/v2/data/obs/${targetHotspotId}/recent?back=30&detail=simple&maxResults=200`,
            ebirdHeaders
          );
          recentSpecies = Array.isArray(recentData)
            ? recentData.map((r: any) => ({
                ebirdSpeciesCode: r.speciesCode,
                commonName: r.comName,
                scientificName: r.sciName,
              }))
            : [];
        }

        if (hotspotGeoId && recentSpecies.length > 0 && !recentFromCache) {
          await supabase.from("hotspot_recent_observations_cache").upsert(
            {
              hotspot_geo_id: hotspotGeoId,
              species_json: recentSpecies,
              species_count: recentSpecies.length,
              source: "ebird_recent",
              fetched_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            },
            { onConflict: "hotspot_geo_id" }
          );
        }
      }

      speciesList = buildSpeciesList(trendsRow?.species_data || [], recentSpecies, currentWeek);
      cacheSource = "live_enriched";

      if (hotspotGeoId && speciesList.length > 0) {
        await supabase.from("hotspot_species_cache").upsert(
          {
            hotspot_geo_id: hotspotGeoId,
            week_number: currentWeek,
            species_json: speciesList,
            species_count: speciesList.length,
            source: cacheSource,
            fetched_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          },
          { onConflict: "hotspot_geo_id,week_number" }
        );
      }
    }

    const targetIndex = finalHotspots.findIndex((h) => h.hotspot_id === targetHotspotId);
    const nearbyHotspots = finalHotspots.map((h: any, idx: number) =>
      hotspotCard(h, idx === Math.max(0, targetIndex) ? speciesList : [])
    );
    const card = nearbyHotspots[Math.max(0, targetIndex)] ?? nearbyHotspots[0] ?? null;

    return jsonResponse(200, {
      card: card ? { ...card, weekNumber: `Week ${currentWeek}` } : null,
      nearbyHotspots,
      meta: {
        hotspotCacheHit: cacheSource === "spot_species_predictions" || cacheSource === "hotspot_species_cache",
        ebirdCacheUsed: cacheSource !== "live_enriched",
        cacheSource,
      },
    });
  } catch (e: any) {
    return jsonResponse(500, { error: e.message });
  }
});
