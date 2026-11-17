"""Draw DayMind's original calendar/sun/leaf mark. Developer tool: Pillow.

No source images, fonts, downloaded assets or third-party character art.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw

folder = Path(__file__).resolve().parents[1] / 'ios/Runner/Assets.xcassets/DayMindIcon.appiconset'
folder.mkdir(exist_ok=True)
image = Image.new('RGB', (1024, 1024), '#526b4b')
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((208, 240, 816, 816), radius=116, fill='#f5f6f1')
draw.rounded_rectangle((288, 192, 336, 336), radius=24, fill='#d6e4c7')
draw.rounded_rectangle((688, 192, 736, 336), radius=24, fill='#d6e4c7')
draw.line((280, 400, 744, 400), fill='#d6e4c7', width=24)
draw.ellipse((328, 456, 568, 696), fill='#edc66c')
draw.polygon([(488, 700), (516, 574), (652, 502), (712, 488), (700, 610), (628, 688), (552, 716)], fill='#526b4b')
draw.line([(496, 716), (560, 652), (648, 564)], fill='#f5f6f1', width=18)
image.save(folder / 'DayMind-1024.png', optimize=True)
(folder / 'Contents.json').write_text(json.dumps({
    'images': [{'filename': 'DayMind-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
    'info': {'author': 'DayMind', 'version': 1},
}, indent=2) + '\n')
