
// БАЗОВЫЕ ХЕШ-ФУНКЦИИ
uint PuddleMaskHashPCG(
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

float PuddleMaskHash21(
    float2 p
)
{
    uint2 u = uint2(int(p.x * 65536.0), int(p.y * 65536.0));
    uint h = PuddleMaskHashPCG(u);
    return float(h) / 4294967296.0;
}

float PuddleMaskHash11(
    float p
)
{
    return PuddleMaskHash21(float2(p, p * 0.739));
}

// РАНДОМНЫЙ ГРАДИЕНТ
float2 PuddleMaskGradient(
    float2 p
)
{
    float angle = PuddleMaskHash21(p) * 6.28318530718;
    return float2(cos(angle), sin(angle));
}

// ГРАДИЕНТНЫЙ ШУМ ПЕРЛИНА
float PuddleMaskPerlin(
    float2 p
)
{
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float2 g00 = PuddleMaskGradient(i + float2(0.0, 0.0));
    float2 g10 = PuddleMaskGradient(i + float2(1.0, 0.0));
    float2 g01 = PuddleMaskGradient(i + float2(0.0, 1.0));
    float2 g11 = PuddleMaskGradient(i + float2(1.0, 1.0));

    float n00 = dot(g00, f - float2(0.0, 0.0));
    float n10 = dot(g10, f - float2(1.0, 0.0));
    float n01 = dot(g01, f - float2(0.0, 1.0));
    float n11 = dot(g11, f - float2(1.0, 1.0));

    return lerp(lerp(n00, n10, u.x), lerp(n01, n11, u.x), u.y);
}

// ФРАКТАЛЬНЫЙ ШУМ (FBM)
float PuddleMaskFBM(
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
        sum += amplitude * PuddleMaskPerlin(p * frequency);
        normalization += amplitude;
        amplitude *= gain;
        frequency *= lacunarity;
    }

    return sum / max(normalization, 1e-5);
}

// DOMAIN WARPING
float2 PuddleMaskWarpDomain(
    float2 p,
    float strength
)
{
    float2 q = float2(
        PuddleMaskFBM(p + float2(0.0, 0.0), 4, 2.0, 0.5),
        PuddleMaskFBM(p + float2(5.2, 1.3), 4, 2.0, 0.5)
    );

    float2 r = float2(
        PuddleMaskFBM(p + strength * q + float2(1.7, 9.2), 4, 2.0, 0.5),
        PuddleMaskFBM(p + strength * q + float2(8.3, 2.8), 4, 2.0, 0.5)
    );

    return p + strength * r;
}

// SDF ЭЛЛИПСА (Signed Distance Field)
float PuddleMaskSDFEllipse(
    float2 p,
    float2 radii
)
{
    float2 q = p / radii;
    float k = length(q);
    return (k - 1.0) * min(radii.x, radii.y);
}

// ГИДРАВЛИЧЕСКАЯ ЭРОЗИЯ (упрощённая)
float PuddleMaskApplyErosion(
    float sdf,
    float2 uv,
    float erosionStrength,
    float erosionScale,
    float time
)
{
    // Эрозия - это типо у нас ещё один FBM, но с другой частотой
    float2 erosionUV = uv * erosionScale + float2(time * 0.05, time * 0.03);
    float erosionNoise = PuddleMaskFBM(erosionUV, 5, 2.2, 0.55);

    // Положительный шум «приподнимает» край, отрицательный — «вдавливает» внутрь
    float erodedSDF = sdf - erosionNoise * erosionStrength;
    
    return erodedSDF;
}

/*
 * Input:
 *   uv                 — UV-координаты
 *   objectWorldPos     — мировая позиция объекта
 *   maxOutwardOffset   — максимальное расстояние, на которое маска «размывается» за границей
 *   noiseScale         — масштаб шума для искажения формы
 *   noiseAmount        — сила шума (0..1)
 *   enablePuddleCutoff — флаг отключения маски
 *   warpStrength       — сила domain warping
 *   erosionStrength    — сила эрозии
 *   time               — время
 *
 * Output:
 *   mask               — 0 или 1 (float)
*/
void GetPuddleMask_float(
    float2 uv,
    float3 objectWorldPos,
    float maxOutwardOffset,
    float noiseScale,
    float noiseAmount,
    bool enablePuddleCutoff,
    float warpStrength,
    float erosionStrength,
    float time,
    out float mask
)
{
    if (enablePuddleCutoff == false)
    {
        mask = 1.0;
        return;
    }
    
    float seedX = objectWorldPos.x * 0.7 + objectWorldPos.z * 1.3;
    float seedY = objectWorldPos.z * 0.9 + objectWorldPos.x * 1.1;
    
    float2 centeredUV = uv - 0.5;

    // Базовые радиусы эллипса
    float minRX = 0.15 + 0.30 * (sin(seedX) * 0.4 + 0.4);
    float minRY = 0.15 + 0.30 * (cos(seedY) * 0.4 + 0.4);

    // Domain Warping UV (типо искажаем пространство)
    float2 warpedUV = PuddleMaskWarpDomain(
        centeredUV * noiseScale,
        warpStrength
    );

    // Считаем SDF эллипса в искажённом пространстве
    float sdf = PuddleMaskSDFEllipse(warpedUV, float2(minRX, minRY));
    
    // Эрозия
    sdf = PuddleMaskApplyErosion(
        sdf,
        centeredUV,
        erosionStrength,
        noiseScale * 2.0,
        time
    );

    // Для мелких деталей
    float2 detailUV = centeredUV * noiseScale * 3.0 + float2(seedX, seedY);
    float detailNoise = PuddleMaskFBM(detailUV, 3, 2.5, 0.6);
    sdf += detailNoise * noiseAmount * 0.15;
    
    // Внутри SDF < 0, снаружи SDF > 0. Нормализуем расстояние до границы в диапазон [0, 1]
    float t = saturate(sdf / max(0.0001, maxOutwardOffset));

    // внутри mask = 1, снаружи mask = 0
    mask = 1.0 - smoothstep(0.0, 1.0, t);
    mask = step(0.5, mask);
}