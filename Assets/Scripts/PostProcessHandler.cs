using UnityEngine;

public class PostProcessHandler : MonoBehaviour
{
    public Material wetGlassMaterial;
    public Material staticDropsMaterial;
    public Material normalMaterial;
    private RenderTexture dropsMask;

    private DropController dropController;

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
        if (dropsMask == null || dropsMask.width != source.width || dropsMask.height != source.height)
        {
            if (dropsMask != null) dropsMask.Release();

            dropsMask = new RenderTexture(source.width, source.height, 0, RenderTextureFormat.RHalf);
            Graphics.Blit(Texture2D.blackTexture, dropsMask);
        }

        if (dropController == null)
        {
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

        Graphics.Blit(source, bufferA, staticDropsMaterial);
        Graphics.Blit(bufferA, bufferB, normalMaterial);
        Graphics.Blit(bufferB, destination, wetGlassMaterial);
        
        RenderTexture.ReleaseTemporary(bufferA);
        RenderTexture.ReleaseTemporary(bufferB);
    }
}