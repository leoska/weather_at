using UnityEngine;

public class FlyCamera : MonoBehaviour
{
    public float moveSpeed = 100f;      // скорость движения
    public float lookSpeed = 2f;       // чувствительность мыши
    public float sprintMultiplier = 2f;// ускорение при Shift

    private float _rotationX = 0f;
    private float _rotationY = 0f;

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked; // скрыть и зафиксировать курсор
        Cursor.visible = false;
    }

    void Update()
    {
        // Поворот мышью
        _rotationX += Input.GetAxis("Mouse X") * lookSpeed;
        _rotationY -= Input.GetAxis("Mouse Y") * lookSpeed;
        _rotationY = Mathf.Clamp(_rotationY, -90f, 90f); // ограничиваем угол вверх/вниз

        transform.localRotation = Quaternion.Euler(_rotationY, _rotationX, 0f);

        // Движение
        float speed = moveSpeed * (Input.GetKey(KeyCode.LeftShift) ? sprintMultiplier : 1f);
        Vector3 move = new Vector3(
            Input.GetAxis("Horizontal"), // A/D или ←/→
            (Input.GetKey(KeyCode.E) ? 1 : 0) - (Input.GetKey(KeyCode.Q) ? 1 : 0), // вверх/вниз (E/Q)
            Input.GetAxis("Vertical")    // W/S или ↑/↓
        );

        transform.Translate(move * (speed * Time.deltaTime));
        
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
    }
}