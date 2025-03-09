
```shell
sudo apt install -y libx11-dev \
libxtst-dev libxkbcommon-dev libglib2.0-dev libpugixml-dev libgdk-pixbuf2.0-dev
sudo apt install -y libnotify-dev 
sudo apt install -y cmake build-essential ninja-build \
            xorg-dev libx11-dev libxtst-dev libssl-dev \
            libglib2.0-dev libgdk-pixbuf-2.0-dev libnotify-dev \
            libxkbfile-dev qt6-base-dev qt6-tools-dev \
            libgtk-3-dev libgtest-dev libgmock-dev libpugixml-dev \
            libei-dev libportal-dev libtomlplusplus-dev libcli11-dev
```

```shell
cmake -G Ninja -B build && cmake --build build --config Release
```



```shell
sudo apt install -y libsystemd-dev libevdev-dev

git clone https://gitlab.freedesktop.org/libei/libei.git
cd libei
sudo apt install meson
meson setup build
cd build
ninja
sudo ninja install
```


```shell
sudo apt install libevdev-dev libsystemd-dev -y
sudo apt install libxml2-utils pipx

pipx install jinja2
```

```shell
pip install jinja2 pytest
```

pkg-config --modversion libportal

```shell
# 检查当前安装的 libportal 版本
pkg-config --modversion libportal

# 如果版本过低或未安装，从源码构建最新版本
# 安装依赖项
sudo apt install -y gobject-introspection libgirepository1.0-dev

git clone https://github.com/flatpak/libportal.git
cd libportal
# 禁用不需要的组件以简化构建
meson setup build -Ddocs=false -Dtests=false -Dbackend-gtk3=disabled -Dbackend-gtk4=disabled -Dbackend-qt5=disabled
cd build
ninja
sudo ninja install

# 更新动态链接库缓存
sudo ldconfig
git clone git@github.com:flatpak/libportal.git
sudo apt install libvala-dev
sudo apt install -y valac
```