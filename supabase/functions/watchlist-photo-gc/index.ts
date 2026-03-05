import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const bucketName = Deno.env.get("PHOTO_BUCKET") ?? "observed-bird-photos";
const batchSize = Number(Deno.env.get("GC_BATCH_SIZE") ?? "100");
const retryLimit = Number(Deno.env.get("GC_RETRY_LIMIT") ?? "5");

function extractStoragePath(raw: string): string {
  if (!raw) return raw;
  if (raw.startsWith("http")) {
    const marker = `/storage/v1/object/public/${bucketName}/`;
    const idx = raw.indexOf(marker);
    if (idx >= 0) return raw.slice(idx + marker.length);
  }
  return raw;
}

Deno.serve(async () => {
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const { data: jobs, error: fetchError } = await supabase
    .from("photo_delete_gc_queue")
    .select("id, storage_path, retry_count")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(batchSize);

  if (fetchError) {
    return new Response(JSON.stringify({ ok: false, error: fetchError.message }), { status: 500 });
  }

  let deleted = 0;
  let failed = 0;

  for (const job of jobs ?? []) {
    const objectPath = extractStoragePath(job.storage_path);
    const { error: removeError } = await supabase.storage.from(bucketName).remove([objectPath]);

    if (removeError) {
      failed += 1;
      const nextRetryCount = (job.retry_count ?? 0) + 1;
      const status = nextRetryCount >= retryLimit ? "dead_letter" : "pending";
      await supabase
        .from("photo_delete_gc_queue")
        .update({
          retry_count: nextRetryCount,
          status,
          last_error: removeError.message,
          updated_at: new Date().toISOString(),
        })
        .eq("id", job.id);
      continue;
    }

    deleted += 1;
    await supabase
      .from("photo_delete_gc_queue")
      .update({
        status: "done",
        updated_at: new Date().toISOString(),
      })
      .eq("id", job.id);
  }

  return new Response(JSON.stringify({ ok: true, processed: jobs?.length ?? 0, deleted, failed }), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  });
});
