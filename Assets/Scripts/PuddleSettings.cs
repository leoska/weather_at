using UnityEngine;

[ExecuteInEditMode]
public class PuddleSettings : MonoBehaviour
{
    [Header("Wave Colors")]
    public Color baseColor = new Color(0f, 0.12f, 1.0f);
    public Color waveColor = new Color(0.3f, 0.38f, 1.0f);
    public Color troughColor = new Color(0f, 0.09f, 0.8f);

    [Header("Wave Physics")]
    [Range(0, 1)] public float amplitude = 1.0f;
    [Range(0.1f, 2f)] public float maxRadius = 0.25f;
    [Range(0.1f, 5f)] public float waveSpeed = 0.5f;
    [Range(0.02f, 0.5f)] public float waveLength = 0.065f;

    [Header("Rain Grid")]
    [Range(4, 32)] public float gridSize = 30f;
    [Range(0.1f, 2f)] public float dropInterval = 20f;
    [Range(0, 100)] public float randomSeed = 5.42f;

    [Header("Puddle Shape")]
    [Range(0.01f, 0.5f)] public float minRadiusX = 0.32f;
    [Range(0.01f, 0.5f)] public float minRadiusY = 0.26f;
    [Range(0.01f, 0.5f)] public float maxOutwardOffset = 0.22f;
    [Range(1, 20)] public float noiseScale = 6f;
    [Range(0, 0.4f)] public float noiseAmount = 0.18f;

    private MaterialPropertyBlock propBlock;
    private Renderer renderer;

    void OnEnable()
    {
        renderer = GetComponent<Renderer>();
        if (renderer == null) return;
        propBlock = new MaterialPropertyBlock();
        ApplyProperties();
    }

    void OnDisable()
    {
        if (renderer != null && propBlock != null)
            renderer.SetPropertyBlock(null);
    }

    void OnValidate()
    {
        ApplyProperties();
    }

    void ApplyProperties()
    {
        if (renderer == null || propBlock == null) return;

        renderer.GetPropertyBlock(propBlock);

        propBlock.SetColor("_BaseColor", baseColor);
        propBlock.SetColor("_WaveColor", waveColor);
        propBlock.SetColor("_TroughColor", troughColor);

        propBlock.SetFloat("_Amplitude", amplitude);
        propBlock.SetFloat("_MaxRadius", maxRadius);
        propBlock.SetFloat("_WaveSpeed", waveSpeed);
        propBlock.SetFloat("_WaveLength", waveLength);

        propBlock.SetFloat("_GridSize", gridSize);
        propBlock.SetFloat("_DropInterval", dropInterval);
        propBlock.SetFloat("_RandomSeed", randomSeed);

        propBlock.SetFloat("_MinRadiusX", minRadiusX);
        propBlock.SetFloat("_MinRadiusY", minRadiusY);
        propBlock.SetFloat("_MaxOutwardOffset", maxOutwardOffset);
        propBlock.SetFloat("_NoiseScale", noiseScale);
        propBlock.SetFloat("_NoiseAmount", noiseAmount);

        renderer.SetPropertyBlock(propBlock);
    }
}