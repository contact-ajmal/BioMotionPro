import { motion } from 'framer-motion'
import { Activity, Layers, Zap, BarChart3, ShieldCheck } from 'lucide-react'

const features = [
    {
        title: "Native Performance",
        description: "Built with Swift and Metal. Zero electron overhead. Blazing fast 3D rendering.",
        icon: Zap,
        className: "col-span-12 md:col-span-8 bg-gradient-to-br from-blue-500 to-indigo-600 text-white"
    },
    {
        title: "Smart Skeleton",
        description: "Auto-detects Plug-in Gait and Helen Hayes marker sets instantly.",
        icon: Activity,
        className: "col-span-12 md:col-span-4 bg-white border border-slate-200"
    },
    {
        title: "Side-by-Side Comparison",
        description: "Synchronized playback of two trials. Analyze kinematic differences in real-time.",
        icon: Layers,
        className: "col-span-12 md:col-span-4 bg-white border border-slate-200"
    },
    {
        title: "Advanced Data Plotting",
        description: "Interactive graphs for joint angles, forces, and moments. Export to CSV.",
        icon: BarChart3,
        className: "col-span-12 md:col-span-4 bg-white border border-slate-200"
    },
    {
        title: "Secure & Sandboxed",
        description: "Full macOS App Sandbox compliance. Your data stays safe and local.",
        icon: ShieldCheck,
        className: "col-span-12 md:col-span-4 bg-white border border-slate-200"
    },
]

export default function Features() {
    return (
        <section id="features" className="py-24 bg-slate-50">
            <div className="container mx-auto px-6">
                <div className="mb-16 text-center">
                    <h2 className="text-4xl font-bold text-slate-900 mb-4">
                        Professional Grade Analysis
                    </h2>
                    <p className="text-xl text-slate-600 max-w-2xl mx-auto">
                        Everything you need for clinical gait analysis and research, packaged in a beautiful native experience.
                    </p>
                </div>

                <div className="grid grid-cols-12 gap-6 max-w-6xl mx-auto">
                    {features.map((feature, i) => (
                        <motion.div
                            key={i}
                            initial={{ opacity: 0, y: 20 }}
                            whileInView={{ opacity: 1, y: 0 }}
                            viewport={{ once: true }}
                            transition={{ delay: i * 0.1 }}
                            className={`rounded-3xl p-8 shadow-sm hover:shadow-md transition-shadow ${feature.className}`}
                        >
                            <feature.icon className={`w-10 h-10 mb-6 ${feature.className.includes('text-white') ? 'text-white/90' : 'text-blue-600'}`} />
                            <h3 className={`text-2xl font-bold mb-3 ${feature.className.includes('text-white') ? 'text-white' : 'text-slate-900'}`}>
                                {feature.title}
                            </h3>
                            <p className={`text-lg leading-relaxed ${feature.className.includes('text-white') ? 'text-blue-100' : 'text-slate-600'}`}>
                                {feature.description}
                            </p>
                        </motion.div>
                    ))}
                </div>
            </div>
        </section>
    )
}
