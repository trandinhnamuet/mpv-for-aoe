# mpv-for-aoe

**[⬇ Tải bản Windows mới nhất (mpv-for-aoe-win64.zip)](https://github.com/trandinhnamuet/mpv-for-aoe/releases/latest/download/mpv-for-aoe-win64.zip)**
· [Các phiên bản trước](https://github.com/trandinhnamuet/mpv-for-aoe/releases)
· [Kiểm tra file tải về](#kiểm-tra-file-tải-về)

Trình phát video dựa trên [mpv](https://mpv.io), chỉnh sẵn để xem lại video toàn bản đồ Age of Empires do
[AoE-MapCap](https://github.com/trandinhnamuet/AoEMapCap) ghi lại: lăn chuột để zoom vào đúng chỗ con trỏ, kéo
chuột để di chuyển, zoom quá 1:1 vẫn giữ nét từng pixel của game. Giải nén là chạy, không cần cài đặt.

## Vì sao fork mpv

AoE-MapCap dựng video toàn bản đồ của cả trận đấu ở kích cỡ gốc của game, tới **9216x4690 px** (lớn hơn 8K). Muốn
xem chuyện gì đang xảy ra ở một góc bản đồ thì phải zoom vào được chỗ bất kì trong video. Các trình phát thông dụng
đều vướng:

- **Phim & TV, Media Player của Windows**: thường từ chối video H.264 lớn cỡ này (vượt giới hạn level 6.2 của chuẩn).
- **GPU** chỉ giải mã H.264 tới khoảng 4096 px ngang, nên mọi trình phát đều phải giải mã bằng CPU.
- **VLC** giải mã được nhưng zoom bằng bộ lọc, thao tác bất tiện.
- **mpv gốc** giải mã tốt và đã có zoom quanh con trỏ, nhưng mặc định phải giữ Ctrl khi lăn chuột, kéo chuột
  không di chuyển được khung nhìn, phóng to làm nhoè pixel game. Sửa bằng file cấu hình cá nhân thì mỗi người phải
  tự làm, khó chia sẻ cho nhiều người dùng.

Fork để **mọi người tải về một file là dùng được ngay**, cùng một cách điều khiển, và **mã nguồn công khai** để ai
cũng tự kiểm tra được bảo mật: mọi thay đổi so với mpv gốc nằm trong vài file, đánh dấu `[mpv-for-aoe]`, bản
Windows do GitHub Actions build từ chính mã nguồn này.

## Tính năng thêm

| Thao tác | mpv gốc | mpv-for-aoe |
|---|---|---|
| Lăn chuột | Âm lượng | **Zoom mượt vào / ra quanh con trỏ** (mỗi nấc ~19%, chạy hoạt ảnh thay vì nhảy) |
| Ctrl + lăn chuột | Zoom quanh con trỏ | Zoom từng bước nhỏ (~3,5%) |
| Giữ chuột trái và kéo | Kéo cả cửa sổ đi chỗ khác | **Di chuyển khung nhìn** khi đang zoom (như Ctrl + kéo của mpv gốc); muốn dời cửa sổ thì kéo thanh tiêu đề |
| Bấm chuột giữa | Không làm gì | **Về toàn bản đồ** (bỏ zoom và di chuyển) |
| Giữ phím mũi tên | Tua 5 giây / 1 phút | **Di chuyển khung nhìn** như máy quay trong game, giữ phím thì lướt liên tục |
| Shift + lăn chuột | Không làm gì | Âm lượng |
| Hết video | Đóng cửa sổ | Dừng ở khung cuối để xem kết quả trận |

## Tối ưu và sửa lỗi

- **Giữ nét pixel khi zoom quá 1:1**: phóng to dùng `nearest` thay cho `lanczos`, từng pixel game hiện thành ô vuông
  sắc nét thay vì bị nhoè. Thu nhỏ (khi xem toàn bản đồ) vẫn dùng `hermite` mịn như mpv gốc; màu (chroma 4:2:0)
  dùng `bilinear` để không bị vỡ khối màu.
- **Kéo chuột không dời cửa sổ**: tắt mặc định `window-dragging` của mpv, nếu không Windows sẽ dời cả cửa sổ
  ngay khi giữ chuột trái và kéo, khung nhìn không di chuyển. Bật lại bằng `window-dragging=yes` trong `mpv.conf`.
- **Giới hạn zoom** từ vừa cửa sổ tới 64 lần: lăn chuột ra không làm video nhỏ hơn cửa sổ.
- **Sửa lỗi video nhảy sát mép**: video toàn bản đồ rộng hơn tỉ lệ màn hình 16:9 nên vừa khít chiều ngang cửa sổ;
  mpv gốc khi đó chia cho 0 lúc kéo chuột hoặc zoom về mức ban đầu, làm khung nhìn nhảy sát mép.
- **Sửa lỗi zoom bằng màn hình cảm ứng** (biến toạ độ chưa khởi tạo trong mpv gốc).
- **Zoom và kéo mượt khi đang phát video 9216 px**: đo trên laptop Iris Xe, bản trước chỉ cập nhật khung nhìn được
  vài lần mỗi giây trong lúc phát. Ba nguyên nhân đã sửa:
  - Mỗi bước zoom/kéo làm đổi lề video, mpv báo "cửa sổ đổi kích thước" và đọc lại `current-window-scale`; lần
    đọc này chờ luồng vẽ đang bận đưa khung 9216 px lên GPU (~10 ms mỗi khung), có lúc chờ hàng trăm ms. Nay kích
    thước cửa sổ được dùng lại khi cửa sổ không thật sự đổi kích thước (`player/command.c`).
  - Menu chuột phải dựng lại toàn bộ dữ liệu mỗi khi zoom/căn chỉnh đổi, vì có mục "đánh dấu" theo `video-zoom`,
    `video-align`, `video-pan`; đã bỏ các điều kiện đó (`etc/menu.conf`).
  - Script zoom/kéo giữ trạng thái khung nhìn, tính mỗi bước tại chỗ và gửi lệnh không chờ; lệnh đến dồn thì gộp
    lại, chỉ gửi giá trị mới nhất. Timer chạy 120 Hz (đồng hồ Windows mặc định làm timer 60 Hz chỉ chạy ~33 lần/s).
  - Khi đang phát, mpv gốc chỉ vẽ lại theo nhịp khung video (25 lần/s) nên zoom/kéo cũng chỉ mượt 25 lần/s; nay vẽ
    lại ngay giữa hai khung video khi khung nhìn đổi, tối đa bằng tần số màn hình (`player/playloop.c`).
- **Thu nhỏ rẻ trong lúc chuyển động**: vẽ lại khung 9216 px với `hermite` tốn ~14 ms trên GPU tích hợp, với
  `bilinear` ~1 ms. Trong lúc zoom/kéo dùng `bilinear`, dừng 0,3 s thì tự trả lại `hermite` để ảnh tĩnh mịn.
- **Giải mã bằng CPU nhiều luồng** (mặc định của mpv): đo trên CPU 16 luồng, video 9216x4690 giải mã 61 khung/s, đủ
  phát mượt 25 khung/s. Bản Windows build tĩnh, chỉ gồm `mpv.exe`/`mpv.com`, không cần cài thêm thư viện.

## Hướng dẫn sử dụng

### Cài đặt

1. Tải [mpv-for-aoe-win64.zip](https://github.com/trandinhnamuet/mpv-for-aoe/releases/latest/download/mpv-for-aoe-win64.zip),
   giải nén ra một thư mục bất kì.
2. Kéo file video `.mp4` thả vào `mpv.exe`, hoặc chuột phải video > **Open with** > **Choose another app** > chọn
   `mpv.exe` (đánh dấu "Always" nếu muốn mở mọi video bằng nó).

Lần đầu chạy, Windows có thể hiện "Windows protected your PC" vì file chưa ký số: bấm **More info > Run anyway**.

### Điều khiển

| Thao tác | Tác dụng |
|---|---|
| Lăn chuột | Zoom vào / ra quanh vị trí con trỏ |
| Ctrl + lăn chuột | Zoom từng bước nhỏ |
| Giữ chuột trái và kéo | Di chuyển khung nhìn khi đang zoom |
| Bấm chuột giữa / `Alt+Backspace` | Về toàn bản đồ |
| Nhấp đúp chuột trái / `f` | Bật/tắt toàn màn hình |
| Dấu cách | Dừng / phát |
| Phím mũi tên | Di chuyển khung nhìn sang trái / phải / lên / xuống (giữ phím để lướt) |
| Shift + mũi tên trái / phải | Lùi / tới 1 giây |
| Shift + mũi tên xuống / lên | Lùi / tới 5 giây |
| `Shift+PgDn` / `Shift+PgUp` | Lùi / tới 10 phút |
| Bấm vào thanh tiến độ phía dưới | Tua tới vị trí đó |
| `.` và `,` | Tới / lùi từng khung hình (khi dừng) |
| `[` và `]` | Giảm / tăng tốc độ phát; `Backspace` về tốc độ thường |
| Shift + lăn chuột | Âm lượng |
| `s` | Chụp ảnh khung hiện tại (ảnh đúng kích cỡ gốc của video) |
| Chuột phải | Menu |
| `q` | Thoát |

Các phím khác giữ nguyên như mpv gốc: <https://mpv.io/manual/stable/#keyboard-control>.

### Mẹo xem trận

- Dừng (dấu cách) rồi zoom vào một trận giao tranh, dùng `.` để xem từng khung hình.
- Tăng tốc độ bằng `]` để lướt nhanh giai đoạn đầu trận, `Backspace` để về tốc độ thường.
- Tua tới đúng một thời điểm có thể mất vài giây với video 9216 px vì phải giải mã từ khung khoá gần nhất.

### Tuỳ chỉnh

Mọi tuỳ chọn vẫn đổi được như mpv gốc: đặt `mpv.conf` và `input.conf` trong thư mục `portable_config\` cạnh
`mpv.exe` (zip có sẵn `portable_config\mpv.conf.example` để tham khảo). Ví dụ đổi bước zoom của lăn chuột, thêm vào
`portable_config\input.conf`:

```
WHEEL_UP   script-binding positioning/cursor-centric-zoom  0.5
WHEEL_DOWN script-binding positioning/cursor-centric-zoom -0.5
```

Muốn phím mũi tên tua như mpv gốc, thêm vào `portable_config\input.conf`:

```
RIGHT seek  5
LEFT  seek -5
UP    seek  60
DOWN  seek -60
```

Độ mượt và tốc độ chỉnh trong `portable_config\script-opts\positioning.conf`:

```
# thời gian zoom đuổi kịp con lăn, giây (0,25 mặc định; nhỏ hơn = nhanh hơn)
zoom_smoothness=0.25
# no = mỗi nấc zoom nhảy ngay như mpv gốc
smooth_zoom=yes
# tốc độ di chuyển bằng phím mũi tên, chiều cao cửa sổ mỗi giây
camera_speed=1.0
# no = luôn thu nhỏ bằng dscale đã cấu hình, kể cả lúc đang zoom/kéo
fast_scaling_in_motion=yes
```

Muốn phóng to mịn như mpv gốc thay vì giữ ô pixel, thêm `scale=lanczos` vào `portable_config\mpv.conf`.

## Kiểm tra file tải về

Bản Windows được build hoàn toàn trên GitHub Actions
([.github/workflows/aoe-release.yml](.github/workflows/aoe-release.yml)) từ mã nguồn công khai của repo này, bằng
script build gốc của mpv `ci/build-mingw64-full.sh` trong container công khai `ghcr.io/btbn/ffmpeg-builds/win64-gpl`,
không build trên máy cá nhân nào. Mỗi Release có chứng nhận nguồn gốc (build provenance) do GitHub ký:

```
gh attestation verify mpv-for-aoe-win64.zip -R trandinhnamuet/mpv-for-aoe
gh attestation verify mpv.exe -R trandinhnamuet/mpv-for-aoe
```

Lệnh trả về commit và lần chạy workflow đã tạo ra file. Mã băm SHA-256 nằm trong `SHA256SUMS.txt` (trong zip) và
`mpv-for-aoe-win64.zip.sha256` (trên trang Release); `VERSION.txt` ghi commit nguồn.

Toàn bộ thay đổi so với mpv gốc: `git diff upstream/master...aoe`, gồm `etc/input.conf`, `player/lua/positioning.lua`,
`video/out/gpu/video.c`, `options/options.c`, `input/input.c`, `player/command.c`, `player/playloop.c`, `etc/menu.conf`,
workflow build và README này.

## Dành cho người duy trì

- Nhánh `aoe` là nhánh chính của fork; `master` giữ nguyên như mpv gốc.
- Mỗi lần đẩy lên `aoe`: GitHub build và lưu bản thử ở mục Actions > artifact.
- Đăng phiên bản mới: `git tag aoe-v2 && git push origin aoe-v2`, workflow tự đăng Release kèm chứng nhận nguồn gốc.
- Cập nhật từ mpv gốc ([mpv-player/mpv](https://github.com/mpv-player/mpv)): `git remote add upstream https://github.com/mpv-player/mpv` (một lần), rồi trên nhánh `aoe` chạy `git fetch upstream && git merge upstream/master`, đẩy lên và gắn tag mới.

## Giấy phép

GPL v2 trở lên, như mpv (xem [LICENSE.GPL](LICENSE.GPL), [Copyright](Copyright)).
