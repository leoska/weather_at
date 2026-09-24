
// ХЕШ-ФУНКЦИИ
float WaveDropsHash21(
    float2 p
)
{
    float3 p3 = frac(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.x + p3.y) * p3.z);
}

float2 WaveDropsHash22(
    float2 p
)
{
    float3 p3 = frac(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return frac((p3.xx + p3.yz) * p3.zy);
}

float WaveDropsHash11(
    float p
)
{
    return WaveDropsHash21(float2(p, p * 0.739));
}

/* Для данной ячейки и данного поколения возвращает случайную позицию
 *
 * Input:
 *   cellCoord — координата клетки
 *   cellWidth — размер клетки
 *   period    — поколение
 *   seed      - сид
 */
float2 WaveDropsSamplePosition(
    float2 cellCoord,
    float cellWidth,
    float period,
    float seed
)
{
    float2 jitterSeed = cellCoord + float2(seed, seed * 1.37) + float2(period * 17.13, period * 31.71);
    float2 jitter = WaveDropsHash22(jitterSeed);
    return (cellCoord + jitter) * cellWidth;
}

/* Для данной ячейки и данного поколения возвращает случайное время появления
 *
 * Input:
 *   cellCoord — координата клетки
 *   interval  — базовое время
 *   period    — поколение
 *   seed      - сид
 */
float WaveDropsSampleTime(
    float2 cellCoord,
    float interval,
    float period,
    float seed
)
{
    float2 timeSeed = cellCoord + float2(seed, seed * 0.91) + float2(period * 41.73, period * 7.91) + 3.1;
    return period * interval + WaveDropsHash21(timeSeed) * interval;
}

/* Для данной ячейки и данного поколения возвращает случайную фазу
 *
 * Input:
 *   cellCoord — координата клетки
 *   period    — поколение
 *   seed      - сид
 */
float WaveDropsSamplePhase(
    float2 cellCoord,
    float period,
    float seed
)
{
    float2 phaseSeed = cellCoord + float2(seed * 1.13, seed * 0.77) + float2(period * 23.4, period * 8.7) + 11.3;
    return WaveDropsHash21(phaseSeed) * 6.28318530718;
}

/* Для текущего волнового числа k вычисляем ФАЗОВУЮ скорость
 *
 * Input:
 *   k                  — координата клетки
 *   k0                 — поколение
 *   waveSpeed          - сид
 *   dispersionStrength — сила дисперсии
 */
float WaveDropsPhaseSpeed(
    float k,
    float k0,
    float waveSpeed,
    float dispersionStrength
)
{
    float ratio = k / max(k0, 1e-5);
    float cp = waveSpeed * (1.0 + 2.0 * dispersionStrength * (ratio - 1.0));
    return max(cp, 1e-4);
}

/* Для текущего волнового числа k вычисляем ГРУППОВУЮ скорость
 *
 * Input:
 *   k                  — координата клетки
 *   k0                 — поколение
 *   waveSpeed          - сид
 *   dispersionStrength — сила дисперсии
 */
float WaveDropsGroupSpeed(
    float k,
    float k0,
    float waveSpeed,
    float dispersionStrength
)
{
    float ratio = k / max(k0, 1e-5);
    float cg = waveSpeed * (1.0 + 2.0 * dispersionStrength * (2.0 * ratio - 1.0));
    return max(cg, 1e-4);
}

/* Возвращает высоту точки относительно фронта на основе Гауссовского колокола G(x) = exp(- x^2 / (2 * a^2))
 * 
 * Input:
 *   r      — расстояние от центра капли до точки, в которой считаем высоту
 *   frontR — расстояние, на которое ушёл фронт пакета
 *   width  — ширина пакета
 */
float WaveDropsPacketEnvelope(
    float r,
    float frontR,
    float width
)
{
    float d = r - frontR;
    float w = max(width, 1e-4);
    return exp(-(d * d) / (2.0 * w * w));
}

/* Возвращает ширину колокола взависимости от удаленности от точки падения капли
 * 
 * Input:
 *   baseWidth — стартовая ширина колокола
 *   frontR    — расстояние, на которое ушёл фронт пакета
 */
float WaveDropsPacketWidth(
    float baseWidth,
    float frontR
)
{
    const float kWidthGrowth = 0.08;
    return baseWidth + kWidthGrowth * max(frontR, 0.0);
}

/* Вычисляет, как амплитуда волны падает с расстоянием от центра
 * 
 * Input:
 *   r           — расстояние от точки падения капли до точки, где мы считаем амплитуду
 *   power       — показатель степени затухания
 *   clampRadius — безопасный радиус вокруг капли, внутри которого амплитуда не растёт до бесконечности
 */
float WaveDropsSpreadingAttenuation(
    float r,
    float power,
    float clampRadius
)
{
    float safeR = max(r, clampRadius);
    float ratio = clamp(safeR / clampRadius, 1.0, 1e6);
    return pow(ratio, -power);
}

/* Вычисляет, насколько волна просела по амплитуде к текущему возрасту
 * 
 * Input:
 *   age      — сколько секунд прошло с момента падения капли
 *   lifetime — сколько волна живёт всего
 */
float WaveDropsTemporalDecay(
    float age,
    float lifetime
)
{
    float n = clamp(age / max(lifetime, 1e-5), 0.0, 1.0);
    
    // Экспоненциальный распад
    float decay = exp(-2.5 * n * n - 0.5 * n);
    float cull = 1.0 - smoothstep(0.7, 1.0, n);
    return decay * cull;
}

/* Плавно проявляет волну по мере отдаления её фронта
 * 
 * Input:
 *   frontR          — расстояние, на которое ушёл фронт пакета
 *   emergenceRadius — расстояние, за которое волна проявляется от нуля до полной амплитуды
 */
float WaveDropsEmergenceRamp(
    float frontR,
    float emergenceRadius
)
{
    return smoothstep(0.0, max(emergenceRadius, 1e-4), frontR);
}

/* Считает вклад одной частотной компоненты одной капли в точке
 * 
 * Input:
 *   uv                 — точка на поверхности лужи, в которой считаем высоту
 *   dropPos            — точка падения капли
 *   dropTime           — момент времени, когда капля упала
 *   dropPhase          — начальный сдвиг фазы для этой капли
 *   time               — текущее глобальное время шейдера
 *   k_in               — волновое число этой конкретной компоненты
 *   k0                 — центральное волновое число пакета
 *   waveSpeed          — базовая скорость волны (при k = k0)
 *   amplitude          — общая амплитуда волн
 *   componentWeight    — вклад этой компоненты в пакет
 *   dispersionStrength — сила дисперсии
 *   packetWidth        — стартовая ширина колокола
 *   attenuationPower   — показатель затухания по расстоянию
 *   waveLifetime       — сколько секунд живёт волна от момента падения до полного исчезновения
 */
float WaveDropsEvaluateComponent(
    float2 uv,
    float2 dropPos,
    float dropTime,
    float dropPhase,
    float time,
    float k_in,
    float k0,
    float waveSpeed,
    float amplitude,
    float componentWeight,
    float dispersionStrength,
    float packetWidth,
    float attenuationPower,
    float waveLifetime
)
{
    float age = time - dropTime;
    if (age < 0.0 || age > waveLifetime)
        return 0.0;

    float r = max(length(uv - dropPos), 1e-6);
    float k = max(k_in, 1e-6);

    float c_p = WaveDropsPhaseSpeed(k, k0, waveSpeed, dispersionStrength);      // Фазовая скорость
    float c_g = WaveDropsGroupSpeed(k, k0, waveSpeed, dispersionStrength);      // Групповая скорость
    float omega = c_p * k;                                                      // Круговая частота

    float frontR = c_g * age;                                                   // Отдаленность фронта
    float width = WaveDropsPacketWidth(packetWidth, frontR);                    // Ширина группы
    float envelope = WaveDropsPacketEnvelope(r, frontR, width);                 // Отношение нашей высоты и высоты на фронте

    float spreading = WaveDropsSpreadingAttenuation(r, attenuationPower, 0.03); // чтобы амплитуда просто умирала
    float decay = WaveDropsTemporalDecay(age, waveLifetime);                    // чтобы амплитуда плавно умирала В КОНЦЕ
    float emergence = WaveDropsEmergenceRamp(frontR, 0.01);                     // чтобы амплитуда плавно родилась В НАЧАЛЕ

    float phase = k * r - omega * age + dropPhase;

    float A = amplitude * componentWeight * envelope * spreading * decay * emergence;

    return A * cos(phase);
}

// Для одной точки
float WaveDropsCore(
    float2 uv,
    float time,
    float gridSize,
    float waveSpeed,
    float amplitude,
    float waveLength,
    float dropInterval,
    float randomSeed,
    float waveLifetime,
    float dispersionStrength,
    float frequencySpread,
    float packetWidth,
    float attenuationPower,
    bool enableDrops
)
{
    float total = 0.0;

    if (enableDrops == false)
        return 0.0;

    float k0 = 6.28318530718 / max(1e-5, waveLength);

    int N = (int) gridSize;
    float cw = 1.0 / gridSize;

    int maxPeriods = (int) ceil(waveLifetime / max(1e-5, dropInterval * 0.7)) + 1;
    maxPeriods = clamp(maxPeriods, 1, 32);

    for (int cx = 0; cx < N; cx++)
    {
        for (int cy = 0; cy < N; cy++)
        {
            float2 cellCoord = float2(cx, cy);

            float cellRand = WaveDropsHash21(cellCoord * 1.37 + randomSeed);
            float cellInterval = dropInterval * (0.7 + 0.6 * cellRand);

            int currentPeriod = (int) floor(time / cellInterval);

            for (int pi = 0; pi < maxPeriods; pi++)
            {
                int period = currentPeriod - pi;
                float fp = (float) period;

                float2 dropPos = WaveDropsSamplePosition(
                    cellCoord, cw, fp, randomSeed
                );
                float dropTime = WaveDropsSampleTime(
                    cellCoord, cellInterval, fp, randomSeed
                );
                float dropPhase = WaveDropsSamplePhase(
                    cellCoord, fp, randomSeed
                );

                float age = time - dropTime;
                if (age < 0.0 || age > waveLifetime)
                    continue;

                float dk = k0 * frequencySpread;

                float k_low = k0 - dk;
                float w_low = 1.0 / (1.0 + 1.5 * frequencySpread);
                total += WaveDropsEvaluateComponent(
                    uv, dropPos, dropTime, dropPhase, time,
                    k_low, k0, waveSpeed, amplitude, w_low,
                    dispersionStrength, packetWidth,
                    attenuationPower, waveLifetime
                );

                total += WaveDropsEvaluateComponent(
                    uv, dropPos, dropTime, dropPhase, time,
                    k0, k0, waveSpeed, amplitude, 1.0,
                    dispersionStrength, packetWidth,
                    attenuationPower, waveLifetime
                );

                float k_high = k0 + dk;
                float w_high = 1.0 / (1.0 + 1.5 * frequencySpread);
                total += WaveDropsEvaluateComponent(
                    uv, dropPos, dropTime, dropPhase, time,
                    k_high, k0, waveSpeed, amplitude, w_high,
                    dispersionStrength, packetWidth,
                    attenuationPower, waveLifetime
                );
            }
        }
    }

    return total;
}

/* Функция для генерации волн от падающих капель
 *
 * Input:
 *   uv                 — точка на поверхности лужи, в которой считаем высоту
 *   time               — текущее глобальное время шейдера
 *   gridSize           — размер сетки капель (N × N ячеек)
 *   waveSpeed          — базовая скорость волны при k = k0
 *   amplitude          — общая амплитуда волн
 *   waveLength         — центральная длина волны (задаёт k0 = 2π/λ)
 *   dropInterval       — базовый интервал падения капель
 *   randomSeed         — глобальный сид для рандомизации
 *   waveLifetime       — сколько секунд живёт волна от падения до исчезновения
 *   dispersionStrength — сила дисперсии (0 — все частоты бегут одинаково, 1 — макс. расхождение)
 *   frequencySpread    — разброс частот в волновом пакете (ширина «звона»)
 *   packetWidth        — стартовая ширина гауссова колокола в момент рождения волны
 *   attenuationPower   — показатель затухания по расстоянию (0.5 — цилиндрическое расхождение)
 *   enableDrops        — флаг отключения капель (false — вернуть 0)
 *   eps                — шаг конечных разностей для расчёта производных
 *
 * Output:
 *   h                  — высота воды в точке uv
 *   hx                 — высота воды в точке uv + (eps, 0)
 *   hy                 — высота воды в точке uv + (0, eps)
 */

void GetWaveDrops_float(
    float2 uv,
    float time,
    float gridSize,
    float waveSpeed,
    float amplitude,
    float waveLength,
    float dropInterval,
    float randomSeed,
    float waveLifetime,
    float dispersionStrength,
    float frequencySpread,
    float packetWidth,
    float attenuationPower,
    bool enableDrops,
    float eps,
    out float h,
    out float hx,
    out float hy
)
{
    h = WaveDropsCore(
        uv, time, gridSize, waveSpeed, amplitude, waveLength,
        dropInterval, randomSeed, waveLifetime,
        dispersionStrength, frequencySpread, packetWidth,
        attenuationPower, enableDrops
    );

    hx = WaveDropsCore(
        uv + float2(eps, 0.0), time, gridSize, waveSpeed, amplitude, waveLength,
        dropInterval, randomSeed, waveLifetime,
        dispersionStrength, frequencySpread, packetWidth,
        attenuationPower, enableDrops
    );

    hy = WaveDropsCore(
        uv + float2(0.0, eps), time, gridSize, waveSpeed, amplitude, waveLength,
        dropInterval, randomSeed, waveLifetime,
        dispersionStrength, frequencySpread, packetWidth,
        attenuationPower, enableDrops
    );
}