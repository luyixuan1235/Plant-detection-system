from __future__ import annotations

import json
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont


def load_font(name: str, size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype(name, size)
    except OSError:
        return ImageFont.load_default()


def centered_text(
    draw: ImageDraw.ImageDraw,
    canvas_width: int,
    y: int,
    text: str,
    font: ImageFont.ImageFont,
    fill: str | tuple[int, int, int],
) -> None:
    box = draw.textbbox((0, 0), text, font=font)
    text_width = box[2] - box[0]
    draw.text(((canvas_width - text_width) / 2, y), text, fill=fill, font=font)


def main() -> None:
    frontend_root = Path(__file__).resolve().parents[1]
    data_path = frontend_root / "assets" / "data" / "campus_plants.json"
    output_dir = frontend_root / "assets" / "qr_codes"
    output_dir.mkdir(parents=True, exist_ok=True)

    data = json.loads(data_path.read_text(encoding="utf-8"))
    title_font = load_font("arial.ttf", 26)
    subtitle_font = load_font("arial.ttf", 18)

    for plant in data["plants"]:
        plant_id = plant["id"]
        plant_name = plant["name"]
        qr_payload = plant.get("info_url") or plant_id

        qr = qrcode.QRCode(
            version=None,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=10,
            border=3,
        )
        qr.add_data(qr_payload)
        qr.make(fit=True)

        qr_img = qr.make_image(fill_color="black", back_color="white").convert("RGB")
        canvas_width = max(qr_img.width + 80, 420)
        canvas_height = qr_img.height + 100
        canvas = Image.new("RGB", (canvas_width, canvas_height), "white")
        canvas.paste(qr_img, ((canvas_width - qr_img.width) // 2, 24))

        draw = ImageDraw.Draw(canvas)
        centered_text(draw, canvas_width, qr_img.height + 34, plant_id, title_font, "black")
        centered_text(
            draw,
            canvas_width,
            qr_img.height + 66,
            plant_name,
            subtitle_font,
            (70, 70, 70),
        )

        canvas.save(output_dir / f"{plant_id}.png")

    print(f"Generated {len(data['plants'])} QR code files in {output_dir}")


if __name__ == "__main__":
    main()
