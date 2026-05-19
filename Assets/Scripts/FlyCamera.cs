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

    public Vector3 reconstructionBaseRotation = new Vector3(0f, 270f, 270f);

    private float _yaw = 0f;
    private float _pitch = 0f;

    void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void Update()
    {
        _yaw += Input.GetAxis("Mouse X") * lookSpeed;
        _pitch -= Input.GetAxis("Mouse Y") * lookSpeed;
        _pitch = Mathf.Clamp(_pitch, -90f, 90f);

        if (mode == CameraMode.Reconstruction)
        {
            Quaternion axisCorrection = Quaternion.Euler(reconstructionBaseRotation);
            Quaternion mouseLook = Quaternion.Euler(_pitch, _yaw, 0f);
            transform.localRotation = axisCorrection * mouseLook;
        }
        else
        {
            transform.localRotation = Quaternion.Euler(_pitch, _yaw, 0f);
        }

        float speed = moveSpeed * (Input.GetKey(KeyCode.LeftShift) ? sprintMultiplier : 1f);
        Vector3 move = new Vector3(
            Input.GetAxis("Horizontal"),
            (Input.GetKey(KeyCode.E) ? 1 : 0) - (Input.GetKey(KeyCode.Q) ? 1 : 0),
            Input.GetAxis("Vertical")
        );

        transform.Translate(move * (speed * Time.deltaTime));

        if (Input.GetKeyDown(KeyCode.Escape))
        {
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
        }
    }
}