import { useState } from 'react'
import { motion } from 'framer-motion'
import { ChevronRight, FileText, Terminal, Code, Settings } from 'lucide-react'

const docsContent = [
    {
        id: 'intro',
        title: 'Introduction',
        icon: FileText,
        content: `
      ## Welcome to BioMotionPro
      
      BioMotionPro is a high-performance native macOS application for visualizing and analyzing 3D motion capture data. It is designed for biomechanics researchers, sports scientists, and clinicians who need a fast, reliable tool for gait analysis and kinematics.

      ### Key Features
      - **Native Metal Rendering**: Smooth 60fps+ visualization of skeletal models.
      - **C3D & TRC Support**: Import standard motion capture file formats directly.
      - **Kinematics Analysis**: Real-time calculation of joint angles (Hip, Knee, Ankle, etc.).
      - **Python Integration**: Run custom analysis scripts directly within the app.
    `
    },
    {
        id: 'getting-started',
        title: 'Getting Started',
        icon: Terminal,
        content: `
      ## Installation
      1. Download the latest \`.dmg\` from the [Releases page](https://github.com/contact-ajmal/BioMotionPro/releases).
      2. Drag "BioMotionPro" to your Applications folder.
      3. Double-click to launch.

      ## Your First Analysis
      1. Click "Open File" in the toolbar.
      2. Select a \`.c3d\` or \`.trc\` file.
      3. The 3D view will automatically load the marker data.
      4. If a standard marker set is detected (Plug-in Gait), the skeleton will be auto-generated.
    `
    },
    {
        id: 'scripting',
        title: 'Python Scripting',
        icon: Code,
        content: `
      ## Custom Analysis
      BioMotionPro embeds a Python runner to allow extended analysis. You can access the loaded motion data via the \`biomotion\` module.

      ### Example Script
      \`\`\`python
      import biomotion

      # Get marker data
      markers = biomotion.get_markers()
      
      # Calculate average velocity of R.HEEL
      heel_vel = biomotion.calc_velocity("R.HEEL")
      print(f"Peak Velocity: {max(heel_vel)} m/s")
      \`\`\`
    `
    },
    {
        id: 'advanced',
        title: 'Advanced Settings',
        icon: Settings,
        content: `
      ## Visual Configuration
      You can customize the appearance of markers, bones, and the environment in the **Settings** panel.
      
      - **Marker Size**: Adjust scale for better visibility.
      - **Skeleton Color**: Change color for contrast against background.
      - **Floor Grid**: Toggle grid for spatial reference.
    `
    }
]

export default function DocsPage() {
    const [activeTab, setActiveTab] = useState(docsContent[0].id)

    const activeDoc = docsContent.find(d => d.id === activeTab)

    return (
        <div className="container mx-auto px-6 max-w-7xl py-12 flex flex-col md:flex-row gap-12">
            {/* Sidebar */}
            <aside className="w-full md:w-64 flex-shrink-0">
                <div className="sticky top-24 space-y-2">
                    <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider mb-4 px-4">Documentation</h3>
                    {docsContent.map((doc) => (
                        <button
                            key={doc.id}
                            onClick={() => setActiveTab(doc.id)}
                            className={`w-full flex items-center justify-between px-4 py-3 rounded-lg text-sm font-medium transition-all ${activeTab === doc.id
                                    ? 'bg-blue-50 text-blue-700 shadow-sm'
                                    : 'text-slate-600 hover:bg-slate-100'
                                }`}
                        >
                            <div className="flex items-center gap-3">
                                <doc.icon className={`w-4 h-4 ${activeTab === doc.id ? 'text-blue-600' : 'text-slate-400'}`} />
                                {doc.title}
                            </div>
                            {activeTab === doc.id && <ChevronRight className="w-4 h-4 text-blue-500" />}
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
                    className="bg-white rounded-2xl shadow-sm border border-slate-200 p-8 md:p-12"
                >
                    <div className="prose prose-slate max-w-none prose-headings:font-display prose-headings:tracking-tight prose-a:text-blue-600">
                        {/* Simple Markdown Rendering (Manual for now to avoid huge dependencies) */}
                        {activeDoc?.content.split('\n').map((line, i) => {
                            const cleanLine = line.trim()
                            if (cleanLine.startsWith('### ')) return <h3 key={i} className="text-xl font-bold mt-8 mb-4 border-b border-slate-100 pb-2">{cleanLine.replace('### ', '')}</h3>
                            if (cleanLine.startsWith('## ')) return <h2 key={i} className="text-3xl font-bold mt-0 mb-6">{cleanLine.replace('## ', '')}</h2>
                            if (cleanLine.startsWith('- **')) {
                                const parts = cleanLine.replace('- ', '').split('**:')
                                return <li key={i} className="list-disc ml-4 my-2"><strong>{parts[0].replace('**', '')}</strong>:{parts[1]}</li>
                            }
                            if (cleanLine.startsWith('1. ')) return <li key={i} className="list-decimal ml-4 my-2">{cleanLine.replace('1. ', '')}</li>
                            if (cleanLine.startsWith('```')) return null // Skip code block markers for simple render
                            if (cleanLine.includes(' = ') || cleanLine.startsWith('import') || cleanLine.startsWith('#')) {
                                return <code key={i} className="block bg-slate-900 text-blue-300 p-1 rounded my-1 font-mono text-sm">{cleanLine}</code>
                            }
                            if (cleanLine === '') return <br key={i} />
                            return <p key={i} className="my-2 leading-relaxed text-slate-600">{cleanLine}</p>
                        })}
                    </div>
                </motion.div>
            </main>
        </div>
    )
}
