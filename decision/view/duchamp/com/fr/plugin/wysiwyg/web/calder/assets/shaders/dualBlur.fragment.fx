/* Original implementation by Keijiro Takahashi
 * Blender integration by Clément Foucault
 *
 * Original License :
 *
 * Kino/Bloom v2 - Bloom filter for Unity
 *
 * Copyright (C) 2015, 2016 Keijiro Takahashi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
#if defined(WEBGL2) || defined(WEBGPU) || defined(NATIVE)
	#define TEXTUREFUNC(s, c, lod) texture2DLodEXT(s, c, lod)
#else
	#define TEXTUREFUNC(s, c, bias) texture2D(s, c, bias)
#endif

varying vec2 uvcoordsvar;

uniform float sampleScale;

uniform sampler2D sourceBuffer;
uniform vec2 sourceBufferTexelSize;

uniform sampler2D baseBuffer;

/* ------------- Common Math ------------ */

#define max_v3(v) max((v).x, max((v).y, (v).z))

/* ------------- Filters ------------ */

vec3 downsample_filter_high(sampler2D tex, vec2 uv, vec2 texelSize)
{
  /* Downsample with a 4x4 box filter + anti-flicker filter */
  vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, +1.0, +1.0);

  vec3 s1 = TEXTUREFUNC(tex, uv + d.xy, 0.0).rgb;
  vec3 s2 = TEXTUREFUNC(tex, uv + d.zy, 0.0).rgb;
  vec3 s3 = TEXTUREFUNC(tex, uv + d.xw, 0.0).rgb;
  vec3 s4 = TEXTUREFUNC(tex, uv + d.zw, 0.0).rgb;

  /* Karis's luma weighted average (using brightness instead of luma) */
  float s1w = 1.0 / (max_v3(s1) + 1.0);
  float s2w = 1.0 / (max_v3(s2) + 1.0);
  float s3w = 1.0 / (max_v3(s3) + 1.0);
  float s4w = 1.0 / (max_v3(s4) + 1.0);
  float one_div_wsum = 1.0 / (s1w + s2w + s3w + s4w);

  return (s1 * s1w + s2 * s2w + s3 * s3w + s4 * s4w) * one_div_wsum;
}

vec3 downsample_filter(sampler2D tex, vec2 uv, vec2 texelSize)
{
  /* Downsample with a 4x4 box filter */
  vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, +1.0, +1.0);

  vec3 s;
  s = TEXTUREFUNC(tex, uv + d.xy, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv + d.zy, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv + d.xw, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv + d.zw, 0.0).rgb;

  return s * (1.0 / 4.0);
}

vec3 upsample_filter_high(sampler2D tex, vec2 uv, vec2 texelSize)
{
  /* 9-tap bilinear upsampler (tent filter) */
  vec4 d = texelSize.xyxy * vec4(1.0, 1.0, -1.0, 0.0) * sampleScale;

  vec3 s;
  s = TEXTUREFUNC(tex, uv - d.xy, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv - d.wy, 0.0).rgb * 2.0;
  s += TEXTUREFUNC(tex, uv - d.zy, 0.0).rgb;

  s += TEXTUREFUNC(tex, uv + d.zw, 0.0).rgb * 2.0;
  s += TEXTUREFUNC(tex, uv, 0.0).rgb * 4.0;
  s += TEXTUREFUNC(tex, uv + d.xw, 0.0).rgb * 2.0;

  s += TEXTUREFUNC(tex, uv + d.zy, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv + d.wy, 0.0).rgb * 2.0;
  s += TEXTUREFUNC(tex, uv + d.xy, 0.0).rgb;

  return s * (1.0 / 16.0);
}

vec3 upsample_filter(sampler2D tex, vec2 uv, vec2 texelSize)
{
  /* 4-tap bilinear upsampler */
  vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, +1.0, +1.0) * (sampleScale * 0.5);

  vec3 s;
  s = TEXTUREFUNC(tex, uv + d.xy, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv + d.zy, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv + d.xw, 0.0).rgb;
  s += TEXTUREFUNC(tex, uv + d.zw, 0.0).rgb;

  return s * (1.0 / 4.0);
}

/* ----------- Steps ----------- */

vec4 step_downsample(void)
{
#ifdef HIGH_QUALITY /* Anti flicker */
  vec3 samp = downsample_filter_high(sourceBuffer, uvcoordsvar.xy, sourceBufferTexelSize);
#else
  vec3 samp = downsample_filter(sourceBuffer, uvcoordsvar.xy, sourceBufferTexelSize);
#endif
  return vec4(samp, 1.0);
}

vec4 step_upsample(void)
{
#ifdef HIGH_QUALITY
  vec3 blur = upsample_filter_high(sourceBuffer, uvcoordsvar.xy, sourceBufferTexelSize);
#else
  vec3 blur = upsample_filter(sourceBuffer, uvcoordsvar.xy, sourceBufferTexelSize);
#endif
  vec3 base = TEXTUREFUNC(baseBuffer, uvcoordsvar.xy, 0.0).rgb;
  return vec4(base + blur, 1.0);
}

void main(void)
{
#ifdef STEP_DOWNSAMPLE
  gl_FragColor = step_downsample();
#endif

#ifdef STEP_UPSAMPLE
  gl_FragColor = step_upsample();
#endif
}
