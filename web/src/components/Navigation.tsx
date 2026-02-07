import { useState, useEffect } from 'react'
import { Menu, X } from 'lucide-react'

export default function Navigation() {
  const [isScrolled, setIsScrolled] = useState(false)
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50)
    }
    window.addEventListener('scroll', handleScroll, { passive: true })
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  const navLinks = [
    { name: 'Features', href: '#features' },
    { name: 'How It Works', href: '#how-it-works' },
    { name: 'Pricing', href: '#pricing' },
    { name: 'FAQ', href: '#faq' },
  ]

  const scrollToSection = (href: string) => {
    const element = document.querySelector(href)
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' })
    }
    setIsMobileMenuOpen(false)
  }

  return (
    <>
      <nav
        className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
          isScrolled ? 'glass py-3' : 'bg-transparent py-5'
        }`}
      >
        <div className="container flex items-center justify-between">
          {/* Logo */}
          <a
            href="#"
            className="text-2xl font-bold tracking-tight text-white"
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
          >
            Pausely
          </a>

          {/* Desktop Nav */}
          <div className="hidden md:flex items-center gap-1">
            {navLinks.map((link) => (
              <button
                key={link.name}
                onClick={() => scrollToSection(link.href)}
                className="nav-link"
              >
                {link.name}
              </button>
            ))}
          </div>

          {/* CTA Buttons */}
          <div className="hidden md:flex items-center gap-3">
            <a
              href="#get-started"
              className="btn-secondary text-sm py-2 px-5"
              onClick={(e) => {
                e.preventDefault()
                scrollToSection('#cta')
              }}
            >
              Sign In
            </a>
            <a
              href="#get-started"
              className="btn-primary text-sm py-2 px-5"
              onClick={(e) => {
                e.preventDefault()
                scrollToSection('#cta')
              }}
            >
              Get Started
            </a>
          </div>

          {/* Mobile Menu Button */}
          <button
            className="md:hidden p-2 text-white"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          >
            {isMobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
      </nav>

      {/* Mobile Menu */}
      <div
        className={`fixed inset-0 z-40 bg-black/95 backdrop-blur-xl transition-all duration-300 md:hidden ${
          isMobileMenuOpen ? 'opacity-100 visible' : 'opacity-0 invisible'
        }`}
      >
        <div className="flex flex-col items-center justify-center h-full gap-8">
          {navLinks.map((link) => (
            <button
              key={link.name}
              onClick={() => scrollToSection(link.href)}
              className="text-3xl font-semibold text-white hover:text-blue-400 transition-colors"
            >
              {link.name}
            </button>
          ))}
          <div className="flex flex-col gap-4 mt-8">
            <button
              onClick={() => scrollToSection('#cta')}
              className="btn-secondary text-lg px-8 py-4"
            >
              Sign In
            </button>
            <button
              onClick={() => scrollToSection('#cta')}
              className="btn-primary text-lg px-8 py-4"
            >
              Get Started
            </button>
          </div>
        </div>
      </div>
    </>
  )
}
