using UnityEngine;


[ExecuteInEditMode] // Чтобы эффект был виден даже в редакторе, а не только в игре
public class PostProcessHandler : MonoBehaviour
{
    public Material[] effectMaterials;
    private FlyCamera flyCam;


    void Start() 
    {
        flyCam = GetComponent<FlyCamera>();
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        RenderTextureDescriptor desc = source.descriptor;
    
        RenderTexture bufferA = RenderTexture.GetTemporary(desc);
        RenderTexture bufferB = RenderTexture.GetTemporary(desc);

        Graphics.Blit(source, bufferA);

        RenderTexture src = bufferA;
        RenderTexture dst = bufferB;

        foreach (Material mat in effectMaterials)
        {
            mat.SetFloat("_MovementSpeed", flyCam.movementSpeed);
            Graphics.Blit(src, dst, mat);

            RenderTexture tmp = src;
            src = dst;
            dst = tmp; 
        }

        Graphics.Blit(src, destination);
        
        RenderTexture.ReleaseTemporary(bufferA);
        RenderTexture.ReleaseTemporary(bufferB);
    }
}