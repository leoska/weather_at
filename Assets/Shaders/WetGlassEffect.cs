using UnityEngine;

[RequireComponent(typeof(Camera))]
public class WetGlassEffect : MonoBehaviour
{
    public Material wetGlass;                  // Unlit/WetGlass
    [Range(0, 360)] public float angleA = 90f; // направление первого луча (градусы)
    [Range(0, 360)] public float angleB = 20f; // направление второго луча
    [Range(1, 4)]   public int downsample = 2;
    [Range(2, 4)]   public int streakPasses = 4; // 3 прохода ~ 0.3 высоты, 4 прохода ~ весь экран

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (wetGlass == null) { Graphics.Blit(src, dst); return; }

        int w = Mathf.Max(16, src.width / downsample);
        int h = Mathf.Max(16, src.height / downsample);

        // Карта ярких пикселей с mip-цепочкой (для ореола, призраков и капель)
        var desc = new RenderTextureDescriptor(w, h, RenderTextureFormat.ARGBHalf, 0)
        {
            useMipMap = true,
            autoGenerateMips = true
        };
        var bright = RenderTexture.GetTemporary(desc);
        bright.filterMode = FilterMode.Trilinear;
        bright.wrapMode = TextureWrapMode.Clamp;

        Graphics.Blit(src, bright, wetGlass, 0);

        var sA = RunStreak(bright, angleA);
        var sB = RunStreak(bright, angleB);

        wetGlass.SetTexture("_BrightTex", bright);
        wetGlass.SetTexture("_StreakTex", sA);
        wetGlass.SetTexture("_StreakTex2", sB);
        wetGlass.SetFloat("_Time", Time.time);
        Graphics.Blit(src, dst, wetGlass, 2);

        RenderTexture.ReleaseTemporary(sA);
        RenderTexture.ReleaseTemporary(sB);
        RenderTexture.ReleaseTemporary(bright);
    }

    RenderTexture RunStreak(RenderTexture bright, float angleDeg)
    {
        var a = RenderTexture.GetTemporary(bright.width, bright.height, 0, RenderTextureFormat.ARGBHalf);
        var b = RenderTexture.GetTemporary(bright.width, bright.height, 0, RenderTextureFormat.ARGBHalf);
        a.filterMode = b.filterMode = FilterMode.Bilinear;
        a.wrapMode = b.wrapMode = TextureWrapMode.Clamp;

        float rad = angleDeg * Mathf.Deg2Rad;
        Vector2 dir = new Vector2(Mathf.Cos(rad), Mathf.Sin(rad));

        RenderTexture src = bright;
        float stride = 1f;
        for (int k = 0; k < streakPasses; k++)
        {
            var dst = (k % 2 == 0) ? a : b;
            wetGlass.SetVector("_StreakDir", new Vector4(dir.x * stride, dir.y * stride, 0, 0));
            Graphics.Blit(src, dst, wetGlass, 1);
            src = dst;
            stride *= 7f;   // 7 отсчётов на проход, поэтому линия остаётся сплошной
        }

        RenderTexture.ReleaseTemporary(src == a ? b : a);
        return src;
    }
}