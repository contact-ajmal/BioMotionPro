import { useState } from 'react'
import { motion } from 'framer-motion'
import { ChevronRight, FileText, Terminal, Code, Settings, Activity, FileCode } from 'lucide-react'

const docsContent = [
    {
        id: 'intro',
        title: 'Introduction',
        icon: FileText,
        content: `
# Welcome to BioMotionPro

BioMotionPro is an **open-source, high-performance native macOS application** for visualizing and analyzing 3D motion capture data. It is designed for biomechanics researchers, sports scientists, physical therapists, and clinicians who need a fast, reliable tool for gait analysis and kinematics.

## Why BioMotionPro?

- **Native Performance**: Built with Swift and Metal for buttery-smooth 60fps+ visualization.
- **Open Source**: MIT licensed. Free to use, modify, and distribute.
- **Research-Ready**: Supports industry-standard C3D, TRC, and MOT file formats.
- **Extensible**: Run custom Python scripts for advanced analysis.

## Key Features

- 3D skeleton and marker visualization
- Side-by-side trial comparison
- Kinematics solver (joint angles)
- Interactive signal plots
- Annotation tools
- CSV export
    `
    },
    {
        id: 'getting-started',
        title: 'Getting Started',
        icon: Terminal,
        content: `
# Getting Started

## Installation

1. Download the latest \`.dmg\` from the [Releases page](https://github.com/contact-ajmal/BioMotionPro/releases).
2. Open the DMG and drag **BioMotionPro** to your Applications folder.
3. Double-click to launch.

> **Note**: On first launch, macOS may ask you to confirm opening the app from an unidentified developer. Go to System Settings → Privacy & Security and click "Open Anyway".

## Your First Analysis

1. Click **File → Open** or drag a \`.c3d\` or \`.trc\` file onto the window.
2. The 3D view will automatically load the marker data.
3. If a standard marker set is detected (e.g., Plug-in Gait), a skeleton will be auto-generated.
4. Use the timeline at the bottom to scrub through frames.
5. Enable **Signal Plots** from the View menu to see joint angles.

## Interface Overview

- **Left Sidebar**: Data browser showing loaded files and markers.
- **Center**: 3D visualization canvas.
- **Right Panel**: Data inspector with marker details.
- **Bottom**: Timeline and playback controls.
    `
    },
    {
        id: 'importing-data',
        title: 'Importing Data',
        icon: FileCode,
        content: `
# Importing Data

BioMotionPro supports multiple file formats commonly used in biomechanics research.

## Supported Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| C3D    | \`.c3d\`  | Industry standard for motion capture. Contains markers, analogs, and events. |
| TRC    | \`.trc\`  | OpenSim marker trajectory format. |
| MOT    | \`.mot\`, \`.sto\` | OpenSim motion/forces file. Ground reaction forces, moments. |

## Opening Files

- **Drag & Drop**: Drag files directly onto the app window.
- **File Menu**: Use File → Open to browse for files.
- **Recent Files**: Access recently opened files from File → Open Recent.

## Exporting Data

You can export processed data for use in other tools:

- **CSV Export**: Export marker positions and calculated angles to CSV format.
- **TRC Export**: Re-export processed markers back to TRC format.

Go to **File → Export** and choose your format.
    `
    },
    {
        id: 'kinematics',
        title: 'Kinematics Analysis',
        icon: Activity,
        content: `
# Kinematics Analysis

BioMotionPro includes a built-in kinematics solver that calculates joint angles from marker data.

## Supported Angles

The following angles are automatically calculated when the required markers are present:

| Joint | Angle | Required Markers |
|-------|-------|------------------|
| Knee  | Flexion/Extension | Hip, Knee, Ankle |
| Elbow | Flexion/Extension | Shoulder, Elbow, Wrist |

## Viewing Angles

1. Load a motion capture file with the required markers.
2. Open **View → Signal Plots** (or press \`Cmd+G\`).
3. Joint angles will appear as line graphs synchronized with the 3D view.

## Interpretation

- **Knee Flexion**: 180° = fully extended (straight leg), 90° = bent.
- **Elbow Flexion**: 180° = fully extended, lower values indicate flexion.

## Custom Angles

For custom joint angle calculations, use the **Python Scripting** feature to define your own analysis.
    `
    },
    {
        id: 'python',
        title: 'Python Scripting',
        icon: Code,
        content: `
# Python Scripting

Extend BioMotionPro with custom Python scripts for advanced analysis.

## How It Works

1. BioMotionPro exports the current motion data to a temporary CSV file.
2. Your Python script reads the input, processes it, and writes output.
3. BioMotionPro reimports the processed data.

## Script Interface

Your script receives two arguments:

\`\`\`bash
python your_script.py INPUT_CSV OUTPUT_CSV
\`\`\`

## Example Script

\`\`\`python
import pandas as pd
import sys

# Read input
input_file = sys.argv[1]
output_file = sys.argv[2]

df = pd.read_csv(input_file)

# Process data (example: smooth markers)
for col in df.columns:
    if col.endswith('_X') or col.endswith('_Y') or col.endswith('_Z'):
        df[col] = df[col].rolling(window=5, center=True).mean()

# Write output
df.to_csv(output_file, index=False)
\`\`\`

## Running Scripts

1. Go to **Analysis → Run Python Script**.
2. Select your \`.py\` file.
3. The processed data will replace the current capture.

## Requirements

- Python 3 must be installed on your system.
- Common paths checked: \`/usr/bin/python3\`, \`/opt/homebrew/bin/python3\`.
    `
    },
    {
        id: 'settings',
        title: 'Settings & Themes',
        icon: Settings,
        content: `
# Settings & Themes

Customize BioMotionPro to match your preferences.

## Theme

Switch between **Dark** and **Light** mode:

1. Go to **View → Theme**.
2. Select your preferred theme.

The app remembers your choice between sessions.

## Marker Styles

Customize how markers appear in the 3D view:

- **Size**: Adjust marker radius for visibility.
- **Color**: Set custom colors for specific markers or groups.
- **Labels**: Show or hide marker labels.

Access these options from **View → Marker Style Editor**.

## Skeleton Options

- **Show Skeleton**: Toggle skeleton bone rendering.
- **Bone Color**: Customize segment colors.
- **Auto-Connect**: Automatically connect markers based on naming conventions.

## Display Options

- **Grid Floor**: Toggle the reference grid in the 3D scene.
- **Coordinate Axes**: Show/hide XYZ axes indicator.
- **Background Color**: Customize the 3D canvas background.
    `
    },
]

export default function DocsPage() {
    const [activeTab, setActiveTab] = useState(docsContent[0].id)
    const activeDoc = docsContent.find(d => d.id === activeTab)

    return (
        <div className="pt-24 pb-20 bg-slate-900 min-h-screen">
            <div className="container mx-auto px-6 max-w-7xl">
                {/* Header */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="text-center mb-12"
                >
                    <h1 className="text-5xl font-bold mb-4">
                        <span className="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500">Documentation</span>
                    </h1>
                    <p className="text-xl text-slate-400">
                        Learn how to use BioMotionPro for your biomechanics analysis.
                    </p>
                </motion.div>

                <div className="flex flex-col md:flex-row gap-8">
                    {/* Sidebar */}
                    <aside className="w-full md:w-64 flex-shrink-0">
                        <div className="sticky top-24 space-y-1">
                            {docsContent.map((doc) => (
                                <button
                                    key={doc.id}
                                    onClick={() => setActiveTab(doc.id)}
                                    className={`w-full flex items-center justify-between px-4 py-3 rounded-xl text-sm font-medium transition-all ${activeTab === doc.id
                                        ? 'bg-cyan-500/10 text-cyan-400 border border-cyan-500/20'
                                        : 'text-slate-400 hover:bg-slate-800/50 hover:text-white'
                                        }`}
                                >
                                    <div className="flex items-center gap-3">
                                        <doc.icon className={`w-4 h-4 ${activeTab === doc.id ? 'text-cyan-400' : 'text-slate-500'}`} />
                                        {doc.title}
                                    </div>
                                    {activeTab === doc.id && <ChevronRight className="w-4 h-4" />}
                                </button>
                            ))}
                        </div>
                    </aside>

                    {/* Content */}
                    <main className="flex-1 min-w-0">
                        <motion.div
                            key={activeTab}
                            initial={{ opacity: 0, x: 20 }}
                            animate={{ opacity: 1, x: 0 }}
                            transition={{ duration: 0.3 }}
                            className="bg-slate-800/30 border border-slate-700/50 rounded-2xl p-8 md:p-10"
                        >
                            <div className="prose prose-invert prose-slate max-w-none prose-headings:font-bold prose-h1:text-3xl prose-h2:text-xl prose-h2:mt-8 prose-h2:mb-4 prose-p:text-slate-300 prose-li:text-slate-300 prose-a:text-cyan-400 prose-code:text-cyan-300 prose-code:bg-slate-900 prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-pre:bg-slate-900 prose-pre:border prose-pre:border-slate-700 prose-table:text-sm prose-th:text-slate-200 prose-td:text-slate-400">
                                {/* Simple markdown-like rendering */}
                                {activeDoc?.content.split('\n').map((line, i) => {
                                    const trimmed = line.trim()

                                    if (trimmed.startsWith('# ')) {
                                        return <h1 key={i} className="text-3xl font-bold mb-6 text-white">{trimmed.slice(2)}</h1>
                                    }
                                    if (trimmed.startsWith('## ')) {
                                        return <h2 key={i} className="text-xl font-bold mt-10 mb-4 text-white border-b border-slate-700 pb-2">{trimmed.slice(3)}</h2>
                                    }
                                    if (trimmed.startsWith('> ')) {
                                        return <blockquote key={i} className="border-l-4 border-cyan-500 pl-4 py-2 my-4 bg-cyan-500/5 text-slate-300 rounded-r">{trimmed.slice(2)}</blockquote>
                                    }
                                    if (trimmed.startsWith('- ')) {
                                        return <li key={i} className="text-slate-300 ml-4">{trimmed.slice(2)}</li>
                                    }
                                    if (trimmed.startsWith('|')) {
                                        // Skip table rows for simple render
                                        return null
                                    }
                                    if (trimmed.startsWith('```')) {
                                        return null
                                    }
                                    if (trimmed.includes('python') || trimmed.includes('import') || trimmed.includes('sys.argv') || trimmed.includes('df[')) {
                                        return <code key={i} className="block bg-slate-900 border border-slate-700 text-cyan-300 p-1 rounded my-0.5 font-mono text-sm">{line}</code>
                                    }
                                    if (/^\d+\./.test(trimmed)) {
                                        return <li key={i} className="text-slate-300 ml-4 list-decimal">{trimmed.replace(/^\d+\.\s*/, '')}</li>
                                    }
                                    if (trimmed === '') return <br key={i} />

                                    // Handle inline formatting
                                    const formatted = trimmed
                                        .replace(/\*\*(.*?)\*\*/g, '<strong class="text-white">$1</strong>')
                                        .replace(/`([^`]+)`/g, '<code class="text-cyan-300 bg-slate-900 px-1.5 py-0.5 rounded text-sm">$1</code>')
                                        .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" class="text-cyan-400 hover:underline">$1</a>')

                                    return <p key={i} className="text-slate-300 my-2 leading-relaxed" dangerouslySetInnerHTML={{ __html: formatted }} />
                                })}
                            </div>
                        </motion.div>
                    </main>
                </div>
            </div>
        </div>
    )
}
