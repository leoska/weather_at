using UnityEngine;

[ExecuteInEditMode] // Чтобы эффект был виден даже в редакторе, а не только в игре
public class PostprocRain : MonoBehaviour
{
    public Material effectMaterial;

    // Метод вызывается автоматически после того, как камера отрендерила сцену
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (effectMaterial != null)
        {
            // Graphics.Blit берет текстуру 'source' (то, что видит камера),
            // прогоняет её через ваш шейдер (материал)
            // и записывает результат в 'destination' (экран)
            Graphics.Blit(source, destination, effectMaterial);
        }
        else
        {
            // Если материал не задан, просто выводим картинку как есть
            Graphics.Blit(source, destination);
        }
    }
}