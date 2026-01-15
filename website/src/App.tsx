import { useState } from 'react'
import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import FeaturesPage from './pages/FeaturesPage'
import DownloadPage from './pages/DownloadPage'
import DocsPage from './pages/DocsPage'
import './App.css'

export type PageType = 'home' | 'features' | 'download' | 'docs'

function App() {
  const [page, setPage] = useState<PageType>('home')

  const renderPage = () => {
    switch (page) {
      case 'home':
        return <HomePage onNavigate={setPage} />
      case 'features':
        return <FeaturesPage />
      case 'download':
        return <DownloadPage />
      case 'docs':
        return <DocsPage />
      default:
        return <HomePage onNavigate={setPage} />
    }
  }

  return (
    <Layout currentPage={page} onNavigate={setPage}>
      {renderPage()}
    </Layout>
  )
}

export default App
