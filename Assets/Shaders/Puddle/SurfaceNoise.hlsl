
// БАЗОВЫЕ ХЕШ-ФУНКЦИИ
uint SurfaceNoiseHashPCG(
    uint2 v
)
{
    v = v * 1664525u + 1013904223u;
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> 16u);
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> 16u);
    return v.x ^ (v.y >> 16u);
}

float SurfaceNoiseHash21(
    float2 p
)
{
    uint2 u = uint2(int(p.x * 65536.0), int(p.y * 65536.0));
    uint h = SurfaceNoiseHashPCG(u);
    return float(h) / 4294967296.0;
}

// РАНДОМНЫЙ ГРАДИЕНТ
float2 SurfaceNoiseGradient(
    float2 p
)
{
    float angle = SurfaceNoiseHash21(p) * 6.28318530718;
    return float2(cos(angle), sin(angle));
}

// ГРАДИЕНТНЫЙ ШУМ ПЕРЛИНА
float SurfaceNoisePerlin(
    float2 p
)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float2 g00 = SurfaceNoiseGradient(i + float2(0.0, 0.0));
    float2 g10 = SurfaceNoiseGradient(i + float2(1.0, 0.0));
    float2 g01 = SurfaceNoiseGradient(i + float2(0.0, 1.0));
    float2 g11 = SurfaceNoiseGradient(i + float2(1.0, 1.0));

    float n00 = dot(g00, f - float2(0.0, 0.0));
    float n10 = dot(g10, f - float2(1.0, 0.0));
    float n01 = dot(g01, f - float2(0.0, 1.0));
    float n11 = dot(g11, f - float2(1.0, 1.0));

    return lerp(lerp(n00, n10, u.x), lerp(n01, n11, u.x), u.y);
}

// ФРАКТАЛЬНЫЙ ШУМ (FBM)
float SurfaceNoiseFBM(
    float2 p,
    int octaves,
    float lacunarity,
    float gain
)
{
    float sum = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float normalization = 0.0;

    for (int i = 0; i < octaves; i++)
    {
        sum += amplitude * SurfaceNoisePerlin(p * frequency);
        normalization += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return sum / max(normalization, 1e-5);
}

// DOMAIN WARPING
float2 SurfaceNoiseWarpDomain(
    float2 p,
    float strength,
    float time
)
{
    float2 q = float2(
        SurfaceNoiseFBM(p + float2(0.0, 0.0) + time * 0.07, 4, 2.0, 0.5),
        SurfaceNoiseFBM(p + float2(5.2, 1.3) + time * 0.05, 4, 2.0, 0.5)
    );

    float2 r = float2(
        SurfaceNoiseFBM(p + strength * q + float2(1.7, 9.2) + time * 0.11, 4, 2.0, 0.5),
        SurfaceNoiseFBM(p + strength * q + float2(8.3, 2.8) + time * 0.09, 4, 2.0, 0.5)
    );

    return p + strength * r;
}

// АНИЗОТРОПИЯ (направленное растяжение)
float2 SurfaceNoiseAnisotropy(
    float2 p,
    float2 windDir,
    float stretch
)
{
    float2 dir = normalize(windDir + 1e-5);
    float2 perp = float2(-dir.y, dir.x);
    
    // Меняем базис
    float along = dot(p, dir);
    float across = dot(p, perp);

    return float2(along / max(stretch, 0.01), across * max(stretch, 0.01));
}

// Для одной точки
float SurfaceNoiseCore(
    float2 uv,
    float time,
    float scale,
    float speed,
    float amount,
    float warpStrength,
    float windAngleDeg,
    float anisotropy
)
{
    float windAngleRad = radians(windAngleDeg);
    
    // Масштабируем UV и добавляем дрейф со временем
    float2 p = uv * scale;
    float2 drift = float2(cos(windAngleRad), sin(windAngleRad)) * time * speed * 0.1;

    // Анизотропное растяжение (ветровые волны)
    float2 windDir = float2(cos(windAngleRad), sin(windAngleRad));
    float2 anisoP = SurfaceNoiseAnisotropy(p, windDir, anisotropy);

    // Domain warping для органических искажений
    float2 warped = SurfaceNoiseWarpDomain(anisoP + drift, warpStrength, time);

    // Многослойный FBM
    float n = 0.0;
    n += SurfaceNoiseFBM(warped * 1.0, 5, 2.1, 0.55) * 1.0;
    n += SurfaceNoiseFBM(warped * 2.7 + 13.7, 4, 2.3, 0.5) * 0.5;
    n += SurfaceNoiseFBM(warped * 6.1 + 41.3, 3, 2.5, 0.45) * 0.25;

    return n / 1.75 * amount;
}

/*
 * Input:
 *   uv                — UV-координаты
 *   scale             — масштаб шума
 *   speed             — скорость дрейфа
 *   amount            — амплитуда шума
 *   eps               — шаг конечных разностей
 *   warpStrength      — сила domain warping
 *   windAngle         — угол ветра (радианы)
 *   anisotropy        — степень анизотропии
 *   time              — время
 *
 * Output:
 *   h                 — высота в точке uv
 *   hx                — высота в точке uv + (eps, 0)
 *   hy                — высота в точке uv + (0, eps)
 */
void GetSurfaceNoise_float(
    float2 uv,
    float time,
    float scale,
    float speed,
    float amount,
    float eps,
    float warpStrength,
    float windAngleDeg,
    float anisotropy,
    out float h,
    out float hx,
    out float hy
)
{
    h  = SurfaceNoiseCore(uv + float2(0.0, 0.0), time, scale, speed, amount, warpStrength, windAngleDeg, anisotropy);
    hx = SurfaceNoiseCore(uv + float2(eps, 0.0), time, scale, speed, amount, warpStrength, windAngleDeg, anisotropy);
    hy = SurfaceNoiseCore(uv + float2(0.0, eps), time, scale, speed, amount, warpStrength, windAngleDeg, anisotropy);
}
