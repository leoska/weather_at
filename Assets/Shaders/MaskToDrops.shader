Shader "Unlit/MaskToDrops"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MaskTex ("Drop Mask", 2D) = "black" {}

        _Height      ("Drop Height", Range(0.1, 10)) = 3
        _NormalStep  ("Normal Step (texels)", Range(0.5, 4)) = 1.5
        _Refraction  ("Refraction Strength", Range(0, 0.5)) = 0.08
        _Blur        ("Inner Blur (mip level)", Range(0, 4)) = 1.5

        _EnvCube     ("Environment Cubemap", Cube) = "" {}
        _EnvIntens   ("Reflection Intensity", Range(0, 4)) = 1.5
        _EnvBlur     ("Reflection Blur (mip)", Range(0, 6)) = 1.0
        _F0          ("Fresnel F0", Range(0.0, 0.2)) = 0.04
        _RimDarken   ("Edge Darkening", Range(0, 1)) = 0.35
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "UnityCG.cginc"

            struct appdata { float4 vertex : POSITION; float2 uv : TEXCOORD0; };
            struct v2f     { float2 uv : TEXCOORD0; float4 vertex : SV_POSITION; };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            sampler2D _MaskTex;
            float4 _MaskTex_TexelSize;

            samplerCUBE _EnvCube;
            float4 _EnvCube_HDR;   // параметры декодирования HDR (Unity заполняет сама)

            float _Height, _NormalStep, _Refraction, _Blur;
            float _EnvIntens, _EnvBlur, _F0, _RimDarken;

            float Height(float2 uv)
            {
                float m = tex2D(_MaskTex, uv).r;
                float sphere = sqrt(saturate(1.0 - (1.0 - m) * (1.0 - m)));
                return sphere * _Height;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 px = _MaskTex_TexelSize.xy * _NormalStep;

                float hl = Height(i.uv - float2(px.x, 0));
                float hr = Height(i.uv + float2(px.x, 0));
                float hd = Height(i.uv - float2(0, px.y));
                float hu = Height(i.uv + float2(0, px.y));

                // Нормаль в пространстве камеры (z смотрит на зрителя)
                float3 N = normalize(float3(hl - hr, hd - hu, 1.0));

                float mask = tex2D(_MaskTex, i.uv).r;
                float coverage = smoothstep(0.0, 0.15, mask);

                // --- Рефракция ---
                float2 uvR = i.uv - N.xy * _Refraction;
                float3 bg   = tex2D(_MainTex, i.uv).rgb;
                float3 refr = tex2Dlod(_MainTex, float4(uvR, 0, _Blur * coverage)).rgb;

                // --- Отражение окружения ---
                // Луч из камеры в сцену в пространстве камеры (Unity: вперёд = -z)
                float3 I = float3(0, 0, -1);
                float3 Rview = reflect(I, N);
                // Переводим в мировое пространство для выборки кубмапы
                float3 Rworld = mul((float3x3)unity_CameraToWorld, Rview);

                //float4 envSample = texCUBElod(_EnvCube, float4(Rworld, _EnvBlur));
                //float3 env = DecodeHDR(envSample, _EnvCube_HDR) * _EnvIntens;
                float4 envSample = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, Rworld, _EnvBlur);
                float3 env = DecodeHDR(envSample, unity_SpecCube0_HDR) * _EnvIntens;

                // Френель по Шлику: F0 для воды около 0.02-0.04
                float NdotV = saturate(N.z);
                float fresnel = _F0 + (1.0 - _F0) * pow(1.0 - NdotV, 5.0);

                // Затемнение по краю (капля толстая и "глотает" свет)
                float rimDark = pow(1.0 - NdotV, 2.0) * _RimDarken;

                // Отражение прибавляем к рефракции, взвешивая по Френелю
                float3 dropCol = refr * (1.0 - rimDark) * (1.0 - fresnel) + env * fresnel;

                return fixed4(lerp(bg, dropCol, coverage), 1);
            }
            ENDCG
        }
    }
}