Shader "Unlit/DynDropsMask"
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

            struct Drop 
            {
                float2 center;
                float radius;
            };

            sampler2D _MainTex;
            float4 _DropsData[100];
            int _DropsCount;
            float _DeltaTime;

            float hitDrop(float2 uv, Drop drop){
                float distFromDrop = length(uv - drop.center);
                float t = smoothstep(drop.radius, 0, distFromDrop);
                return t;
            }

            float drops(float2 uv) {
                float c = 0;

                for (int i = 0; i < _DropsCount; i++) {
                    Drop drop;
                    drop.center = _DropsData[i].xy;
                    drop.radius = _DropsData[i].z;

                    c = max(c, hitDrop(uv, drop));
                }

                return c;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                fixed4 col = fixed4(0,0,0,1);
                
                float texelSize = 5.0 / _ScreenParams.xy;

                float4 oldTrail = 0;

                oldTrail += tex2D(_MainTex, i.uv + float2(-1, -1) * texelSize);
                oldTrail += tex2D(_MainTex, i.uv + float2( 0, -1) * texelSize);
                oldTrail += tex2D(_MainTex, i.uv + float2( 1, -1) * texelSize);
                
                oldTrail += tex2D(_MainTex, i.uv + float2(-1,  0) * texelSize);
                oldTrail += tex2D(_MainTex, i.uv + float2( 0,  0) * texelSize) * 2.0;
                oldTrail += tex2D(_MainTex, i.uv + float2( 1,  0) * texelSize);
                
                oldTrail += tex2D(_MainTex, i.uv + float2(-1,  1) * texelSize);
                oldTrail += tex2D(_MainTex, i.uv + float2( 0,  1) * texelSize);
                oldTrail += tex2D(_MainTex, i.uv + float2( 1,  1) * texelSize);

                col = oldTrail / 10.0;
                float fading = exp(_DeltaTime * 60 * log(0.9));
                col = max(0.0, col * fading - 0.004 * _DeltaTime);
                
                float2 ratio = float2(_ScreenParams.x / _ScreenParams.y, 1);

                float c = drops(i.uv * ratio);
                col.r = max(col.r, c);
                
                return col;
            }

            ENDCG
        }
    }
}
