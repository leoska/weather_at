using UnityEngine;
using UnityEngine.InputSystem;

public class SwitchScene : MonoBehaviour
{
    [Space, Header( "Список Реконструкций" ), Space]
    [SerializeField] private GameObject[] _reconstructions;

    private int _activeID;

    private void Awake()
    {
        foreach ( var reconstruction in _reconstructions )
            reconstruction.SetActive( false );

        _activeID = 0;
        _reconstructions[_activeID].SetActive( true );
    }

    public void NextReconstruction ( InputAction.CallbackContext cntxt )
    {
        _reconstructions[ _activeID ].SetActive( false );

        ++_activeID;
        if ( _activeID >= _reconstructions.Length ) _activeID = 0;

        _reconstructions[ _activeID ].SetActive( true );
    }

    public void AfterReconstruction ( InputAction.CallbackContext cntxt )
    {
        _reconstructions[ _activeID ].SetActive( false );

        --_activeID;
        if ( _activeID < 0 ) _activeID = _reconstructions.Length - 1;

        _reconstructions[ _activeID ].SetActive( true );
    }
}
