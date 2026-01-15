import { motion } from 'framer-motion'
import {
    Activity, Layers, Zap, BarChart3, FileCode, Code2,
    GitCompare, PenTool, Download, Palette, Settings, Terminal
} from 'lucide-react'

const features = [
    {
        icon: Activity,
        title: '3D Skeleton Visualization',
        description: 'Real-time Metal-powered rendering of skeletal models and marker data. Smooth 60fps+ performance with customizable camera controls.',
        category: 'Visualization',
    },
    {
        icon: GitCompare,
        title: 'Side-by-Side Comparison',
        description: 'Compare two motion captures simultaneously with synchronized playback. Ideal for pre/post analysis or multi-subject studies.',
        category: 'Visualization',
    },
    {
        icon: BarChart3,
        title: 'Signal Plots',
        description: 'Interactive 2D graphs for joint angles, forces, and analog signals. Real-time updates as you scrub through the timeline.',
        category: 'Analysis',
    },
    {
        icon: Zap,
        title: 'Kinematics Solver',
        description: 'Automatic calculation of joint angles including Knee Flexion, Elbow Flexion, and more. Based on standard biomechanical definitions.',
        category: 'Analysis',
    },
    {
        icon: FileCode,
        title: 'C3D File Support',
        description: 'Full support for industry-standard C3D files. Import marker trajectories, analog data, and events with high fidelity.',
        category: 'Data I/O',
    },
    {
        icon: Layers,
        title: 'TRC & MOT Support',
        description: 'Native parsing for OpenSim-compatible TRC (marker) and MOT (forces/moments) files. Export your processed data back to these formats.',
        category: 'Data I/O',
    },
    {
        icon: Download,
        title: 'CSV Export',
        description: 'Export marker positions and calculated angles to CSV for further analysis in Python, MATLAB, or spreadsheet software.',
        category: 'Data I/O',
    },
    {
        icon: Code2,
        title: 'Python Scripting',
        description: 'Run custom Python scripts directly from the app. Access marker data via a simple API and return processed results.',
        category: 'Extensibility',
    },
    {
        icon: PenTool,
        title: 'Annotation Tools',
        description: 'Draw lines, angles, and notes directly on the 3D scene. Perfect for presentations, reports, and clinical documentation.',
        category: 'Tools',
    },
    {
        icon: Palette,
        title: 'Theme Customization',
        description: 'Dark and light mode support. Customize marker colors, skeleton styles, and background to match your preferences.',
        category: 'UI',
    },
    {
        icon: Settings,
        title: 'Skeleton Designer',
        description: 'Define custom skeleton models with your own bone connections. Auto-detection for Plug-in Gait and Helen Hayes marker sets.',
        category: 'Tools',
    },
    {
        icon: Terminal,
        title: 'Timeline & Playback',
        description: 'Frame-by-frame scrubbing with play/pause controls. Loop regions of interest for detailed analysis.',
        category: 'UI',
    },
]

export default function FeaturesPage() {
    return (
        <div className="pt-24 pb-20 bg-slate-900 min-h-screen">
            <div className="container mx-auto px-6 max-w-7xl">
                {/* Header */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="text-center mb-16"
                >
                    <h1 className="text-5xl font-bold mb-4">
                        <span className="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500">Features</span>
                    </h1>
                    <p className="text-xl text-slate-400 max-w-2xl mx-auto">
                        Everything you need for professional biomechanics analysis, built natively for macOS.
                    </p>
                </motion.div>

                {/* Feature Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {features.map((feature, i) => (
                        <motion.div
                            key={i}
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: i * 0.05 }}
                            className="group p-6 rounded-2xl bg-slate-800/50 border border-slate-700/50 hover:border-cyan-500/30 transition-all hover:bg-slate-800"
                        >
                            <div className="flex items-start gap-4">
                                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center flex-shrink-0 group-hover:scale-110 transition-transform">
                                    <feature.icon className="w-6 h-6 text-cyan-400" />
                                </div>
                                <div>
                                    <span className="text-xs font-medium text-slate-500 uppercase tracking-wider">{feature.category}</span>
                                    <h3 className="text-lg font-bold text-white mt-1 mb-2">{feature.title}</h3>
                                    <p className="text-slate-400 text-sm leading-relaxed">{feature.description}</p>
                                </div>
                            </div>
                        </motion.div>
                    ))}
                </div>

                {/* Open Source Banner */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    className="mt-20 p-8 md:p-12 rounded-3xl bg-gradient-to-br from-cyan-900/30 to-blue-900/30 border border-cyan-500/20 text-center"
                >
                    <h2 className="text-3xl font-bold mb-4">100% Open Source</h2>
                    <p className="text-slate-300 max-w-2xl mx-auto mb-6">
                        BioMotionPro is released under the MIT License. View the source code, contribute features, or fork it for your own research needs.
                    </p>
                    <a
                        href="https://github.com/contact-ajmal/BioMotionPro"
                        className="inline-flex items-center gap-2 px-6 py-3 bg-white text-slate-900 rounded-xl font-semibold hover:bg-slate-100 transition-colors"
                    >
                        <Code2 className="w-5 h-5" />
                        View on GitHub
                    </a>
                </motion.div>
            </div>
        </div>
    )
}
