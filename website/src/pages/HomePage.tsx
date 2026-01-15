import Hero3D from '../components/Hero3D'
import Features from '../components/Features'
import { motion } from 'framer-motion'
import { ArrowRight, Download } from 'lucide-react'

export default function HomePage() {
    return (
        <div className="flex flex-col">
            {/* Hero Section */}
            <Hero3D />

            {/* Features Section */}
            <Features />

            {/* CTA / Download Section */}
            <section className="py-24 bg-slate-900 text-white relative overflow-hidden">
                <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-blue-900/40 via-transparent to-transparent"></div>
                <div className="container mx-auto px-6 max-w-4xl text-center relative z-10">
                    <motion.div
                        initial={{ opacity: 0, scale: 0.95 }}
                        whileInView={{ opacity: 1, scale: 1 }}
                        viewport={{ once: true }}
                        className="space-y-8"
                    >
                        <h2 className="text-4xl md:text-5xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-200 to-white">
                            Ready to Upgrade Your Analysis?
                        </h2>
                        <p className="text-xl text-slate-300 leading-relaxed">
                            Join thousands of biomechanists and researchers using BioMotionPro for their gait analysis and motion capture workflows.
                        </p>
                        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
                            <a href="https://github.com/contact-ajmal/BioMotionPro/releases"
                                className="px-8 py-4 bg-blue-600 hover:bg-blue-500 rounded-xl font-bold text-lg flex items-center gap-2 transition-all hover:scale-105 shadow-lg shadow-blue-500/25">
                                <Download className="w-5 h-5" />
                                Download for Mac
                            </a>
                            <a href="https://github.com/contact-ajmal/BioMotionPro"
                                className="px-8 py-4 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-xl font-bold text-lg flex items-center gap-2 transition-all hover:scale-105">
                                View Source Code
                                <ArrowRight className="w-5 h-5" />
                            </a>
                        </div>
                    </motion.div>
                </div>
            </section>
        </div>
    )
}
