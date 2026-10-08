# mpv-for-aoe

Trình phát video dựa trên [mpv](https://mpv.io), chỉnh sẵn để xem lại video toàn bản đồ Age of Empires do
[AoE-MapCap](https://github.com/trandinhnamuet/AoEMapCap) ghi (tới 9216 px ngang): lăn chuột để zoom vào đúng
chỗ con trỏ, kéo chuột để di chuyển, zoom quá 1:1 vẫn giữ nét từng pixel của game.

## Tải và dùng

1. Vào trang [Releases](https://github.com/trandinhnamuet/mpv-for-aoe/releases/latest), tải
   `mpv-for-aoe-win64.zip`, giải nén ra một thư mục bất kì (không cần cài đặt).
2. Kéo file video `.mp4` thả vào `mpv.exe` (hoặc chuột phải video > Open with > chọn `mpv.exe`).

Lần đầu chạy Windows có thể hiện "Windows protected your PC" vì file chưa ký số: bấm **More info > Run anyway**.
Muốn chắc chắn file không bị sửa, xem mục [Kiểm tra file tải về](#kiểm-tra-file-tải-về).

## Điều khiển

| Thao tác | Tác dụng |
|---|---|
| Lăn chuột | Zoom vào / ra quanh vị trí con trỏ |
| Ctrl + lăn chuột | Zoom từng bước nhỏ |
| Giữ chuột trái và kéo | Di chuyển khung nhìn khi đang zoom |
| Bấm chuột giữa | Về toàn bản đồ (bỏ zoom) |
| Nhấp đúp chuột trái | Bật/tắt toàn màn hình |
| Dấu cách | Dừng / phát |
| Mũi tên trái / phải | Lùi / tới 5 giây |
| Mũi tên lên / xuống | Tới / lùi 1 phút |
| `.` và `,` | Tới / lùi từng khung hình (khi dừng) |
| `[` và `]` | Giảm / tăng tốc độ phát; `Backspace` về tốc độ thường |
| Shift + lăn chuột | Âm lượng |
| `s` | Chụp ảnh khung hiện tại |
| `q` | Thoát |

Các phím khác giữ nguyên như mpv gốc: <https://mpv.io/manual/stable/#keyboard-control>.

## Khác gì so với mpv gốc

Mọi thay đổi đánh dấu `[mpv-for-aoe]` trong mã nguồn:

- `etc/input.conf`: lăn chuột = zoom quanh con trỏ (mpv gốc: âm lượng), chuột trái kéo = di chuyển, chuột giữa =
  về ban đầu, Ctrl + lăn = zoom nhỏ, Shift + lăn = âm lượng.
- `player/lua/positioning.lua`: giới hạn zoom từ vừa cửa sổ tới 2^6 lần (không thu video nhỏ hơn cửa sổ); sửa lỗi
  kéo chuột làm video nhảy sát mép khi video vừa khít cửa sổ theo một chiều; sửa lỗi zoom bằng màn hình cảm ứng.
- `video/out/gpu/video.c`: phóng to dùng `nearest` (giữ nét pixel game), màu (chroma) dùng `bilinear`.
- `options/options.c`: `keep-open=yes`, hết video thì dừng ở khung cuối thay vì đóng cửa sổ.
- `.github/workflows/aoe-release.yml`: tự build bản Windows và đăng Release.

Mọi tuỳ chọn vẫn đổi được như mpv gốc bằng `portable_config\mpv.conf` và `portable_config\input.conf` đặt cạnh
`mpv.exe` (xem `portable_config\mpv.conf.example`).

## Kiểm tra file tải về

Bản Windows được build hoàn toàn trên GitHub Actions từ mã nguồn công khai của repo này (script build gốc của mpv
`ci/build-mingw64-full.sh`, trong container công khai `ghcr.io/btbn/ffmpeg-builds/win64-gpl`), không build trên máy
cá nhân nào. Mỗi Release có chứng nhận nguồn gốc (build provenance) ký bởi GitHub:

```
gh attestation verify mpv-for-aoe-win64.zip -R trandinhnamuet/mpv-for-aoe
gh attestation verify mpv.exe -R trandinhnamuet/mpv-for-aoe
```

Lệnh trả về commit và lần chạy workflow đã tạo ra file. Mã băm SHA-256 có trong `SHA256SUMS.txt` (trong zip) và
`mpv-for-aoe-win64.zip.sha256` (trên trang Release); `VERSION.txt` ghi commit nguồn.

## Ghi chú kĩ thuật

Video H.264 rộng hơn 4096 px không giải mã được bằng GPU, mpv giải mã bằng CPU (đo trên CPU 16 luồng: 61 khung/s
với video 9216x4690, đủ phát 25 khung/s). Tua lâu hay nhanh phụ thuộc khoảng cách khung khoá (keyframe) của video.

## Giấy phép

GPL v2 trở lên, như mpv (xem `LICENSE.GPL`, `Copyright`). Mã nguồn đầy đủ: chính repo này, nhánh `aoe`.
