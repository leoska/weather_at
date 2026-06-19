Shader "Unlit/MaskToDrops"
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
            sampler2D _MaskTex;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = fixed4(0, 0, 0, 1);
                float2 e = float2(.001, 0.);     
                float h = 6.0;

                //float tmp = tex2D(_MaskTex, i.uv).r; // Значение маски
                float c = h * tex2D(_MaskTex, i.uv).r;
                float cx = h * tex2D(_MaskTex, i.uv + e).r;
                float cy = h * tex2D(_MaskTex, i.uv + e.yx).r;
                float2 n = float2(cx-c, cy-c);

                col.rgb = tex2D(_MainTex, i.uv + n).rgb;
                return col;
            }

            ENDCG
        }
    }
}
