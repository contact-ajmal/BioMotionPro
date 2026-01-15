import { motion } from 'framer-motion'
import { Download, Apple, Github, Terminal, HardDrive, Cpu, Monitor } from 'lucide-react'

const requirements = [
    { icon: Apple, label: 'macOS 13.0+', description: 'Ventura or later' },
    { icon: Cpu, label: 'Apple Silicon or Intel', description: 'Universal binary' },
    { icon: HardDrive, label: '100 MB', description: 'Disk space' },
    { icon: Monitor, label: 'Metal GPU', description: 'For 3D rendering' },
]

const steps = [
    'Download the DMG file from the button above.',
    'Open the DMG and drag BioMotionPro to Applications.',
    'Launch BioMotionPro from your Applications folder.',
    'Open a C3D or TRC file to start analyzing!',
]

export default function DownloadPage() {
    return (
        <div className="pt-24 pb-20 bg-slate-900 min-h-screen">
            <div className="container mx-auto px-6 max-w-4xl">
                {/* Header */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="text-center mb-12"
                >
                    <h1 className="text-5xl font-bold mb-4">
                        <span className="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500">Download</span>
                    </h1>
                    <p className="text-xl text-slate-400">
                        Get BioMotionPro for macOS. Free forever.
                    </p>
                </motion.div>

                {/* Download Card */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.1 }}
                    className="bg-slate-800/50 border border-slate-700/50 rounded-3xl p-8 md:p-12 mb-12"
                >
                    <div className="flex flex-col md:flex-row items-center justify-between gap-8">
                        <div className="flex items-center gap-6">
                            <div className="w-20 h-20 bg-gradient-to-br from-cyan-500 to-blue-600 rounded-2xl flex items-center justify-center shadow-xl shadow-cyan-500/20">
                                <span className="text-4xl font-bold text-white">B</span>
                            </div>
                            <div>
                                <h2 className="text-2xl font-bold text-white">BioMotionPro</h2>
                                <p className="text-slate-400">Version 1.0 • macOS</p>
                            </div>
                        </div>
                        <a
                            href="https://github.com/contact-ajmal/BioMotionPro/releases/download/v1.0/BioMotionPro.dmg"
                            className="w-full md:w-auto px-8 py-4 bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 rounded-xl font-bold text-lg flex items-center justify-center gap-3 transition-all hover:scale-105 shadow-lg shadow-cyan-500/25"
                        >
                            <Download className="w-5 h-5" />
                            Download DMG
                        </a>
                    </div>
                </motion.div>

                {/* Requirements */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.2 }}
                    className="mb-12"
                >
                    <h3 className="text-xl font-bold text-white mb-6">System Requirements</h3>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        {requirements.map((req, i) => (
                            <div key={i} className="p-4 rounded-xl bg-slate-800/50 border border-slate-700/50">
                                <req.icon className="w-6 h-6 text-cyan-400 mb-3" />
                                <p className="font-semibold text-white">{req.label}</p>
                                <p className="text-sm text-slate-400">{req.description}</p>
                            </div>
                        ))}
                    </div>
                </motion.div>

                {/* Installation Steps */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.3 }}
                    className="mb-12"
                >
                    <h3 className="text-xl font-bold text-white mb-6">Installation</h3>
                    <div className="space-y-4">
                        {steps.map((step, i) => (
                            <div key={i} className="flex items-start gap-4 p-4 rounded-xl bg-slate-800/30 border border-slate-700/30">
                                <div className="w-8 h-8 rounded-full bg-cyan-500/20 flex items-center justify-center flex-shrink-0">
                                    <span className="text-cyan-400 font-bold text-sm">{i + 1}</span>
                                </div>
                                <p className="text-slate-300 pt-1">{step}</p>
                            </div>
                        ))}
                    </div>
                </motion.div>

                {/* Build from Source */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.4 }}
                    className="p-8 rounded-2xl bg-slate-800/30 border border-slate-700/50"
                >
                    <div className="flex items-start gap-4">
                        <Terminal className="w-6 h-6 text-cyan-400 flex-shrink-0 mt-1" />
                        <div>
                            <h3 className="text-lg font-bold text-white mb-2">Build from Source</h3>
                            <p className="text-slate-400 mb-4">
                                Want to build from source or contribute? Clone the repository and build with Swift.
                            </p>
                            <div className="bg-slate-900 rounded-lg p-4 font-mono text-sm text-slate-300 overflow-x-auto">
                                <code>
                                    git clone https://github.com/contact-ajmal/BioMotionPro.git<br />
                                    cd BioMotionPro<br />
                                    swift build -c release
                                </code>
                            </div>
                            <a
                                href="https://github.com/contact-ajmal/BioMotionPro"
                                className="inline-flex items-center gap-2 mt-4 text-cyan-400 hover:text-cyan-300 font-medium transition-colors"
                            >
                                <Github className="w-4 h-4" />
                                View on GitHub
                            </a>
                        </div>
                    </div>
                </motion.div>
            </div>
        </div>
    )
}
