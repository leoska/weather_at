Shader "Unlit/StaticDrops"
{
   
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            float2 staticDrops(float2 c, float iTime)
            {
                float2 u = c,
                    v = (c*.1),
                    n = noise(v*200.); // Displacement
                    
                // Loop through the different inverse sizes of drops
                for (float r = 2. ; r > 1. ; r--) {
                    float2 x = _ScreenParams.xy * r * .025,  // Number of potential drops (in a grid)
                        p = 6.28 * u * x + (n - .5) * 2.,
                        s = sin(p);
                    
                    // Current drop properties. Coordinates are rounded to ensure a
                    // consistent value among the fragment of a given drop.
                    //float4 d = texture(iChannel1, round(u * x - 0.25) / x);
                    float2 v = round(u * x - 0.25) / x;
                    float4 d = float4(noise(v*200.), noise(v));
                    
                    // Drop shape and fading
                    float t = (s.x+s.y) * max(0., 1. - frac(iTime * (d.b + .1) + d.g) * 2.);;
                    
                    // d.r -> only x% of drops are kept on, with x depending on the size of drops
                    if (d.r < (5.-r)*.08 && t > .5) {
                        // Drop normal
                        float3 v = 0.1*normalize(-float3(cos(p), lerp(.2, 2., t-.5)));
                        // fragColor = float4(v * 0.5 + 0.5, 1.0);  // show normals
                        
                        // Poor man's refraction (no visual need to do more)
                        return -v.xy;
                    }
                }
                return float2(0.0, 0.0);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 n = staticDrops(i.uv, _Time.y);
                fixed4 col = fixed4(0, 0, 0, 1);
                col.rgb = tex2D(_MainTex, i.uv + n).rgb;
                return col;
            }
            ENDCG
        }
    }
}
