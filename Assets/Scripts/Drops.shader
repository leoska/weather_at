Shader "Unlit/Drops"
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
            
            float3 N13(float p) {
                //  from DAVE HOSKINS
                float3 p3 = frac(float3(p,p,p) * float3(.1031,.11369,.13787));
                p3 += dot(p3, p3.yzx + 20.);
                return frac(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z)*p3.y, (p3.y + p3.z) * p3.x));
            }

            struct Lens {
                float2 center;
                float2 coef;
                float r;
                float h;
                float2 cellCenter;
                float2 start;
                float2 end;
            };

            float smoothRand(float a, float b, float p) {
                float t = N13(p).x;
                return lerp(a,b,t);
            }

            Lens createLens(float p) {
                Lens l;
                l.coef.y = smoothRand(0.9, 1.0, p);
                l.coef.x = 1.;
                return l;
            }

            //ai slop
            float softMax(float t1, float t2){
                float k = 0.1;
                float softMax = log(exp(t1/k) + exp(t2/k)) * k;
                return softMax;
            }

            Lens getLens(float2 uv, float T, float2 shift, float z) {
                T *= rainSpeed;
                T += z * 1024.;

                float2 cells = float2(0.5, 0.5);
                float2 grid = cells;
                float2 id = float2(0,0);
                float3 left = float3(id / cells, 0);
                float2 cellCenter = left.xy;
                float timeShift = smoothRand(0.01, 1.0, id.x + z * 64.);
                float timeMul = 0.3;
                float t = frac(T * timeMul + timeShift);
                float cycle = floor(T * timeMul + timeShift);
                float2 UV = uv;
                float st = S(sin(1.51 * t));
                float s = st / cells.y;
                
                float2 n = N13(id.x * 35.2 + id.y * 2376.1 + cycle).xy;
                float2 n2 = N13(id.x * 35.2 + (id.y - 1.) * 2376.1 + (cycle + 1.0)).xy;
                float n3 = N13(cycle + id.y + id.x).x;
                Lens l = createLens(n3);
                
                float2 p1 = n.xy * float2(2., 1.);
                float2 p2 =  n2.xy * float2(2., 1.);
                float2 p = p1 * (1.0 - st) + p2 * st;
                l.center = cellCenter + p;
                l.center.y -= s;
                l.r = n3 / 16. + 0.08;
                l.h = 6.0;
                l.start = cellCenter + p1;
                l.end = cellCenter + p2 - float2(0, 1. / cells.y);
                return l;
            }

        float hitLens(float2 uv, Lens l){
            float t = l.h * smoothstep(l.r, 0., length((uv - l.center.xy)));
            float2 v = l.end - uv;
            float2 path = normalize(l.end - l.start);
            float2 dist = v - dot(v, path) * path;
            float distFromDrop = length(uv - l.center);
            float taper = smoothstep(0.8, 0.0, distFromDrop); 
            float breakup = smoothstep(-0.5, 1.0, sin(uv.y * 20.0));
            float t2 = smoothstep(l.r, 0.0, length(dist)) * taper * l.h * breakup;
            if (uv.y < l.center.y || uv.y > l.start.y && length(uv - l.start) > l.r) t2 = 0.;
            float m = softMax(t, t2);
            return m;
        }

        float Drops(float2 uv, float t) {
            #define layers 4.0
            float2 UV = uv;
            float c = 0;

            for (float l = 0.0; l < layers; l += 1.0) {
                Lens drop = getLens(uv, t, float2(0.0, 0), l);
                c += hitLens(UV, drop);
            }

            return c;
        }

        float4 mainImage(float2 fragCoord)
        {
            float iTime = _Time.y;
            float2 uv = fragCoord / _ScreenParams.y;
            float2 UV = fragCoord / _ScreenParams.xy;
            
            float2 e = float2(.001, 0.);
            float c = Drops(uv, iTime);
            float cx = Drops(uv + e, iTime);
            float cy = Drops(uv + e.yx, iTime);
            float2 n = float2(cx-c, cy-c);

            float2 n2 = staticDrops(UV, iTime);

            n = max(n,n2);

            float3 col = tex2D(_MainTex, UV + n).rgb;
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
