using UnityEngine;


[ExecuteInEditMode] // Чтобы эффект был виден даже в редакторе, а не только в игре
public class PostProcessHandler1 : MonoBehaviour
{
    public Material[] effectMaterials;
    public Material mainMaterial;

    public GameObject reflection;

    public RenderTexture mainTexture;


    void Start() 
    {
        mainTexture = new RenderTexture(512, 512, 0, RenderTextureFormat.ARGB32);
        mainMaterial = GetComponent<Renderer>().sharedMaterial;
        mainTexture.Create();
        effectMaterials = new Material[1];
        effectMaterials[0] = reflection.GetComponent<Renderer>().sharedMaterial;
    }

    void Update()
    {
        if (effectMaterials.Length > 0)
        {   
            Graphics.Blit(Texture2D.whiteTexture, mainTexture, effectMaterials[0]);
            mainMaterial.SetTexture("_MainTex", mainTexture);
        }
    }
}