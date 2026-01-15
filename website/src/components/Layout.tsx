import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Menu, X, Github, Download, BookOpen, Sparkles, Home } from 'lucide-react'
import type { PageType } from '../App'
import type { LucideIcon } from 'lucide-react'

interface LayoutProps {
    children: React.ReactNode
    currentPage: PageType
    onNavigate: (page: PageType) => void
}

interface NavLink {
    page: PageType
    label: string
    icon: LucideIcon
}

const navLinks: NavLink[] = [
    { page: 'home', label: 'Home', icon: Home },
    { page: 'features', label: 'Features', icon: Sparkles },
    { page: 'docs', label: 'Docs', icon: BookOpen },
    { page: 'download', label: 'Download', icon: Download },
]

export default function Layout({ children, currentPage, onNavigate }: LayoutProps) {
    const [isScrolled, setIsScrolled] = useState(false)
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

    useEffect(() => {
        const handleScroll = () => setIsScrolled(window.scrollY > 20)
        window.addEventListener('scroll', handleScroll)
        return () => window.removeEventListener('scroll', handleScroll)
    }, [])

    return (
        <div className="min-h-screen bg-slate-900 text-white relative flex flex-col">
            {/* Navigation */}
            <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${isScrolled ? 'bg-slate-900/95 backdrop-blur-md border-b border-slate-800 py-3' : 'bg-transparent py-5'
                }`}>
                <div className="container mx-auto px-6 max-w-7xl flex items-center justify-between">

                    {/* Logo */}
                    <div
                        className="flex items-center gap-3 cursor-pointer group"
                        onClick={() => onNavigate('home')}
                    >
                        <div className="w-10 h-10 bg-gradient-to-br from-cyan-400 to-blue-600 rounded-xl flex items-center justify-center text-white font-bold text-xl shadow-lg shadow-cyan-500/20 group-hover:scale-105 transition-transform">
                            B
                        </div>
                        <span className="text-xl font-bold tracking-tight">
                            BioMotion<span className="text-cyan-400">Pro</span>
                        </span>
                    </div>

                    {/* Desktop Menu */}
                    <div className="hidden md:flex items-center gap-1">
                        {navLinks.map(({ page, label, icon: Icon }) => (
                            <button
                                key={page}
                                onClick={() => onNavigate(page)}
                                className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all ${currentPage === page
                                    ? 'bg-slate-800 text-cyan-400'
                                    : 'text-slate-300 hover:text-white hover:bg-slate-800/50'
                                    }`}
                            >
                                <Icon className="w-4 h-4" />
                                {label}
                            </button>
                        ))}
                        <div className="w-px h-6 bg-slate-700 mx-2" />
                        <a
                            href="https://github.com/contact-ajmal/BioMotionPro"
                            target="_blank"
                            rel="noreferrer"
                            className="p-2 text-slate-400 hover:text-white transition-colors"
                        >
                            <Github className="w-5 h-5" />
                        </a>
                    </div>

                    {/* Mobile Toggle */}
                    <button
                        onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                        className="md:hidden p-2 text-slate-300 hover:text-white"
                    >
                        {mobileMenuOpen ? <X /> : <Menu />}
                    </button>
                </div>
            </nav>

            {/* Mobile Menu */}
            <AnimatePresence>
                {mobileMenuOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: -20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        className="fixed inset-0 z-40 bg-slate-900 pt-24 px-6 md:hidden"
                    >
                        <div className="flex flex-col gap-2">
                            {navLinks.map(({ page, label, icon: Icon }) => (
                                <button
                                    key={page}
                                    onClick={() => { onNavigate(page); setMobileMenuOpen(false) }}
                                    className={`flex items-center gap-3 px-4 py-4 rounded-xl text-lg font-medium transition-all ${currentPage === page
                                        ? 'bg-slate-800 text-cyan-400'
                                        : 'text-slate-300 hover:bg-slate-800/50'
                                        }`}
                                >
                                    <Icon className="w-5 h-5" />
                                    {label}
                                </button>
                            ))}
                            <a
                                href="https://github.com/contact-ajmal/BioMotionPro"
                                className="flex items-center gap-3 px-4 py-4 rounded-xl text-lg font-medium text-slate-300 hover:bg-slate-800/50"
                            >
                                <Github className="w-5 h-5" />
                                GitHub
                            </a>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Main Content */}
            <main className="flex-grow">
                {children}
            </main>

            {/* Footer */}
            <footer className="bg-slate-950 border-t border-slate-800 py-16">
                <div className="container mx-auto px-6 max-w-7xl">
                    <div className="grid grid-cols-1 md:grid-cols-4 gap-12">
                        <div className="col-span-1 md:col-span-2">
                            <div className="flex items-center gap-3 mb-4">
                                <div className="w-8 h-8 bg-gradient-to-br from-cyan-400 to-blue-600 rounded-lg flex items-center justify-center font-bold text-sm">B</div>
                                <span className="font-bold text-xl">BioMotionPro</span>
                            </div>
                            <p className="text-slate-400 max-w-sm leading-relaxed">
                                Open-source biomechanics analysis for macOS. Built for researchers, clinicians, and engineers who need precision motion capture visualization.
                            </p>
                            <div className="flex gap-4 mt-6">
                                <a href="https://github.com/contact-ajmal/BioMotionPro" className="text-slate-500 hover:text-cyan-400 transition-colors">
                                    <Github className="w-5 h-5" />
                                </a>
                            </div>
                        </div>

                        <div>
                            <h4 className="font-semibold mb-4 text-slate-200">Product</h4>
                            <ul className="space-y-3 text-sm text-slate-400">
                                <li><button onClick={() => onNavigate('features')} className="hover:text-cyan-400 transition-colors">Features</button></li>
                                <li><button onClick={() => onNavigate('download')} className="hover:text-cyan-400 transition-colors">Download</button></li>
                                <li><button onClick={() => onNavigate('docs')} className="hover:text-cyan-400 transition-colors">Documentation</button></li>
                            </ul>
                        </div>

                        <div>
                            <h4 className="font-semibold mb-4 text-slate-200">Resources</h4>
                            <ul className="space-y-3 text-sm text-slate-400">
                                <li><a href="https://github.com/contact-ajmal/BioMotionPro" className="hover:text-cyan-400 transition-colors">Source Code</a></li>
                                <li><a href="https://github.com/contact-ajmal/BioMotionPro/issues" className="hover:text-cyan-400 transition-colors">Report Issues</a></li>
                                <li><a href="https://github.com/contact-ajmal/BioMotionPro/blob/main/LICENSE" className="hover:text-cyan-400 transition-colors">MIT License</a></li>
                            </ul>
                        </div>
                    </div>

                    <div className="mt-12 pt-8 border-t border-slate-800 text-center text-sm text-slate-500">
                        © {new Date().getFullYear()} BioMotionPro. Open Source under MIT License.
                    </div>
                </div>
            </footer>
        </div>
    )
}
