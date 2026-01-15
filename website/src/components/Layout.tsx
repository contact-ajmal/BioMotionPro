import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Menu, X, Github, Download, BookOpen } from 'lucide-react'

interface LayoutProps {
    children: React.ReactNode
    currentPage: string
    onNavigate: (page: string) => void
}

export default function Layout({ children, currentPage, onNavigate }: LayoutProps) {
    const [isScrolled, setIsScrolled] = useState(false)
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false)

    useEffect(() => {
        const handleScroll = () => setIsScrolled(window.scrollY > 20)
        window.addEventListener('scroll', handleScroll)
        return () => window.removeEventListener('scroll', handleScroll)
    }, [])

    return (
        <div className="min-h-screen bg-slate-50 relative flex flex-col">
            {/* Navigation */}
            <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${isScrolled ? 'bg-white/80 backdrop-blur-md shadow-sm py-4' : 'bg-transparent py-6'
                }`}>
                <div className="container mx-auto px-6 max-w-7xl flex items-center justify-between">

                    {/* Logo */}
                    <div
                        className="flex items-center gap-2 cursor-pointer group"
                        onClick={() => onNavigate('home')}
                    >
                        <div className="w-8 h-8 bg-gradient-to-tr from-blue-600 to-cyan-400 rounded-lg flex items-center justify-center text-white font-bold text-lg shadow-lg group-hover:scale-105 transition-transform">
                            B
                        </div>
                        <span className={`text-xl font-bold tracking-tight ${isScrolled ? 'text-slate-900' : 'text-slate-900'}`}>
                            BioMotion<span className="text-blue-600">Pro</span>
                        </span>
                    </div>

                    {/* Desktop Menu */}
                    <div className="hidden md:flex items-center gap-8">
                        <button
                            onClick={() => onNavigate('home')}
                            className={`text-sm font-medium transition-colors hover:text-blue-600 ${currentPage === 'home' ? 'text-blue-600' : 'text-slate-600'}`}
                        >
                            Overview
                        </button>
                        <button
                            onClick={() => onNavigate('docs')}
                            className={`flex items-center gap-2 text-sm font-medium transition-colors hover:text-blue-600 ${currentPage === 'docs' ? 'text-blue-600' : 'text-slate-600'}`}
                        >
                            <BookOpen className="w-4 h-4" />
                            Documentation
                        </button>
                        <a href="https://github.com/contact-ajmal/BioMotionPro" target="_blank" rel="noreferrer" className="text-slate-400 hover:text-slate-900 transition-colors">
                            <Github className="w-5 h-5" />
                        </a>
                        <a
                            href="https://github.com/contact-ajmal/BioMotionPro/releases"
                            className="bg-slate-900 hover:bg-slate-800 text-white px-4 py-2 rounded-lg text-sm font-semibold transition-all hover:scale-105 flex items-center gap-2"
                        >
                            <Download className="w-4 h-4" />
                            Download
                        </a>
                    </div>

                    {/* Mobile Toggle */}
                    <div className="md:hidden">
                        <button onClick={() => setMobileMenuOpen(!mobileMenuOpen)} className="p-2 text-slate-600">
                            {mobileMenuOpen ? <X /> : <Menu />}
                        </button>
                    </div>
                </div>
            </nav>

            {/* Mobile Menu Overlay */}
            <AnimatePresence>
                {mobileMenuOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: -20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        className="fixed inset-0 z-40 bg-white pt-24 px-6 md:hidden"
                    >
                        <div className="flex flex-col gap-6 text-lg font-medium text-slate-900">
                            <button onClick={() => { onNavigate('home'); setMobileMenuOpen(false) }} className="text-left py-2 border-b border-slate-100">Home</button>
                            <button onClick={() => { onNavigate('docs'); setMobileMenuOpen(false) }} className="text-left py-2 border-b border-slate-100">Documentation</button>
                            <a href="https://github.com/contact-ajmal/BioMotionPro" className="text-left py-2 border-b border-slate-100">GitHub</a>
                            <a href="https://github.com/contact-ajmal/BioMotionPro/releases" className="text-blue-600 font-bold py-2">Download App</a>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Main Content */}
            <main className="flex-grow pt-0">
                {children}
            </main>

            {/* Footer */}
            <footer className="bg-slate-900 text-slate-400 py-12">
                <div className="container mx-auto px-6 max-w-7xl grid grid-cols-1 md:grid-cols-4 gap-8">
                    <div className="col-span-1 md:col-span-1">
                        <div className="flex items-center gap-2 text-white mb-4">
                            <div className="w-6 h-6 bg-blue-600 rounded flex items-center justify-center font-bold text-xs">B</div>
                            <span className="font-bold text-lg">BioMotionPro</span>
                        </div>
                        <p className="text-sm">
                            Advanced musculoskeletal analysis for macOS.
                            Built for researchers, clinicians, and engineers.
                        </p>
                    </div>

                    <div>
                        <h4 className="text-white font-semibold mb-4">Product</h4>
                        <ul className="space-y-2 text-sm">
                            <li><button onClick={() => onNavigate('home')} className="hover:text-white transition-colors">Features</button></li>
                            <li><button onClick={() => onNavigate('docs')} className="hover:text-white transition-colors">Documentation</button></li>
                            <li><a href="#" className="hover:text-white transition-colors">Changelog</a></li>
                        </ul>
                    </div>

                    <div>
                        <h4 className="text-white font-semibold mb-4">Resources</h4>
                        <ul className="space-y-2 text-sm">
                            <li><a href="#" className="hover:text-white transition-colors">Example Data</a></li>
                            <li><a href="#" className="hover:text-white transition-colors">Python API</a></li>
                            <li><a href="#" className="hover:text-white transition-colors">Community</a></li>
                        </ul>
                    </div>

                    <div>
                        <h4 className="text-white font-semibold mb-4">Connect</h4>
                        <div className="flex gap-4">
                            <a href="https://github.com/contact-ajmal/BioMotionPro" className="hover:text-white transition-colors"><Github className="w-5 h-5" /></a>
                        </div>
                    </div>
                </div>
                <div className="container mx-auto px-6 max-w-7xl mt-12 pt-8 border-t border-slate-800 text-xs text-center md:text-left">
                    © {new Date().getFullYear()} BioMotionPro. Open Source under MIT License.
                </div>
            </footer>
        </div>
    )
}
