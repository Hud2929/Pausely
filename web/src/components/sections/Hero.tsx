import { ArrowRight } from 'lucide-react'

export default function Hero() {
  const scrollToCTA = () => {
    document.querySelector('#cta')?.scrollIntoView({ behavior: 'smooth' })
  }

  return (
    <section className="relative min-h-screen flex items-center justify-center pt-24 pb-32">
      <div className="container relative z-10">
        <div className="max-w-4xl mx-auto text-center">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full glass mb-16">
            <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
            <span className="text-sm text-white/70">Now with AI insights</span>
          </div>

          {/* Headline */}
          <h1 className="headline-xl mb-8">
            Stop overpaying.
          </h1>

          <p className="body-large mb-16 max-w-lg mx-auto">
            Find and optimize your subscriptions. 
            The average user saves $127/month.
          </p>

          {/* CTA */}
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <button onClick={scrollToCTA} className="btn-primary">
              Start Free Trial
              <ArrowRight className="w-5 h-5 ml-2" />
            </button>
            <button onClick={scrollToCTA} className="btn-secondary">
              Learn More
            </button>
          </div>

          {/* Simple Stats - NO FAKE NUMBERS */}
          <div className="mt-32 grid grid-cols-2 md:grid-cols-3 gap-12 max-w-xl mx-auto">
            <div className="text-center">
              <p className="text-4xl font-semibold mb-2">$127</p>
              <p className="text-sm text-white/40">Saved monthly</p>
            </div>
            <div className="text-center">
              <p className="text-4xl font-semibold mb-2">5 min</p>
              <p className="text-sm text-white/40">To start</p>
            </div>
            <div className="text-center col-span-2 md:col-span-1">
              <p className="text-4xl font-semibold mb-2">Free</p>
              <p className="text-sm text-white/40">To try</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
