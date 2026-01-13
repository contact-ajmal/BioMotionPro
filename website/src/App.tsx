import Hero3D from './components/Hero3D'
import Features from './components/Features'

function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-white/80 backdrop-blur-md border-b border-slate-200">
      <div className="container mx-auto px-6 h-16 flex items-center justify-between max-w-7xl">
        <div className="flex items-center gap-3 font-bold text-xl text-slate-900">
          {/* Simple Logo Placeholder */}
          <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white">B</div>
          BioMotionPro
        </div>
        <div className="flex items-center gap-8">
          <a href="#features" className="text-sm font-medium text-slate-600 hover:text-blue-600 transition-colors hidden md:block">Features</a>
          <a href="documentation.html" className="text-sm font-medium text-slate-600 hover:text-blue-600 transition-colors hidden md:block">Documentation</a>
          <a href="https://github.com/contact-ajmal/BioMotionPro" className="text-sm font-medium text-slate-900 hover:text-blue-600 transition-colors">GitHub</a>
        </div>
      </div>
    </nav>
  )
}

function Footer() {
  return (
    <footer className="bg-slate-50 border-t border-slate-200 py-12">
      <div className="container mx-auto px-6 text-center text-slate-500">
        <p>&copy; 2026 BioMotionPro. Open Source under MIT License.</p>
        <p className="mt-2">Designed by Ajmal</p>
      </div>
    </footer>
  )
}

function App() {
  return (
    <div className="font-sans antialiased text-slate-900 bg-white selection:bg-blue-100 selection:text-blue-900">
      <Navbar />
      <Hero3D />
      <Features />
      <Footer />
    </div>
  )
}

export default App
