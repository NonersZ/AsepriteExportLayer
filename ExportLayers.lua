------------------------------------------------------------
-- ExportLayers.lua
--
-- 功能：
--   导出每个普通 Layer 的每一帧为独立 PNG
--
-- 输出结构：
--
--   Player.aseprite
--
--   Player_Export/
--       Body/
--           Body_001.png
--           Body_002.png
--           Body_003.png
--           ...
--
--       Head/
--           Head_001.png
--           Head_002.png
--           ...
--
--       Weapon/
--           Weapon_001.png
--           Weapon_002.png
--           ...
--
-- 特性：
--   1. 遍历所有 Layer
--   2. 遍历所有 Frame
--   3. 每个 Layer 的每个 Frame 单独导出
--   4. 自动裁剪透明区域
--   5. 隐藏 Layer 跳过
--   6. Group Layer 跳过
--   7. 没有 Cel 的 Frame 跳过
--   8. 保留 Cel opacity
--   9. 保留 Indexed Palette
--  10. Layer 重名自动处理
--  11. Frame 使用 001、002、003 编号
--  12. 不修改原始 Sprite
------------------------------------------------------------


------------------------------------------------------------
-- 当前 Sprite
------------------------------------------------------------

local sprite = app.activeSprite

if not sprite then
    app.alert("没有打开 Aseprite 文件！")
    return
end


------------------------------------------------------------
-- 必须保存文件
------------------------------------------------------------

if sprite.filename == "" then
    app.alert("请先保存 Aseprite 文件！")
    return
end


------------------------------------------------------------
-- 工具函数
------------------------------------------------------------


------------------------------------------------------------
-- 删除文件扩展名
------------------------------------------------------------

local function removeExtension(filename)

    return filename:gsub("%.[^%.]+$", "")

end


------------------------------------------------------------
-- 清理 Windows 文件名非法字符
------------------------------------------------------------

local function sanitizeFileName(name)

    name = name:gsub('[\\/:*?"<>|]', "_")

    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")

    if name == "" then
        name = "Layer"
    end

    return name

end


------------------------------------------------------------
-- 防止 Layer 重名
--
-- Body
-- Body
-- Body
--
-- 变成：
--
-- Body
-- Body_2
-- Body_3
------------------------------------------------------------

local usedLayerNames = {}


local function getUniqueLayerName(name)

    if not usedLayerNames[name] then

        usedLayerNames[name] = 1

        return name

    end


    usedLayerNames[name] =
        usedLayerNames[name] + 1


    return name ..
        "_" ..
        usedLayerNames[name]

end


------------------------------------------------------------
-- 创建目录
------------------------------------------------------------

local function ensureDirectory(path)

    if app.fs.isDirectory(path) then
        return true
    end

    return app.fs.makeDirectory(path)

end


------------------------------------------------------------
-- 获取文件路径
------------------------------------------------------------

local filePath =
    app.fs.filePath(sprite.filename)


local fileName =
    app.fs.fileName(sprite.filename)


------------------------------------------------------------
-- 检查路径
------------------------------------------------------------

if not filePath or filePath == "" then

    app.alert(
        "无法获取 Aseprite 文件所在目录！\n\n" ..
        "文件路径：\n" ..
        tostring(sprite.filename)
    )

    return

end


if not fileName or fileName == "" then

    app.alert(
        "无法获取 Aseprite 文件名！"
    )

    return

end


------------------------------------------------------------
-- 文件基础名称
--
-- Player.aseprite
-- ↓
-- Player
------------------------------------------------------------

local baseName =
    removeExtension(fileName)


------------------------------------------------------------
-- 总输出目录
--
-- Player_Export/
------------------------------------------------------------

local outputDirectory =
    app.fs.joinPath(
        filePath,
        baseName .. "_Export"
    )


------------------------------------------------------------
-- 创建总输出目录
------------------------------------------------------------

if not ensureDirectory(outputDirectory) then

    app.alert(
        "无法创建输出目录：\n\n" ..
        outputDirectory
    )

    return

end


------------------------------------------------------------
-- Sprite Frame 数量
------------------------------------------------------------

local frameCount =
    #sprite.frames


if frameCount <= 0 then

    app.alert(
        "当前 Sprite 没有 Frame！"
    )

    return

end


------------------------------------------------------------
-- 统计
------------------------------------------------------------

local exportedCount = 0
local skippedCount = 0
local failedCount = 0


------------------------------------------------------------
-- Layer
------------------------------------------------------------

for _, layer in ipairs(sprite.layers) do


    --------------------------------------------------------
    -- Group Layer 跳过
    --------------------------------------------------------

    if layer.isGroup then

        skippedCount =
            skippedCount + frameCount


    else


        ----------------------------------------------------
        -- 隐藏 Layer 跳过
        ----------------------------------------------------

        if not layer.isVisible then

            skippedCount =
                skippedCount + frameCount


        else


            ------------------------------------------------
            -- Layer 名称
            ------------------------------------------------

            local layerName =
                sanitizeFileName(
                    layer.name
                )


            ------------------------------------------------
            -- 处理 Layer 重名
            ------------------------------------------------

            layerName =
                getUniqueLayerName(
                    layerName
                )


            ------------------------------------------------
            -- 当前 Layer 输出目录
            --
            -- Player_Export/Body/
            ------------------------------------------------

            local layerDirectory =
                app.fs.joinPath(
                    outputDirectory,
                    layerName
                )


            ------------------------------------------------
            -- 创建 Layer 目录
            ------------------------------------------------

            if not ensureDirectory(layerDirectory) then

                failedCount =
                    failedCount + frameCount

            else


                ------------------------------------------------
                -- 遍历所有 Frame
                ------------------------------------------------

                for frameNumber = 1, frameCount do


                    ------------------------------------------------
                    -- 获取当前 Frame
                    ------------------------------------------------

                    local frame =
                        sprite.frames[frameNumber]


                    ------------------------------------------------
                    -- 获取当前 Layer 当前 Frame 的 Cel
                    ------------------------------------------------

                    local cel =
                        layer:cel(frameNumber)


                    ------------------------------------------------
                    -- 没有 Cel
                    ------------------------------------------------

                    if not cel then

                        skippedCount =
                            skippedCount + 1


                    else


                        ------------------------------------------------
                        -- 获取 Cel Image
                        ------------------------------------------------

                        local sourceImage =
                            cel.image


                        if not sourceImage then

                            skippedCount =
                                skippedCount + 1


                        else


                            ------------------------------------------------
                            -- 获取实际非透明区域
                            ------------------------------------------------

                            local bounds =
                                sourceImage:shrinkBounds()


                            ------------------------------------------------
                            -- 空 Image
                            ------------------------------------------------

                            if not bounds or
                               bounds.width <= 0 or
                               bounds.height <= 0 then

                                skippedCount =
                                    skippedCount + 1


                            else


                                ------------------------------------------------
                                -- 裁剪 Image
                                ------------------------------------------------

                                local croppedImage =
                                    Image(
                                        sourceImage,
                                        bounds
                                    )


                                if not croppedImage then

                                    failedCount =
                                        failedCount + 1


                                else


                                    ------------------------------------------------
                                    -- 创建临时 Sprite
                                    ------------------------------------------------

                                    local tempSprite =
                                        Sprite(
                                            bounds.width,
                                            bounds.height,
                                            sprite.colorMode
                                        )


                                    ------------------------------------------------
                                    -- 保留 Color Space
                                    ------------------------------------------------

                                    tempSprite.colorSpace =
                                        sprite.colorSpace


                                    ------------------------------------------------
                                    -- Indexed 模式
                                    --
                                    -- 保留原 Palette
                                    ------------------------------------------------

                                    if sprite.colorMode ==
                                       ColorMode.INDEXED then

                                        if sprite.palettes and
                                           sprite.palettes[1] then

                                            local palette =
                                                Palette(
                                                    sprite.palettes[1]
                                                )

                                            tempSprite:setPalette(
                                                palette
                                            )

                                        end
                                    end


                                    ------------------------------------------------
                                    -- 临时 Layer
                                    ------------------------------------------------

                                    local tempLayer =
                                        tempSprite.layers[1]


                                    ------------------------------------------------
                                    -- 创建 Cel
                                    ------------------------------------------------

                                    local newCel =
                                        tempSprite:newCel(
                                            tempLayer,
                                            1,
                                            croppedImage,
                                            Point(0, 0)
                                        )


                                    ------------------------------------------------
                                    -- 保留 Cel Opacity
                                    ------------------------------------------------

                                    if newCel then

                                        newCel.opacity =
                                            cel.opacity

                                    end


                                    ------------------------------------------------
                                    -- Frame 文件名
                                    --
                                    -- 1  -> 001
                                    -- 2  -> 002
                                    -- 10 -> 010
                                    ------------------------------------------------

                                    local frameName =
                                        string.format(
                                            "%s_%03d.png",
                                            layerName,
                                            frameNumber
                                        )


                                    ------------------------------------------------
                                    -- 输出路径
                                    ------------------------------------------------

                                    local outputPath =
                                        app.fs.joinPath(
                                            layerDirectory,
                                            frameName
                                        )


                                    ------------------------------------------------
                                    -- 保存 PNG
                                    ------------------------------------------------

                                    local success =
                                        tempSprite:saveAs(
                                            outputPath
                                        )


                                    ------------------------------------------------
                                    -- 关闭临时 Sprite
                                    ------------------------------------------------

                                    tempSprite:close()


                                    ------------------------------------------------
                                    -- 统计
                                    ------------------------------------------------

                                    if success then

                                        exportedCount =
                                            exportedCount + 1

                                    else

                                        failedCount =
                                            failedCount + 1

                                    end

                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- 完成
------------------------------------------------------------

app.alert(
    "全部 Frame 导出完成！\n\n" ..

    "Frame 数量： " ..
    frameCount ..
    "\n\n" ..

    "成功导出： " ..
    exportedCount ..
    " 张\n" ..

    "跳过： " ..
    skippedCount ..
    " 个\n" ..

    "失败： " ..
    failedCount ..
    " 个\n\n" ..

    "输出目录：\n" ..
    outputDirectory
)


------------------------------------------------------------
-- 自动打开导出目录
------------------------------------------------------------

if app.fs.isDirectory(outputDirectory) then

    os.execute(
        'explorer "' ..
        outputDirectory ..
        '"'
    )

end
