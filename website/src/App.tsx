import { useState } from 'react'
import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import DocsPage from './pages/DocsPage'
import './App.css'

function App() {
  const [page, setPage] = useState('home')

  return (
    <Layout currentPage={page} onNavigate={setPage}>
      {page === 'home' && <HomePage />}
      {page === 'docs' && <DocsPage />}
    </Layout>
  )
}

export default App
