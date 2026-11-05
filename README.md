# Unofficial Linux Kernel Module for Acer Gaming RGB Keyboard Backlight and Turbo Mode (Acer Predator , Nitro)
> **This fork adds support for the Acer Nitro V16S (ANV16S-71)** on top of upstream [0x7375646F/Linuwu-Sense](https://github.com/0x7375646F/Linuwu-Sense). See [Supported Models](#-supported-models).

The code base is still in its early stages, as I’ve just started working on developing this kernel module. It's a bit messy at the moment, but I’m hopeful that, with your help, we can collaborate to improve its structure and make it more organized over time.

Inspired by [acer-predator-turbo](https://github.com/JafarAkhondali/acer-predator-turbo-and-rgb-keyboard-linux-module), which has a similar goal, this project was born out of my own challenges. I faced issues detecting the Turbo key and ended up using [acer_wmi](https://github.com/torvalds/linux/blob/master/drivers/platform/x86/acer-wmi.c), but it lacked key features like RGB , custom fan support, battery limiter, and more. As a result, I decided to implement these missing features in my own project.

## 🚀 Installation
To begin, identify your current kernel version:
```bash
uname -r
```

Install the appropriate Linux headers based on your kernel version. The module handles both the old and new platform-profile APIs, so kernel 6.12 and newer are supported; it has been verified on Debian 13 with kernel 6.12.115 on an ANV16S-71.
For Arch Linux:
```bash
sudo pacman -S linux-headers
```
For Debian / Ubuntu:
```bash
sudo apt install linux-headers-$(uname -r)
```
Next, clone the repository and build the module (the ANV16S-71 support lives on the `nitro-anv16s-71` branch):
```bash
git clone https://github.com/neryaAthlan/Div-Linuwu-Sense.git
cd Div-Linuwu-Sense
git checkout nitro-anv16s-71
make install
```
The make command will remove the current acer_wmi module and load the patched version.

To Uninstall:
```bash
make uninstall
```
> **⚠️ Warning!**
> ## Use at your own risk! This driver is independently developed through reverse engineering the official PredatorSense app, without any involvement from Acer. It interacts with low-level WMI methods, which may not be tested across all models.

## 💻 Supported Models
Model support is selected by a DMI match in `acer_quirks[]` inside `src/linuwu_sense.c`. Laptops without a matching entry fall back to the generic Nitro/Predator quirks.

### Acer Nitro V16S (ANV16S-71)
The **ANV16S-71** uses the `nitro_v4` and `four_zone_kb` quirks, the same combination as the Nitro AN16-41, AN16-43 and AN517-54. Because the `nitro_v4` quirk is used, the driver creates the **`nitro_sense`** directory (NitroSense v4 layout) instead of `predator_sense`, and it exposes the full feature set normally reserved for Predator laptops.

| Feature | Status on ANV16S-71 (verified) |
| --- | --- |
| Thermal (platform) profiles | ✅ Works. The firmware reports all five: `low-power`, `quiet`, `balanced`, `balanced-performance`, `performance` (Turbo, the max). Reading and switching profiles works; `quiet`, `balanced-performance` and `performance` are rejected while running on battery, matching PredatorSense. |
| `nitro_sense/fan_speed` | ✅ Read/write. Fan RPM is also exposed through `hwmon` (`fan1_input`, `fan2_input`). |
| `nitro_sense/battery_limiter` | ✅ Read/write. |
| `nitro_sense/battery_calibration` | ✅ Reads correctly. Not exercised, since starting a calibration drains the battery. |
| `nitro_sense/usb_charging` | ✅ Read/write. |
| `nitro_sense/backlight_timeout` | ✅ Read/write (root only). |
| `nitro_sense/boot_animation_sound` | ✅ Read/write (root only). |
| `nitro_sense/lcd_override` | ⚠️ Writable, but the state read-back reports `-1` (unrecognized) on this model. |
| Four-zone keyboard RGB | ✅ `four_zoned_kb/four_zone_mode` and `four_zoned_kb/per_zone_mode` both read/write, and the state is restored on reload/reboot. |
| Per-key RGB | ❌ Not supported (the keyboard is four-zone). |

To verify the module picked up your model:
```bash
cat /sys/class/dmi/id/product_name   # should print: Nitro ANV16S-71
sudo dmesg | grep -i -e "Detected model type" -e "Linuwu-Sense" -e "thermal profiles"
ls /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/
```
The directory listing should contain `nitro_sense` and `four_zoned_kb`, and the log should show `Detected model type: Nitro ANV16S-71` followed by the five detected profiles.

On this model, `make install` grants group write access (via `/etc/tmpfiles.d/linuwu_sense.conf`) to `fan_speed`, `battery_limiter`, `battery_calibration` and `usb_charging`; `backlight_timeout`, `boot_animation_sound` and `lcd_override` are writable by root only, so use `sudo` for those.

> **Upgrading from an older build?** If you previously forced this laptop to work with `options linuwu_sense enable_all=1` or `options linuwu_sense nitro_v4=1` in `/etc/modprobe.d/`, remove those options. They bypass the DMI table entirely (`find_quirks()` returns before matching the model), so the ANV16S-71 entry is never used and the profiles get force-enabled instead of read from the firmware. The model is now detected on its own:
> ```bash
> sudo rm -f /etc/modprobe.d/linuwu_sense.conf /etc/modprobe.d/linuwu-sense.conf
> sudo modprobe -r linuwu_sense && sudo modprobe linuwu_sense
> ```

> **Note:** Every example below is written with the `predator_sense` path. On the ANV16S-71 (and other Nitro models using `nitro_v4`), replace `predator_sense` with `nitro_sense` in those paths, for example:
> ```bash
> echo 1 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/nitro_sense/battery_limiter
> echo 50,70 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/nitro_sense/fan_speed
> ```

## 🛠️ Usage
# Example Usage and Configuration

Thermal profiles can be easily switched with a single click! 😎 For battery mode, you can choose between Eco and Balanced, while when plugged into AC, you have the options for Quiet, Balanced, Performance, and Turbo. ⚡💻 Each profile will be different for battery and AC, and the thermal and fan settings will automatically adjust based on your current power source. Customize it to fit your preferences! 🌟

---

For **Predator** laptops, the following path is used: `/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense`

For **Nitro** laptops, the following path is used: `/sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/nitro_sense`

predator_sense – This directory includes all the features, excluding the custom boot logo functionality.
four_zoned_kb – If your keyboard is four-zoned, this directory provides support for it. Unfortunately, there is no support for per-key RGB keyboards.
Here is how to interact with the Virtual Filesystems (VFS) mounted in this path:

### **0. Thermal Profiles (Nitro users especially who don't have switch key) 🚀**

Some acer nitro laptops don't come up with the thermal profile switch button in this case we manually need to set it:

To probe the current thermal profile:

`cat /sys/firmware/acpi/platform_profile`

To check the supported thermal profile:

`cat /sys/firmware/acpi/platform_profile_choices`

To switch the platform profile:

`echo balanced | sudo tee /sys/firmware/acpi/platform_profile`

Replace the balanced with the supported profile you have.

#### **1. Backlight Timeout ⏰**

This feature turns off the keyboard RGB after 30 seconds of idle mode.

- **0** – Disabled
- **1** – Enabled

To check the current status, use:

`cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/backlight_timeout`

To change the state, use:

`echo 1 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/backlight_timeout`

---

#### **2. Battery Calibration 🔋**

This function calibrates your battery to provide a more accurate percentage reading. It involves charging the battery to 100%, draining it to 0%, and recharging it back to 100%. **Do not unplug the laptop from AC power during calibration.**

- **1** – Start calibration
- **0** – Stop calibration

To check the current status:

`cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/battery_calibration`

To change the state:

`echo 1 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/battery_calibration`

---

#### **3. Battery Limiter ⚡**

Limits battery charging to 80%, preserving battery health for laptops primarily used while plugged into AC power.

- **1** – Enabled
- **0** – Disabled

To check the current status:

`cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/battery_limiter`

To change the state:

`echo 1 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/battery_limiter`

---

#### **4. Boot Animation Sound 🎶**

Enables or disables custom boot animation and sound.

- **1** – Enabled
- **0** – Disabled

To check the current status:

`cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/boot_animation_sound`

To change the state:

`echo 0 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/boot_animation_sound`

---

#### **5. Fan Speed  🌬️**

Controls the CPU and GPU fan speeds.

- **0** – Auto
- **1** – Minimum fan speed (not recommended)
- **100** – Maximum fan speed
- Other values like **50, 55, 70** can be set according to your preference.

Example (set CPU to 50 and GPU to 70):

`echo 50,70 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/fan_speed`

---

#### **6. LCD Override 🖥️**

Reduces LCD latency and minimizes ghosting.

- **1** – Enabled
- **0** – Disabled

To check the current status:

`cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/lcd_override`

To change the state:

`echo 1 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/lcd_override`

---

#### **7. USB Charging ⚡**

Allows the USB charging port to provide power even when the laptop is off.

- **0** – Disabled
- **10** – Provides power until battery reaches 10%
- **20** – Provides power until battery reaches 20%
- **30** – Provides power until battery reaches 30%

To check the current status:

`cat /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/usb_charging`

To change the state:

`echo 20 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/predator_sense/usb_charging`

---
## 💻 Keyboard Configuration 
### **Directory: `four_zoned_kb`**

The `four_zoned_kb` directory contains two Virtual File Systems (VFS) that control the RGB backlight behavior of the four-zone keyboard:

1. **`four_zone_mode`**
2. **`per_zone_mode`**

#### **1. Per-Zone Mode (`per_zone_mode`) 🎨**

This mode allows you to set a specific RGB color for each of the four keyboard zones individually. Each zone is represented by an RGB value in hexadecimal format (e.g., `4287f5` where `42` is Red, `87` is Green, and `f5` is Blue).

- **Parameters:**
    
    - The `per_zone_mode` file accepts four parameters, one for each zone, separated by commas.
    - The `per_zone_mode` also accepts brightness value.
    - Each parameter represents the RGB value for a specific zone in the format `RRGGBB`.
- **Example:**

To set all four zones to the same color (`4287f5`) and brightness to full:

`echo 4287f5,4287f5,4287f5,4287f5,100 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb/per_zone_mode`

To set each zone with unique colors:

`echo 4287f5,ff5733,33ff57,ff33a6,100 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb/per_zone_mode`

When reading (`cat`) the `per_zone_mode` file, the current color values for each zone are displayed in the format:

`4287f5,4287f5,4287f5,4287f5,100`

This indicates the current RGB color for each of the four zones.

### **Four-Zone Mode (`four_zone_mode`) ✨**

The `four_zone_mode` controls advanced RGB effects for your keyboard, requiring seven parameters:

- **Parameters:**
    
    - **Mode (0-7):** Lighting effect type (e.g., static, breathing, wave).
    - **Speed (0-9):** Speed of the effect (if applicable).
    - **Brightness (0-100):** Intensity of the lighting effect.
    - **Direction (1-2):** Direction of the effect (1 = right to left, 2 = left to right).
    - **Red (0-255), Green (0-255), Blue (0-255):** RGB color values.
- **Modes:**
    
    - **0:** Static Mode – Fixed color, no animation.
    - **1:** Breathing Mode – Color fades in and out.
    - **2:** Neon Mode – Neon glow effect, fixed color (black), direction ignored.
    - **3:** Wave Mode – Wave-like effect, color transitions across the keyboard.
    - **4:** Shifting Mode – Shifting light effect, full control over speed, direction, and color.
    - **5:** Zoom Mode – Zoom effect, direction ignored.
    - **6:** Meteor Mode – Meteor-like effect, direction ignored.
    - **7:** Twinkling Mode – Twinkling light effect, direction ignored.
- **Example Command:**
    
    Set to **Neon Mode** with speed 1, full brightness, and top-to-bottom direction:
    
    `echo 3,1,100,2,0,0,0 | sudo tee /sys/module/linuwu_sense/drivers/platform:acer-wmi/acer-wmi/four_zoned_kb/four_zone_mode`
    
    **Explanation:**
    
    - `3`: Neon Mode
    - `1`: Speed (1)
    - `100`: Full brightness
    - `2`: Direction (top to bottom)
    - `0`: Red (black for Neon)
    - `0`: Green (black for Neon)
    - `0`: Blue (black for Neon)
 
The thermal and fan profiles will be saved and loaded on each reboot, ensuring that the settings remain persistent across restarts.
## GUI:
- [Div Acer Manager Max By PXDiv](https://github.com/PXDiv/Div-Acer-Manager-Max)

## License
GNU General Public License v3

