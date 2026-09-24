using UnityEditor;
using UnityEngine;

public class FlyCamera : MonoBehaviour
{
    public enum CameraMode
    {
        Standard,
        Reconstruction
    }

    public CameraMode mode = CameraMode.Standard;

    public float moveSpeed = 100f;
    public float lookSpeed = 2f;
    public float sprintMultiplier = 2f;

    public bool flyingMode = true;

    public Vector3 reconstructionBaseRotation = new Vector3(0f, 270f, 270f);

    private float _yaw = 0f;
    private float _pitch = 0f;

    public float movementSpeed = 0f;
    void Start()
    {
        // Cursor.lockState = CursorLockMode.None;
        // Cursor.visible = true;
        _yaw = transform.localRotation.eulerAngles.y;
        _pitch = transform.localRotation.eulerAngles.x;
    }
    
    void Update()
    {
        if (Cursor.lockState == CursorLockMode.Locked && !Cursor.visible) {
            transform.localRotation = Quaternion.Euler(_pitch, _yaw, 0f);
            
            _yaw += Input.GetAxis("Mouse X") * lookSpeed;
            _pitch -= Input.GetAxis("Mouse Y") * lookSpeed;
            _pitch = Mathf.Clamp(_pitch, -90f, 90f);

            if (mode == CameraMode.Reconstruction)
            {
                Quaternion axisCorrection = Quaternion.Euler(reconstructionBaseRotation);
                Quaternion mouseLook = Quaternion.Euler(_pitch, _yaw, 0f);
                transform.localRotation = axisCorrection * mouseLook;   
            } else
            {
                transform.localRotation = Quaternion.Euler(_pitch, _yaw, 0f);
            }
        }

        float speed = moveSpeed * (Input.GetKey(KeyCode.LeftShift) ? sprintMultiplier : 1f);
        Vector3 move = new Vector3(
            Input.GetAxis("Horizontal"),
            (Input.GetKey(KeyCode.E) ? 1 : 0) - (Input.GetKey(KeyCode.Q) ? 1 : 0),
            Input.GetAxis("Vertical")
        );

        if (!flyingMode)
        {
            move = transform.localRotation * move;
            move.y = 0;
            move = Quaternion.Inverse(transform.localRotation) * move;
        }

        transform.Translate(move * (speed * Time.deltaTime));
        movementSpeed = move.magnitude;

        if (Input.GetMouseButtonDown(0))
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;
            Input.ResetInputAxes();
        }

        if (Input.GetKeyDown(KeyCode.Escape))
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
    }
}