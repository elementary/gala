# xrdesktop

A library for XR interaction with traditional desktop compositors.

## Installation

Add the [xrdesktop PPA](https://launchpad.net/~xrdesktop/+archive/ubuntu/xrdesktop/+packages):

```bash
sudo add-apt-repository ppa:xrdesktop/xrdesktop
sudo apt update
```

Then install the xrdesktop package:

```bash
sudo apt install xrdesktop libsdl2-2.0-0
```

### gxr backend (mandatory)

xrdesktop can run on Valve's SteamVR via the OpenVR API as well as any OpenXR runtime (specifically tested is the "Monado" runtime) via the OpenXR API. This support is implemented as backend libraries for gxr.

To run xrdesktop on OpenVR/SteamVR, install the OpenVR backend:

```bash
sudo apt install libgxr-openvr-0.15-0
```

Running xrdesktop on OpenXR/Monado is supported without additional packages. The OpenXR backend is already included in the libgxr-0.15 (or newer) package. Read the [xrdesktop wiki about openxr](https://gitlab.freedesktop.org/xrdesktop/xrdesktop/-/wikis/openxr) for more information.

## Running

1. Start SteamVR
2. Enable `Mirror to XR` in Wingpanel (To be done).

## Further reading

See the corresponding project repositories for more information and in depth documentation:

- [xrdesktop](https://gitlab.freedesktop.org/xrdesktop/xrdesktop) - A library for XR interaction with traditional desktop compositors
- [Monado](https://gitlab.freedesktop.org/monado/monado) - The open source OpenXR runtime