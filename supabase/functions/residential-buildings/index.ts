const allowedOrigin = "https://intfree78-ux.github.io";
const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Vary": "Origin",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

function toMercator(lon: number, lat: number) {
  const x = lon * 20037508.34 / 180;
  const clampedLat = Math.max(-85.05112878, Math.min(85.05112878, lat));
  const y = Math.log(Math.tan((90 + clampedLat) * Math.PI / 360)) * 20037508.34 / Math.PI;
  return [x, y] as const;
}

function toWgs84(position: number[]): number[] {
  const x = position[0], y = position[1];
  const lon = x / 20037508.34 * 180;
  const lat = 180 / Math.PI * (2 * Math.atan(Math.exp(y / 6378137)) - Math.PI / 2);
  return [lon, lat, ...position.slice(2)];
}

function reprojectCoordinates(value: unknown): unknown {
  if (!Array.isArray(value)) return value;
  if (value.length >= 2 && typeof value[0] === "number" && typeof value[1] === "number") {
    return toWgs84(value as number[]);
  }
  return value.map(reprojectCoordinates);
}

function classifyBuildingUse(properties: Record<string, unknown>): "residential" | "other" | "unknown" {
  const useEntries = Object.entries(properties)
    .filter(([key, value]) => /purps|purpose|usability|usage|main.*use/i.test(key) && value != null && String(value).trim() !== "");
  const useValues = useEntries.map(([, value]) => String(value).trim());
  if (useValues.some(value => /아파트|연립|다세대|다가구|단독주택|공동주택|주거|기숙사/.test(value))) return "residential";
  const residentialCode = Object.entries(properties).some(([key, value]) =>
    /main.*purps.*cd|main.*use.*cd/i.test(key) && /^(01000|02000|0100|0200)$/.test(String(value ?? "").trim())
  );
  if (residentialCode) return "residential";
  return useValues.length ? "other" : "unknown";
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const origin = request.headers.get("origin");
  if (origin !== allowedOrigin) return json({ error: "허용되지 않은 출처입니다." }, 403);
  if (request.method !== "GET") return json({ error: "GET 요청만 지원합니다." }, 405);

  const url = new URL(request.url);
  const west = Number(url.searchParams.get("west"));
  const south = Number(url.searchParams.get("south"));
  const east = Number(url.searchParams.get("east"));
  const north = Number(url.searchParams.get("north"));
  const mapLevel = Number(url.searchParams.get("level"));
  if (![west, south, east, north, mapLevel].every(Number.isFinite) ||
      !Number.isInteger(mapLevel) || mapLevel < 1 || mapLevel > 4 ||
      west < 124 || east > 132 || south < 32 || north > 39 ||
      west >= east || south >= north || east - west > 0.7 || north - south > 0.5) {
    return json({ error: "건물 조회는 지도 축척 100m 이하의 현재 화면 범위에서만 가능합니다." }, 400);
  }

  const apiKey = Deno.env.get("VWORLD_API_KEY");
  if (!apiKey) return json({ error: "Supabase에 VWORLD_API_KEY secret이 설정되지 않았습니다." }, 500);

  const [minX, minY] = toMercator(west, south);
  const [maxX, maxY] = toMercator(east, north);
  const query = new URLSearchParams({
    key: apiKey,
    domain: allowedOrigin,
    service: "WFS",
    version: "1.1.0",
    request: "GetFeature",
    typeName: "lt_c_bldginfo",
    BBOX: [minX, minY, maxX, maxY].join(","),
    SRSNAME: "EPSG:900913",
    outputFormat: "application/json",
    MAXFEATURES: "250",
  });

  try {
    const upstream = await fetch("https://api.vworld.kr/req/wfs?" + query.toString(), {
      headers: { Accept: "application/json", Referer: allowedOrigin + "/" },
      signal: AbortSignal.any([request.signal, AbortSignal.timeout(12000)]),
    });
    const text = await upstream.text();
    if (!upstream.ok) return json({ error: "브이월드 조회에 실패했습니다.", status: upstream.status }, 502);

    let payload: any;
    try { payload = JSON.parse(text); }
    catch {
      const marker = "<ServiceException";
      const start = text.indexOf(marker);
      const tagEnd = start >= 0 ? text.indexOf(">", start) : -1;
      const detail = tagEnd >= 0 ? text.slice(tagEnd + 1).split("</ServiceException>")[0].trim().slice(0, 220) : "응답 형식을 확인해 주세요."; 
      return json({ error: "브이월드 WFS 오류: " + detail }, 502);
    }
    if (!Array.isArray(payload.features)) {
      return json({ error: "브이월드 응답에 건물 피처가 없습니다.", detail: payload.Exception?.text ?? payload.error ?? null }, 502);
    }

    const features = payload.features
      .filter((feature: any) => feature?.geometry)
      .map((feature: any) => ({ feature, useStatus: classifyBuildingUse(feature.properties ?? {}) }))
      .filter((item: any) => item.useStatus !== "other")
      .slice(0, 250)
      .map((item: any) => ({
        type: "Feature",
        id: String(item.feature.id ?? item.feature.properties?.bd_mgt_sn ?? item.feature.properties?.bldg_id ?? item.feature.properties?.buld_id ?? ""),
        geometry: {
          ...item.feature.geometry,
          coordinates: reprojectCoordinates(item.feature.geometry.coordinates),
        },
        properties: { ...(item.feature.properties ?? {}), _residential_status: item.useStatus },
      }));

    return json({ type: "FeatureCollection", features, count: features.length });
  } catch (error) {
    return json({ error: "브이월드에 연결하지 못했습니다.", detail: error instanceof Error ? error.message : "unknown" }, 502);
  }
});
