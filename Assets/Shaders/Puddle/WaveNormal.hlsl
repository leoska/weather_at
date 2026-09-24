void GetWaveNormal_float(
    float h,
    float hx,
    float hy,
    float eps,
    float normalStrength,
    out float3 Normal
) {
    float dhdx = (hx - h) / eps * normalStrength;
    float dhdy = (hy - h) / eps * normalStrength;
    Normal = normalize(float3(-dhdx, -dhdy, 1.0));
}
