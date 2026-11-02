import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  if (req.method !== "GET") return Response.json({ error: "method_not_allowed" }, { status: 405 });

  const authorization = req.headers.get("authorization") ?? "";
  if (!/^Bearer\s+\S+$/i.test(authorization)) {
    console.warn("Naver userinfo request had no bearer token");
    return Response.json({ error: "missing_naver_access_token" }, { status: 401 });
  }

  try {
    const naverResponse = await fetch("https://openapi.naver.com/v1/nid/me", {
      headers: { Authorization: authorization },
    });
    const payload = await naverResponse.json().catch(() => ({}));
    const profile = payload?.response;
    if (!naverResponse.ok || payload?.resultcode !== "00") {
      console.warn("Naver userinfo rejected token", { status: naverResponse.status, resultcode: payload?.resultcode, message: payload?.message });
      return Response.json({ error: "naver_profile_request_failed", status: naverResponse.status, resultcode: payload?.resultcode }, { status: 401 });
    }
    if (typeof profile?.id !== "string" || !profile.id) {
      console.warn("Naver userinfo response did not include response.id");
      return Response.json({ error: "invalid_naver_profile" }, { status: 401 });
    }

    return Response.json({
      sub: profile.id,
      email: typeof profile.email === "string" ? profile.email : undefined,
      name: typeof profile.nickname === "string" ? profile.nickname : "네이버 회원",
      picture: typeof profile.profile_image === "string" ? profile.profile_image : undefined,
    }, { headers: { "Cache-Control": "no-store" } });
  } catch (error) {
    console.error("Naver profile lookup failed", error instanceof Error ? error.message : "unknown error");
    return Response.json({ error: "naver_profile_unavailable" }, { status: 502 });
  }
});
