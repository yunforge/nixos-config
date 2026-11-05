// Ghostty 光标拖尾着色器 —— 最简单的 Kitty 样式拖尾
//
// 效果：光标移动时，在「上一位置」与「当前位置」之间拖出一条四边形残影，
// 颜色取当前光标色（与 Kitty 的 cursor_trail 默认行为一致：用光标背景色），
// 越靠近新光标越明显、越靠后越淡，动画结束后完全消失。没有彩虹、没有粒子。
//
// 来源：KroneCorylus 的 cursor_smear_fade，经 reshen 改为「取光标色 + 半透明」
//       https://github.com/KroneCorylus/shader-playground/blob/main/shaders/cursor_smear_fade.glsl
//       https://gist.github.com/reshen/991d19f9f8c8fedf64ff726f05f05f44

// 拖尾动画时长（秒）。想观察细节时可临时调大。
const float DURATION = 0.3;

// 拖尾最大不透明度（0..1）。越大越实，越小越淡。
const float TRAIL_MAX_OPACITY = 0.35;

// 矩形有符号距离场（内部为负，外部为正）
float getSdfRectangle(in vec2 p, in vec2 xy, in vec2 b) {
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 在一条边上累积距离与内外翻转（Inigo Quilez 2D SDF 的极简化写法）
float seg(in vec2 p, in vec2 a, in vec2 b, inout float s, float d) {
    vec2 e = b - a;
    vec2 w = p - a;
    vec2 proj = a + e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
    float segd = dot(p - proj, p - proj);
    d = min(d, segd);

    float c0 = step(0.0, p.y - a.y);
    float c1 = 1.0 - step(0.0, p.y - b.y);
    float c2 = 1.0 - step(0.0, e.x * w.y - e.y * w.x);
    float allCond = c0 * c1 * c2;
    float noneCond = (1.0 - c0) * (1.0 - c1) * (1.0 - c2);
    float flip = mix(1.0, -1.0, step(0.5, allCond + noneCond));
    s *= flip;
    return d;
}

// 平行四边形有符号距离场（拖尾区域）
float getSdfParallelogram(in vec2 p, in vec2 v0, in vec2 v1, in vec2 v2, in vec2 v3) {
    float s = 1.0;
    float d = dot(p - v0, p - v0);

    d = seg(p, v0, v3, s, d);
    d = seg(p, v1, v0, s, d);
    d = seg(p, v2, v1, s, d);
    d = seg(p, v3, v2, s, d);

    return s * sqrt(d);
}

// 像素坐标 → 以屏幕高度归一化、以屏幕中心为原点的坐标
vec2 norm(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float antialising(float distance) {
    return 1. - smoothstep(0., norm(vec2(2., 2.), 0.).x, distance);
}

// 根据移动方向，决定平行四边形从光标左上角还是右上角起笔
float determineStartVertexFactor(vec2 a, vec2 b) {
    float condition1 = step(b.x, a.x) * step(a.y, b.y);
    float condition2 = step(a.x, b.x) * step(b.y, a.y);
    return 1.0 - max(condition1, condition2);
}

vec2 getRectangleCenter(vec4 rectangle) {
    return vec2(rectangle.x + (rectangle.z / 2.), rectangle.y - (rectangle.w / 2.));
}

float ease(float x) {
    return pow(1.0 - x, 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);

    // 归一化坐标
    vec2 vu = norm(fragCoord, 1.);
    vec2 offsetFactor = vec2(-.5, 0.5);

    // 光标位置与尺寸（xy：-1..1 位置；zw：宽高）
    vec4 currentCursor = vec4(norm(iCurrentCursor.xy, 1.), norm(iCurrentCursor.zw, 0.));
    vec4 previousCursor = vec4(norm(iPreviousCursor.xy, 1.), norm(iPreviousCursor.zw, 0.));

    // 构造连接两次光标位置的平行四边形四个顶点
    float vertexFactor = determineStartVertexFactor(currentCursor.xy, previousCursor.xy);
    float invertedVertexFactor = 1.0 - vertexFactor;

    vec2 v0 = vec2(currentCursor.x + currentCursor.z * vertexFactor, currentCursor.y - currentCursor.w);
    vec2 v1 = vec2(currentCursor.x + currentCursor.z * invertedVertexFactor, currentCursor.y);
    vec2 v2 = vec2(previousCursor.x + currentCursor.z * invertedVertexFactor, previousCursor.y);
    vec2 v3 = vec2(previousCursor.x + currentCursor.z * vertexFactor, previousCursor.y - previousCursor.w);

    float sdfCurrentCursor = getSdfRectangle(vu, currentCursor.xy - (currentCursor.zw * offsetFactor), currentCursor.zw * 0.5);
    float sdfTrail = getSdfParallelogram(vu, v0, v1, v2, v3);

    // 动画进度（0 → 1）
    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    float easedProgress = ease(progress);

    // 两次光标中心的距离决定拖尾总长
    vec2 centerCC = getRectangleCenter(currentCursor);
    vec2 centerCP = getRectangleCenter(previousCursor);
    float lineLength = distance(centerCC, centerCP);

    // 沿拖尾方向衰减：越靠近新光标越实
    float fadeFactor = clamp(1.0 - smoothstep(lineLength, sdfCurrentCursor, easedProgress * lineLength), 0., TRAIL_MAX_OPACITY);

    // 用当前光标色绘制拖尾
    vec4 fadedTrailColor = mix(fragColor, iCurrentCursorColor, fadeFactor);

    // 叠加拖尾（带抗锯齿）
    vec4 newColor = mix(fragColor, fadedTrailColor, antialising(sdfTrail));

    // 新光标处保持原样（不被拖尾覆盖）
    newColor = mix(newColor, iCurrentCursorColor, antialising(sdfCurrentCursor));
    newColor = mix(newColor, fragColor, step(sdfCurrentCursor, 0.));
    fragColor = mix(fragColor, newColor, step(sdfCurrentCursor, easedProgress * lineLength));
}
