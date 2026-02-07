export default function Footer() {
  return (
    <footer className="py-12 border-t border-white/5">
      <div className="container flex flex-col md:flex-row items-center justify-between gap-4">
        <span className="text-lg font-semibold">Pausely</span>
        
        <div className="flex gap-8 text-sm text-white/50">
          <a href="#" className="hover:text-white transition-colors">Privacy</a>
          <a href="#" className="hover:text-white transition-colors">Terms</a>
          <a href="#" className="hover:text-white transition-colors">Contact</a>
        </div>

        <p className="text-sm text-white/30">2025 Pausely</p>
      </div>
    </footer>
  )
}
