precision highp float;
varying vec3 vPositionW;
uniform vec3 cameraPosition;
uniform vec3 daySunPosition;
uniform vec3 nightMoonPosition;
uniform sampler2D tonemapDayTexture;
uniform sampler2D tonemapNightTexture;
uniform float transitionFactor;
uniform float time;
// Cloud
uniform sampler2D dayCloudColorTexture;
uniform sampler2D nightCloudColorTexture;
uniform float dayLuminance;
uniform float nightLuminance;
uniform vec2 cloudMoveSpeed;
uniform sampler2D noiseTex;
// Ocean
uniform sampler2D oceanReflectionTex;
uniform sampler2D oceanBumpTex;
uniform float oceanBumpHeight;
uniform float oceanFresnelPowerFactor;
uniform vec3 deepOceanColor;
uniform vec2 oceanWaveSpeed;
uniform float oceanReflectionDistur;
uniform float oceanReflectionAlpha;
// Ocean Reflection
uniform mat4 view;
uniform mat4 oceanReflectionMatrix;

const vec2 madd = vec2(0.5, 0.5);
const float skyDomeRadius = 1e8;
const vec3 skyDomeCenter = vec3(0.0);

const float sunAngularDiameterCos = 0.999956676946448443553574619906976478926848692873900859324;

//  线-球面 交点计算
vec2 sphereIntersect(vec3 ro, vec3 rd, vec3 ce, float ra)
{
    vec3 oc = ro - ce;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - ra * ra;
    float h = b * b - c;
    if (h < 0.) return vec2(-1.);
    // no intersection
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}
// 线-平面 交点计算 平面参数 p = (法线方向，到原点的距离)
float planeIntersect(in vec3 ro, in vec3 rd, in vec4 p)
{
    // return -(dot(ro,p.xyz)+p.w)/dot(rd,p.xyz);
    // p 固定为(0, 1, 0, 0) 简化计算
    return -(ro.y / rd.y);
}
float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float EEE = 0.02;
float F = 0.30;
float W = 1000.0;
vec3 Uncharted2Tonemap(vec3 x)
{
    // 简化计算
    // return ((x*(A*x+C*B)+D*EEE)/(x*(A*x+B)+D*F))-EEE/F;
    vec3 ax = A * x;
    return ((x * (ax + 0.05) + 0.004) / (x * (ax + B) + 0.06)) - EEE / F;
}
float random(in vec2 uv)
{
    return texture2D(noiseTex, uv / 64.0).r;
}
float noise(in vec2 uv)
{
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3. - 2. * f);
    // float lb = random(i + vec2(0., 0.));
    // float rb = random(i + vec2(1., 0.));
    // float lt = random(i + vec2(0., 1.));
    // float rt = random(i + vec2(1., 1.));

    // 原始的采样噪声采样是基于 dev-assets/texture/cloudNoise.png ，并进行四次近邻采样，考虑到图片尺寸为64，上述逻辑等价于
    // 分别采样图片近邻的四个像素，这个过程可以事先完成，并将四次采样的结果分别存储在 rgba 四个通道中。
    // 之后就可以通过一次采样，获取临近的四个像素值，减少采样次数

    // 对 cloudNoise.png 进行预处理代码 （java)

    // int getRed(BufferedImage input, int i, int j) {
    //     i = i % 64;
    //     j = j % 64;
    //     if (input.isAlphaPremultiplied()) {
    //         int[] color =  input.getRaster().getPixel(i, j, new int[4]);
    //         return color[1];
    //     } else {
    //         int[] color =  input.getRaster().getPixel(i, j, new int[3]);
    //         return color[0];
    //     }
    // }

    //  BufferedImage input = ImageIO.read(new File("cloudNoise.png"));
    //     BufferedImage output = new BufferedImage(64, 64, BufferedImage.TYPE_4BYTE_ABGR);
    //     for (int j = 0; j < 64; j++) {
    //         for (int i = 0; i < 64; i++) {
    //             int lb = getRed(input, i, j);
    //             int rb = getRed(input, i + 1, j);
    //             int lt = getRed(input, i, j + 1);
    //             int rt = getRed(input, i + 1, j + 1);

    //             output.getRaster().setPixel(i, j, new int[]{lb, rb, lt, rt});
    //         }
    //     }

    //     ImageIO.write(output, "png", new File("MergedCloudNoise.png"));

    vec4 value = texture2D(noiseTex, i / 64.0);
    float lb = value.r;
    float rb = value.g;
    float lt = value.b;
    float rt = value.a;

    return mix(mix(lb, rb, f.x),
               mix(lt, rt, f.x), f.y);
}
#define OCTAVES 5
float fbm(in vec2 uv)
{
    float value = 0.;
    float amplitude = .5;
    for (int i = 0; i < OCTAVES; i++)
    {
        value += noise(uv) * amplitude;
        amplitude *= .5;
        uv *= 2.;
    }
    return value;
}
float fresnel(float f0, vec3 n, vec3 r)
{
    return f0 + (1.0 - f0) * pow((1.0 - clamp(dot(n, r), 0.0, 1.0)), 5.0 * oceanFresnelPowerFactor);
}
float computeLuminance(vec3 color)
{
    return dot(color, vec3(0.299, 0.587, 0.114));
}
vec3 computeProjectionCoords(vec4 worldPos, mat4 view, mat4 reflectionMatrix)
{
    return vec3(reflectionMatrix * (view * worldPos));
}
void main()
{
    // 计算视线与天球的交点，交点坐标在世界坐标系中的方向
    vec3 rayDirection = normalize(vPositionW - cameraPosition);
    vec3 rayOrigin = cameraPosition;
    vec2 traces = sphereIntersect(rayOrigin, rayDirection, skyDomeCenter, skyDomeRadius);
    vec3 direction = rayDirection;

    float skyFlag = step(0.0, direction.y);

    vec3 oceanNormal = vec3(0.0, 1.0, 0.0);
    vec4 oceanReflectionColor = vec4(0.0, 0.0, 0.0, 0.0);
    if (skyFlag < 1.0)
    {
        // 如果视线在地平线以下，则y方向取反，以计算海平面反射天空的效果
        float oceanTrace = planeIntersect(rayOrigin, rayDirection, vec4(0.0, 1.0, 0.0, 0.0));
        vec3 oceanPos = rayOrigin + rayDirection * oceanTrace;
        // 使用 bump 贴图计算水面法向量
        // 生成不同层级、细节的水波后叠加(算是某种 fbm 吧)
        vec2 waveOffset = time * oceanWaveSpeed;
        vec2 oceanUV1 = fract(oceanPos.xz / 16.0 + waveOffset);
        vec2 oceanUV2 = fract(oceanPos.xz / 4.0 + waveOffset);
        vec2 oceanUV3 = fract(oceanPos.xz / 0.2 + waveOffset);
        vec4 oceanNormalBump = 0.6 * texture2D(oceanBumpTex, oceanUV1) + 0.3 * texture2D(oceanBumpTex, oceanUV2) + 0.1 * texture2D(oceanBumpTex, oceanUV2);
        float bumpHeight = oceanBumpHeight;
        vec3 perturbation = bumpHeight * (oceanNormalBump.rbg - 0.5);
        // 越接近地平圈，海面起伏越小
        perturbation *= pow(abs(direction.y), 0.65);
        oceanNormal = normalize(oceanNormal + perturbation * 8.0);
        // 确保水面法向量总是向上
        oceanNormal.y = abs(oceanNormal.y);
        vec3 reflectionRay = reflect(rayDirection, oceanNormal);
        vec2 reflectionTraces = sphereIntersect(rayOrigin, rayDirection, skyDomeCenter, skyDomeRadius);
        vec3 reflectionSkyDirection = normalize(oceanPos + reflectionRay * reflectionTraces.y);
        direction = reflectionSkyDirection;
        // 使用反射贴图
        vec3 vReflectionUVW = computeProjectionCoords(vec4(oceanPos, 1.0), view, oceanReflectionMatrix);
        vec2 coords = vReflectionUVW.xy;
        coords /= vReflectionUVW.z;
        coords.y = 1.0 - coords.y;
        oceanReflectionColor = texture2D(oceanReflectionTex, coords + perturbation.xz * oceanReflectionDistur);
    }

    // Sky

    vec2 dayUV = vec2(0.0);
    vec3 daySkyColor = vec3(0.0);
    if (transitionFactor > 0.0) {
        dayUV = vec2(dot(direction, normalize(daySunPosition)), direction.y) * madd + madd;
        dayUV.x = pow(dayUV.x, 256.0);
        daySkyColor = texture2D(tonemapDayTexture, dayUV).rgb;
        // 太阳光晕
        float angleCos = dot(normalize(daySunPosition), normalize(direction));
        float sunHaloEdge = 0.00016; // 决定光晕宽度
        if (angleCos > sunAngularDiameterCos - sunHaloEdge) {
            float sunFade = smoothstep(sunAngularDiameterCos - sunHaloEdge, sunAngularDiameterCos + sunHaloEdge * 0.2, angleCos);
            vec3 daySunColor = texture2D(tonemapDayTexture, vec2(1.0, daySunPosition.y) * madd + madd).rgb;
            if (skyFlag < 1.0) {
                // 太阳倒影减少亮度
                daySunColor *= 0.8;
            }
            daySkyColor = mix(daySkyColor, daySunColor, pow(sunFade, 2.0));
        }
    }

    vec2 nightUV = vec2(0.0);
    vec3 nightSkyColor = vec3(0.0);
    if (transitionFactor < 1.0) {
        nightUV = vec2(dot(direction, normalize(nightMoonPosition)), direction.y) * madd + madd;
        nightUV.x = pow(nightUV.x, 256.0);
        nightSkyColor = texture2D(tonemapNightTexture, nightUV).rgb;
    }

    // Cloud
    vec3 cloudDirection = direction;
    // 在天空物理模型高度 SC 米处，绘制云朵
    // 简化计算 p
    // float SC = 1e8;
    // float dist = (SC - cameraPosition.y) / cloudDirection.y;
    // vec2 p = (cameraPosition + dist * rayDirection).xz;
    // p *= 1.2 / SC;
    vec2 p = 1.2 * rayDirection.xz / cloudDirection.y;
    // 计算云朵密度（随时动画)
    vec2 cloudOffset = time * cloudMoveSpeed;
    float den = fbm(p + cloudOffset);
    // 根据天空原本的亮度和云朵密度决定云朵的颜色
    vec3 dayCloudColor = daySkyColor;
    if (transitionFactor > 0.0) {
        dayCloudColor = texture2D(dayCloudColorTexture, dayUV).rgb;
        daySkyColor = mix(daySkyColor, dayCloudColor, smoothstep(.5, .8, den));
    }

    vec3 nightCloudColor = nightSkyColor;
    if (transitionFactor < 1.0) {
        nightCloudColor = texture2D(nightCloudColorTexture, nightUV).rgb;
        nightSkyColor = mix(nightSkyColor, nightCloudColor, smoothstep(.5, .8, den));
    }

    vec3 skyColor = mix(nightSkyColor, daySkyColor, transitionFactor);

    // Ocean
    if (skyFlag < 1.0)
    {
        skyColor = mix(skyColor, oceanReflectionColor.rgb, oceanReflectionColor.a * oceanReflectionAlpha);
        // 粗糙的海面反射效果（近似模拟海面亮度变化: 远离地平线，海面变暗)
        float oceanFresnel = fresnel(0.02, -1.0 * rayDirection, oceanNormal);
        skyColor = mix(deepOceanColor, skyColor, oceanFresnel);
    }
    skyColor = clamp(skyColor, 0.0, 1.0);
    gl_FragColor = vec4(skyColor, 1.0);
}