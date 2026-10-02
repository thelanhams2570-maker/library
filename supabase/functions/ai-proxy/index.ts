// Supabase Edge Function: proxies AI prompts to the Anthropic API so the API key
// never has to live in the browser. Supabase validates the caller's login token
// before this function runs (default verify_jwt behaviour), so only your signed-in
// account can use it.
//
// Deploy: supabase functions deploy ai-proxy
// Secret: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");

// Cheaper alternative if you want to cut costs: "claude-haiku-4-5-20251001"
const MODEL = "claude-sonnet-5";

// This model returns a "thinking" content block before the "text" block, so
// content[0] is not reliably the answer -- must search for the text block.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  try {
    if (!ANTHROPIC_API_KEY) throw new Error("ANTHROPIC_API_KEY secret is not set");
    const { prompt } = await req.json();
    if (!prompt || typeof prompt !== "string") throw new Error("Missing prompt");

    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 8192,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!resp.ok) {
      const errText = await resp.text();
      throw new Error(`Anthropic API error (${resp.status}): ${errText}`);
    }

    const data = await resp.json();
    const blocks = data.content || [];
    const textBlock = blocks.find((b: any) => b.type === "text");
    const text = textBlock?.text ?? "";

    if (!text && data.stop_reason === "max_tokens") {
      throw new Error(
        "The AI's response was cut off before it could answer (ran out of its token budget, often because it spent it all thinking). Try a shorter request."
      );
    }

    return new Response(JSON.stringify({ text }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err?.message || err) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
