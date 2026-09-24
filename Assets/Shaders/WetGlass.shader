Shader "Unlit/WetGlass"
{
   
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MovementSpeed ("MovementSpeed", float) = 0.0
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float _MovementSpeed;
            #define rainSpeed 0.5
            #define S(t) smoothstep(0.0, 1.0, t)
            #define ratio float2(iResolution.x / iResolution.y, 1)

            // Author: Élie Michel
            // License: CC BY 3.0
            // July 2017

            float2 rand(float2 c){
                float2x2 m = float2x2(12.9898,.16180,78.233,.31415);
                return frac(sin(mul(m, c)) * float2(43758.5453, 14142.1));
            }

            float2 noise(float2 p){
                float2 co = floor(p);
                float2 mu = frac(p);
                mu = 3.0 * mu * mu - 2.0 * mu * mu * mu;
                float2 a = rand((co+float2(0.,0.)));
                float2 b = rand((co+float2(1.,0.)));
                float2 c = rand((co+float2(0.,1.)));
                float2 d = rand((co+float2(1.,1.)));
                return lerp(lerp(a, b, mu.x), lerp(c, d, mu.x), mu.y);
            }

            float noise_mix(float2 p) {
                float2 v = noise(p * float2(200., 100))
                    + noise(p * float2(150., 100)) 
                    + noise(p * float2(100., 50)) 
                    + noise(p * float2(40., 20));
                v /= 4.0;
                float res = v.x + v.y;
                return res / 2.0;
            }

            float3 getNoiseNormal(float2 uv, float strength) {
                float center = noise_mix(uv);
                float t      = noise_mix(uv + float2(0.0, strength));
                float r      = noise_mix(uv + float2(strength, 0.0));
                
                float dx = (center - r) / strength;
                float dy = (center - t) / strength;
                
                return normalize(float3(dx, dy, 1.0));
            }
            
            float get_blur(float2 p) {
               return (noise(p * 60.0) + noise(p * 30.0)) / 2.0;
            }

            float4 mainImage(float2 fragCoord)
            {
                float iTime = _Time.y;
                float2 UV = fragCoord / _ScreenParams.xy;

                float2 UVShifted = UV + sin(iTime / 31.0);

                float moveBlur = get_blur(UVShifted);
                float staticBlur = get_blur(UV);
                float blur = moveBlur * _MovementSpeed + staticBlur * (1 - _MovementSpeed);
                float2 sft = blur * length(UV - float2(0.5, 0.5));
                UV += sft * 0.05;
                
                float2 wetN = getNoiseNormal(UV, cos(iTime / 13.) * sin(iTime / 17.) * 0.1 + 0.1).xy;
                float2 reflectionUV = UV + wetN;
                float3 reflectionColor = tex2D(_MainTex, reflectionUV).rgb;

                float brightness = dot(reflectionColor, float3(0.2126, 0.7152, 0.0722));

                float3 specularReflection = reflectionColor * pow(smoothstep(0.0, 1.0, brightness), 1.0);
                specularReflection.x = pow(specularReflection.x, 0.3);
                specularReflection.y = pow(specularReflection.y, 0.3);
                specularReflection.z = pow(specularReflection.z, 0.3);
                
                float3 col = tex2D(_MainTex, UV).rgb;
                col += specularReflection * 0.01;

                float4 fragColor = float4(col, 1);
                return fragColor;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = mainImage(i.uv * _ScreenParams.xy);
                return col;
            }
            ENDCG
        }
    }
}
