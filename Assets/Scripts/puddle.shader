Shader "Custom/RainDropWaves_Puddle_Final"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.0, 0.4, 0.8, 1.0)
        _WaveColor ("Wave Color (crest)", Color) = (1.0, 1.0, 1.0, 1.0)
        _TroughColor ("Trough Color", Color) = (0.0, 0.2, 0.5, 1.0)
        
        _Amplitude ("Wave Amplitude", Float) = 0.8
        _MaxRadius ("Wave max Radius", Float) = 0.8
        _WaveSpeed ("Wave Speed", Float) = 1.5
        _WaveLength ("Wave Length (λ)", Float) = 0.15
        
        [Header(Rain Grid)]
        _GridSize ("Grid Size (NxN)", Float) = 12
        _DropInterval ("Drop Interval (seconds)", Float) = 0.8   // должно быть больше _MaxRadius/_WaveSpeed
        _RandomSeed ("Random Seed", Float) = 0.0
        
        [Header(Puddle Shape)]
        _MinRadiusX ("Min Radius X", Float) = 0.25
        _MinRadiusY ("Min Radius Y", Float) = 0.2
        _MaxOutwardOffset ("Max Outward Offset", Float) = 0.12
        _NoiseScale ("Noise Scale", Float) = 6.0
        _NoiseAmount ("Noise Amount", Float) = 0.18
    }
    
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv     : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            // Параметры
            float4 _BaseColor;
            float4 _WaveColor;
            float4 _TroughColor;
            float  _Amplitude;
            float  _MaxRadius;
            float  _WaveSpeed;
            float  _WaveLength;
            
            float  _GridSize;
            float  _DropInterval;
            float  _RandomSeed;
            
            float  _MinRadiusX;
            float  _MinRadiusY;
            float  _MaxOutwardOffset;
            float  _NoiseScale;
            float  _NoiseAmount;
            
            // Хеш-функции
            float hash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }
            
            float2 hash2(float2 p)
            {
                p = frac(p * float2(127.1, 311.7));
                p += dot(p, p.yx + 19.19);
                return frac(float2(p.x * p.y, p.x * p.y + p.x));
            }
            
            // Маска лужи (центр 0.5, эллипс + шум, резкий край)
            float GetPuddleMask(float2 uv)
            {
                float2 center = float2(0.5, 0.5);
                float2 p = uv - center;
                
                float ellipseDist = (p.x * p.x) / (_MinRadiusX * _MinRadiusX) + (p.y * p.y) / (_MinRadiusY * _MinRadiusY);
                
                float mask;
                if (ellipseDist <= 1.0)
                {
                    mask = 1.0;
                }
                else
                {
                    float angle = atan2(p.y, p.x);
                    float cosA = cos(angle);
                    float sinA = sin(angle);
                    float r_boundary = 1.0 / sqrt((cosA*cosA)/(_MinRadiusX*_MinRadiusX) + (sinA*sinA)/(_MinRadiusY*_MinRadiusY));
                    float r_current = length(p);
                    float distanceOutside = max(0.0, r_current - r_boundary);
                    float t = distanceOutside / _MaxOutwardOffset;
                    mask = 1.0 - smoothstep(0.0, 1.0, t);
                }
                
                float2 noiseUV = uv * _NoiseScale;
                float noise = sin(noiseUV.x * 6.28318) * cos(noiseUV.y * 6.28318);
                noise += 0.5 * sin(noiseUV.x * 12.56636 + 1.2) * cos(noiseUV.y * 15.70795 + 2.4);
                noise += 0.25 * sin(noiseUV.x * 25.13274) * cos(noiseUV.y * 31.4159);
                noise = noise * 0.5 + 0.5;
                noise = (noise - 0.5) * _NoiseAmount;
                
                float finalValue = saturate(mask + noise);
                return step(0.5, finalValue);
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            float4 frag (v2f i) : SV_Target
            {
                // Отбрасываем всё, что вне лужи
                if (GetPuddleMask(i.uv) < 0.5) discard;
                
                float currentTime = _Time.y;
                float totalAmplitude = 0.0;
                
                // Волновые константы
                float k = 6.28318530718 / _WaveLength;
                float omega = k * _WaveSpeed;
                float waveLifetime = _MaxRadius / _WaveSpeed;
                
                float gridSize = _GridSize;
                float cellW = 1.0 / gridSize;
                
                float interval = _DropInterval;
                
                // Перебор клеток
                for (int cx = 0; cx < gridSize; cx++)
                {
                    for (int cy = 0; cy < gridSize; cy++)
                    {
                        float2 cellSeed = float2(float(cx), float(cy)) + _RandomSeed;
                        
                        // Позиция капли внутри клетки
                        float2 randPos = hash2(cellSeed);
                        float2 dropPos = float2(
                            (float(cx) + randPos.x) * cellW,
                            (float(cy) + randPos.y) * cellW
                        );
                        
                        // Если капля падает вне лужи – не создаём волну
                        if (GetPuddleMask(dropPos) < 0.5) continue;
                        
                        // Случайная фаза (сдвиг времени первого падения)
                        float phase = hash(cellSeed + 0.123) * interval;
                        
                        // Время последнего падения в этой клетке
                        float t_last = floor((currentTime - phase) / interval) * interval + phase;
                        float age = currentTime - t_last;
                        
                        // Если волна ещё не затухла и возраст в пределах времени жизни
                        if (age >= 0.0 && age <= waveLifetime)
                        {
                            float2 delta = i.uv - dropPos;
                            float dist = length(delta);
                            
                            float waveFront = age * _WaveSpeed;
                            if (dist <= waveFront)
                            {
                                float phaseWave = k * dist - omega * age;
                                float amplitude = sin(phaseWave) * _Amplitude;
                                
                                float distFactor = 1.0 / (1.0 + dist * 3.0);
                                float timeFade = 1.0 - smoothstep(0.0, waveLifetime, age);
                                float falloff = distFactor * timeFade;
                                
                                totalAmplitude += amplitude * falloff;
                            }
                        }
                    }
                }
                
                float intensity = saturate(abs(totalAmplitude) * 2.0);
                float3 color;
                if (totalAmplitude > 0.0)
                    color = lerp(_BaseColor.rgb, _WaveColor.rgb, intensity);
                else
                    color = lerp(_BaseColor.rgb, _TroughColor.rgb, intensity);
                
                return float4(color, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}