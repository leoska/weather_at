using UnityEngine;

public class PostProcessHandler : MonoBehaviour
{
    public Material wetGlassMaterial;
    public Material staticDropsMaterial;
    public Material normalMaterial;
    public bool isActive = true;
    public float distrotionValue = 5f;
    private RenderTexture dropsMask;

    private DropController dropController;

    public Material flareMaterial;
    [Range(0, 360)] public float angleA = 90f;
    [Range(0, 360)] public float angleB = 20f;
    [Range(1, 4)]   public int downsample = 2;
    [Range(2, 4)]   public int streakPasses = 4;
    
    void RenderFlare(RenderTexture src, RenderTexture dst)
    {
        if (flareMaterial == null) { Graphics.Blit(src, dst); return; }

        int w = Mathf.Max(16, src.width / downsample);
        int h = Mathf.Max(16, src.height / downsample);

        var desc = new RenderTextureDescriptor(w, h, RenderTextureFormat.ARGBHalf, 0)
        {
            useMipMap = true,
            autoGenerateMips = true
        };
        var bright = RenderTexture.GetTemporary(desc);
        bright.filterMode = FilterMode.Trilinear;
        bright.wrapMode = TextureWrapMode.Clamp;

        Graphics.Blit(src, bright, flareMaterial, 0);

        var sA = RunStreak(bright, angleA);
        var sB = RunStreak(bright, angleB);

        flareMaterial.SetTexture("_BrightTex", bright);
        flareMaterial.SetTexture("_StreakTex", sA);
        flareMaterial.SetTexture("_StreakTex2", sB);
        Graphics.Blit(src, dst, flareMaterial, 2);

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
            flareMaterial.SetVector("_StreakDir", new Vector4(dir.x * stride, dir.y * stride, 0, 0));
            Graphics.Blit(src, dst, flareMaterial, 1);
            src = dst;
            stride *= 7f;
        }

        RenderTexture.ReleaseTemporary(src == a ? b : a);
        return src;
    }

    void Start() 
    {
        dropController = GetComponent<DropController>();
        if (dropController == null)
        {
            Debug.LogError("DropController component missing!");
        }
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {   
        if (!isActive)
        {
            Graphics.Blit(source, destination);
            return;
        }

        if (dropsMask == null || dropsMask.width != source.width || dropsMask.height != source.height)
        {
            if (dropsMask != null) dropsMask.Release();

            dropsMask = new RenderTexture(source.width, source.height, 0, RenderTextureFormat.RHalf);
            Graphics.Blit(Texture2D.blackTexture, dropsMask);
        }

        if (dropController == null || 
            staticDropsMaterial == null || 
            normalMaterial == null || 
            wetGlassMaterial == null
        ) {
            Graphics.Blit(source, destination);
            return;
        }

        dropController.resolutionRatio = (float)source.width / source.height;
        Material dynDrops = dropController.MaskMaterial();
        
        RenderTexture tempMask = RenderTexture.GetTemporary(dropsMask.descriptor);

        Graphics.Blit(dropsMask, tempMask, dynDrops);
        Graphics.Blit(tempMask, dropsMask);

        RenderTexture.ReleaseTemporary(tempMask);
        
        normalMaterial.SetTexture("_MaskTex", dropsMask);

        RenderTextureDescriptor desc = source.descriptor;
        RenderTexture bufferA = RenderTexture.GetTemporary(desc);
        RenderTexture bufferB = RenderTexture.GetTemporary(desc);

        normalMaterial.SetFloat("_Height", distrotionValue);
        RenderFlare(source, bufferA);
        Graphics.Blit(bufferA, bufferB, staticDropsMaterial);
        Graphics.Blit(bufferB, bufferA, normalMaterial);
        Graphics.Blit(bufferA, destination, wetGlassMaterial);
        
        RenderTexture.ReleaseTemporary(bufferA);
        RenderTexture.ReleaseTemporary(bufferB);
    }
}