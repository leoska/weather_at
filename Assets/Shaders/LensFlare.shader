Shader "Unlit/LensFlare"
{
    Properties
    {
        _MainTex ("Scene", 2D) = "white" {}
        [HideInInspector] _BrightTex  ("Bright", 2D) = "black" {}
        [HideInInspector] _StreakTex  ("Streak A", 2D) = "black" {}
        [HideInInspector] _StreakTex2 ("Streak B", 2D) = "black" {}
        [HideInInspector] _StreakDir  ("Streak Dir", Vector) = (1, 0, 0, 0)

        _Threshold ("Bright Threshold", Range(0, 3)) = 0.8
        _Knee      ("Threshold Knee", Range(0.01, 1)) = 0.4
        _Intensity ("Global Intensity", Range(0, 4)) = 1
        _LightTint ("Light Tint", Color) = (1, 1, 1, 1)

        // Ореол
        _HaloGain   ("Halo Gain", Range(0, 2)) = 0.25
        _HaloSpread ("Halo Spread", Range(1, 4)) = 2

        // Лучи
        _StreakLength ("Streak Length (screen height)", Range(0.05, 1.5)) = 0.4
        _StreakGain0  ("Streak A Gain", Range(0, 2)) = 0.5
        _StreakGain1  ("Streak B Gain", Range(0, 2)) = 0.0

        // Блики-призраки
        _GhostGain ("Ghost Gain", Range(0, 3)) = 0.8
        _GhostSize ("Ghost Size", Range(0.01, 0.15)) = 0.07
        _GhostRim  ("Ghost Rim Emphasis", Range(0, 1)) = 0.6

        // Капли на линзе (диски)
        _DropGain    ("Lens Drop Gain", Range(0, 4)) = 2
        _DropScale   ("Lens Drop Grid Scale", Range(2, 20)) = 7
        _DropDensity ("Lens Drop Density", Range(0, 1)) = 0.25
        _DropMinR    ("Lens Drop Min Radius", Range(0.05, 0.45)) = 0.12
        _DropMaxR    ("Lens Drop Max Radius", Range(0.05, 0.45)) = 0.35
        _DropMag     ("Lens Drop Magnify", Range(1, 6)) = 2.5
        _DropRim     ("Lens Drop Rim", Range(0, 2)) = 0.5
        _DropFlicker ("Lens Drop Flicker Speed", Range(0, 2)) = 0.3
    }

    CGINCLUDE
    #include "UnityCG.cginc"
    #pragma target 3.0

    sampler2D _MainTex;   float4 _MainTex_TexelSize;
    sampler2D _BrightTex;
    sampler2D _StreakTex, _StreakTex2;
    float4 _StreakDir;

    float _Threshold, _Knee, _Intensity;
    float4 _LightTint;
    float _HaloGain, _HaloSpread;
    float _StreakLength, _StreakGain0, _StreakGain1;
    float _GhostGain, _GhostSize, _GhostRim;
    float _DropGain, _DropScale, _DropDensity, _DropMinR, _DropMaxR, _DropMag, _DropRim, _DropFlicker;

    // ---------------- Проход 0: выделение ярких пикселей (с понижением разрешения) ----------------
    float3 BrightTap(float2 uv)
    {
        float3 c = tex2D(_MainTex, uv).rgb;
        float br = max(c.r, max(c.g, c.b));
        float w = smoothstep(_Threshold, _Threshold + _Knee, br);
        return c * w;
    }

    float4 fragBright(v2f_img i) : SV_Target
    {
        float2 d = _MainTex_TexelSize.xy * 0.5;
        float3 c = BrightTap(i.uv + float2(-d.x, -d.y))
                 + BrightTap(i.uv + float2( d.x, -d.y))
                 + BrightTap(i.uv + float2(-d.x,  d.y))
                 + BrightTap(i.uv + float2( d.x,  d.y));
        return float4(c * 0.2, 1);
    }

    // ---------------- Проход 1: растягивание в луч (по 7 отсчётов, шаг растёт от прохода к проходу) ----------------
    float4 fragStreak(v2f_img i) : SV_Target
    {
        float stride = length(_StreakDir.xy);
        float2 stepUV = _StreakDir.xy * _MainTex_TexelSize.xy;
        // затухание: к концу длины луча остаётся ~5%
        float fall = 3.0 * _MainTex_TexelSize.y / max(_StreakLength, 0.01);

        float3 sum = 0;
        [unroll] for (int j = -3; j <= 3; j++)
        {
            float w = exp(-fall * abs(j) * stride);
            sum += tex2Dlod(_MainTex, float4(i.uv + stepUV * j, 0, 0)).rgb * w;
        }
        return float4(sum, 1);
    }

    // ---------------- Проход 2: сборка ----------------
    float4 hash42(float2 p)
    {
        float4 q = float4(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)),
                          dot(p, float2(419.2, 371.9)), dot(p, float2(57.3, 91.7)));
        return frac(sin(q) * 43758.5453);
    }

    float Aspect() { return _MainTex_TexelSize.y / _MainTex_TexelSize.x; }

    // Ореол: сумма высоких mip-уровней карты ярких пикселей
    float3 Halo(float2 uv)
    {
        float3 h = 0;
        float w = 1;
        [unroll] for (int l = 1; l <= 5; l++)
        {
            w *= _HaloSpread;
            h += tex2Dlod(_BrightTex, float4(uv, 0, l)).rgb * w;
        }
        return h / 20.0;
    }

    // Круглое ядро размытия: точечный источник превращается в диск с чётким краем
    float3 DiscSample(float2 uv, float radius, float lod)
    {
        float2 asp = float2(1.0 / Aspect(), 1.0);
        float3 s = 0;
        float ws = 0;
        [unroll] for (int n = 0; n < 16; n++)
        {
            float r = sqrt((n + 0.5) / 16.0);
            float a = n * 2.39996323;
            float2 o = float2(cos(a), sin(a)) * r * radius * asp;
            float w = lerp(1.0, r * r * 2.0, _GhostRim);   // акцент на кромке диска
            s += tex2Dlod(_BrightTex, float4(uv + o, 0, lod)).rgb * w;
            ws += w;
        }
        return s / ws;
    }

    // Блик-призрак: копия источников, отражённая через центр кадра
    float3 Ghost(float2 uv, float k, float sizeMul, float3 tint)
    {
        float2 c = 0.5;
        float2 b = c - (uv - c) / k;   // где стоял бы источник
        float inside = step(max(abs(b.x - 0.5), abs(b.y - 0.5)), 0.5);
        float fade = saturate(1.0 - length((b - c) * float2(1.0 / Aspect(), 1.0)) * 1.6);
        fade *= fade;
        return DiscSample(b, _GhostSize * sizeMul, 2.0) * tint * fade * inside;
    }

    // Блик-призрак: копия источников, отражённая через центр кадра
    float3 Ghost2(float2 uv, float k, float sizeMul, float3 tint)
    {
        float2 c = 0.5;
        float2 b = (uv - c) / k;   // где стоял бы источник
        float3 result = 0;
        for (int i = 0; i < 10; ++i) 
        { 
            float2 offset = frac(uv + b * float(i));
            float inside = step(max(abs(b.x - 0.5), abs(b.y - 0.5)), 0.5);
            float fade = saturate(1.0 - length((b - c) * float2(1.0 / Aspect(), 1.0)) * 1.6);
            fade *= fade;
            result += tex2D(_MainTex, offset) * inside * fade;
        }
        return result/10.0;
    }

    // Капли на линзе: диски, внутри которых виден перевёрнутый размытый свет сцены
    float3 LensDrops(float2 uv)
    {
        float2 scl = float2(Aspect(), 1.0) * _DropScale;
        float2 p = uv * scl;
        float2 id = floor(p);
        float3 acc = 0;

        [unroll] for (int j = -1; j <= 1; j++)
        [unroll] for (int i = -1; i <= 1; i++)
        {
            float2 n = id + float2(i, j);
            float4 r = hash42(n);

            float2 centre = n + 0.5 + (r.yz - 0.5) * 0.5;
            float radius = lerp(_DropMinR, _DropMaxR, r.w);
            float2 q = p - centre;
            float d = length(q) / radius;

            float aa = max(fwidth(d), 1e-3);
            float disc = saturate((1.0 - d) / aa + 0.5);
            float rim = smoothstep(0.65, 1.0, d) * disc;

            // Капли медленно «появляются и исчезают»
            float life = 0.3 + 0.3 * sin(7.0 * _Time.y * _DropFlicker * (0.5 + frac(r.w * 7.7)) + r.y * 6.2831);
            float present = step(r.x, _DropDensity) * life * life;

            float2 cUV = centre / scl;
            float2 sUV = cUV - (q / scl) * _DropMag;     // линза: изображение перевёрнуто и сжато
            float3 inner = tex2Dlod(_BrightTex, float4(sUV, 0, 3)).rgb;
            float3 glow  = tex2Dlod(_BrightTex, float4(cUV, 0, 5)).rgb;

            acc += present * disc * (inner + glow * 4.0 * (0.3 + _DropRim * rim));
        }
        return acc;
    }

    float4 fragComposite(v2f_img i) : SV_Target
    {
        float3 scene = tex2D(_MainTex, i.uv).rgb;

        float3 glare = 0;
        glare += Halo(i.uv) * _HaloGain;
        glare += tex2D(_StreakTex,  i.uv).rgb * _StreakGain0 * 0.05;
        glare += tex2D(_StreakTex2, i.uv).rgb * _StreakGain1 * 0.3;

        glare += Ghost(i.uv,  0.45, 1.0, float3(1.0, 0.85, 0.6)) * _GhostGain;
        glare += Ghost(i.uv,  0.80, 1.6, float3(0.6, 0.8, 1.0))  * _GhostGain;
        glare += Ghost(i.uv, -0.70, 2.2, float3(0.8, 1.0, 0.7))  * _GhostGain;

        glare += LensDrops(i.uv) * _DropGain;

        glare *= _LightTint.rgb * _Intensity;
        glare = 1.0 - exp(-glare);                       // мягкое ограничение

        // Screen-смешивание: не пересвечивает и не «выжигает» сцену
        float3 col = scene + glare * (1.0 - saturate(scene));
        return float4(col, 1);
    }
    ENDCG

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass { 
            CGPROGRAM 
            #pragma vertex vert_img 
            #pragma fragment fragBright    
            ENDCG 
        }
        Pass { 
            CGPROGRAM 
            #pragma vertex vert_img 
            #pragma fragment fragStreak    
            ENDCG
        }
        Pass { 
            CGPROGRAM #pragma vertex vert_img 
            #pragma fragment fragComposite 
            ENDCG 
        }
    }
}