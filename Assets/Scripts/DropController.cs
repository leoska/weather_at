using UnityEngine;

public class DropStruct
{
    public Vector2 Center;
    public float Radius;

    public DropStruct(Vector2 center, float r)
    {
        Center = center;
        Radius = r;
    }
}

public class Drop
{
    public DropStruct Data { get; private set; }

    private Vector2 startPos;
    private Vector2 curDelta;
    private float cycleTime = 0f;
    
    private const float dt = 0.2f; // Период цикла

    public Drop(float movingSpeed, float resolutionRatio, float maxRadius)
    {
        Reset(movingSpeed, resolutionRatio, maxRadius);
    }

    public void Reset(float movingSpeed, float resolutionRatio, float maxRadius)
    {
        startPos = new Vector2(Random.value * resolutionRatio * 0.8f, Random.value + 0.1f);
        float radius = maxRadius * (Random.value * 0.6f + 0.4f);
        Data = new DropStruct(startPos, radius);
        curDelta = NextDelta(movingSpeed, Data.Center, resolutionRatio);
        cycleTime = 0f;
    }

    public void Update(float deltaTime, float movingSpeed, float resolutionRatio, float maxRadius)
    {
        cycleTime += deltaTime;

        if (cycleTime >= dt)
        {
            cycleTime %= dt;
            startPos += curDelta;
            curDelta = NextDelta(movingSpeed, Data.Center, resolutionRatio);

            if (startPos.x - Data.Radius > resolutionRatio || startPos.y - Data.Radius > 1.1f ||
                startPos.x + Data.Radius < 0 || startPos.y + Data.Radius < -0.1f)
            {
                Reset(movingSpeed, resolutionRatio, maxRadius);
                return;
            }
        }

        Data.Center = startPos + curDelta * (cycleTime / dt);
    }

    private static Vector2 NextDelta(float speed, Vector2 position, float resolutionRatio)
    {
        Vector2 dir = position - new Vector2(0.5f, 0);
        dir.y = 1 - dir.y;
        dir.Normalize();
        dir += Vector2.up;
        dir.Normalize();

        Vector2 baseDir = new Vector2(0, -1) * (1 - speed);
        Vector2 shift = new Vector2(RandomNormal(0f, 0.3f), RandomNormal(0f, 0.3f));
        return (baseDir + shift + dir * speed) * (0.1f + 0.1f * Random.value);
    }

    private static float RandomNormal(float mean = 0f, float stdDev = 1f)
    {
        float sum = Random.value + Random.value + Random.value;
        float randStdNormal = (sum - 1.5f) * 1.632993f;
        return mean + stdDev * randStdNormal;
    }
}

public class DropController : MonoBehaviour
{
    public int maxDrops = 4;
    public Material maskMaterial;
    private Drop[] drops;
    private Vector4[] shaderDropData;

    public float maxRadius = 0.15f;
    
    public float resolutionRatio = 1.77777778f; // 16:9

    private FlyCamera flyCam;
    private float movingSpeed = 0f;

    void Start()
    {
        flyCam = GetComponent<FlyCamera>();
        if (flyCam == null)
        {
            Debug.LogError("FlyCamera component missing!");
        }

        drops = new Drop[maxDrops];
        shaderDropData = new Vector4[maxDrops];

        for (int i = 0; i < maxDrops; i++)
        {
            drops[i] = new Drop(flyCam != null ? flyCam.movementSpeed : 1f, resolutionRatio, maxRadius);
        }
    }

    void Update()
    {
        if (flyCam != null)
        {
            movingSpeed = flyCam.movementSpeed;
        }

        float dt = Time.deltaTime;

        for (int i = 0; i < maxDrops; i++)
        {
            drops[i].Update(dt, movingSpeed, resolutionRatio, maxRadius);
            
            Vector2 center = drops[i].Data.Center;
            float radius = drops[i].Data.Radius;
            shaderDropData[i] = new Vector4(center.x, center.y, radius, 0f); 
        }
    }

    public Material MaskMaterial()
    {   
        maskMaterial.SetVectorArray("_DropsData", shaderDropData);
        maskMaterial.SetInt("_DropsCount", maxDrops);
        maskMaterial.SetFloat("_DeltaTime", Time.deltaTime);
        return maskMaterial;
    }
}