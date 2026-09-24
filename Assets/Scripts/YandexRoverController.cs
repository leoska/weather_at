using UnityEngine;
using UnityEngine.InputSystem;

public class YandexRoverController : MonoBehaviour, MoveControllers
{
    [Space, Header("Параметры"), Space]
    [SerializeField] private float _moveSpeed = 5f;
    [SerializeField] private float _sprintMultiplier = 2f;
    [SerializeField] private float _gravity = 9.81f;
    [SerializeField] private float _rotateSpeed = 100f;
    [SerializeField] private float _cameraSensitivity = 2f;

    [Space, Header("Компоненты"), Space]
    [SerializeField] private Transform _headTransform;
    [Space]
    [SerializeField] private Transform[] _leftWheels;
    [SerializeField] private Transform[] _rightWheels;
    [Space]
    [SerializeField] private GameObject _cameraFirstPerson;
    [SerializeField] private GameObject _cameraThirdPerson;

    private bool _sprintFlag;
    private bool _isFPS;
    private Vector2 _moveInput;
    private Vector2 _cameraInput;
    private Vector3 _velocity;
    private float _cameraPitch;
    private float _cameraYaw;

    private CharacterController _char;

    private void Awake()
    {
        _char = GetComponent<CharacterController>();
    }

    private void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
        _isFPS = false;
        SetCurrentCamera();
    }

    private void FixedUpdate()
    {
        TranslateCharacter();
        RotateCharacter();
        RotateCamera();
        AnimateWheels();
    }

    #region InputSystem methods

    public void Movement(InputAction.CallbackContext cntxt)
    {
        _moveInput = cntxt.ReadValue<Vector2>();
    }

    public void Rotation(InputAction.CallbackContext cntxt)
    {
        _cameraInput = cntxt.ReadValue<Vector2>();
    }

    public void Sprint(InputAction.CallbackContext cntxt)
    {
        _sprintFlag = cntxt.performed;
    }

    public void SwitchCameraMode(InputAction.CallbackContext cntxt)
    {
        _isFPS = !_isFPS; 
        SetCurrentCamera();
    }

    #endregion

    public float GetMovementSpeed() { return _velocity.magnitude; }

    private void SetCurrentCamera()
    {
        _cameraFirstPerson.SetActive(_isFPS);
        _cameraThirdPerson.SetActive(!_isFPS);
    }

    private void TranslateCharacter()
    {
        float speed = _moveSpeed * (_sprintFlag ? _sprintMultiplier : 1f);

        Vector3 moveDirection = transform.forward * _moveInput.y * speed;

        if (_char.isGrounded)
            _velocity.y = 0f;
        else
            _velocity.y -= _gravity * Time.fixedDeltaTime;

        _velocity.x = moveDirection.x;
        _velocity.z = moveDirection.z;

        _char.Move(_velocity * Time.fixedDeltaTime);
    }

    private void RotateCharacter()
    {
        float turn = _moveInput.x * _rotateSpeed * Time.fixedDeltaTime;
        transform.Rotate(0f, turn, 0f);
    }

    private void RotateCamera()
    {
        _cameraYaw += _cameraInput.x * _cameraSensitivity * Time.fixedDeltaTime;
        _cameraPitch -= _cameraInput.y * _cameraSensitivity * Time.fixedDeltaTime;
        _cameraPitch = Mathf.Clamp(_cameraPitch, -90f, 90f);

        _headTransform.rotation = Quaternion.Euler(_cameraPitch, _cameraYaw, 0f);

        _headTransform.position = transform.position;
    }

    private void AnimateWheels()
    {
        float wheelRotation = _moveInput.y * _moveSpeed * Time.fixedDeltaTime * 100f;
        foreach (var wheel in _leftWheels)
            wheel.Rotate(Vector3.right, wheelRotation);
        foreach (var wheel in _rightWheels)
            wheel.Rotate(Vector3.left, wheelRotation);
    }
}
