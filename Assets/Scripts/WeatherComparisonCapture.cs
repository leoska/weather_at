using System;
using System.IO;
using UnityEngine;

/// <summary>
/// Захватывает пару кадров с одной и той же камеры и позиции: один с включённым
/// погодным эффектом, один без него. Используйте для сравнительного теста CV-алгоритма.
///
/// Как использовать:
/// 1. Повесьте скрипт на объект с камерой, которая публикует кадр в Apollo
///    (та же, что в CameraImagePublisher, а не декоративная).
/// 2. Укажите ссылку на компонент/объект вашего погодного эффекта в weatherEffectObject
///    (или замените ToggleWeatherEffect() на ваш способ включения/выключения).
/// 3. В Play Mode нажмите назначенную клавишу (по умолчанию C) в нужный момент —
///    скрипт сохранит два PNG подряд: с эффектом выключенным и включённым,
///    с одной и той же позиции камеры (сцена на паузе между кадрами).
/// </summary>
public class WeatherComparisonCapture : MonoBehaviour
{
    [SerializeField] private Camera sourceCamera;
    [SerializeField] private PostProcessHandler weatherEffectObject; // объект/система вашего дождя/тумана
    [SerializeField] private KeyCode captureKey = KeyCode.C;
    [SerializeField] private string outputFolder = "WeatherCaptures";
    [SerializeField] private int width = 1280;
    [SerializeField] private int height = 720;

    private int pairIndex;

    private void Start()
    {
        if (sourceCamera == null)
        {
            sourceCamera = GetComponent<Camera>();
        }
        Directory.CreateDirectory(GetFullOutputPath());
    }

    private void Update()
    {
        if (Input.GetKeyDown(captureKey))
        {
            StartCoroutine(CapturePairRoutine());
        }
    }

    private System.Collections.IEnumerator CapturePairRoutine()
    {
        bool wasActive = weatherEffectObject != null && weatherEffectObject.isActive;

        // Кадр без эффекта
        SetWeatherActive(false);
        yield return new WaitForEndOfFrame();
        CaptureFrame($"clean_{pairIndex:0000}.png");

        // Тот же ракурс, эффект включён
        SetWeatherActive(true);
        yield return new WaitForEndOfFrame();
        CaptureFrame($"weather_{pairIndex:0000}.png");

        SetWeatherActive(wasActive);
        pairIndex++;
        Debug.Log($"Сохранена пара кадров #{pairIndex - 1} в {GetFullOutputPath()}");
    }

    private void SetWeatherActive(bool active)
    {
        if (weatherEffectObject != null)
        {
            weatherEffectObject.isActive = active;
             Debug.Log(weatherEffectObject.isActive);
        }
    }

    private void CaptureFrame(string fileName)
    {
        RenderTexture rt = new RenderTexture(width, height, 24);
        RenderTexture prevTarget = sourceCamera.targetTexture;
        RenderTexture prevActive = RenderTexture.active;

        sourceCamera.targetTexture = rt;
        sourceCamera.Render();
        RenderTexture.active = rt;

        Texture2D tex = new Texture2D(width, height, TextureFormat.RGB24, false);
        tex.ReadPixels(new Rect(0, 0, width, height), 0, 0);
        tex.Apply();

        File.WriteAllBytes(Path.Combine(GetFullOutputPath(), fileName), tex.EncodeToPNG());

        sourceCamera.targetTexture = prevTarget;
        RenderTexture.active = prevActive;
        Destroy(rt);
        Destroy(tex);
    }

    private string GetFullOutputPath()
    {
        return Path.Combine(Application.persistentDataPath, outputFolder);
    }
}