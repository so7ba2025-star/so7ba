from PIL import Image, ImageDraw, ImageFilter

# إعدادات عامة
WIDTH, HEIGHT = 800, 400
RADIUS = 30
BORDER_THICKNESS = 1  # إطار رفيع جدًا أو معدوم
SPLIT_LINE_THICKNESS = 4 # خط رفيع
DOT_RADIUS = 24 # حجم النقطة
DOT_GLOW_RADIUS = 0 # إزالة التوهج

# ألوان البلاطة: أبيض ناصع
BASE_LIGHT = (250, 250, 250, 255)
BASE_DARK = (235, 235, 235, 255)
BORDER_COLOR = (255, 255, 255, 255) # إطار بنفس لون الخلفية لعدم رؤيته
# BACKGROUND_COLOR لم تعد مستخدمة في add_drop_shadow بشكل مباشر كخلفية صلبة، 
# بدلاً من ذلك، ستكون خلفية الصورة النهائية شفافة.
SHADOW_COLOR = (0, 0, 0, 50)        # ظل ساقط داكن قليلاً ليتضح

DOT_COLOR = (30, 30, 30, 255)       # أسود شبه نقي للنقاط
DIVIDER_COLOR = (30, 30, 30, 255)   # أسود شبه نقي للخط الفاصل

# قائمة البلاطات المطلوبة (a, b, filename)
# توليد كل الاحتمالات الممكنة: 7x7 = 49 صورة أفقية + 49 صورة رأسية = 98 صورة
DOMINO_TILES = []
for i in range(7):
    for j in range(7):
        # صورة أفقية
        filename_h = f"domino_{i}_{j}.png"
        DOMINO_TILES.append((i, j, filename_h))
        # صورة رأسية
        filename_v = f"domino_{i}_{j}_v.png"
        DOMINO_TILES.append((i, j, filename_v))

BACK_TILES = [
    ("domino_back.png", "player"),
    ("domino_back_ai.png", "ai"),
]


def create_vertical_gradient(size, top_color, bottom_color):
    """تدرج رأسي بسيط (سيكون غير مرئي تقريباً بسبب استخدام الأبيض النقي)."""
    w, h = size
    grad = Image.new("RGBA", (1, h), 0)
    draw = ImageDraw.Draw(grad)
    for y in range(h):
        ratio = y / (h - 1)
        r = int(top_color[0] * (1 - ratio) + bottom_color[0] * ratio)
        g = int(top_color[1] * (1 - ratio) + bottom_color[1] * ratio)
        b = int(top_color[2] * (1 - ratio) + bottom_color[2] * ratio)
        a = int(top_color[3] * (1 - ratio) + bottom_color[3] * ratio)
        draw.point((0, y), (r, g, b, a))
    return grad.resize(size, Image.Resampling.BILINEAR)


def add_inner_shadow(tile_img):
    """إضافة ظل داخلي لإعطاء تأثير ثلاثي الأبعاد."""
    draw = ImageDraw.Draw(tile_img)
    width, height = tile_img.size
    
    # ظل داخلي خفيف حول الحواف
    shadow_color = (180, 180, 180, 130)
    for i in range(6):
        alpha = 130 - i * 18
        draw.rounded_rectangle(
            (42 + i, 42 + i, width - 42 - i, height - 42 - i),
            radius=RADIUS - i,
            outline=(*shadow_color[:3], alpha),
            width=1
        )


def add_drop_shadow(tile_img, is_vertical=False):
    """إضافة ظل طري وناعم أسفل البلاطة فقط، مع خلفية شفافة."""
    if is_vertical:
        img_width, img_height = HEIGHT, WIDTH
    else:
        img_width, img_height = WIDTH, HEIGHT
        
    canvas = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0)) # خلفية شفافة

    shadow = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    shadow_offset_x = 0
    shadow_offset_y = 10 # إزاحة الظل للأسفل
    shadow_blur_radius = 20 # نصف قطر تشويش لظل ناعم
    
    s_draw.rounded_rectangle(
        (40 + shadow_offset_x, 40 + shadow_offset_y, 
         img_width - 40 + shadow_offset_x, img_height - 40 + shadow_offset_y),
        radius=RADIUS,
        fill=SHADOW_COLOR,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur_radius))

    canvas.alpha_composite(shadow)
    canvas.alpha_composite(tile_img)
    return canvas # إرجاع صورة RGBA (شفافة)


def get_pip_positions(num, left_half=True):
    """إرجاع أماكن النقاط التقليدية لنصف البلاطة."""
    mid_x = WIDTH // 2
    padding_x = 110
    padding_y = 90

    if left_half:
        region_left = 0
        region_right = mid_x
    else:
        region_left = mid_x
        region_right = WIDTH

    x_left = region_left + padding_x
    x_right = region_right - padding_x
    x_center = (region_left + region_right) // 2

    top = padding_y
    bottom = HEIGHT - padding_y
    middle_y = HEIGHT // 2

    positions = {
        0: [],
        1: [(x_center, middle_y)],
        2: [(x_left, top), (x_right, bottom)],
        3: [(x_left, top), (x_center, middle_y), (x_right, bottom)],
        4: [(x_left, top), (x_right, top), (x_left, bottom), (x_right, bottom)],
        5: [
            (x_left, top),
            (x_right, top),
            (x_center, middle_y),
            (x_left, bottom),
            (x_right, bottom),
        ],
        6: [
            (x_left, top),
            (x_right, top),
            (x_left, middle_y),
            (x_right, middle_y),
            (x_left, bottom),
            (x_right, bottom),
        ],
    }
    return positions[num]


def get_pip_positions_vertical(num, is_top=True, img_width=400, img_height=800):
    """إرجاع أماكن النقاط التقليدية للصورة الرأسية."""
    mid_y = img_height // 2
    padding_x = 90
    padding_y = 110

    if is_top:
        region_top = 0
        region_bottom = mid_y
    else:
        region_top = mid_y
        region_bottom = img_height

    x_left = padding_x
    x_right = img_width - padding_x
    x_center = img_width // 2

    top = region_top + padding_y
    bottom = region_bottom - padding_y
    middle_y = (region_top + region_bottom) // 2

    positions = {
        0: [],
        1: [(x_center, middle_y)],
        2: [(x_left, top), (x_right, bottom)],
        3: [(x_left, top), (x_center, middle_y), (x_right, bottom)],
        4: [(x_left, top), (x_right, top), (x_left, bottom), (x_right, bottom)],
        5: [
            (x_left, top),
            (x_right, top),
            (x_center, middle_y),
            (x_left, bottom),
            (x_right, bottom),
        ],
        6: [
            (x_left, top),
            (x_right, top),
            (x_left, middle_y),
            (x_right, middle_y),
            (x_left, bottom),
            (x_right, bottom),
        ],
    }
    return positions[num]


def draw_pip(tile_img, x, y, img_width=800, img_height=400):
    """نقطة سوداء كأنها محفورة في الحجر مع تأثير ثلاثي الأبعاد."""
    dot_layer = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
    d_draw = ImageDraw.Draw(dot_layer)

    # الظل الداخلي للنقطة (يمنح تأثير الحفر)
    shadow_offset = 2
    shadow_color = (180, 180, 180, 200)
    d_draw.ellipse(
        (x - DOT_RADIUS + shadow_offset, y - DOT_RADIUS + shadow_offset,
         x + DOT_RADIUS + shadow_offset, y + DOT_RADIUS + shadow_offset),
        fill=shadow_color,
    )
    
    # النقطة الرئيسية
    d_draw.ellipse(
        (x - DOT_RADIUS, y - DOT_RADIUS,
         x + DOT_RADIUS, y + DOT_RADIUS),
        fill=DOT_COLOR,
    )
    
    # إبراز لامع صغير أعلى يسار النقطة
    highlight_layer = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight_layer)
    h_draw.ellipse(
        (x - DOT_RADIUS + 6, y - DOT_RADIUS + 6,
         x - DOT_RADIUS + 18, y - DOT_RADIUS + 14),
        fill=(255, 255, 255, 110),
    )
    highlight_layer = highlight_layer.filter(ImageFilter.GaussianBlur(1))
    
    # ظل حافة خفيف أسفل يمين النقطة
    rim_shadow_layer = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
    rs_draw = ImageDraw.Draw(rim_shadow_layer)
    rs_draw.ellipse(
        (x + DOT_RADIUS - 18, y + DOT_RADIUS - 14,
         x + DOT_RADIUS - 6, y + DOT_RADIUS - 6),
        fill=(0, 0, 0, 110),
    )
    rim_shadow_layer = rim_shadow_layer.filter(ImageFilter.GaussianBlur(1))

    # إضافة توهج خفيف حول النقطة
    glow_layer = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow_layer)
    glow_color = (100, 100, 100, 50)
    g_draw.ellipse(
        (x - DOT_RADIUS - 2, y - DOT_RADIUS - 2,
         x + DOT_RADIUS + 2, y + DOT_RADIUS + 2),
        outline=glow_color,
        width=2
    )
    
    tile_img.alpha_composite(highlight_layer)
    tile_img.alpha_composite(rim_shadow_layer)
    tile_img.alpha_composite(glow_layer)
    tile_img.alpha_composite(dot_layer)


def trim_image(img, padding=0):
    """
    يقوم بتقليص الصورة لإزالة المساحات البيضاء الزائدة حول البلاطة.
    """
    bbox = img.getbbox()
    if bbox:
        # تقليص الصورة بالضبط حول المحتوى المرئي بدون إضافة padding
        return img.crop(bbox)
    return img # إذا كانت الصورة فارغة تماماً


def add_inner_glow(tile_img):
    """إضافة توهج داخلي خفيف لإعطاء مظهر ثلاثي الأبعاد."""
    draw = ImageDraw.Draw(tile_img)
    width, height = tile_img.size
    
    # توهج داخلي خفيف حول الحواف
    glow_color = (240, 240, 240, 80)
    for i in range(3):
        alpha = 80 - i * 25
        draw.rounded_rectangle(
            (45 + i, 45 + i, width - 45 - i, height - 45 - i),
            radius=RADIUS - i - 5,
            outline=(*glow_color[:3], alpha),
            width=1
        )


def add_bevel_edges(tile_img):
    w, h = tile_img.size
    hl = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d_hl = ImageDraw.Draw(hl)
    d_sh = ImageDraw.Draw(sh)
    for i in range(3):
        a1 = 90 - i * 25
        a2 = 90 - i * 25
        d_hl.rounded_rectangle((40 + i, 40 + i, w - 40 - i, h - 40 - i), radius=RADIUS - i, outline=(255, 255, 255, a1), width=1)
        d_sh.rounded_rectangle((40 + i, 40 + i, w - 40 - i, h - 40 - i), radius=RADIUS - i, outline=(120, 120, 120, a2), width=1)
    tile_img.alpha_composite(hl)
    tile_img.alpha_composite(sh)


def add_specular_highlight(tile_img):
    """لمعان براق خفيف في أعلى يسار الوجه لإحساس لامع."""
    w, h = tile_img.size
    spec = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(spec)
    d.ellipse((60, 50, 280, 170), fill=(255, 255, 255, 35))
    spec = spec.filter(ImageFilter.GaussianBlur(10))
    tile_img.alpha_composite(spec)


def add_corner_vignette(tile_img):
    """تظليل اتجاهي خفيف في أسفل يمين بدون ظهور بقعة."""
    w, h = tile_img.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    corner_w, corner_h = 180, 120
    steps = 24
    for i in range(steps):
        alpha = int(25 * (1 - i / steps))
        rect = (
            w - 40 - corner_w + i * 4,
            h - 40 - corner_h + i * 3,
            w - 40,
            h - 40,
        )
        d.rectangle(rect, fill=(0, 0, 0, alpha))
    overlay = overlay.filter(ImageFilter.GaussianBlur(6))
    tile_img.alpha_composite(overlay)


def create_domino_face(a, b, filename, is_vertical=False):
    if is_vertical:
        img_width, img_height = HEIGHT, WIDTH
    else:
        img_width, img_height = WIDTH, HEIGHT

    tile = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(tile)

    face_size = (img_width - 80, img_height - 80)

    grad = create_vertical_gradient(face_size, BASE_LIGHT, BASE_DARK)
    mask = Image.new("L", face_size, 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle((0, 0, face_size[0] - 1, face_size[1] - 1), radius=RADIUS, fill=255)
    tile.paste(grad, (40, 40), mask)

    t_draw.rounded_rectangle(
        (40, 40, img_width - 40, img_height - 40),
        radius=RADIUS,
        outline=BORDER_COLOR,
        width=BORDER_THICKNESS,
    )

    # خط فاصل رفيع مع تأثير حفر ثلاثي الأبعاد
    if is_vertical:
        divider_margin_x = 70
        divider_layer = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
        d_draw = ImageDraw.Draw(divider_layer)
        dy1 = img_height // 2 - SPLIT_LINE_THICKNESS // 2
        dy2 = img_height // 2 + SPLIT_LINE_THICKNESS // 2
        
        # الظل الداخلي للخط الفاصل
        shadow_offset = 1
        shadow_rect = (divider_margin_x + shadow_offset, dy1 + shadow_offset, 
                       img_width - divider_margin_x + shadow_offset, dy2 + shadow_offset)
        d_draw.rectangle(shadow_rect, fill=(180, 180, 180, 150))
        # إبراز خفيف أعلى الخط (هايلايت)
        highlight_rect = (divider_margin_x, dy1 - 2, img_width - divider_margin_x, dy1 - 1)
        d_draw.rectangle(highlight_rect, fill=(255, 255, 255, 120))
        
        # الخط الفاصل الرئيسي
        d_draw.rectangle(
            (divider_margin_x, dy1, img_width - divider_margin_x, dy2),
            fill=DIVIDER_COLOR,
        )
    else:
        divider_margin_y = 70
        divider_layer = Image.new("RGBA", (img_width, img_height), (0, 0, 0, 0))
        d_draw = ImageDraw.Draw(divider_layer)
        dx1 = img_width // 2 - SPLIT_LINE_THICKNESS // 2
        dx2 = img_width // 2 + SPLIT_LINE_THICKNESS // 2
        
        # الظل الداخلي للخط الفاصل
        shadow_offset = 1
        shadow_rect = (dx1 + shadow_offset, divider_margin_y + shadow_offset, 
                       dx2 + shadow_offset, img_height - divider_margin_y + shadow_offset)
        d_draw.rectangle(shadow_rect, fill=(180, 180, 180, 150))
        # إبراز خفيف يسار الخط (هايلايت)
        highlight_rect = (dx1 - 2, divider_margin_y, dx1 - 1, img_height - divider_margin_y)
        d_draw.rectangle(highlight_rect, fill=(255, 255, 255, 120))
        
        # الخط الفاصل الرئيسي
        d_draw.rectangle(
            (dx1, divider_margin_y, dx2, img_height - divider_margin_y),
            fill=DIVIDER_COLOR,
        )
    tile.alpha_composite(divider_layer)

    # إضافة التأثيرات ثلاثية الأبعاد
    add_inner_shadow(tile)
    add_inner_glow(tile)
    add_bevel_edges(tile)
    add_specular_highlight(tile)
    add_corner_vignette(tile)

    # نقاط الدومينو - تعديل الأماكن للصورة الرأسية
    if is_vertical:
        # للصورة الرأسية، نستخدم نفس الدالة ولكن نعتبر الجزء العلوي والسفلي
        for (x, y) in get_pip_positions_vertical(a, is_top=True, img_width=img_width, img_height=img_height):
            draw_pip(tile, x, y, img_width=img_width, img_height=img_height)
        for (x, y) in get_pip_positions_vertical(b, is_top=False, img_width=img_width, img_height=img_height):
            draw_pip(tile, x, y, img_width=img_width, img_height=img_height)
    else:
        # للصورة الأفقية، نستخدم الدالة الأصلية
        for (x, y) in get_pip_positions(a, left_half=True):
            draw_pip(tile, x, y)
        for (x, y) in get_pip_positions(b, left_half=False):
            draw_pip(tile, x, y)

    final_img = add_drop_shadow(tile, is_vertical=is_vertical)
    trimmed_img = trim_image(final_img)
    trimmed_img.save(filename, format="PNG", dpi=(300, 300))


def create_back_tile(filename, mode="player"):
    tile = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    t_draw = ImageDraw.Draw(tile)

    face_size = (WIDTH - 80, HEIGHT - 80)
    grad = create_vertical_gradient(face_size, BASE_LIGHT, BASE_DARK)
    mask = Image.new("L", face_size, 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle((0, 0, face_size[0] - 1, face_size[1] - 1), radius=RADIUS, fill=255)
    tile.paste(grad, (40, 40), mask)

    t_draw.rounded_rectangle(
        (40, 40, WIDTH - 40, HEIGHT - 40),
        radius=RADIUS,
        outline=BORDER_COLOR,
        width=BORDER_THICKNESS,
    )

    add_inner_shadow(tile)
    add_inner_glow(tile)
    add_bevel_edges(tile)
    add_specular_highlight(tile)
    add_corner_vignette(tile)

    final_img = add_drop_shadow(tile, is_vertical=False)
    trimmed_img = trim_image(final_img)
    trimmed_img.save(filename, format="PNG", dpi=(300, 300))


def main():
    print("Generating domino faces...")
    for a, b, filename in DOMINO_TILES:
        is_vertical = filename.endswith('_v.png')
        create_domino_face(a, b, filename, is_vertical)
        print(f"Saved {filename}")

    print("Generating back tiles...")
    for filename, mode in BACK_TILES:
        create_back_tile(filename, mode)
        print(f"Saved {filename}")

    print("Done. All tiles generated in current folder.")


if __name__ == "__main__":
    main()