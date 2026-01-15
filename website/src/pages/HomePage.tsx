import Hero3D from '../components/Hero3D'
import { motion } from 'framer-motion'
import { ArrowRight, Zap, Activity, FileCode, Code2, Layers, Download } from 'lucide-react'
import type { PageType } from '../App'

interface HomePageProps {
    onNavigate: (page: PageType) => void
}

const highlights = [
    {
        icon: Activity,
        title: '3D Visualization',
        description: 'Real-time Metal-powered skeleton and marker rendering at 60fps+.',
    },
    {
        icon: Zap,
        title: 'Kinematics Analysis',
        description: 'Calculate joint angles (Knee, Elbow, Hip) with biomechanical accuracy.',
    },
    {
        icon: FileCode,
        title: 'Open File Formats',
        description: 'Native support for C3D, TRC, and MOT files used in research and clinical settings.',
    },
    {
        icon: Code2,
        title: 'Python Scripting',
        description: 'Extend with custom Python scripts for advanced analysis workflows.',
    },
]

export default function HomePage({ onNavigate }: HomePageProps) {
    return (
        <div className="flex flex-col">
            {/* Hero Section - Dark Mode */}
            <section className="relative min-h-screen w-full flex items-center bg-slate-900 overflow-hidden pt-20">
                {/* Gradient Background */}
                <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-cyan-900/30 via-slate-900 to-slate-900" />

                {/* Grid Pattern */}
                <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PGRlZnM+PHBhdHRlcm4gaWQ9ImdyaWQiIHdpZHRoPSI0MCIgaGVpZ2h0PSI0MCIgcGF0dGVyblVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+PHBhdGggZD0iTSAwIDEwIEwgNDAgMTAgTSAxMCAwIEwgMTAgNDAgTSAwIDIwIEwgNDAgMjAgTSAyMCAwIEwgMjAgNDAgTSAwIDMwIEwgNDAgMzAgTSAzMCAwIEwgMzAgNDAiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzFmMjkzNyIgb3BhY2l0eT0iMC4zIiBzdHJva2Utd2lkdGg9IjEiLz48L3BhdHRlcm4+PC9kZWZzPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InVybCgjZ3JpZCkiLz48L3N2Zz4=')] opacity-40" />

                {/* 3D Scene */}
                <div className="absolute right-0 top-0 w-full h-full lg:w-3/5 opacity-60 lg:opacity-100">
                    <Hero3D />
                </div>

                {/* Content */}
                <div className="container mx-auto px-6 max-w-7xl relative z-10">
                    <div className="max-w-2xl">
                        <motion.div
                            initial={{ opacity: 0, y: 30 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ duration: 0.8 }}
                        >
                            <span className="inline-flex items-center gap-2 py-1.5 px-4 rounded-full bg-cyan-500/10 border border-cyan-500/20 text-cyan-400 text-sm font-medium mb-8">
                                <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
                                Open Source • MIT License
                            </span>

                            <h1 className="text-5xl md:text-6xl lg:text-7xl font-bold tracking-tight mb-6 leading-[1.1]">
                                Biomechanics Analysis.{' '}
                                <span className="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500">
                                    Free for Everyone.
                                </span>
                            </h1>

                            <p className="text-xl text-slate-400 mb-10 leading-relaxed max-w-lg">
                                Medical-grade precision. Native macOS performance.
                                Visualize, compare, and analyze motion capture data like never before.
                            </p>

                            <div className="flex flex-col sm:flex-row gap-4">
                                <button
                                    onClick={() => onNavigate('download')}
                                    className="group px-8 py-4 bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-white rounded-xl font-semibold shadow-lg shadow-cyan-500/25 transition-all hover:scale-105 flex items-center justify-center gap-3"
                                >
                                    <Download className="w-5 h-5" />
                                    Download for Mac
                                    <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                                </button>
                                <button
                                    onClick={() => onNavigate('features')}
                                    className="px-8 py-4 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-white rounded-xl font-semibold transition-all hover:scale-105 flex items-center justify-center gap-2"
                                >
                                    <Layers className="w-5 h-5" />
                                    Explore Features
                                </button>
                            </div>
                        </motion.div>
                    </div>
                </div>
            </section>

            {/* Feature Highlights */}
            <section className="py-24 bg-slate-950">
                <div className="container mx-auto px-6 max-w-7xl">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        className="text-center mb-16"
                    >
                        <h2 className="text-4xl font-bold mb-4">
                            Professional Grade. <span className="text-cyan-400">Zero Cost.</span>
                        </h2>
                        <p className="text-xl text-slate-400 max-w-2xl mx-auto">
                            Everything you need for clinical gait analysis and research, packaged in a beautiful native macOS experience.
                        </p>
                    </motion.div>

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                        {highlights.map((item, i) => (
                            <motion.div
                                key={i}
                                initial={{ opacity: 0, y: 20 }}
                                whileInView={{ opacity: 1, y: 0 }}
                                viewport={{ once: true }}
                                transition={{ delay: i * 0.1 }}
                                className="group p-6 rounded-2xl bg-slate-900 border border-slate-800 hover:border-cyan-500/30 transition-all hover:shadow-lg hover:shadow-cyan-500/5"
                            >
                                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cyan-500/20 to-blue-500/20 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                                    <item.icon className="w-6 h-6 text-cyan-400" />
                                </div>
                                <h3 className="text-lg font-bold mb-2 text-white">{item.title}</h3>
                                <p className="text-slate-400 text-sm leading-relaxed">{item.description}</p>
                            </motion.div>
                        ))}
                    </div>

                    <div className="mt-12 text-center">
                        <button
                            onClick={() => onNavigate('features')}
                            className="text-cyan-400 hover:text-cyan-300 font-medium flex items-center gap-2 mx-auto transition-colors"
                        >
                            View all features
                            <ArrowRight className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            </section>

            {/* CTA Section */}
            <section className="py-24 bg-slate-900 relative overflow-hidden">
                <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-cyan-900/20 via-transparent to-transparent" />
                <div className="container mx-auto px-6 max-w-3xl text-center relative z-10">
                    <motion.div
                        initial={{ opacity: 0, scale: 0.95 }}
                        whileInView={{ opacity: 1, scale: 1 }}
                        viewport={{ once: true }}
                    >
                        <h2 className="text-4xl md:text-5xl font-bold mb-6">
                            Ready to Upgrade Your Analysis?
                        </h2>
                        <p className="text-xl text-slate-400 mb-10">
                            Join biomechanists and researchers using BioMotionPro for gait analysis. It's free, open-source, and built with precision.
                        </p>
                        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                            <button
                                onClick={() => onNavigate('download')}
                                className="px-8 py-4 bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 rounded-xl font-bold text-lg flex items-center gap-2 transition-all hover:scale-105 shadow-lg shadow-cyan-500/25"
                            >
                                <Download className="w-5 h-5" />
                                Download Now
                            </button>
                            <a
                                href="https://github.com/contact-ajmal/BioMotionPro"
                                className="px-8 py-4 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-xl font-bold text-lg flex items-center gap-2 transition-all hover:scale-105"
                            >
                                View on GitHub
                                <ArrowRight className="w-5 h-5" />
                            </a>
                        </div>
                    </motion.div>
                </div>
            </section>
        </div>
    )
}
