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

    public Drop(float movingSpeed, float resolutionRatio)
    {
        Reset(movingSpeed, resolutionRatio);
    }

    public void Reset(float movingSpeed, float resolutionRatio)
    {
        startPos = new Vector2(Random.value * resolutionRatio * 0.8f, Random.value + 0.1f);
        float radius = 0.15f * (Random.value * 0.6f + 0.4f);
        Data = new DropStruct(startPos, radius);
        curDelta = NextDelta(movingSpeed);
        cycleTime = 0f;
    }

    public void Update(float deltaTime, float movingSpeed, float resolutionRatio)
    {
        cycleTime += deltaTime;

        if (cycleTime >= dt)
        {
            cycleTime %= dt;
            startPos += curDelta;
            curDelta = NextDelta(movingSpeed);

            if (startPos.x - Data.Radius > resolutionRatio || startPos.y - Data.Radius > 1.1f ||
                startPos.x + Data.Radius < 0 || startPos.y + Data.Radius < -0.1f)
            {
                Reset(movingSpeed, resolutionRatio);
                return;
            }
        }

        Data.Center = startPos + curDelta * (cycleTime / dt);
    }

    private static Vector2 NextDelta(float speed)
    {
        float angle = Mathf.PI * speed - Mathf.PI / 2f;
        Vector2 baseDir = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle));
        Vector2 shift = new Vector2(RandomNormal(0f, 0.3f), RandomNormal(0f, 0.3f));
        return (baseDir + shift) * (0.1f + 0.1f * Random.value);
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
    
    public float resolutionRatio = 1.77777778f; // 16:9

    [SerializeField] private GameObject gameobjMoveCont;
    private float movingSpeed = 0f;

    private MoveControllers moveCont;

    void Start()
    {
        if (gameobjMoveCont == null)
        {
            gameobjMoveCont = gameObject;
        }
        moveCont = gameobjMoveCont.GetComponent<MoveControllers>();
        if (moveCont == null)
        {
            Debug.LogError("MoveController component missing!");
        }

        drops = new Drop[maxDrops];
        shaderDropData = new Vector4[maxDrops];

        for (int i = 0; i < maxDrops; i++)
        {
            drops[i] = new Drop(moveCont != null ? moveCont.GetMovementSpeed() : 1f, resolutionRatio);
        }
    }

    void Update()
    {
        if (moveCont != null)
        {
            movingSpeed = moveCont.GetMovementSpeed();
        }

        float dt = Time.deltaTime;

        for (int i = 0; i < maxDrops; i++)
        {
            drops[i].Update(dt, movingSpeed, resolutionRatio);
            
            Vector2 center = drops[i].Data.Center;
            float radius = drops[i].Data.Radius;
            shaderDropData[i] = new Vector4(center.x, center.y, radius, 0f); 
        }
    }

    public Material MaskMaterial()
    {   
        maskMaterial.SetVectorArray("_DropsData", shaderDropData);
        maskMaterial.SetInt("_DropsCount", maxDrops);
        return maskMaterial;
    }
}