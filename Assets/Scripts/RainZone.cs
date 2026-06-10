using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(ParticleSystem))]
[RequireComponent(typeof(ParticleSystemRenderer))]
public class RainZone : MonoBehaviour
{
    [Header("Follow")]
    public Transform followTarget;

    [Header("Rain Zone")]
    public Vector3 zoneSize = new Vector3(35f, 18f, 35f);

    [Header("Material")]
    public Material rainMaterial;

    [Header("Drops")]
    [Range(0, 3000)] public float emissionRate = 1200f;
    [Range(100, 8000)] public int maxParticles = 2500;
    [Range(0.002f, 0.08f)] public float dropWidth = 0.014f;
    [Range(0.05f, 2f)] public float dropLength = 0.85f;
    [Range(0.1f, 50f)] public float fallSpeed = 22f;
    [Range(-1.5f, 1.5f)] public float incline = 0.15f;

    private ParticleSystem rainSystem;
    private ParticleSystemRenderer rainRenderer;
    private Vector3 followVelocity = Vector3.zero;

    private const float followSmoothTime = 0.2f;
    private const float emitterThickness = 0.15f;
    private static readonly Vector3 targetOffset = new Vector3(0f, 6f, 0f);

    void Reset()
    {
        Camera mainCamera = Camera.main;
        if (mainCamera != null)
        {
            followTarget = mainCamera.transform;
        }
    }

    void OnEnable()
    {
        rainSystem = GetComponent<ParticleSystem>();
        rainRenderer = GetComponent<ParticleSystemRenderer>();
        ApplyNow();
    }

    void Update()
    {
        ApplyNow();
    }

    void OnValidate()
    {
        zoneSize.x = Mathf.Max(0.1f, zoneSize.x);
        zoneSize.y = Mathf.Max(0.1f, zoneSize.y);
        zoneSize.z = Mathf.Max(0.1f, zoneSize.z);
        ApplyNow();
    }

    public void ApplyNow()
    {
        if (rainSystem == null)
            rainSystem = GetComponent<ParticleSystem>();

        if (rainRenderer == null)
            rainRenderer = GetComponent<ParticleSystemRenderer>();

        ApplyPlacement();
        ApplyParticles();
    }

    void ApplyPlacement()
    {
        Transform target = followTarget;
        if (target == null && Camera.main != null)
            target = Camera.main.transform;

        if (target == null) return;

        Vector3 targetPosition = target.position + targetOffset;

        if (Application.isPlaying && followSmoothTime > 0f)
        {
            transform.position = Vector3.SmoothDamp(
                transform.position,
                targetPosition,
                ref followVelocity,
                followSmoothTime
            );
        }
        else
        {
            transform.position = targetPosition;
        }

        transform.rotation = Quaternion.identity;
    }

    void ApplyParticles()
    {
        if (rainSystem == null || rainRenderer == null) return;

        float speed = Mathf.Max(0.1f, fallSpeed);
        float lifetime = Mathf.Max(0.2f, zoneSize.y / speed * 1.2f);
        Vector3 velocity = new Vector3(incline * speed, -speed, 0f);

        ParticleSystem.MainModule main = rainSystem.main;
        main.loop = true;
        main.playOnAwake = true;
        main.simulationSpace = ParticleSystemSimulationSpace.World;
        main.maxParticles = maxParticles;
        main.startLifetime = lifetime;
        main.startSpeed = 0f;
        main.startSize = dropWidth;
        main.startColor = Color.white;
        main.gravityModifier = 0f;

        ParticleSystem.EmissionModule emission = rainSystem.emission;
        emission.enabled = true;
        emission.rateOverTime = emissionRate;
        emission.rateOverDistance = 0f;

        ParticleSystem.ShapeModule shape = rainSystem.shape;
        shape.enabled = true;
        shape.shapeType = ParticleSystemShapeType.Box;
        shape.scale = new Vector3(zoneSize.x, emitterThickness, zoneSize.z);
        shape.position = new Vector3(0f, zoneSize.y * 0.5f, 0f);

        ParticleSystem.VelocityOverLifetimeModule velocityModule = rainSystem.velocityOverLifetime;
        velocityModule.enabled = true;
        velocityModule.space = ParticleSystemSimulationSpace.World;
        velocityModule.x = velocity.x;
        velocityModule.y = velocity.y;
        velocityModule.z = velocity.z;

        rainRenderer.renderMode = ParticleSystemRenderMode.Stretch;
        rainRenderer.lengthScale = dropLength;
        rainRenderer.velocityScale = 0.05f;
        rainRenderer.cameraVelocityScale = 0f;

        if (rainMaterial != null)
            rainRenderer.sharedMaterial = rainMaterial;

        if (Application.isPlaying && !rainSystem.isPlaying)
            rainSystem.Play();
    }

    void OnDrawGizmosSelected()
    {
        Matrix4x4 oldMatrix = Gizmos.matrix;
        Color oldColor = Gizmos.color;

        Gizmos.matrix = transform.localToWorldMatrix;
        Gizmos.color = new Color(0.35f, 0.7f, 1f, 0.7f);
        Gizmos.DrawWireCube(Vector3.zero, zoneSize);
        Gizmos.DrawWireCube(new Vector3(0f, zoneSize.y * 0.5f, 0f), new Vector3(zoneSize.x, emitterThickness, zoneSize.z));

        Gizmos.matrix = oldMatrix;
        Gizmos.color = oldColor;
    }

#if UNITY_EDITOR
    [UnityEditor.MenuItem("GameObject/Weather/Rain Zone", false, 10)]
    static void CreateRainZone(UnityEditor.MenuCommand menuCommand)
    {
        GameObject zoneObject = new GameObject("Rain Zone");
        UnityEditor.GameObjectUtility.SetParentAndAlign(zoneObject, menuCommand.context as GameObject);

        ParticleSystem particles = zoneObject.AddComponent<ParticleSystem>();
        particles.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);

        RainZone zone = zoneObject.AddComponent<RainZone>();
        Material material = UnityEditor.AssetDatabase.LoadAssetAtPath<Material>("Assets/Scripts/Rain.mat");
        if (material != null)
        {
            zone.rainMaterial = material;
            ParticleSystemRenderer particleRenderer = zoneObject.GetComponent<ParticleSystemRenderer>();
            if (particleRenderer != null)
                particleRenderer.sharedMaterial = material;
        }

        Camera mainCamera = Camera.main;
        if (mainCamera != null)
        {
            zone.followTarget = mainCamera.transform;
        }

        zone.ApplyNow();
        UnityEditor.Undo.RegisterCreatedObjectUndo(zoneObject, "Create Rain Zone");
        UnityEditor.Selection.activeObject = zoneObject;
    }
#endif
}
