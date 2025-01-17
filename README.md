# 帆软calder逆向

- [下载DEMO解包可得到资源(.mfvs或.fvs都是压缩包)](https://market.fanruan.com/template/20000714/)
- calder 等同于 babylon
- [3D产线流程看板DEMO](https://finemaxdemo.fanruan.com/decision/v10/entry/access/ac1a7bf7-34b3-42dc-8455-2d5cce1b5ba4?preview=true&page_number=1)

## 对Babylon.js的扩展

```markdown
1. 用了**Babylon.js** 
2. 自定义了多个 **ShaderMaterial**:  noise\ShockWave\ColorSky\line\CylinderData\LineData\PointDataSpot\PointDataPolyhedron\EffectFence\EffectCircle
3. 自定义了多个 **Effect**, ShadersStore.[dynamic2D\effectGround\glowMapMerge2\customHighlight\customStencil\TileGroun\customFilter\ShockWave\ColorSky\CloudColor\Tonemap\colorify\CylinderData\LineData\PointDataSpot\PointDataPolyhedron\EffectFence\EffectCircle]
4. 自定义了多个 **PostProcess**: dualBlur
5. scene.style.[glowLayer\groundReflection\meteor\shockWaveLayer\snow]
    `_glowLayer` -> `DualBlurGlowLayer`-> `_dualBlurPostProcessesChain` -> `dualBlur.fragment.fx` -> `Kino/Bloom v2 - Bloom filter for Unity`
6. extend扩展3个 **CustomMaterial**
    `this.Vertex_Definitions\this.Vertex_MainEnd\this.Fragment_Definitions\this.Fragment_Before_FragColor`
7. 自定义 Babylon.js 中的材质插件（**MaterialPlugin**）
    `CUSTOM_OVERLAY\CUSTOM_SHADER_INPUTS\dissolvable\wireframe_crease_vertexdata\wireframe_texture\WireframeSkinMaterialPlugin`
```

## JSON解析流程

```js
store.json
    1. configFile 得到 7x-lqgd7PJISU2BWulAlgWjmw==.json 3D场景描述文件(包含很多可以在在Babylon.js Node Material Editor.用的对象被解析成材质 和 各种效果)
    2. tplPath reportlets/fvs/3D产线流程看板.fvs 联合   ee9040023b1c2d761edc83e7727feb7c.calder(即.babylon文件 被解析成Mesh)

```

## 资源

- [帆软市场-FineVis数据可视化-下载页面](https://market.fanruan.com/plugin/2b55753a-3d27-45cc-997b-e450b6c33fbc)
- [下载](https://shopps.finereport.com/com.fr.plugin.wysiwyg.v11-3.2.1.zip)
- 在解压的`plugin-com.fr.plugin.wysiwyg.v11-3.2.1/plugin-com.fr.plugin.wysiwyg.v11-3.2.1/com/fr/plugin/wysiwyg/web/calder`目录下找到各种贴图材质资源
