import { useState, useEffect } from 'react'
import { Menu, X, LayoutDashboard } from 'lucide-react'

interface NavigationProps {
  onGetStarted: () => void
  isAuthenticated?: boolean
}

const navLinks = [
  { name: 'Features', href: '#features' },
  { name: 'Pricing', href: '#pricing' },
]

export default function Navigation({ onGetStarted, isAuthenticated }: NavigationProps) {
  const [isScrolled, setIsScrolled] = useState(false)
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)

  useEffect(() => {
    const handleScroll = () => setIsScrolled(window.scrollY > 50)
    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  const scrollTo = (href: string) => {
    document.querySelector(href)?.scrollIntoView({ behavior: 'smooth' })
    setIsMobileMenuOpen(false)
  }

  return (
    <>
      <nav className={`fixed top-0 left-0 right-0 z-50 transition-all ${isScrolled ? 'glass py-3' : 'py-5'}`}>
        <div className="container flex items-center justify-between">
          <a href="#" className="text-xl font-semibold">Pausely</a>

          <div className="hidden md:flex items-center gap-6">
            {navLinks.map((link) => (
              <button
                key={link.name}
                onClick={() => scrollTo(link.href)}
                className="text-sm text-white/70 hover:text-white transition-colors"
              >
                {link.name}
              </button>
            ))}
            <button 
              onClick={onGetStarted}
              className="btn-primary text-sm py-2.5 px-5 flex items-center gap-2"
            >
              {isAuthenticated ? (
                <>
                  <LayoutDashboard className="w-4 h-4" />
                  Dashboard
                </>
              ) : (
                'Get Started'
              )}
            </button>
          </div>

          <button
            className="md:hidden p-2"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          >
            {isMobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
      </nav>

      {/* Mobile Menu */}
      <div className={`fixed inset-0 z-40 bg-black transition-all md:hidden ${
        isMobileMenuOpen ? 'opacity-100 visible' : 'opacity-0 invisible'
      }`}>
        <div className="flex flex-col items-center justify-center h-full gap-8">
          {navLinks.map((link) => (
            <button
              key={link.name}
              onClick={() => scrollTo(link.href)}
              className="text-2xl font-medium"
            >
              {link.name}
            </button>
          ))}
          <button 
            onClick={() => {
              onGetStarted()
              setIsMobileMenuOpen(false)
            }} 
            className="btn-primary text-lg px-8 py-4 flex items-center gap-2"
          >
            {isAuthenticated ? (
              <>
                <LayoutDashboard className="w-5 h-5" />
                Dashboard
              </>
            ) : (
              'Get Started'
            )}
          </button>
        </div>
      </div>
    </>
  )
}
