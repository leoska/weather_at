Shader "Weather/Rain"
{
    Properties
    {
        _Tint ("Tint", Color) = (0.86, 0.88, 0.88, 0.55)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "IgnoreProjector" = "True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

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
                fixed4 color : COLOR;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;
            };

            fixed4 _Tint;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float x = abs(i.uv.x - 0.5) * 2.0;
                float y = i.uv.y;

                float width = lerp(0.16, 0.072, y);
                float sideFade = 1.0 - smoothstep(width, width + 0.25, x);
                float endFade = smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.92, 1.0, y));
                float tailFade = 1.0 - smoothstep(0.45, 1.0, y);

                float alpha = sideFade * endFade * tailFade * _Tint.a * i.color.a;
                float3 color = _Tint.rgb * i.color.rgb;

                return fixed4(color, alpha);
            }
            ENDCG
        }
    }
}
