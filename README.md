<div align="center">

<img src="assets/hero-skeleton.png" alt="BioMotionPro" width="600"/>

# BioMotionPro

### Open-Source Biomechanics Analysis for macOS

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B-lightgrey.svg)](https://github.com/contact-ajmal/BioMotionPro/releases)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Metal](https://img.shields.io/badge/Graphics-Metal-red.svg)](https://developer.apple.com/metal/)

[Download](https://github.com/contact-ajmal/BioMotionPro/releases) •
[Features](#features) •
[Installation](#installation) •
[Documentation](#documentation) •
[Contributing](#contributing)

</div>

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 🦴 3D Visualization
Real-time Metal-powered rendering of skeletal models and markers at 60fps+. Customizable camera controls and multiple viewing modes.

### 📊 Kinematics Solver
Automatic calculation of joint angles including Knee Flexion, Elbow Flexion, and more based on standard biomechanical definitions.

### 📁 File Format Support
- **C3D** - Industry standard motion capture
- **TRC** - OpenSim marker trajectories  
- **MOT** - Forces and moments data

</td>
<td width="50%">

### 🔬 Side-by-Side Comparison
Compare two motion captures simultaneously with synchronized playback. Perfect for pre/post analysis.

### 🐍 Python Scripting
Extend functionality with custom Python scripts. Access marker data via a simple API.

### 🎨 Customization
- Dark/Light themes
- Marker style editor
- Skeleton designer
- Annotation tools

</td>
</tr>
</table>

---

## 🚀 Installation

### Download Pre-built App

1. Download the latest `.dmg` from [Releases](https://github.com/contact-ajmal/BioMotionPro/releases)
2. Open the DMG and drag **BioMotionPro** to Applications
3. Launch and start analyzing!

### Build from Source

```bash
git clone https://github.com/contact-ajmal/BioMotionPro.git
cd BioMotionPro
swift build -c release
```

### System Requirements

| Requirement | Minimum |
|-------------|---------|
| macOS | 13.0 (Ventura) |
| Architecture | Apple Silicon or Intel |
| GPU | Metal-compatible |
| Disk Space | ~100 MB |

---

## 📖 Documentation

| Topic | Description |
|-------|-------------|
| [Getting Started](https://contact-ajmal.github.io/BioMotionPro/) | Installation and first analysis |
| [Importing Data](https://contact-ajmal.github.io/BioMotionPro/) | C3D, TRC, MOT file formats |
| [Kinematics](https://contact-ajmal.github.io/BioMotionPro/) | Joint angle calculations |
| [Python Scripting](https://contact-ajmal.github.io/BioMotionPro/) | Custom analysis workflows |

---

## 🛠️ Tech Stack

- **Language**: Swift 5.9
- **Graphics**: Metal + MetalKit
- **UI**: SwiftUI
- **File Parsing**: Custom C3D, TRC, MOT parsers
- **Scripting**: Python integration via Process

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with ❤️ for the Biomechanics Community**

[⬆ Back to top](#biomotionpro)

</div>
