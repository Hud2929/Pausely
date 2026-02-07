export default function Footer() {
  return (
    <footer className="py-16 border-t border-white/5">
      <div className="container flex flex-col md:flex-row items-center justify-between gap-6">
        <span className="text-xl font-semibold">Pausely</span>
        
        <nav className="flex gap-10 text-sm text-white/40">
          <a href="#" className="hover:text-white transition-colors">Privacy</a>
          <a href="#" className="hover:text-white transition-colors">Terms</a>
          <a href="#" className="hover:text-white transition-colors">Contact</a>
          <a href="#" className="hover:text-white transition-colors">Twitter</a>
        </nav>

        <p className="text-sm text-white/20">2025 Pausely. All rights reserved.</p>
      </div>
    </footer>
  )
}
