https://github.com/blender/blender/blob/main/source/blender/compositor/shaders/compositor_glare_bloom_downsample.glsl

是的，这个实现 **非常类似** 并且很可能就是 **改造 (modified/adapted) 过来的**。

让我们来对比一下，找出相似之处和可能的改造点：

**相似之处：**

1. **Karis 的亮度加权平均 (Karis's brightness weighted average):**
   - 新代码的 `downsample_filter_high` 函数中，明确使用了 "Karis's luma weighted average (using brightness instead of luma)"。这与 Blender 代码中 `#if defined(KARIS_AVERAGE)` 块内的 `karis_brightness_weighted_sum` 函数的核心思想完全一致，都是为了减少火萤现象，使用了亮度倒数作为权重进行平均。
   - 两者都使用了 `max_v3` (或者类似功能) 来计算亮度。
   - 两者都使用了 `1.0 / (brightness + 1.0)` (或者类似) 来计算权重。

2. **Downsample 和 Upsample 步骤:**
   - 新代码明确区分了 `step_downsample` 和 `step_upsample` 步骤，这与 Bloom 效果通常的多Pass处理流程一致，Bloom 效果通常会先进行多次 Downsample 降低分辨率并进行模糊，然后再 Upsample 回到原始分辨率。Blender 的代码虽然只展示了 `compositor_glare_bloom_downsample.glsl`，但从文件名和代码逻辑可以推断出它是 Bloom 效果的 Downsample 阶段。

3. **滤波器 (Filters):**
   - 新代码提供了 `downsample_filter_high`, `downsample_filter`, `upsample_filter_high`, `upsample_filter` 等多种滤波器，分别对应高质量和低质量的 Downsample 和 Upsample。这体现了 Bloom 效果为了性能和质量可以有不同配置的常见做法。
   - 虽然新代码的 Downsample 滤波器是 4x4 box filter，而 Blender 的是更复杂的 13-tap 策略，但 **核心思想都是通过滤波进行降采样和模糊**。

4. **`max_v3` 宏:**
   - 两者都定义了 `max_v3` 宏，用于计算向量的最大分量，这在亮度计算中很常见。

5. **代码结构和宏定义:**
   - 新代码也使用了 `#ifdef HIGH_QUALITY` 等宏定义来控制代码分支，这与 Blender 代码中使用 `#if defined(KARIS_AVERAGE)` 和 `#if defined(SIMPLE_AVERAGE)` 类似，都是为了在编译时选择不同的算法路径。

**可能的改造点和差异：**

1. **Downsample 策略的简化:**
   - Blender 代码使用了更复杂的 13-tap Downsample 策略，引用了 "Call of Duty" 的演讲，旨在提高稳定性和质量。
   - 新代码的 `downsample_filter` 和 `downsample_filter_high` 都使用了更简单的 4x4 box filter。这可能是为了 **性能** 考虑，或者 Kino/Bloom v2 本身就使用了这种更简单的 Downsample。

2. **Upsample 滤波器的加入:**
   - Blender 代码的片段只展示了 Downsample 阶段，没有 Upsample 代码。
   - 新代码包含了 `upsample_filter_high` (9-tap bilinear) 和 `upsample_filter` (4-tap bilinear) 两种 Upsample 滤波器。这表明新代码展示的是一个更完整的 Bloom 流程，包含了 Upsample 阶段。

3. **平台兼容性考虑:**
   - 新代码使用了 `#if defined(WEBGL2) || defined(WEBGPU) || defined(NATIVE)` 和 `#define TEXTUREFUNC` 来处理不同平台下的纹理采样函数 `texture2DLodEXT` 和 `texture2D`。这表明 Kino/Bloom v2 是一个 **跨平台** 的 Bloom 效果，需要考虑不同平台的 GLSL 实现差异。Blender 的代码片段没有这种平台兼容性处理，因为它更专注于 Blender 内部的 GLSL 环境。

4. **许可证和作者信息:**
   - 新代码明确声明 "Original implementation by Keijiro Takahashi" 和 "Kino/Bloom v2 - Bloom filter for Unity"，并附带了原始的 MIT 许可证。这明确表明代码是基于 Keijiro Takahashi 的 Kino/Bloom v2 修改而来。
   - Blender 代码的许可证是 GPL-2.0-or-later，并署名 Blender Authors 和 Aras Pranckevicius 等。虽然 Blender 代码没有直接声明基于 Kino/Bloom，但 Clément Foucault 的 "Blender integration" 署名和代码的相似性，以及新代码的许可证信息都强烈暗示了 **Blender 的 Bloom 效果是受到了 Kino/Bloom v2 的启发和改造**。

**结论:**

**是的，新代码与 Blender 代码非常相似，并且极有可能 Blender 的 Glare Bloom 效果是基于 Kino/Bloom v2 改造而来的。**

- 新代码明确声明了原始作者和项目来源，并提供了更完整的 Bloom 效果实现 (包含 Downsample 和 Upsample)。
- 两者在 Karis 亮度加权平均、Downsample/Upsample 流程、滤波器的使用等方面都高度一致。
- Blender 代码可能在 Downsample 策略上做了更复杂的优化 (13-tap)，而 Kino/Bloom v2 可能为了性能使用了更简单的 4x4 box filter。
- 新代码加入了平台兼容性处理，而 Blender 代码没有，这符合它们各自的应用场景 (跨平台 Unity 插件 vs. Blender 内部合成器)。

因此，可以合理推断，Blender 的 Glare Bloom 效果很可能是由 Clément Foucault 等开发者，基于 Keijiro Takahashi 的 Kino/Bloom v2 (或者类似实现) 进行 **集成和改造** 而来的，并根据 Blender 的需求和性能目标进行了调整和优化。